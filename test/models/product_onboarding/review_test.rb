require "test_helper"
require_relative "support"

class ProductOnboardingReviewTest < ActiveSupport::TestCase
  include ProductOnboardingTestSupport

  def review(action, note: nil, admin_id: 1)
    ProductOnboarding::Review.build!(admin_id: admin_id, action: action, note: note)
  end

  test "is read-only once created" do
    saved = review("approve")

    assert saved.frozen?
    assert_raises(FrozenError) { saved.note = "changed" }
  end

  test "records who decided and when" do
    saved = review("approve", admin_id: 2)

    assert_equal 2, saved.admin_id
    assert_in_delta Time.current, saved.created_at, 5
  end

  test "reject and request_info require a note" do
    %w[reject request_info].each do |action|
      assert_raises(ActiveModel::ValidationError, action) { review(action) }
      assert_raises(ActiveModel::ValidationError, action) { review(action, note: "  ") }
      assert review(action, note: "Photo of the serial number is missing")
    end
  end

  test "approve allows a blank note" do
    assert review("approve")
  end

  test "rejects an unknown action" do
    assert_raises(ActiveModel::ValidationError) { review("delete", note: "x") }
  end

  test "only a mock admin can review" do
    assert_raises(ActiveModel::ValidationError) { review("approve", admin_id: 11) }
    assert_raises(ActiveModel::ValidationError) { review("approve", admin_id: 999) }
  end
end
