require "test_helper"

class CatalogFilterFormTest < ActionView::TestCase
  test "renders GET controls and query-free clear link" do
    filters = Catalog::Filters.new({ q: "กล้อง", status: "ongoing", auction_type: "english" }, categories: [ "กล้อง" ])
    render partial: "catalog/filters", locals: { filters: filters, categories: [ "กล้อง" ], url: "/catalog-preview" }
    assert_select "form[method='get'][action='/catalog-preview']"
    assert_select "input[name='q'][value='กล้อง']"
    assert_select "select[name='status'] option[selected][value='ongoing']"
    assert_select "select[name='auction_type'] option[selected][value='english']"
    assert_select "input[type='datetime-local'][name='from']"
    assert_select "input[type='datetime-local'][name='to']"
    assert_select "a[href='/catalog-preview']", "ล้างตัวกรอง"
  end

  test "shows field errors with accessible references and escapes input" do
    filters = Catalog::Filters.new({ q: '<script>alert("x")</script>', from: "invalid" }, categories: [])
    filters.valid?
    render partial: "catalog/filters", locals: { filters: filters, categories: [], url: "/catalog-preview" }
    assert_select "script", count: 0
    assert_select "input[name='from'][aria-invalid='true'][aria-describedby='filter-from-error']"
    assert_select "#filter-from-error", text: /วันเวลาไทย/
    assert_select "input[name='q']" do |inputs|
      assert_equal '<script>alert("x")</script>', inputs.first["value"]
    end
  end
end
