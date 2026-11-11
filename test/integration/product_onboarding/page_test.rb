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

  test "with MOCK_PRODUCT_ONBOARDING in production it is served and only sellers can sign in" do
    Rails.application.reload_routes_unless_loaded
    original_env = Rails.env
    original_flag = Rails.configuration.x.mock_product_onboarding
    Rails.env = "production"
    Rails.configuration.x.mock_product_onboarding = true

    get product_onboarding_root_path
    assert_response :success

    get new_mock_session_path
    assert_response :success
    assert_select "button", text: /\(seller\)/
    assert_select "button", text: /\(admin\)|\(buyer\)/, count: 0

    post mock_session_path(user_id: 1) # an admin
    assert_redirected_to new_mock_session_path
    get admin_auctions_path
    assert_response :not_found

    post mock_session_path(user_id: 11) # a seller
    assert_redirected_to product_onboarding_root_path
    get new_product_onboarding_item_path
    assert_response :success
    get admin_auctions_path
    assert_response :not_found
  ensure
    Rails.env = original_env
    Rails.configuration.x.mock_product_onboarding = original_flag
  end
end
