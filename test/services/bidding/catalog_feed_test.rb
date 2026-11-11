require "test_helper"

class Bidding::CatalogFeedTest < ActiveSupport::TestCase
  include Rails.application.routes.url_helpers

  setup do
    ProductOnboarding::Store.reset!
    OnboardingStore.reset!
    BuyerStanding.reset!
  end

  teardown { ProductOnboarding::Store.reset! }

  def auction(type: "sealed_first_price", schedule: true, starts: 1.day.from_now, ends: 2.days.from_now)
    a = Auction.create!(title: "งาน", auction_type: type, starts_at: starts, ends_at: ends, created_by_id: 1)
    busy = AuctionLot.where(status: AuctionLot::OPEN_STATUSES).pluck(:item_id)
    pool = MockData.approved_items.reject { |i| busy.include?(i.id) }
    item = type == "english" ? pool.max_by(&:min_price_cents) : pool.min_by(&:min_price_cents)
    lot = a.add_item!(item, bid_increment_cents: (type == "english" ? 1_000_000 : nil))
    a.schedule! if schedule
    [ a, lot, item ]
  end

  test "a scheduled sealed lot appears with public facts and a link to its bidding page" do
    a, lot, item = auction
    feed = Bidding::CatalogFeed.call
    assert_equal 1, feed.size
    entry = feed.first
    assert_equal lot.id, entry.id
    assert_equal item.title, entry.name
    assert_equal item.category, entry.category
    assert_equal "sealed_first_price", entry.auction_type
    assert_equal a.starts_at, entry.starts_at
    assert_equal a.ends_at, entry.ends_at
    assert_equal item.min_price_cents, entry.min_price_cents
    assert_equal bidding_auction_path(a), entry.detail_path
  end

  test "drafts and cancelled auctions are left out" do
    auction(schedule: false)
    cancelled, = auction
    cancelled.cancel!(reason: "ทดสอบ")
    assert_empty Bidding::CatalogFeed.call
  end

  test "english lots show only to invited buyers and admins" do
    a, = auction(type: "english")
    assert_empty Bidding::CatalogFeed.call
    assert_empty Bidding::CatalogFeed.call(viewer: MockData.user(21))
    assert_equal 1, Bidding::CatalogFeed.call(viewer: MockData.user(1)).size

    AuctionParticipant.invite!(auction: a, user: MockData.user(21), admin: MockData.user(1))
    assert_equal 1, Bidding::CatalogFeed.call(viewer: MockData.user(21)).size
  end

  test "nothing secret leaves bidding" do
    _, lot, = auction
    Bid.create!(lot:, user_id: 21, amount: 9_999_999, idempotency_key: "k") if defined?(Bid)
    entry = Bidding::CatalogFeed.call.first
    assert_equal %i[id name category auction_type starts_at ends_at min_price_cents detail_path], entry.to_h.keys
    assert_not_includes entry.to_h.values, 9_999_999
  end

  test "works with the catalog's own filters and sections" do
    now = Time.current
    auction.first.update_columns(status: "live", starts_at: now - 1.hour, ends_at: now + 1.hour)
    auction(starts: now + 1.day, ends: now + 2.days)
    feed = Bidding::CatalogFeed.call
    filters = Catalog::Filters.new({}, categories: feed.map(&:category).uniq)
    sections = filters.sections(lots: feed, now:)
    assert_equal 1, sections[:ongoing].size
    assert_equal 1, sections[:upcoming].size
  end
end
