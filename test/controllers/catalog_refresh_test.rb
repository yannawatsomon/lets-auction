require "test_helper"

class CatalogRefreshTest < ActionDispatch::IntegrationTest
  test "filtered results transition using server time and retain form values" do
    base = Time.utc(2026, 11, 11, 16)
    travel_to base + 14.minutes
    get root_path, params: { q: "รถยนต์", status: "ongoing" }
    assert_response :success
    assert_select ".catalog-overview-section article.catalog-card", count: 3
    travel_to base + 15.minutes
    get root_path, params: { q: "รถยนต์", status: "ongoing", now: "2000-01-01T00:00:00Z" }
    assert_response :success
    assert_select "article.catalog-card", count: 0
    assert_select "input[name='q'][value='รถยนต์']"
    assert_select "select[name='status'] option[value='ongoing'][selected]"
    assert_select "#catalog-total", text: /0/
  end

  test "refresh URL preserves filters and resets expanded listing pages" do
    travel_to Time.utc(2026, 11, 11, 16)
    get catalog_path, params: { q: "ตัวอย่าง", status: "ongoing", ongoing_page: "2", date_field: "ends_at" }
    assert_response :success
    element = css_select("main[data-controller='catalog-refresh']").first
    assert element
    uri = URI.parse(element["data-catalog-refresh-url-value"])
    assert_equal "/catalog", uri.path
    query = Rack::Utils.parse_query(uri.query)
    assert_equal "ตัวอย่าง", query["q"]
    assert_equal "ongoing", query["status"]
    assert_equal "ends_at", query["date_field"]
    assert_not query.keys.any? { |key| key.end_with?("_page") }
    assert_select "[data-catalog-refresh-target='results']", count: 1
    assert_select "time[data-catalog-refresh-target='updatedAt']"
  end

  test "invalid filters disable polling and keep validation errors" do
    get root_path, params: { from: "invalid" }
    assert_response :unprocessable_content
    assert_select "main[data-catalog-refresh-enabled-value='false']"
    assert_select "#filter-from-error"
  end
end
