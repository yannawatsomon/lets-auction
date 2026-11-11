require "test_helper"

class MockSeedTest < ActiveSupport::TestCase
  test "seeds create mock products in every review state and can be run twice" do
    Rails.application.load_seed
    counts = [ User.count, Category.count, Item.count, ItemMedium.count, ItemReview.count ]
    Rails.application.load_seed

    assert_equal counts, [ User.count, Category.count, Item.count, ItemMedium.count, ItemReview.count ]
    assert_equal %w[approved info_requested pending_review], Item.where(seller: User.find_by!(email: "seller@lets-auction.test")).pluck(:status).sort
    assert Item.all.all? { |item| item.item_media.where(kind: "image").count.between?(1, 5) }
  end

  test "seeds do nothing in production" do
    original = Rails.env
    Rails.env = "production"
    assert_no_difference -> { Item.count + User.count } do
      Rails.application.load_seed
    end
  ensure
    Rails.env = original
  end
end
