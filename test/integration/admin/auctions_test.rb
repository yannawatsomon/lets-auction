require "test_helper"

class Admin::AuctionsTest < ActionDispatch::IntegrationTest
  ADMIN = 1
  BUYER = 21
  SELLER = 11

  def login(id) = post(mock_session_path(user_id: id))

  def create_auction(type: "sealed_first_price")
    post admin_auctions_path, params: { auction: { title: "Jewellery & Watches", auction_type: type,
      starts_at: 1.day.from_now.strftime("%Y-%m-%dT%H:%M"), ends_at: 2.days.from_now.strftime("%Y-%m-%dT%H:%M") } }
    Auction.last
  end

  test "non-admins and guests get 404" do
    get admin_auctions_path
    assert_response :not_found
    [ BUYER, SELLER ].each do |id|
      login(id)
      get admin_auctions_path
      assert_response :not_found
      post admin_auctions_path, params: { auction: { title: "x" } }
      assert_response :not_found
    end
    assert_equal 0, Auction.count
  end

  test "admin creates a draft, adds items, schedules" do
    login(ADMIN)
    a = create_auction
    assert_redirected_to admin_auction_path(a)
    assert a.draft?
    assert_equal ADMIN, a.created_by_id

    item = MockData.approved_items.first
    post admin_auction_lots_path(a), params: { item_id: item.id }
    assert_equal [ item.id ], a.reload.item_ids

    post schedule_admin_auction_path(a)
    assert a.reload.scheduled?
    follow_redirect!
    assert_select ".flash.notice"
  end

  test "times are read as Bangkok time" do
    login(ADMIN)
    post admin_auctions_path, params: { auction: { title: "t", auction_type: "sealed_first_price",
      starts_at: "2030-01-01T10:00", ends_at: "2030-01-02T10:00" } }
    assert_equal Time.utc(2030, 1, 1, 3, 0), Auction.last.starts_at.utc
  end

  test "invalid form re-renders with errors" do
    login(ADMIN)
    post admin_auctions_path, params: { auction: { title: "", auction_type: "nope",
      starts_at: "2030-01-02T10:00", ends_at: "2030-01-01T10:00" } }
    assert_response :unprocessable_content
    assert_equal 0, Auction.count
  end

  test "english lots need a valid baht increment" do
    login(ADMIN)
    a = create_auction(type: "english")
    item = MockData.approved_items.max_by(&:min_price_cents)

    post admin_auction_lots_path(a), params: { item_id: item.id, bid_increment: "200,000.123" }
    assert_empty a.reload.lots
    assert_match "ขั้นบิด", flash[:alert]

    post admin_auction_lots_path(a), params: { item_id: item.id, bid_increment: "200,000" }
    assert_equal 20_000_000, a.reload.lots.first.bid_increment_cents
  end

  test "cancel requires a reason" do
    login(ADMIN)
    a = create_auction
    post cancel_admin_auction_path(a), params: { cancel_reason: "" }
    assert a.reload.draft?
    post cancel_admin_auction_path(a), params: { cancel_reason: "เลื่อนงาน" }
    assert a.reload.cancelled?
  end

  test "list is paginated and filterable" do
    login(ADMIN)
    get admin_auctions_path(status: "draft", page: 2)
    assert_response :success
    get admin_auctions_path(status: "bogus")
    assert_response :success
  end

  test "show and edit pages render" do
    login(ADMIN)
    a = create_auction(type: "english")
    get admin_auction_path(a)
    assert_response :success
    assert_select "input[name=bid_increment]"
    get edit_admin_auction_path(a)
    assert_response :success
    get new_admin_auction_path
    assert_response :success
    get admin_auctions_path
    assert_select "td", text: /Jewellery/
  end
end
