require "test_helper"

class HomeControllerTest < ActionDispatch::IntegrationTest
  test "root renders" do
    get root_url
    assert_response :success
    assert_select "h1", "สินค้าประมูล"
    assert_select "article.catalog-card", count: 9
    assert_select "a.catalog-see-more", count: 3
    assert_select "form[action='/'][method='get']"
    assert_select "a[href='/']", "ล้างตัวกรอง"
  end

  test "homepage filters products without leaving root" do
    get root_url, params: { status: "ongoing", auction_type: "sealed_first_price" }
    assert_response :success
    assert_select "main section", count: 1
    assert_select "article.catalog-card", count: 3
    assert_select "h3", "นาฬิกาสปอร์ต"
    assert_select "form[action='/']"
  end

  test "homepage returns field errors for invalid filters" do
    get root_url, params: { from: "invalid" }
    assert_response :unprocessable_content
    assert_select "#filter-from-error"
    assert_select "article.catalog-card", count: 0
  end

  test "production homepage renders catalog without demo inventory" do
    Rails.application.reload_routes_unless_loaded
    original = Rails.env
    original_demo = Rails.configuration.x.catalog_demo_in_production
    Rails.env = "production"
    Rails.configuration.x.catalog_demo_in_production = false
    get root_url
    assert_response :success
    assert_select "h1", "สินค้าประมูล"
    assert_select "main section", count: 3
    assert_select "article.catalog-card", count: 0
    assert_select "aside", count: 0
    assert_select "form[action='/']"
    assert_empty Catalog::DemoLots.call(now: Time.current)
  ensure
    Rails.env = original
    Rails.configuration.x.catalog_demo_in_production = original_demo
  end

  test "production demo catalog shows sample banner and independent load more" do
    Rails.application.reload_routes_unless_loaded
    original = Rails.env
    original_demo = Rails.configuration.x.catalog_demo_in_production
    Rails.env = "production"
    Rails.configuration.x.catalog_demo_in_production = true
    get root_url, params: { ongoing_page: "2" }
    assert_response :success
    assert_select "article.catalog-card", count: 9
    assert_select "aside", text: /ไม่ใช่รายการประมูลจริง/
    assert_select "#catalog-total", text: /45/
    assert_select "a.catalog-see-more", count: 3
    get "/catalog-preview"
    assert_response :not_found
  ensure
    Rails.env = original
    Rails.configuration.x.catalog_demo_in_production = original_demo
  end
end
