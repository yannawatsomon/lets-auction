require "test_helper"

class BidTest < ActiveSupport::TestCase
  def lot(type: "sealed_first_price")
    a = Auction.create!(title: "งาน", auction_type: type, starts_at: 1.day.from_now, ends_at: 2.days.from_now, created_by_id: 1)
    busy = AuctionLot.where(status: AuctionLot::OPEN_STATUSES).pluck(:item_id)
    pool = MockData.approved_items.reject { |i| busy.include?(i.id) }
    item = type == "english" ? pool.max_by(&:min_price_cents) : pool.min_by(&:min_price_cents)
    a.add_item!(item, bid_increment_cents: (type == "english" ? 1_000_000 : nil))
  end

  def bid(lot, user_id: 21, amount: 2_000_000, key: SecureRandom.uuid, **attrs)
    Bid.create!(lot:, user_id:, amount:, idempotency_key: key, **attrs)
  end

  test "stores satang encrypted and reads it back as an integer" do
    b = bid(lot, amount: 2_050_075)
    assert_equal 2_050_075, b.reload.amount
    raw = Bid.connection.select_value("SELECT amount_cents FROM bids WHERE id = #{b.id}")
    assert_not_includes raw, "2050075", "the amount must not be readable in the database"
    assert_equal 2_050_075, Bid.find(b.id).amount
  end

  test "copies the auction type from the lot" do
    assert bid(lot).sealed_first_price?
    assert bid(lot(type: "english")).english?
  end

  test "amount must be a positive whole number of satang" do
    l = lot
    [ 0, -1 ].each do |bad|
      assert_raises(ActiveRecord::RecordInvalid) { bid(l, amount: bad) }
    end
    b = Bid.new(lot: l, user_id: 21, idempotency_key: "k", amount_cents: "1.5")
    assert_not b.valid?
    assert b.errors[:amount_cents].any?
  end

  test "append-only: a saved bid can't be updated or destroyed" do
    b = bid(lot)
    assert_raises(ActiveRecord::ReadOnlyRecord, Bid::AppendOnly) { b.update!(amount: 1) }
    assert_raises(ActiveRecord::ReadOnlyRecord, Bid::AppendOnly) { b.destroy }
    assert_equal 2_000_000, b.reload.amount
  end

  test "sealed: the database allows one bid per buyer per lot" do
    l = lot
    bid(l, user_id: 21)
    assert_raises(ActiveRecord::RecordNotUnique) { bid(l, user_id: 21) }
    assert bid(l, user_id: 22)
  end

  test "english: a buyer may bid many times on the same lot" do
    l = lot(type: "english")
    bid(l, user_id: 21, amount: 2_000_000_000)
    assert bid(l, user_id: 21, amount: 2_001_000_000)
  end

  test "the same idempotency key can't create a second bid for the same buyer" do
    l = lot(type: "english")
    bid(l, user_id: 21, key: "retry-1")
    assert_raises(ActiveRecord::RecordNotUnique) { bid(l, user_id: 21, key: "retry-1") }
    assert bid(l, user_id: 22, key: "retry-1"), "keys are per buyer"
  end

  test "database checks the auction type and the key" do
    l = lot
    assert_raises(ActiveRecord::StatementInvalid) do
      Bid.new(lot: l, user_id: 21, amount: 1, idempotency_key: "x", auction_type: "dutch").save!(validate: false)
    end
    assert_raises(ActiveRecord::StatementInvalid) do
      Bid.new(lot: l, user_id: 22, amount: 1, idempotency_key: "", auction_type: "sealed_first_price").save!(validate: false)
    end
  end

  test "a bid's type must match its auction" do
    b = Bid.new(lot: lot, user_id: 21, amount: 1, idempotency_key: "k", auction_type: "english")
    assert_not b.valid?
  end

  test "ranking: highest first, ties go to the earliest; english keeps each bidder's best" do
    l = lot(type: "english")
    t = Time.current
    early = bid(l, user_id: 21, amount: 500, created_at: t)
    late = bid(l, user_id: 22, amount: 500, created_at: t + 0.001)
    top = bid(l, user_id: 23, amount: 900, created_at: t + 1)
    low_again = bid(l, user_id: 21, amount: 100, created_at: t + 2)

    assert_equal [ top, early, late, low_again ], Bid.ranking(l.bids.to_a)
    assert_equal [ top, early, late ], Bid.ranking(l.bids.to_a, one_per_user: true)
  end

  test "created_at keeps sub-second precision for tie-breaks" do
    l = lot
    t = Time.zone.parse("2030-01-01 10:00:00.123456")
    assert_equal 123_456, bid(l, created_at: t).reload.created_at.usec
  end

  test "a lot with bids can't be deleted, and a leader bid can be linked" do
    l = lot(type: "english")
    b = bid(l, amount: 2_000_000_000)
    l.update!(leader_bid: b, current_price_cents: b.amount)
    assert_equal b, l.reload.leader_bid
    assert_raises(ActiveRecord::DeleteRestrictionError) { l.destroy }
  end
end
