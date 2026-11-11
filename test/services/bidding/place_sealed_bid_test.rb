require "test_helper"

class Bidding::PlaceSealedBidTest < ActiveSupport::TestCase
  BUYER = MockData.user(23)     # grade C (OnboardingStore)
  OTHER = MockData.user(22)     # grade B

  setup do
    OnboardingStore.reset!
    BuyerStanding.reset!
    ProductOnboarding::Store.reset!
    @auction = Auction.create!(title: "งาน", auction_type: "sealed_first_price",
      starts_at: 1.hour.from_now, ends_at: 1.day.from_now, created_by_id: 1)
    item = MockData.approved_items.min_by(&:min_price_cents)
    @lot = @auction.add_item!(item)
    @auction.schedule!
    AuctionParticipant.register!(auction: @auction, user: BUYER)
    AuctionParticipant.register!(auction: @auction, user: OTHER)
    @open = (@auction.starts_at + 1.minute).change(usec: 0)
  end

  def place(user: BUYER, amount: "20,000", key: SecureRandom.uuid, now: @open, accept: true, lot: @lot)
    Bidding::PlaceSealedBid.call(lot:, user:, amount_text: amount, idempotency_key: key, accept_terms: accept, now:)
  end

  def assert_code(code, &)
    e = assert_raises(Bidding::Error, &)
    assert_equal code, e.code
    e
  end

  test "places one encrypted bid, at server time, with an audit log that has no amount" do
    result = place(amount: "20,000.50")
    bid = result.bid
    assert_not result.replayed
    assert_equal 2_000_050, bid.amount
    assert_equal @open, bid.created_at
    log = AuditLog.find_by!(action: "bid.placed", entity_id: bid.id)
    assert_equal BUYER.id, log.actor_id
    assert_not_includes log.data.to_json, "2000050"
  end

  test "audit logs are append-only" do
    log = AuditLog.find_by!(entity_id: place.bid.id)
    assert_raises(ActiveRecord::ReadOnlyRecord, AuditLog::AppendOnly) { log.update!(action: "x") }
    assert_raises(ActiveRecord::ReadOnlyRecord, AuditLog::AppendOnly) { log.destroy }
  end

  test "a second bid on the same lot is refused, even with a new key" do
    place
    assert_code("already_bid") { place(amount: "30,000") }
    assert_equal 1, @lot.bids.count
  end

  test "the same key returns the same bid; reusing it differently is a conflict" do
    first = place(key: "k-1").bid
    again = place(key: "k-1")
    assert again.replayed
    assert_equal first, again.bid
    assert_code("idempotency_conflict") { place(key: "k-1", amount: "99,999") }
    assert_equal 1, Bid.count
  end

  test "a key is required" do
    assert_code("idempotency_key_required") { place(key: " ") }
  end

  test "only registered buyers may bid" do
    assert_code("not_registered") { place(user: MockData.user(21)) } # grade A, not registered
    assert_code("not_registered") { place(user: MockData.user(11)) } # a seller
  end

  test "server time decides: not before the start, not at or after the end" do
    assert_code("bidding_closed") { place(now: @auction.starts_at - 1.second) }
    assert_code("bidding_closed") { place(now: @auction.ends_at) }
    assert_code("bidding_closed") { place(now: @auction.ends_at + 1.second) }
    assert place(now: @auction.ends_at - 0.001).bid
  end

  test "cancelled auctions take no bids" do
    @auction.update_columns(status: "cancelled", cancel_reason: "x")
    assert_code("bidding_closed") { place }
  end

  test "amount must be valid and at least the minimum price" do
    assert_code("amount_invalid") { place(amount: "abc") }
    assert_code("amount_invalid") { place(amount: "100.123") }
    assert_code("amount_invalid") { place(amount: "0") }
    min = @lot.min_price_cents
    assert_code("amount_below_start") { place(amount: Baht.format(min - 1)) }
    assert_equal min, place(amount: Baht.format(min)).bid.amount
  end

  test "terms must be accepted" do
    assert_code("terms_not_accepted") { place(accept: false) }
  end

  test "english lots are not taken here" do
    english = Auction.create!(title: "E", auction_type: "english", starts_at: 1.hour.from_now, ends_at: 1.day.from_now, created_by_id: 1)
    lot = english.add_item!(MockData.approved_items.max_by(&:min_price_cents), bid_increment_cents: 100)
    assert_code("wrong_auction_type") { place(lot:) }
  end

  test "ties: same amount, the earlier bid ranks first" do
    later = place(user: OTHER, amount: "20,000", now: @open + 0.001).bid
    earlier = place(user: BUYER, amount: "20,000", now: @open).bid
    assert_equal [ earlier, later ], Bid.ranking(@lot.bids.to_a)
  end
end
