require "test_helper"

class BiddingParticipationTest < ActionDispatch::IntegrationTest
  # Grades: db/mock/user_onboardings.yml (21 A … 25 E, 26 not started); proof: 21 only.
  setup do
    OnboardingStore.reset!
    BuyerStanding.reset!
  end

  teardown { BuyerStanding.reset! }

  def login(id) = post(mock_session_path(user_id: id))

  def auction(type: "sealed_first_price")
    a = Auction.create!(title: "งานทดสอบ", auction_type: type, starts_at: 1.day.from_now, ends_at: 2.days.from_now, created_by_id: 1)
    busy = AuctionLot.where(status: AuctionLot::OPEN_STATUSES).pluck(:item_id)
    pool = MockData.approved_items.reject { |i| busy.include?(i.id) }
    item = type == "english" ? pool.max_by(&:min_price_cents) : pool.min_by(&:min_price_cents)
    a.add_item!(item, bid_increment_cents: (type == "english" ? 20_000_000 : nil))
    a.schedule!
    a
  end

  test "guest is sent to login; JSON gets 401 with the shared error shape" do
    a = auction
    post bidding_auction_registration_path(a)
    assert_redirected_to new_mock_session_path
    post bidding_auction_registration_path(a, format: :json)
    assert_response :unauthorized
    assert_equal "login_required", response.parsed_body["error"]
  end

  test "sealed: eligible buyer sees it before pressing, then registers" do
    a = auction
    login(23)
    get bidding_auction_path(a)
    assert_select ".bidding-notice--ok", /คุณมีสิทธิ์เข้าร่วม/
    post bidding_auction_registration_path(a)
    assert_redirected_to bidding_auction_path(a)
    assert a.participants.find_by(user_id: 23).registered?
  end

  test "sealed: grade E sees why and gets the error code in JSON" do
    a = auction
    login(25)
    get bidding_auction_path(a)
    assert_select ".bidding-notice--warn", /เกรดเครดิต/
    assert_select "form[action=?]", bidding_auction_registration_path(a), count: 0
    post bidding_auction_registration_path(a, format: :json)
    assert_response :forbidden
    assert_equal({ "error" => "grade_not_allowed", "message" => "เกรดเครดิตของคุณยังเข้าร่วมการประมูลไม่ได้" }, response.parsed_body)
  end

  test "english: page is 404 until invited; admin invites; buyer accepts" do
    a = auction(type: "english")
    login(21)
    get bidding_auction_path(a)
    assert_response :not_found

    login(1)
    get admin_bidding_auction_path(a)
    assert_select "form[action=?]", admin_bidding_auction_invitations_path(a, user_id: 21)
    assert_select "form[action=?]", admin_bidding_auction_invitations_path(a, user_id: 22), count: 0
    post admin_bidding_auction_invitations_path(a, user_id: 21)
    assert_equal "invited", a.participants.find_by(user_id: 21).status

    login(21)
    get bidding_invitations_path
    inv = a.participants.find_by(user_id: 21)
    assert_select "form[action=?]", accept_bidding_invitation_path(inv)
    post accept_bidding_invitation_path(inv)
    assert_redirected_to bidding_auction_path(a)
    assert inv.reload.accepted?
  end

  test "admin can't invite a grade A buyer whose proof is pending" do
    a = auction(type: "english")
    BuyerStanding.revoke_income_proof!(21)
    login(1)
    post admin_bidding_auction_invitations_path(a, user_id: 21)
    assert_match "หลักฐานรายได้", flash[:alert]
    assert_equal 0, a.participants.count
  end

  test "a buyer can't accept someone else's invitation (IDOR)" do
    a = auction(type: "english")
    inv = AuctionParticipant.invite!(auction: a, user: MockData.user(21), admin: MockData.user(1))
    login(22)
    post accept_bidding_invitation_path(inv)
    assert_response :not_found
    assert inv.reload.invited?
  end

  test "non-admins can't invite or revoke" do
    a = auction(type: "english")
    login(21)
    post admin_bidding_auction_invitations_path(a, user_id: 21)
    assert_response :not_found
    assert_equal 0, a.participants.count
  end

  test "admin revokes a registration" do
    a = auction
    p = AuctionParticipant.register!(auction: a, user: MockData.user(23))
    login(1)
    post revoke_admin_bidding_auction_invitation_path(a, p)
    assert p.reload.revoked?
  end

  test "buyer list shows sealed events only" do
    sealed = auction
    english = auction(type: "english")
    get bidding_auctions_path
    assert_select "a[href=?]", bidding_auction_path(sealed)
    assert_select "a[href=?]", bidding_auction_path(english), count: 0
  end
end
