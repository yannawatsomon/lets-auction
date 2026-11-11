require "test_helper"

class BiddingEnglishBidTest < ActionDispatch::IntegrationTest
  setup do
    OnboardingStore.reset!
    BuyerStanding.reset!
    ProductOnboarding::Store.reset!
    @auction = Auction.create!(title: "งาน English", auction_type: "english",
      starts_at: 1.hour.from_now, ends_at: 1.day.from_now, created_by_id: 1)
    @lot = @auction.add_item!(MockData.approved_items.max_by(&:min_price_cents), bid_increment_cents: 20_000_000)
    @auction.schedule!
    AuctionParticipant.invite!(auction: @auction, user: MockData.user(21), admin: MockData.user(1)).accept!(user: MockData.user(21))
  end

  def login(id) = post(mock_session_path(user_id: id))

  test "invited buyer sees price, next minimum and count, bids, and is shown as leader" do
    travel_to(@auction.starts_at + 1.minute)
    login(21)
    get bidding_lot_path(@lot)
    assert_select ".bidding-amount-big", /#{Regexp.escape(Baht.format(@lot.min_price_cents))}/
    assert_select "input[name=amount][value=?]", Baht.format(@lot.min_price_cents)
    key = css_select("input[name=idempotency_key]").first["value"]

    post bidding_lot_bids_path(@lot), params: { amount: Baht.format(@lot.min_price_cents), idempotency_key: key }
    assert_response :see_other
    follow_redirect!
    assert_select ".bidding-ok-title", /ผู้นำ/
    assert_select "form[data-bidding-live-lot-target=form][hidden] input[name=amount]" # hidden while leading; shown again live when outbid (#34)
    assert_equal 1, @lot.reload.bid_count
  end

  test "JSON errors: too low, leading, closed" do
    travel_to(@auction.starts_at + 1.minute)
    login(21)
    post bidding_lot_bids_path(@lot, format: :json), params: { amount: "1" }, headers: { "Idempotency-Key" => "a" }
    assert_equal "bid_too_low", response.parsed_body["error"]

    post bidding_lot_bids_path(@lot, format: :json), params: { amount: Baht.format(@lot.min_price_cents) }, headers: { "Idempotency-Key" => "b" }
    assert_response :created
    post bidding_lot_bids_path(@lot, format: :json), params: { amount: Baht.format(@lot.min_price_cents * 2) }, headers: { "Idempotency-Key" => "c" }
    assert_equal "already_leading", response.parsed_body["error"]

    travel_to(@auction.ends_at + 1.second) # travel_to drops sub-seconds
    post bidding_lot_bids_path(@lot, format: :json), params: { amount: Baht.format(@lot.min_price_cents * 2) }, headers: { "Idempotency-Key" => "d" }
    assert_equal "bidding_closed", response.parsed_body["error"], response.body
  end

  test "people who aren't invited get 404 for the lot and can't bid" do
    travel_to(@auction.starts_at + 1.minute)
    login(23)
    get bidding_lot_path(@lot)
    assert_response :not_found
    post bidding_lot_bids_path(@lot, format: :json), params: { amount: "1" }, headers: { "Idempotency-Key" => "x" }
    assert_response :not_found
    assert_equal 0, Bid.count
  end
end
