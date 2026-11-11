require "test_helper"

class CatalogOverviewTest < ActionDispatch::IntegrationTest
  setup { travel_to Catalog::DemoLots::SCHEDULE_ANCHOR }
  test "overview stays one row even with old page counters" do
    get root_path, params: { ongoing_page: "2", upcoming_page: "2" }
    assert_response :success
    assert_select "section.catalog-overview-section", count: 3
    css_select("section.catalog-overview-section").each do |section|
      assert_select section, "article.catalog-card", count: 3
    end
  end

  test "see more preserves filters and lists the requested status" do
    get root_path, params: { q: "ตัวอย่าง", category: "กล้อง", auction_type: "english",
      date_field: "ends_at", from: "2000-01-01T00:00", to: "2099-01-01T00:00" }
    assert_response :success
    link = css_select("section[aria-labelledby='section-ongoing'] a.catalog-see-more").first["href"]
    uri = URI.parse(link)
    assert_equal "/catalog", uri.path
    query = Rack::Utils.parse_query(uri.query)
    assert_equal "ongoing", query["status"]
    assert_equal "ตัวอย่าง", query["q"]
    assert_equal "กล้อง", query["category"]
    assert_equal "english", query["auction_type"]
    assert_equal "ends_at", query["date_field"]
    assert_equal "2000-01-01T00:00", query["from"]
    assert_equal "2099-01-01T00:00", query["to"]
    assert_not query.keys.any? { |key| key.end_with?("_page") }
    get link
    assert_response :success
    assert_select "main section[aria-labelledby^='section-']", count: 1
    assert_select "article.catalog-card", count: 4
    assert_select "form[action='/catalog']"
    assert_select "a[href='/catalog']", "ล้างตัวกรอง"
  end
end
