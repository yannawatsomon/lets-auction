require "test_helper"

class BiddingSealedBidTest < ActionDispatch::IntegrationTest
  setup do
    Bidding::BidsController::RATE_LIMIT_STORE.clear
    OnboardingStore.reset!
    BuyerStanding.reset!
    ProductOnboarding::Store.reset!
    @auction = Auction.create!(title: "งานยื่นซอง", auction_type: "sealed_first_price",
      starts_at: 1.hour.from_now, ends_at: 1.day.from_now, created_by_id: 1)
    @lot = @auction.add_item!(MockData.approved_items.min_by(&:min_price_cents))
    @auction.schedule!
    AuctionParticipant.register!(auction: @auction, user: MockData.user(23))
    AuctionParticipant.register!(auction: @auction, user: MockData.user(22))
  end

  def login(id) = post(mock_session_path(user_id: id))
  def open_now = travel_to(@auction.starts_at + 1.minute)

  test "full HTML flow: form, review (saves nothing), confirm, receipt" do
    open_now
    login(23)
    get bidding_lot_path(@lot)
    assert_select "form[action=?]", review_bidding_lot_bids_path(@lot)
    key = css_select("input[name=idempotency_key]").first["value"]

    post review_bidding_lot_bids_path(@lot), params: { amount: "25000", idempotency_key: key }
    assert_response :success
    assert_select ".bidding-amount-big", /25,000\.00/
    assert_equal 0, Bid.count

    post bidding_lot_bids_path(@lot), params: { amount: "25000", idempotency_key: key, accept_terms: "1" }
    assert_redirected_to bidding_lot_path(@lot)
    follow_redirect!
    assert_select ".bidding-receipt", /25,000\.00/
    assert_select "form[action=?]", review_bidding_lot_bids_path(@lot), count: 0

    # A double submit of the same form is the same bid.
    post bidding_lot_bids_path(@lot), params: { amount: "25000", idempotency_key: key, accept_terms: "1" }
    assert_equal 1, Bid.count
  end

  test "JSON: 201 then 200 for the same Idempotency-Key, errors in the shared shape" do
    open_now
    login(23)
    headers = { "Idempotency-Key" => "abc-123" }
    post bidding_lot_bids_path(@lot, format: :json), params: { amount: "21000", accept_terms: true }, headers: headers
    assert_response :created
    receipt = response.parsed_body["bid"]
    assert_equal 2_100_000, receipt["amount_cents"]

    post bidding_lot_bids_path(@lot, format: :json), params: { amount: "21000", accept_terms: true }, headers: headers
    assert_response :ok
    assert_equal receipt, response.parsed_body["bid"]

    post bidding_lot_bids_path(@lot, format: :json), params: { amount: "22000", accept_terms: true }, headers: { "Idempotency-Key" => "new" }
    assert_response :conflict
    assert_equal "already_bid", response.parsed_body["error"]
    assert response.parsed_body["message"].present?
  end

  test "nobody sees other people's bids or the count, before results" do
    open_now
    login(22)
    post bidding_lot_bids_path(@lot), params: { amount: "77777", idempotency_key: "x", accept_terms: "1" }
    login(23)
    [ bidding_lot_path(@lot), bidding_auction_path(@auction), bidding_bids_path, bidding_auctions_path ].each do |path|
      get path
      assert_not_includes response.body, "77,777", "#{path} leaked an amount"
      assert_no_match(/ซองทั้งหมด\s*\d|ผู้ยื่นซอง\s*\d|\d+\s*ซอง/, response.body, "#{path} leaked a count")
    end
    get bidding_bids_path
    assert_select "tbody tr", count: 0
  end

  test "my bids lists only my own" do
    open_now
    login(22)
    post bidding_lot_bids_path(@lot), params: { amount: "30000", idempotency_key: "a", accept_terms: "1" }
    login(23)
    post bidding_lot_bids_path(@lot), params: { amount: "31000", idempotency_key: "b", accept_terms: "1" }
    get bidding_bids_path
    assert_select "tbody tr", count: 1
    assert_select "tbody", /31,000\.00/
  end

  test "before the start the form is hidden and a countdown shows" do
    login(23)
    get bidding_lot_path(@lot)
    assert_select "[data-controller=bidding-countdown]"
    assert_select "form[action=?]", review_bidding_lot_bids_path(@lot), count: 0
  end

  test "not registered: told to register; guests must log in" do
    open_now
    get bidding_lot_path(@lot)
    assert_select ".bidding-notice--warn", /เข้าสู่ระบบ/
    post bidding_lot_bids_path(@lot, format: :json), params: { amount: "30000" }, headers: { "Idempotency-Key" => "g" }
    assert_response :unauthorized

    login(21)
    get bidding_lot_path(@lot)
    assert_select ".bidding-notice--warn", /ลงทะเบียน/
  end

  test "bid amounts are filtered from the request log" do
    filter = ActiveSupport::ParameterFilter.new(Rails.application.config.filter_parameters)
    assert_equal "[FILTERED]", filter.filter("amount" => "25000")["amount"]
  end
end
