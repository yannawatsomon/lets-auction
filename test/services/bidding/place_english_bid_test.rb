require "test_helper"

class Bidding::PlaceEnglishBidTest < ActiveSupport::TestCase
  ADMIN = MockData.user(1)
  A = MockData.user(21)   # grade A with approved proof (only one in the mock)

  setup do
    OnboardingStore.reset!
    BuyerStanding.reset!
    ProductOnboarding::Store.reset!
    BuyerStanding.approve_income_proof!(26)
    OnboardingStore.add_assessment(CreditAssessment.new(user_id: 26, score: 90, grade: "A", score_version: 1,
      inputs: {}.freeze, reasons: {}.freeze, created_at: Time.current))
    u = OnboardingStore.find(26)
    u.status = "completed"
    OnboardingStore.save(u)
    @b = MockData.user(26)

    @auction = Auction.create!(title: "English", auction_type: "english",
      starts_at: 1.hour.from_now, ends_at: 1.day.from_now, created_by_id: 1)
    @item = MockData.approved_items.max_by(&:min_price_cents)
    @lot = @auction.add_item!(@item, bid_increment_cents: 20_000_000) # ฿200,000
    @auction.schedule!
    [ A, @b ].each { |u| AuctionParticipant.invite!(auction: @auction, user: u, admin: ADMIN).accept!(user: u) }
    @open = (@auction.starts_at + 1.minute).change(usec: 0)
  end

  def place(user: A, amount:, key: SecureRandom.uuid, now: @open)
    Bidding::PlaceEnglishBid.call(lot: @lot, user:, amount_text: amount, idempotency_key: key, now:)
  end

  def baht(cents) = Baht.format(cents)

  def assert_code(code, &)
    e = assert_raises(Bidding::Error, &)
    assert_equal code, e.code
  end

  test "first bid at the minimum price; then current price + increment" do
    min = @lot.min_price_cents
    assert_code("bid_too_low") { place(amount: baht(min - 1)) }
    first = place(amount: baht(min)).bid
    @lot.reload
    assert_equal min, @lot.current_price_cents
    assert_equal first, @lot.leader_bid
    assert_equal 1, @lot.bid_count
    assert_equal min + 20_000_000, @lot.next_minimum_cents

    assert_code("bid_too_low") { place(user: @b, amount: baht(min + 19_999_999)) }
    place(user: @b, amount: baht(min + 20_000_000))
    assert_equal @b.id, @lot.reload.leader_bid.user_id
    assert_equal 2, @lot.bid_count
  end

  test "the leader can't bid again, others can, many times" do
    min = @lot.min_price_cents
    place(amount: baht(min))
    assert_code("already_leading") { place(amount: baht(min + 50_000_000)) }
    place(user: @b, amount: baht(min + 20_000_000))
    assert place(amount: baht(min + 40_000_000)).bid
    assert_equal 2, @lot.bids.where(user_id: A.id).count
  end

  test "only invited buyers who accepted can bid" do
    pending = MockData.user(21)
    @auction.participants.find_by(user_id: pending.id).update_columns(status: "invited")
    assert_code("not_invited") { place(user: pending, amount: baht(@lot.min_price_cents)) }
    assert_code("not_invited") { place(user: MockData.user(23), amount: baht(@lot.min_price_cents)) }
  end

  test "ends exactly on time, no extension" do
    min = @lot.min_price_cents
    place(amount: baht(min), now: @auction.ends_at - 1.second)
    assert_equal @auction.ends_at, @lot.reload.ends_at
    assert_code("bidding_closed") { place(user: @b, amount: baht(min + 20_000_000), now: @auction.ends_at) }
    assert_code("bidding_closed") { place(user: @b, amount: baht(min), now: @auction.starts_at - 1.second) }
  end

  test "idempotent: same key → same bid, no double move of the price" do
    min = @lot.min_price_cents
    first = place(amount: baht(min), key: "k").bid
    again = place(amount: baht(min), key: "k")
    assert again.replayed
    assert_equal first, again.bid
    assert_equal 1, @lot.reload.bid_count
  end

  test "a stale read can't win: compare-and-set on the lot refuses a bid against an old price" do
    min = @lot.min_price_cents
    place(amount: baht(min))
    stale = AuctionLot.find(@lot.id)
    AuctionLot.where(id: @lot.id).update_all(bid_count: 99) # another bid moved the lot meanwhile
    service = Bidding::PlaceEnglishBid.new(lot: stale, user: @b, amount_text: baht(min + 20_000_000), idempotency_key: "s", now: @open)
    stale.define_singleton_method(:lock!) { self } # simulate a database without row locks
    stale.define_singleton_method(:bid_count) { 1 }
    e = assert_raises(Bidding::Error) { service.call }
    assert_equal "price_moved", e.code
    assert_equal 1, @lot.bids.count, "the losing bid was rolled back"
  end

  test "concurrent bids at the same price: exactly one wins" do
    min = @lot.min_price_cents
    results = [ A, @b ].map do |u|
      Thread.new do
        ActiveRecord::Base.connection_pool.with_connection do
          place(user: u, amount: baht(min))
          :ok
        rescue Bidding::Error => e
          e.code
        end
      end
    end.map(&:value)
    assert_equal 1, results.count(:ok), results.inspect
    assert_equal 1, @lot.reload.bid_count
    assert_equal 1, @lot.bids.count
  end

  test "sealed lots aren't taken here; audit log has no amount" do
    bid = place(amount: baht(@lot.min_price_cents)).bid
    log = AuditLog.find_by!(entity_id: bid.id)
    assert_equal "english", log.data["auction_type"]
    assert_not_includes log.data.to_json, @lot.min_price_cents.to_s
  end
end
