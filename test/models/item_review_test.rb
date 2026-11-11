require "test_helper"

class ItemReviewTest < ActiveSupport::TestCase
  setup do
    @item = Item.create!(
      seller: users(:seller), category: categories(:watches),
      title: "Rare watch", description: "Boxed, 1970s", min_price_cents: 100_000
    )
  end

  def review(action, note: nil)
    ItemReview.new(item: @item, admin: users(:admin), action: action, note: note)
  end

  test "is read-only after create" do
    saved = review("approve").tap(&:save!)

    assert_raises(ActiveRecord::ReadOnlyRecord) { saved.update!(note: "changed") }
    assert_raises(ActiveRecord::ReadOnlyRecord) { saved.destroy }
  end

  test "reject and request_info require a note" do
    %w[reject request_info].each do |action|
      assert_not review(action).valid?, action
      assert_not review(action, note: "  ").valid?, action
      assert review(action, note: "Photo of the serial number is missing").valid?, action
    end
  end

  test "approve allows a blank note" do
    assert review("approve").valid?
  end

  test "rejects an unknown action" do
    assert_not review("delete", note: "x").valid?
  end

  test "only an admin can review" do
    assert_not ItemReview.new(item: @item, admin: users(:seller), action: "approve").valid?
  end

  test "an item with review history cannot be deleted" do
    review("approve").save!
    assert_raises(ActiveRecord::DeleteRestrictionError) { @item.destroy }
  end
end
