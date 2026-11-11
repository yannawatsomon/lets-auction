require "test_helper"

# #37: admins do all checking (bidding.md), so every admin and participation action leaves a
# trail with who, what and when — and never a bid amount.
class BiddingAuditTest < ActionDispatch::IntegrationTest
  setup do
    OnboardingStore.reset!
    BuyerStanding.reset!
    ProductOnboarding::Store.reset!
  end

  def login(id) = post(mock_session_path(user_id: id))
  def actions_for(entity) = AuditLog.where(entity_type: entity.class.name, entity_id: entity.id).order(:id).pluck(:action)

  test "building, scheduling and cancelling an auction are logged with the admin as actor" do
    login(1)
    post admin_bidding_auctions_path, params: { auction: { title: "งาน", auction_type: "english",
      starts_at: 1.day.from_now.strftime("%Y-%m-%dT%H:%M"), ends_at: 2.days.from_now.strftime("%Y-%m-%dT%H:%M") } }
    a = Auction.last
    post admin_bidding_auction_lots_path(a), params: { item_id: MockData.approved_items.max_by(&:min_price_cents).id, bid_increment: "100,000" }
    post schedule_admin_bidding_auction_path(a)
    post admin_bidding_auction_invitations_path(a, user_id: 21)
    inv = a.participants.find_by!(user_id: 21)
    post revoke_admin_bidding_auction_invitation_path(a, inv)
    post cancel_admin_bidding_auction_path(a), params: { cancel_reason: "ผู้ขายถอน" }

    assert_equal %w[auction.created auction.lot_added auction.scheduled auction.cancelled], actions_for(a)
    assert_equal %w[participant.invited participant.revoked], actions_for(inv)
    assert AuditLog.where(entity_type: %w[Auction AuctionParticipant]).all? { |l| l.actor_id == 1 }
    assert_equal "ผู้ขายถอน", AuditLog.find_by(action: "auction.cancelled").data["reason"]
  end

  test "a buyer registering or accepting is logged once" do
    a = Auction.create!(title: "S", auction_type: "sealed_first_price", starts_at: 1.hour.from_now, ends_at: 1.day.from_now, created_by_id: 1)
    a.add_item!(MockData.approved_items.min_by(&:min_price_cents))
    a.schedule!
    login(23)
    2.times { post bidding_auction_registration_path(a) }
    p = a.participants.find_by!(user_id: 23)
    assert_equal %w[participant.registered], actions_for(p)
    assert_equal 23, AuditLog.find_by(action: "participant.registered").actor_id
  end

  test "long text is refused" do
    login(1)
    post admin_bidding_auctions_path, params: { auction: { title: "x", description: "ก" * 2001, auction_type: "sealed_first_price",
      starts_at: 1.day.from_now.strftime("%Y-%m-%dT%H:%M"), ends_at: 2.days.from_now.strftime("%Y-%m-%dT%H:%M") } }
    assert_response :unprocessable_content
    a = Auction.create!(title: "S", auction_type: "sealed_first_price", starts_at: 1.hour.from_now, ends_at: 1.day.from_now, created_by_id: 1)
    assert_raises(Auction::Error) { a.cancel!(reason: "ก" * 501) }
  end
end
