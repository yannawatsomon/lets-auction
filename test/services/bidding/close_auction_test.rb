require "test_helper"

class Bidding::CloseAuctionTest < ActiveSupport::TestCase
  include ActionCable::TestHelper
  ADMIN = MockData.user(1)

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
  end

  teardown { ProductOnboarding::Store.reset! }

  def sealed(items: 1)
    a = Auction.create!(title: "S", auction_type: "sealed_first_price", starts_at: 1.hour.from_now, ends_at: 1.day.from_now, created_by_id: 1)
    busy = AuctionLot.where(status: AuctionLot::OPEN_STATUSES).pluck(:item_id)
    MockData.approved_items.reject { |i| busy.include?(i.id) }.sort_by(&:min_price_cents).first(items).each { |i| a.add_item!(i) }
    a.schedule!
    [ 21, 22, 23 ].each { |id| AuctionParticipant.register!(auction: a, user: MockData.user(id)) }
    a
  end

  def sealed_bid(a, lot, user_id, cents, at)
    Bidding::PlaceSealedBid.call(lot:, user: MockData.user(user_id), amount_text: Baht.format(cents), idempotency_key: SecureRandom.uuid, now: at)
  end

  test "opens on time only, lots go live, and it can run twice" do
    a = sealed
    assert_not Bidding::OpenAuction.call(auction: a, now: a.starts_at - 1.second)
    assert a.reload.scheduled?
    assert Bidding::OpenAuction.call(auction: a, now: a.starts_at)
    assert a.reload.live?
    assert a.lots.all?(&:live?)
    assert_not Bidding::OpenAuction.call(auction: a, now: a.starts_at + 1.minute)
    assert_equal 1, AuditLog.where(action: "auction.opened", entity_id: a.id).count
  end

  test "closes all lots at ends_at, ranks highest first and earliest on ties" do
    a = sealed
    lot = a.lots.first
    t = (a.starts_at + 1.minute).change(usec: 0)
    min = lot.min_price_cents
    late_tie = sealed_bid(a, lot, 22, min + 500, t + 2).bid
    top = sealed_bid(a, lot, 23, min + 900, t + 3).bid
    early_tie = sealed_bid(a, lot, 21, min + 500, t + 1).bid

    assert_not Bidding::CloseAuction.call(auction: a, now: a.ends_at - 0.001)
    assert Bidding::CloseAuction.call(auction: a, now: a.ends_at)
    assert a.reload.awaiting_approval?
    assert lot.reload.closed?
    assert_equal [ top, early_tie, late_tie ], lot.results.map(&:bid)
    assert_equal [ 1, 2, 3 ], lot.results.map(&:rank)
    assert lot.results.all?(&:pending?)
  end

  test "running the close twice changes nothing" do
    a = sealed
    lot = a.lots.first
    sealed_bid(a, lot, 21, lot.min_price_cents, a.starts_at + 1.minute)
    Bidding::CloseAuction.call(auction: a, now: a.ends_at)
    assert_no_difference -> { LotResult.count } do
      Bidding::CloseAuction.call(auction: a, now: a.ends_at + 1.hour)
    end
    assert_equal 1, AuditLog.where(action: "auction.closed", entity_id: a.id).count
  end

  test "a lot with no bids is unsold and its product goes back to approved" do
    a = Auction.create!(title: "S", auction_type: "sealed_first_price", starts_at: 1.hour.from_now, ends_at: 1.day.from_now, created_by_id: 1)
    item = ProductOnboarding::Store.approved.first
    a.add_item!(item)
    a.schedule!
    assert item.in_auction?
    Bidding::CloseAuction.call(auction: a, now: a.ends_at)
    assert a.lots.first.reload.unsold?
    assert item.approved?
    assert a.reload.awaiting_approval?
  end

  test "english: one result per bidder, with their best bid" do
    a = Auction.create!(title: "E", auction_type: "english", starts_at: 1.hour.from_now, ends_at: 1.day.from_now, created_by_id: 1)
    lot = a.add_item!(MockData.approved_items.max_by(&:min_price_cents), bid_increment_cents: 1_000_000)
    a.schedule!
    [ 21, 26 ].each { |id| AuctionParticipant.invite!(auction: a, user: MockData.user(id), admin: ADMIN).accept!(user: MockData.user(id)) }
    t = a.starts_at + 1.minute
    place = ->(id) { Bidding::PlaceEnglishBid.call(lot:, user: MockData.user(id), amount_text: Baht.format(lot.reload.next_minimum_cents), idempotency_key: SecureRandom.uuid, now: t) }
    place.(21); place.(26); best21 = place.(21).bid
    Bidding::CloseAuction.call(auction: a, now: a.ends_at)
    assert_equal [ 21, 26 ], lot.results.map(&:user_id)
    assert_equal best21, lot.results.first.bid
  end

  test "bids are refused after the close, and lot.closed is broadcast after commit" do
    a = sealed
    lot = a.lots.first
    assert_broadcast_on(Bidding::Broadcaster.auction_stream(a), { type: "lot.closed", lot_id: lot.id }) do
      Bidding::CloseAuction.call(auction: a, now: a.ends_at)
    end
    e = assert_raises(Bidding::Error) { sealed_bid(a, lot, 21, lot.min_price_cents, a.ends_at - 1) }
    assert_equal "bidding_closed", e.code
  end

  test "cancelled and draft auctions are never closed" do
    a = sealed
    a.cancel!(reason: "x")
    assert_not Bidding::CloseAuction.call(auction: a.reload, now: a.ends_at)
    assert a.cancelled?
  end
end
