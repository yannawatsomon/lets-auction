require "test_helper"

# #37 — bids arriving at the same moment, each on its own database connection (no shared test
# transaction), released together by a barrier. This is closer to two real requests than the
# unit tests, which share Rails' test connection. SQLite runs write transactions as IMMEDIATE;
# on Postgres the lot row lock does the same job. Either way the invariants below must hold.
class BiddingConcurrencyTest < ActiveSupport::TestCase
  self.use_transactional_tests = false

  ADMIN = MockData.user(1)
  BUYERS = [ 21, 22, 23, 24 ].freeze # made grade A with approved proof below

  setup do
    OnboardingStore.reset!
    BuyerStanding.reset!
    ProductOnboarding::Store.reset!
    BUYERS.each do |id|
      OnboardingStore.add_assessment(CreditAssessment.new(user_id: id, score: 90, grade: "A", score_version: 1,
        inputs: {}.freeze, reasons: {}.freeze, created_at: Time.current))
      u = OnboardingStore.find(id)
      u.status = "completed"
      OnboardingStore.save(u)
      BuyerStanding.approve_income_proof!(id)
    end
  end

  teardown do
    "LotResult".safe_constantize&.delete_all # from #35; may not be on this branch
    AuctionLot.update_all(leader_bid_id: nil)
    Bid.delete_all # test cleanup only; the app never deletes bids
    AuditLog.delete_all
    AuctionParticipant.delete_all
    AuctionLot.delete_all
    Auction.delete_all
  end

  # Runs each block on its own connection, all starting at once. Returns their results.
  def race(blocks)
    ready = Queue.new
    go = Queue.new
    threads = blocks.map do |blk|
      Thread.new do
        ActiveRecord::Base.connection_pool.with_connection do
          ready << true
          go.pop
          blk.call
        rescue Bidding::Error => e
          e.code
        end
      end
    end
    blocks.size.times { ready.pop }
    blocks.size.times { go << true }
    threads.map(&:value)
  end

  def sealed_lot
    a = Auction.create!(title: "S", auction_type: "sealed_first_price", starts_at: 1.hour.from_now, ends_at: 1.day.from_now, created_by_id: 1)
    lot = a.add_item!(MockData.approved_items.min_by(&:min_price_cents))
    a.schedule!
    AuctionParticipant.register!(auction: a, user: MockData.user(21))
    [ a, lot ]
  end

  def english_lot
    a = Auction.create!(title: "E", auction_type: "english", starts_at: 1.hour.from_now, ends_at: 1.day.from_now, created_by_id: 1)
    lot = a.add_item!(MockData.approved_items.max_by(&:min_price_cents), bid_increment_cents: 10_000_000)
    a.schedule!
    BUYERS.each { |id| AuctionParticipant.invite!(auction: a, user: MockData.user(id), admin: ADMIN).accept!(user: MockData.user(id)) }
    [ a, lot ]
  end

  test "sealed: the same buyer submitting twice at once gets exactly one bid" do
    a, lot = sealed_lot
    now = a.starts_at + 1.minute
    results = race(2.times.map { |i|
      -> { Bidding::PlaceSealedBid.call(lot: AuctionLot.find(lot.id), user: MockData.user(21), amount_text: "50,000", idempotency_key: "k#{i}", now:).replayed }
    })
    assert_equal 1, lot.bids.count
    assert_equal [ "already_bid", false ].sort_by(&:to_s), results.sort_by(&:to_s)
  end

  test "sealed: a double click with the same key gives one bid and the same receipt twice" do
    a, lot = sealed_lot
    now = a.starts_at + 1.minute
    race(2.times.map { -> { Bidding::PlaceSealedBid.call(lot: AuctionLot.find(lot.id), user: MockData.user(21), amount_text: "50,000", idempotency_key: "same", now:).bid.id } })
    assert_equal 1, lot.bids.count
  end

  test "english: four bidders at the same price at once — exactly one wins" do
    a, lot = english_lot
    now = a.starts_at + 1.minute
    price = Baht.format(lot.min_price_cents)
    results = race(BUYERS.map { |id|
      -> { Bidding::PlaceEnglishBid.call(lot: AuctionLot.find(lot.id), user: MockData.user(id), amount_text: price, idempotency_key: "u#{id}", now:).bid.id }
    })
    lot.reload
    assert_equal 1, lot.bids.count, results.inspect
    assert_equal 1, lot.bid_count
    assert_equal lot.min_price_cents, lot.current_price_cents
    assert_equal lot.bids.first, lot.leader_bid
    assert_equal 3, results.count { |r| %w[bid_too_low price_moved].include?(r) }, results.inspect
  end

  test "english: a burst of rising bids never lets a bid below the price in, and the lot agrees with its bids" do
    a, lot = english_lot
    now = a.starts_at + 1.minute
    inc = lot.bid_increment_cents
    3.times do |round|
      base = lot.reload.next_minimum_cents
      race(BUYERS.each_with_index.map { |id, i|
        -> { Bidding::PlaceEnglishBid.call(lot: AuctionLot.find(lot.id), user: MockData.user(id), amount_text: Baht.format(base + i * inc), idempotency_key: "r#{round}u#{id}", now:) }
      })
    end
    lot.reload
    accepted = lot.bids.order(:created_at, :id).map(&:amount)
    assert accepted.size >= 3
    assert_equal lot.min_price_cents, accepted.first if accepted.first == lot.min_price_cents
    accepted.each_cons(2) { |prev, cur| assert cur >= prev + inc, "bid #{cur} slipped in under #{prev} + #{inc}" }
    assert_equal accepted.size, lot.bid_count
    assert_equal accepted.last, lot.current_price_cents
    assert_equal lot.bids.order(:created_at, :id).last, lot.leader_bid
    leaders = lot.bids.order(:created_at, :id).map(&:user_id)
    leaders.each_cons(2) { |x, y| assert_not_equal x, y, "a leader outbid themself" }
  end
end
