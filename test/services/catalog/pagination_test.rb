require "test_helper"

class CatalogPaginationTest < ActiveSupport::TestCase
  test "starts with twelve items in each section" do
    pages = Catalog::Pagination.new
    assert pages.valid?
    assert_equal (1..12).to_a, pages.items(:ongoing, (1..25).to_a)
    assert pages.more?(:ongoing, (1..25).to_a)
  end

  test "expands only selected section and preserves existing pages" do
    pages = Catalog::Pagination.new(ongoing_page: "2", ended_page: "3")
    assert_equal (1..24).to_a, pages.items(:ongoing, (1..30).to_a)
    assert_equal 12, pages.items(:upcoming, (1..30).to_a).size
    assert_equal({ "ongoing_page" => "3", "upcoming_page" => "1", "ended_page" => "3" }, pages.next_query(:ongoing))
  end

  test "handles empty and exhausted sections without changing input order" do
    pages = Catalog::Pagination.new
    lots = [ 3, 1, 2 ].freeze
    assert_equal lots, pages.items(:ended, lots)
    assert_not pages.more?(:ended, lots)
    assert_empty pages.items(:ongoing, [])
  end

  test "rejects malformed and nonscalar page counters" do
    [ "0", "-1", "101", "1.5", "9999999999999999999", "abc", [], {} ].each do |value|
      pages = Catalog::Pagination.new(ongoing_page: value)
      assert_not pages.valid?, value.inspect
      assert pages.errors[:ongoing_page].any?
    end
  end

  test "caps expansion and does not offer an invalid next page" do
    pages = Catalog::Pagination.new(ongoing_page: "100")
    assert pages.valid?
    assert_not pages.more?(:ongoing, (1..1300).to_a)
    assert_equal 1200, pages.items(:ongoing, (1..1300).to_a).size
  end
end
