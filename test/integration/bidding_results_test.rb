require "test_helper"

class BiddingResultsTest < ActionDispatch::IntegrationTest
  setup do
    OnboardingStore.reset!
    BuyerStanding.reset!
    ProductOnboarding::Store.reset!
    Bidding::OrderStore.reset!
    @a = Auction.create!(title: "งาน", auction_type: "sealed_first_price", starts_at: 1.hour.from_now, ends_at: 1.day.from_now, created_by_id: 1)
    @lot = @a.add_item!(MockData.approved_items.min_by(&:min_price_cents))
    @a.schedule!
    t = @a.starts_at + 1.minute
    { 21 => "70,000", 22 => "60,000" }.each do |id, amount|
      AuctionParticipant.register!(auction: @a, user: MockData.user(id))
      Bidding::PlaceSealedBid.call(lot: @lot, user: MockData.user(id), amount_text: amount, idempotency_key: "k#{id}", now: t)
    end
  end

  def login(id) = post(mock_session_path(user_id: id))
  def close! = Bidding::CloseAuction.call(auction: @a, now: @a.ends_at)

  test "the admin can't see the ranking before the close" do
    login(1)
    get results_admin_bidding_auction_path(@a)
    assert_redirected_to admin_bidding_auction_path(@a)
  end

  test "after the close the admin sees the ranking (logged) and approves" do
    close!
    login(1)
    get results_admin_bidding_auction_path(@a)
    assert_response :success
    assert_select "tbody tr", 2
    assert_select "tbody tr:first-child td", /70,000\.00/
    assert AuditLog.exists?(action: "auction.results_viewed", entity_id: @a.id, actor_id: 1)
    post approve_results_admin_bidding_auction_path(@a)
    assert @a.reload.published?
    get results_admin_bidding_auction_path(@a)
    assert_select "td", /รอชำระถึง/
  end

  test "non-admins can't open the results admin pages" do
    close!
    login(21)
    get results_admin_bidding_auction_path(@a)
    assert_response :not_found
    post approve_results_admin_bidding_auction_path(@a)
    assert_response :not_found
    assert @a.reload.awaiting_approval?
  end

  test "buyer: 403 not_revealed before publishing, then won / not won with own rank" do
    close!
    login(22)
    get result_bidding_lot_path(@lot, format: :json)
    assert_response :forbidden
    assert_equal "not_revealed", response.parsed_body["error"]
    get result_bidding_lot_path(@lot)
    assert_response :forbidden

    Bidding::Results.approve!(auction: @a, admin: MockData.user(1))
    get result_bidding_lot_path(@lot)
    assert_select "h1", /ไม่ได้รับการประมูล/
    assert_select ".bidding-stat__v", /2 จาก 2/
    assert_not_includes response.body, "70,000.00", "the loser doesn't see the winner's sealed amount"

    login(21)
    get result_bidding_lot_path(@lot)
    assert_select ".bidding-result--win", /70,000\.00/
    offer = Bidding::OrderStore.current_for_lot(@lot.id)
    post decline_bidding_order_path(offer.id)
    assert_equal 22, Bidding::OrderStore.current_for_lot(@lot.id).buyer_id

    login(22)
    get result_bidding_lot_path(@lot)
    assert_select ".bidding-result--win", /อันดับ 2/
  end

  test "a buyer can't decline someone else's offer" do
    close!
    offer = Bidding::Results.approve!(auction: @a, admin: MockData.user(1)).first
    login(22)
    post decline_bidding_order_path(offer.id)
    assert Bidding::OrderStore.find(offer.id).awaiting_payment?
  end

  test "admin marks an offer paid (mock)" do
    close!
    offer = Bidding::Results.approve!(auction: @a, admin: MockData.user(1)).first
    login(1)
    post mark_paid_admin_bidding_order_path(offer.id)
    assert Bidding::OrderStore.find(offer.id).paid?
    assert @lot.reload.sold?
  end
end
