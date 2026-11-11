require "test_helper"

class AuctionTest < ActiveSupport::TestCase
  setup do
    @sealed_items = MockData.approved_items.select { |i| i.min_price_cents <= 2_000_000 }
  end

  def build(**attrs)
    Auction.create!({ title: "งานทดสอบ", auction_type: "sealed_first_price",
      starts_at: 1.day.from_now, ends_at: 2.days.from_now, created_by_id: 1 }.merge(attrs))
  end

  test "english is always invite only" do
    a = build(auction_type: "english")
    assert a.visibility_invite_only?
  end

  test "database refuses english + public even if the model is bypassed" do
    a = build(auction_type: "english")
    assert_raises(ActiveRecord::StatementInvalid) { a.update_columns(visibility: "public") }
  end

  test "ends must be after starts" do
    a = Auction.new(title: "x", auction_type: "sealed_first_price", starts_at: 2.days.from_now, ends_at: 1.day.from_now, created_by_id: 1)
    assert_not a.valid?
    assert a.errors[:ends_at].any?
  end

  test "add item snapshots the minimum price and numbers lots" do
    a = build
    lot = a.add_item!(@sealed_items.first)
    assert_equal 1, lot.lot_no
    assert_equal @sealed_items.first.min_price_cents, lot.min_price_cents
    assert_equal a.ends_at, lot.original_ends_at
    assert_nil lot.bid_increment_cents
  end

  test "only approved items can be added" do
    pending = MockData.items.find { |i| !i.approved? }
    assert_raises(Auction::Error) { build.add_item!(pending) }
  end

  test "an item can be in only one unfinished lot" do
    item = @sealed_items.first
    build.add_item!(item)
    assert_raises(Auction::Error) { build.add_item!(item) }
  end

  test "an item in a cancelled auction can be added again" do
    item = @sealed_items.first
    first = build
    first.add_item!(item)
    first.cancel!(reason: "ทดสอบ")
    assert build.add_item!(item)
  end

  test "at most 10 lots, enforced by the database too" do
    a = build
    10.times { |n| a.lots.create!(item_id: 1000 + n, lot_no: n + 1, min_price_cents: 100, ends_at: a.ends_at, original_ends_at: a.ends_at) }
    assert a.reload.lots_full?
    assert_raises(Auction::Error) { a.add_item!(@sealed_items.first) }
    eleventh = AuctionLot.new(auction: a, item_id: 2000, lot_no: 11, min_price_cents: 100, ends_at: a.ends_at, original_ends_at: a.ends_at)
    assert_raises(ActiveRecord::StatementInvalid) { eleventh.save!(validate: false) }
  end

  test "removing a lot frees its number" do
    a = build
    l1 = a.add_item!(@sealed_items[0])
    a.add_item!(@sealed_items[1])
    a.remove_lot!(l1)
    assert_equal 1, a.add_item!(@sealed_items[2]).lot_no
  end

  test "schedule needs a lot, a future start, and increments for english" do
    a = build
    assert_raises(Auction::Error) { a.schedule! }

    a.add_item!(@sealed_items.first)
    assert_raises(Auction::Error) { a.schedule!(now: a.starts_at + 1.minute) }

    a.schedule!
    assert a.reload.scheduled?
    assert a.scheduled_at

    e = build(auction_type: "english")
    big = MockData.approved_items.max_by(&:min_price_cents)
    e.lots.create!(item_id: big.id, lot_no: 1, min_price_cents: big.min_price_cents, ends_at: e.ends_at, original_ends_at: e.ends_at)
    assert_raises(Auction::Error) { e.schedule! }
  end

  test "only drafts can be edited or get items" do
    a = build
    a.add_item!(@sealed_items.first)
    a.schedule!
    assert_not a.update(title: "ใหม่")
    assert_raises(Auction::Error) { a.add_item!(@sealed_items.second) }
    assert_raises(Auction::Error) { a.remove_lot!(a.lots.first) }
  end

  test "changing the end time of a draft moves its lots" do
    a = build
    lot = a.add_item!(@sealed_items.first)
    new_end = a.ends_at + 1.day
    a.update!(ends_at: new_end)
    assert_in_delta new_end, lot.reload.ends_at, 1
    assert_in_delta new_end, lot.original_ends_at, 1
  end

  test "auction type is fixed once lots exist" do
    a = build
    a.add_item!(@sealed_items.first)
    assert_not a.update(auction_type: "english")
  end

  test "cancel needs a reason and cancels lots" do
    a = build
    lot = a.add_item!(@sealed_items.first)
    assert_raises(Auction::Error) { a.cancel!(reason: "  ") }
    a.cancel!(reason: "ผู้ขายถอนสินค้า")
    assert a.reload.cancelled?
    assert lot.reload.cancelled?
    assert_raises(Auction::Error) { a.cancel!(reason: "อีกครั้ง") }
  end
end
