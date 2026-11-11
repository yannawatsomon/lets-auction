require "test_helper"

class Bidding::ResultsTest < ActiveSupport::TestCase
  include ActiveJob::TestHelper
  include ActionCable::TestHelper
  ADMIN = MockData.user(1)

  setup do
    OnboardingStore.reset!
    BuyerStanding.reset!
    ProductOnboarding::Store.reset!
    Bidding::OrderStore.reset!
    @a = Auction.create!(title: "S", auction_type: "sealed_first_price", starts_at: 1.hour.from_now, ends_at: 1.day.from_now, created_by_id: 1)
    @item = ProductOnboarding::Store.approved.first
    @lot = @a.add_item!(@item)
    @a.schedule!
    t = (@a.starts_at + 1.minute).change(usec: 0)
    { 21 => 3, 22 => 2, 23 => 1 }.each do |id, extra|
      AuctionParticipant.register!(auction: @a, user: MockData.user(id))
      Bidding::PlaceSealedBid.call(lot: @lot, user: MockData.user(id), amount_text: Baht.format(@lot.min_price_cents + extra * 10_000),
        idempotency_key: "k#{id}", now: t)
    end
    Bidding::CloseAuction.call(auction: @a, now: @a.ends_at)
    @now = @a.ends_at + 1.hour
  end

  def assert_code(code, &)
    e = assert_raises(Bidding::Error, &)
    assert_equal code, e.code
  end

  test "approve offers rank 1 at their own bid for 48 hours, publishes and announces" do
    offers = nil
    assert_broadcast_on(Bidding::Broadcaster.auction_stream(@a), { type: "auction.result_published", auction_id: @a.id }) do
      offers = Bidding::Results.approve!(auction: @a, admin: ADMIN, now: @now)
    end
    assert @a.reload.published?
    o = offers.first
    assert_equal [ 21, 1, @lot.min_price_cents + 30_000 ], [ o.buyer_id, o.rank, o.amount_cents ]
    assert_equal @now + 48.hours, o.payment_due_at
    assert_equal @item.seller_id, o.seller_id
    assert_enqueued_with(job: Bidding::OrderExpireJob, args: [ o.id ], at: o.payment_due_at)
    assert_equal ADMIN.id, AuditLog.find_by(action: "auction.results_approved").actor_id
    assert_code("not_awaiting_approval") { Bidding::Results.approve!(auction: @a, admin: ADMIN, now: @now) }
  end

  test "approving needs a closed auction" do
    b = Auction.create!(title: "B", auction_type: "sealed_first_price", starts_at: 1.hour.from_now, ends_at: 1.day.from_now, created_by_id: 1)
    assert_code("not_awaiting_approval") { Bidding::Results.approve!(auction: b, admin: ADMIN) }
  end

  test "a disqualified winner is skipped; disqualifying needs a reason and must happen before approval" do
    assert_code("reason_required") { Bidding::Results.disqualify!(lot: @lot, user_id: 21, reason: " ", admin: ADMIN) }
    assert_code("not_a_bidder") { Bidding::Results.disqualify!(lot: @lot, user_id: 26, reason: "x", admin: ADMIN) }
    Bidding::Results.disqualify!(lot: @lot, user_id: 21, reason: "ข้อมูลไม่ตรง", admin: ADMIN)
    assert_equal 22, Bidding::Results.approve!(auction: @a, admin: ADMIN, now: @now).first.buyer_id
    assert_code("not_awaiting_approval") { Bidding::Results.disqualify!(lot: @lot, user_id: 22, reason: "x", admin: ADMIN) }
  end

  test "winner doesn't pay in 48 hours → next rank is offered at their own bid" do
    first = Bidding::Results.approve!(auction: @a, admin: ADMIN, now: @now).first
    Bidding::Results.expire!(order_id: first.id, now: first.payment_due_at - 1)
    assert Bidding::OrderStore.find(first.id).awaiting_payment?, "not before the deadline"

    Bidding::Results.expire!(order_id: first.id, now: first.payment_due_at)
    assert_equal "expired", Bidding::OrderStore.find(first.id).status
    second = Bidding::OrderStore.current_for_lot(@lot.id)
    assert_equal [ 22, 2, @lot.min_price_cents + 20_000 ], [ second.buyer_id, second.rank, second.amount_cents ]
    assert_equal first.payment_due_at + 48.hours, second.payment_due_at
  end

  test "winner declines → next rank; only the buyer can decline" do
    first = Bidding::Results.approve!(auction: @a, admin: ADMIN, now: @now).first
    assert_code("not_found") { Bidding::Results.decline!(order_id: first.id, buyer: MockData.user(22), now: @now) }
    Bidding::Results.decline!(order_id: first.id, buyer: MockData.user(21), now: @now)
    assert_equal 22, Bidding::OrderStore.current_for_lot(@lot.id).buyer_id
    assert_code("not_awaiting_payment") { Bidding::Results.decline!(order_id: first.id, buyer: MockData.user(21), now: @now) }
  end

  test "when nobody is left the lot is unsold and the product goes back to approved" do
    o = Bidding::Results.approve!(auction: @a, admin: ADMIN, now: @now).first
    3.times do
      Bidding::Results.decline!(order_id: o.id, buyer: MockData.user(o.buyer_id), now: @now)
      o = Bidding::OrderStore.current_for_lot(@lot.id)
      break unless o
    end
    assert_nil Bidding::OrderStore.current_for_lot(@lot.id)
    assert @lot.reload.unsold?
    assert @item.approved?
  end

  test "marking paid sells the lot and the product (mock until payment records it)" do
    o = Bidding::Results.approve!(auction: @a, admin: ADMIN, now: @now).first
    Bidding::Results.mark_paid!(order_id: o.id, admin: ADMIN, now: @now)
    assert @lot.reload.sold?
    assert @item.sold?
    Bidding::Results.expire!(order_id: o.id, now: o.payment_due_at + 1.day)
    assert Bidding::OrderStore.find(o.id).paid?, "a paid order never expires"
  end

  test "the sweep and the expire job move overdue offers on" do
    o = Bidding::Results.approve!(auction: @a, admin: ADMIN, now: @now).first
    Bidding::AuctionSweepJob.perform_now(now: o.payment_due_at + 1)
    assert_equal 22, Bidding::OrderStore.current_for_lot(@lot.id).buyer_id
    Bidding::OrderExpireJob.perform_now(999_999) # unknown (e.g. lost on restart): harmless
  end
end
