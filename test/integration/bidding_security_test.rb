require "test_helper"

# #37 — the riskiest bidding rules, checked from the outside (docs/decision/bidding.md,
# .claude/skills/security-review). Rules already covered closer to the code are listed at the
# bottom so this file stays the index of what is protected.
class BiddingSecurityTest < ActionDispatch::IntegrationTest
  ADMIN = MockData.user(1)
  SECRET_A = "98,765.43" # buyer 22's sealed bid
  SECRET_B = "87,654.32" # buyer 23's sealed bid

  setup do
    OnboardingStore.reset!
    BuyerStanding.reset!
    ProductOnboarding::Store.reset!
    Bidding::BidsController::RATE_LIMIT_STORE.clear
    @auction = Auction.create!(title: "งานลับ", auction_type: "sealed_first_price",
      starts_at: 1.hour.from_now, ends_at: 1.day.from_now, created_by_id: 1)
    @lot = @auction.add_item!(MockData.approved_items.min_by(&:min_price_cents))
    @auction.schedule!
    [ 21, 22, 23 ].each { |id| AuctionParticipant.register!(auction: @auction, user: MockData.user(id)) }
    @open = @auction.starts_at + 1.minute
    { 22 => SECRET_A, 23 => SECRET_B }.each do |id, amount|
      Bidding::PlaceSealedBid.call(lot: @lot, user: MockData.user(id), amount_text: amount, idempotency_key: "k#{id}", now: @open)
    end
  end

  def login(id) = post(mock_session_path(user_id: id))

  def assert_no_secret(body, where)
    [ SECRET_A, SECRET_B, Baht.parse(SECRET_A).to_s, Baht.parse(SECRET_B).to_s ].each do |secret|
      assert_not_includes body, secret, "#{where} leaked a sealed amount"
    end
    # Two sealed bids exist on this lot: "2 ซอง", "2 ราย", "ผู้ยื่นซองแล้ว 2" would leak the count.
    text = body.gsub(/<[^>]+>/, " ").squish
    assert_no_match(/(?<![\d,.])2\s*(ซอง|ราย)|ผู้ยื่นซองแล้ว|จำนวนซอง\s*\d/, text, "#{where} leaked a bid count")
  end

  # --- Sealed secrecy: every page, feed, socket message and log ---------------------------

  test "the leak detector itself catches amounts and counts" do
    [ "<p>฿ #{SECRET_A}</p>", "<td>#{Baht.parse(SECRET_B)}</td>", "<span>มีผู้ยื่น 2 ราย</span>", "<b>2</b> ซอง", "ผู้ยื่นซองแล้ว" ].each do |leak|
      assert_raises(Minitest::Assertion, leak) { assert_no_secret(leak, "sample") }
    end
    assert_no_secret("<p>ยื่นซองได้ 1 ครั้ง · ล็อต 2 · 12 ล็อต</p>", "harmless")
  end

  test "no page shows another buyer's sealed amount or the bid count, for buyers, guests, sellers and admins" do
    travel_to(@open + 1.minute)
    pages = -> {
      [ root_path, bidding_auctions_path, bidding_auction_path(@auction), bidding_lot_path(@lot),
        bidding_bids_path, bidding_invitations_path ]
    }
    [ nil, 21, 11, 1 ].each do |who|
      who ? login(who) : delete(mock_session_path)
      pages.call.each do |path|
        get path
        next if response.status == 302 # guests are sent to log in for "mine" pages
        assert_no_secret(response.body, "#{path} as #{who || 'guest'}")
      end
    end
    login(1)
    [ admin_bidding_auctions_path, admin_bidding_auction_path(@auction) ].each do |path|
      get path
      assert_no_secret(response.body, "#{path} as admin before close")
    end
  end

  test "the sealed lot has no public history endpoint and the socket state carries no bid data" do
    login(21)
    get bids_bidding_lot_path(@lot, format: :json)
    assert_response :not_found
    state = Bidding::Broadcaster.lot_state(@auction).to_json
    assert_no_secret(state, "lot.state")
    assert_not_includes state, "bid_count"
  end

  test "catalog feed, audit log and request log never carry sealed amounts" do
    assert_no_secret(Bidding::CatalogFeed.call(viewer: MockData.user(21)).map(&:to_h).to_json, "catalog feed")
    assert_no_secret(AuditLog.where(entity_type: "Bid").pluck(:data).to_json, "audit log")
    filter = ActiveSupport::ParameterFilter.new(Rails.application.config.filter_parameters)
    assert_equal "[FILTERED]", filter.filter("amount" => SECRET_A)["amount"]
  end

  test "a buyer's own receipt shows only their own amount" do
    travel_to(@open + 1.minute)
    login(22)
    get bidding_lot_path(@lot)
    assert_includes response.body, SECRET_A
    assert_not_includes response.body, SECRET_B
    get bidding_bids_path
    assert_includes response.body, SECRET_A
    assert_not_includes response.body, SECRET_B
  end

  # --- Output escaping (stored XSS) ---------------------------------------------------------

  test "titles typed by admins are escaped on buyer pages" do
    @auction.update_columns(title: "<script>alert(1)</script>")
    travel_to(@open)
    login(21)
    [ bidding_auctions_path, bidding_auction_path(@auction), bidding_lot_path(@lot) ].each do |path|
      get path
      assert_not_includes response.body, "<script>alert(1)</script>", path
      assert_includes response.body, "&lt;script&gt;alert(1)&lt;/script&gt;", path
    end
  end

  # --- Abuse ---------------------------------------------------------------------------------

  test "bidding is rate limited per buyer, with the shared error shape" do
    travel_to(@open)
    login(21)
    Bidding::BidsController::RATE_LIMIT.times do |i|
      post review_bidding_lot_bids_path(@lot), params: { amount: "1", idempotency_key: "r#{i}" }
    end
    post bidding_lot_bids_path(@lot, format: :json), params: { amount: "50000" }, headers: { "Idempotency-Key" => "late" }
    assert_response :too_many_requests
    assert_equal "rate_limited", response.parsed_body["error"]
    assert_equal 0, @lot.bids.where(user_id: 21).count
  end

  # Covered elsewhere (kept here as the index for #37):
  # - sealed: one bid per buyer per lot, DB index ........ test/models/bid_test.rb, place_sealed_bid_test.rb
  # - same Idempotency-Key → same response (201 then 200)  test/integration/bidding_sealed_bid_test.rb
  # - refused at/after ends_at, even by a millisecond ...... test/services/bidding/place_*_bid_test.rb
  # - ties go to the earliest bid .......................... place_sealed_bid_test.rb, close_auction_test.rb (#35)
  # - the seller can't take part in their own lot ......... auction_participant_test.rb (own_item)
  # - English: compare-and-set refuses a stale price ....... place_english_bid_test.rb
  # - no extensions: lots end at ends_at .................. place_english_bid_test.rb
  # - real concurrency with separate DB connections ....... test/integration/bidding_concurrency_test.rb
  # - winner doesn't pay → next rank ...................... #36 (not built yet)
end
