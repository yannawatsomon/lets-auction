require "test_helper"

class CatalogHighlightsControllerTest < ActionDispatch::IntegrationTest
  setup { travel_to Catalog::DemoLots::SCHEDULE_ANCHOR }

  test "homepage highlights precede regular sections and share refresh results" do
    get root_path
    assert_response :success
    assert_select "[data-catalog-refresh-target='results'] .catalog-highlights article", count: 5
    assert_select ".catalog-highlights .catalog-card__badge--english", count: 5
    assert_select ".catalog-highlights [tabindex='0'][role='region']"
    assert_select ".catalog-highlights button[data-action='catalog-carousel#next']"
    sections = css_select("section")
    assert_includes sections.first["class"], "catalog-highlights"
    assert_select "#catalog-total", text: /45/
    ids = css_select("[id]").map { |element| element["id"] }
    assert_equal ids.uniq, ids
  end

  test "highlights combine all filters and retain auction type labels" do
    get root_path, params: { q: "นาฬิกา", category: "นาฬิกา", status: "ongoing", auction_type: "sealed_first_price",
      date_field: "ends_at", from: "2026-11-11T23:40", to: "2026-11-11T23:50" }
    assert_response :success
    assert_select ".catalog-highlights article", count: 5
    assert_select ".catalog-highlights .catalog-card__badge--sealed_first_price", count: 5
    assert_select ".catalog-highlights .catalog-card__badge--ongoing", count: 5
    assert_select ".catalog-highlights h3", text: /นาฬิกาสปอร์ต/, count: 5
    assert_select ".catalog-highlights h3", text: /นาฬิกาคลาสสิก/, count: 0
  end

  test "empty filters show an empty highlight state and invalid filters show no carousel" do
    get root_path, params: { q: "no matching product" }
    assert_select ".catalog-highlights article", count: 0
    assert_select ".catalog-highlights .catalog-preview__empty"
    get root_path, params: { status: "invalid" }
    assert_response :unprocessable_content
    assert_select ".catalog-highlights", count: 0
  end

  test "highlights disappear at closing time and exclude upcoming and ended filters" do
    travel_to Catalog::DemoLots::SCHEDULE_ANCHOR + 44.minutes
    get root_path, params: { q: "นาฬิกาสปอร์ต" }
    assert_select ".catalog-highlights article", count: 5
    travel_to Catalog::DemoLots::SCHEDULE_ANCHOR + 45.minutes
    get root_path, params: { q: "นาฬิกาสปอร์ต" }
    assert_select ".catalog-highlights article", count: 0
    %w[upcoming ended].each do |status|
      get root_path, params: { status: status }
      assert_select ".catalog-highlights article", count: 0
    end
  end

  test "full status listing keeps its independent pagination without duplicate highlights" do
    get catalog_path
    assert_response :success
    assert_select ".catalog-highlights", count: 0
  end
end
