require "test_helper"

class CatalogFlowTest < ActionDispatch::IntegrationTest
  setup { travel_to Catalog::DemoLots::SCHEDULE_ANCHOR }

  test "combined filtering navigates from overview to listing and resets to all inventory" do
    filters = { q: "ตัวอย่าง", category: "กล้อง", auction_type: "english", date_field: "ends_at",
      from: "2026-11-11T23:00", to: "2026-11-12T01:00" }
    get root_path, params: filters
    assert_response :success
    assert_select ".catalog-highlights article", count: 4
    assert_select ".catalog-highlights .catalog-card__badge--ongoing", count: 4
    assert_select "#catalog-total", text: /4 รายการ/
    url = css_select(".catalog-see-more").first["href"]
    query = Rack::Utils.parse_query(URI.parse(url).query)
    filters.each { |key, value| assert_equal value, query[key.to_s] }
    assert_equal "ongoing", query["status"]
    get url
    assert_response :success
    assert_select ".catalog-listing-section article", count: 4
    assert_select "time", text: "12/11/2026 00:30"
    get css_select("a").find { |a| a.text == "ล้างตัวกรอง" }["href"]
    assert_response :success
    assert_select "#catalog-total", text: /45 รายการ/
    assert_select ".catalog-listing-section", count: 3
    assert_select "input[name='q'][value='']"
  end

  test "exact start and close move a product between sections and highlight eligibility" do
    filters = { q: "เลนส์กล้อง", auction_type: "sealed_first_price" }
    travel_to Catalog::DemoLots::SCHEDULE_ANCHOR + 30.minutes - 1.second
    get root_path, params: filters
    assert_select "section[aria-labelledby='section-upcoming'] article", count: 3
    assert_select ".catalog-highlights article", count: 0
    travel_to Catalog::DemoLots::SCHEDULE_ANCHOR + 30.minutes
    get root_path, params: filters.merge(now: "2000-01-01")
    assert_select "section[aria-labelledby='section-ongoing'] article", count: 3
    assert_select ".catalog-highlights article", count: 5
    travel_to Catalog::DemoLots::SCHEDULE_ANCHOR + 3.hours
    get root_path, params: filters
    assert_select "section[aria-labelledby='section-ended'] article", count: 3
    assert_select ".catalog-highlights article", count: 0
    assert_select "#catalog-total", text: /5 รายการ/
  end

  test "malformed structured inputs and script search remain safe" do
    [ { q: [ "camera" ] }, { category: { value: "กล้อง" } }, { auction_type: "english OR 1=1" },
      { from: "2026-02-30T10:00" }, { ongoing_page: "999999999" } ].each do |params|
      get root_path, params: params
      assert_response :unprocessable_content
      assert_select "article", count: 0
    end
    payload = "<script>alert('catalog')</script>"
    get root_path, params: { q: payload }
    assert_response :success
    assert_select "input[name='q'][value=?]", payload
    assert_select "script", text: /alert\('catalog'\)/, count: 0
    assert_select "#catalog-total", text: /0 รายการ/
  end
end
