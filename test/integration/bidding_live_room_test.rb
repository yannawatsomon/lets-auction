require "test_helper"

class BiddingLiveRoomTest < ActionDispatch::IntegrationTest
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
    @a = MockData.user(21)
    @b = MockData.user(26)
    @auction = Auction.create!(title: "งาน English", auction_type: "english",
      starts_at: 1.hour.from_now, ends_at: 1.day.from_now, created_by_id: 1)
    @lot = @auction.add_item!(MockData.approved_items.max_by(&:min_price_cents), bid_increment_cents: 20_000_000)
    @auction.schedule!
    [ @a, @b ].each { |x| AuctionParticipant.invite!(auction: @auction, user: x, admin: ADMIN).accept!(user: x) }
    @now = @auction.starts_at + 1.minute
  end

  def login(id) = post(mock_session_path(user_id: id))

  def bid(user, cents, at)
    Bidding::PlaceEnglishBid.call(lot: @lot, user:, amount_text: Baht.format(cents), idempotency_key: SecureRandom.uuid, now: at)
  end

  test "the room wires the live controller with this viewer's masked label" do
    travel_to(@now)
    login(21)
    get bidding_lot_path(@lot)
    assert_select "[data-controller='bidding-live-lot'][data-bidding-live-lot-auction-id-value='#{@auction.id}']"
    assert_select "[data-bidding-live-lot-my-label-value='ผู้ประมูล 1']"
    assert_select "[data-bidding-live-lot-history-url-value=?]", bids_bidding_lot_path(@lot)
    assert_select "[data-bidding-live-lot-target=price]"
    assert_select "[data-bidding-live-lot-target=history] .bidding-hint", /ยังไม่มีการเสนอราคา/
  end

  test "history is newest first, masked, and says คุณ for your own bids" do
    bid(@a, @lot.min_price_cents, @now)
    bid(@b, @lot.reload.next_minimum_cents, @now + 1)
    login(21)
    get bids_bidding_lot_path(@lot, format: :json)
    rows = response.parsed_body["bids"]
    assert_equal [ "ผู้ประมูล 2", "คุณ" ], rows.map { |r| r["bidder"] }
    assert_equal [ false, true ], rows.map { |r| r["mine"] }
    assert_not_includes response.body, @b.display_name

    get bids_bidding_lot_path(@lot)
    assert_select ".bidding-history__row", 2
    assert_select ".bidding-history__row--mine", 1
  end

  test "history pages through 20 at a time" do
    25.times { |i| Bid.create!(lot: @lot, user_id: [ 21, 26 ][i % 2], amount: 2_000_000_000 + i, idempotency_key: "k#{i}", created_at: @now + i) }
    login(21)
    get bids_bidding_lot_path(@lot, format: :json)
    assert_equal 20, response.parsed_body["bids"].size
    assert response.parsed_body["next_page"]
    get bids_bidding_lot_path(@lot, format: :json, page: 2)
    assert_equal 5, response.parsed_body["bids"].size
  end

  test "history is 404 for sealed lots and for people who aren't invited" do
    login(23)
    get bids_bidding_lot_path(@lot, format: :json)
    assert_response :not_found

    sealed = Auction.create!(title: "S", auction_type: "sealed_first_price", starts_at: 1.hour.from_now, ends_at: 1.day.from_now, created_by_id: 1)
    lot = sealed.add_item!(MockData.approved_items.min_by(&:min_price_cents))
    sealed.schedule!
    login(1)
    get bids_bidding_lot_path(lot, format: :json)
    assert_response :not_found
  end

  test "the leader sees 'you're leading' and no form; the other bidder sees the form at the next minimum" do
    bid(@a, @lot.min_price_cents, @now)
    travel_to(@now + 1.minute)
    login(21)
    get bidding_lot_path(@lot)
    assert_select "[data-bidding-live-lot-target=leading]:not([hidden])"
    assert_select "form[data-bidding-live-lot-target=form][hidden]"

    login(26)
    get bidding_lot_path(@lot)
    assert_select "[data-bidding-live-lot-target=leading][hidden]"
    assert_select "input[name=amount][value=?]", Baht.format(@lot.reload.next_minimum_cents)
    assert_select "[data-bidding-live-lot-target=leader]", /ผู้ประมูล 1/
  end
end
