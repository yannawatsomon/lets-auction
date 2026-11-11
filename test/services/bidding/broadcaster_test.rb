require "test_helper"

class Bidding::BroadcasterTest < ActiveSupport::TestCase
  include ActionCable::TestHelper

  ADMIN = MockData.user(1)

  setup do
    OnboardingStore.reset!
    BuyerStanding.reset!
    ProductOnboarding::Store.reset!
    # A second grade-A buyer with approved proof of income.
    BuyerStanding.approve_income_proof!(26)
    OnboardingStore.add_assessment(CreditAssessment.new(user_id: 26, score: 90, grade: "A", score_version: 1,
      inputs: {}.freeze, reasons: {}.freeze, created_at: Time.current))
    u = OnboardingStore.find(26)
    u.status = "completed"
    OnboardingStore.save(u)
    @a = MockData.user(21)
    @b = MockData.user(26)
  end

  def english
    auction = Auction.create!(title: "E", auction_type: "english", starts_at: 1.hour.from_now, ends_at: 1.day.from_now, created_by_id: 1)
    lot = auction.add_item!(MockData.approved_items.max_by(&:min_price_cents), bid_increment_cents: 20_000_000)
    auction.schedule!
    [ @a, @b ].each { |u| AuctionParticipant.invite!(auction:, user: u, admin: ADMIN).accept!(user: u) }
    [ auction, lot ]
  end

  def bid(lot, user, cents, now)
    Bidding::PlaceEnglishBid.call(lot:, user:, amount_text: Baht.format(cents), idempotency_key: SecureRandom.uuid, now:)
  end

  test "an English bid broadcasts bid.accepted with a masked leader, and bid.outbid to the old leader only" do
    auction, lot = english
    now = auction.starts_at + 1.minute
    stream = Bidding::Broadcaster.auction_stream(auction)

    assert_broadcasts(stream, 1) { bid(lot, @a, lot.min_price_cents, now) }
    msg = broadcasts(stream).last
    assert_equal "bid.accepted", JSON.parse(msg)["type"]
    assert_equal "ผู้ประมูล 1", JSON.parse(msg)["lot"]["leader"]
    assert_not_includes msg, @a.display_name

    a_stream = Bidding::Broadcaster.user_stream(auction, @a)
    b_stream = Bidding::Broadcaster.user_stream(auction, @b)
    assert_broadcasts(a_stream, 1) do
      assert_no_broadcasts(b_stream) { bid(lot, @b, lot.reload.next_minimum_cents, now) }
    end
    outbid = JSON.parse(broadcasts(a_stream).last)
    assert_equal "bid.outbid", outbid["type"]
    assert_equal lot.reload.current_price_cents, outbid["current_price_cents"]
  end

  test "a refused bid broadcasts nothing" do
    auction, lot = english
    stream = Bidding::Broadcaster.auction_stream(auction)
    assert_no_broadcasts(stream) do
      assert_raises(Bidding::Error) { bid(lot, @a, 1, auction.starts_at + 1.minute) }
    end
  end

  test "sealed bids are never broadcast" do
    auction = Auction.create!(title: "S", auction_type: "sealed_first_price", starts_at: 1.hour.from_now, ends_at: 1.day.from_now, created_by_id: 1)
    lot = auction.add_item!(MockData.approved_items.min_by(&:min_price_cents))
    auction.schedule!
    AuctionParticipant.register!(auction:, user: MockData.user(23))
    assert_no_broadcasts(Bidding::Broadcaster.auction_stream(auction)) do
      Bidding::PlaceSealedBid.call(lot:, user: MockData.user(23), amount_text: Baht.format(lot.min_price_cents),
        idempotency_key: "k", now: auction.starts_at + 1.minute)
    end
  end

  test "lot.closed and auction.result_published are ready for the jobs (#35/#36)" do
    auction, lot = english
    stream = Bidding::Broadcaster.auction_stream(auction)
    assert_broadcast_on(stream, { type: "lot.closed", lot_id: lot.id }) { Bidding::Broadcaster.lot_closed(lot) }
    assert_broadcast_on(stream, { type: "auction.result_published", auction_id: auction.id }) { Bidding::Broadcaster.result_published(auction) }
  end
end
