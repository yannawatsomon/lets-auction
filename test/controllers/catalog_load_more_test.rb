require "test_helper"

class CatalogLoadMoreTest < ActionDispatch::IntegrationTest
  test "shows matching totals and expands sections independently in stable order" do
    get root_path, params: { upcoming_page: "2" }
    assert_response :success
    assert_select "#catalog-total", text: /45/
    assert_select "#{section(:ongoing)} article", count: 12
    assert_select "#{section(:upcoming)} article", count: 15
    assert_select "#{section(:ended)} article", count: 12
    original_titles = css_select("#{section(:ongoing)} h3").map(&:text)
    more = css_select("#{section(:ongoing)} a.catalog-load-more").first["href"]
    query = Rack::Utils.parse_query(URI.parse(more).query)
    assert_equal "2", query["ongoing_page"]
    assert_equal "2", query["upcoming_page"]
    get more.split("#").first
    assert_response :success
    expanded = css_select("#{section(:ongoing)} h3").map(&:text)
    assert_equal 15, expanded.size
    assert_equal original_titles, expanded.first(12)
    assert_equal expanded.uniq, expanded
    assert_select "#{section(:upcoming)} article", count: 15
    assert_select "#{section(:ended)} article", count: 12
    assert_select "#{section(:ongoing)} a.catalog-load-more", count: 0
  end

  test "more links preserve filters and filter form resets page counts" do
    get root_path, params: { q: "ตัวอย่าง", status: "ongoing", auction_type: "english", ongoing_page: "2" }
    assert_response :success
    assert_select "form input[name$='_page']", count: 0
    assert_select "form select[name$='_page']", count: 0
    assert_select "a[href='/']", "ล้างตัวกรอง"

    get root_path, params: { status: "ongoing", date_field: "ends_at", from: "2000-01-01T00:00" }
    more = css_select("a.catalog-load-more").first["href"]
    query = Rack::Utils.parse_query(URI.parse(more).query)
    assert_equal "ongoing", query["status"]
    assert_equal "ends_at", query["date_field"]
    assert_equal "2000-01-01T00:00", query["from"]
    get root_path, params: { status: "ongoing" }
    assert_select "article", count: 12
  end

  test "reports invalid page counters without showing products" do
    get root_path, params: { ongoing_page: [ "2" ] }
    assert_response :unprocessable_content
    assert_select "#catalog-pagination-errors", text: /1.*100/
    assert_select "article", count: 0
    assert_select ".catalog-preview__empty", text: /กรุณาแก้ไข/, count: 3
  end

  test "empty results do not offer load more" do
    get root_path, params: { q: "no matches" }
    assert_response :success
    assert_select "article", count: 0
    assert_select "a.catalog-load-more", count: 0
    assert_select ".catalog-preview__empty", count: 3
  end

  test "inventory failure offers a retry preserving filters and pages then recovers" do
    original = Catalog::DemoLots.method(:call)
    Catalog::DemoLots.define_singleton_method(:call) { |now:| raise Catalog::InventoryUnavailable }
    get root_path, params: { status: "upcoming", upcoming_page: "2" }
    assert_response :service_unavailable
    assert_select "#catalog-load-error", text: /ไม่สำเร็จ/
    assert_select "#catalog-total", count: 0
    retry_url = css_select("#catalog-load-error a").first["href"]
    query = Rack::Utils.parse_query(URI.parse(retry_url).query)
    assert_equal "upcoming", query["status"]
    assert_equal "2", query["upcoming_page"]
    Catalog::DemoLots.define_singleton_method(:call, original)
    get retry_url
    assert_response :success
    assert_select "article", count: 15
  ensure
    Catalog::DemoLots.define_singleton_method(:call, original) if original
  end

  private
    def section(status)
      "section[aria-labelledby='section-#{status}']"
    end
end
