require "test_helper"
require_relative "../../models/product_onboarding/support"

class ProductOnboardingPageTest < ActionDispatch::IntegrationTest
  include ProductOnboardingTestSupport

  test "the milestone page is at /product-onboarding and lists every mock product with its status, note and the file rules" do
    assert_equal "/product-onboarding", product_onboarding_root_path

    get "/product-onboarding"

    assert_response :success
    ProductOnboarding::Store.all.each { |item| assert_select "td", text: /#{Regexp.escape(item.title)}/ }
    assert_select ".chip.pending_review"
    assert_select ".chip.info_requested"
    assert_select ".chip.approved"
    assert_select "td", text: /Please add a photo of the hallmark\./
    assert_select "body", text: /200 MB/
  end

  test "it filters by status and ignores an unknown status" do
    get product_onboarding_root_path(status: "approved")
    assert_select "table.list tbody tr", count: 1

    get product_onboarding_root_path(status: "nonsense")
    assert_select "table.list tbody tr", count: ProductOnboarding::Store.all.size
  end

  test "it is not served in production" do
    Rails.application.reload_routes_unless_loaded # routes load lazily; draw them in the test env first
    original = Rails.env
    Rails.env = "production"
    get product_onboarding_root_path
    assert_response :not_found
  ensure
    Rails.env = original
  end
end
