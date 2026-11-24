require "test_helper"

# Bidding reads products from product onboarding's store and follows its status rules.
class AuctionItemsTest < ActiveSupport::TestCase
  setup { ProductOnboarding::Store.reset! }
  teardown { ProductOnboarding::Store.reset! }

  def store_item = ProductOnboarding::Store.approved.first

  def auction
    Auction.create!(title: "งาน", auction_type: "sealed_first_price", starts_at: 1.day.from_now, ends_at: 2.days.from_now, created_by_id: 1)
  end

  test "items approved in product onboarding are offered, together with bidding demo items" do
    ids = AuctionItems.approved.map(&:id)
    assert_includes ids, store_item.id
    assert_includes ids, MockData.approved_items.first.id
    assert_equal store_item, AuctionItems.find(store_item.id)
  end

  test "scheduling moves store items to in_auction; cancelling moves them back" do
    a = auction
    item = store_item
    a.add_item!(item)
    assert item.approved?, "a draft auction doesn't lock the item yet"

    a.schedule!
    assert item.in_auction?

    a.cancel!(reason: "ทดสอบ")
    assert item.approved?
  end

  test "an item withdrawn while the auction is a draft blocks scheduling" do
    a = auction
    item = store_item
    a.add_item!(item)
    item.transition!("withdrawn")
    e = assert_raises(Auction::Error) { a.schedule! }
    assert_match "ล็อต 1", e.message
    assert a.reload.draft?
  end

  test "an item in a scheduled auction can't be withdrawn by the seller" do
    a = auction
    item = store_item
    a.add_item!(item)
    a.schedule!
    assert_raises(ProductOnboarding::Item::InvalidTransition) { item.transition!("withdrawn") }
  end
end
