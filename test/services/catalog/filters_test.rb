require "test_helper"

class CatalogFiltersTest < ActiveSupport::TestCase
  Lot = Data.define(:id, :name, :category, :auction_type, :starts_at, :ends_at)

  setup do
    @now = Time.utc(2026, 11, 11, 3)
    @lots = [
      Lot.new(1, "Camera Alpha", "กล้อง", "english", @now - 60, @now + 60),
      Lot.new(2, "Camera Beta", "กล้อง", "sealed_first_price", @now + 60, @now + 120),
      Lot.new(3, "Watch 100%", "นาฬิกา", "english", @now - 120, @now - 60)
    ]
  end

  test "defaults return all three sorted groups" do
    f = filters
    assert_equal "starts_at", f.date_field
    assert_equal({ ongoing: [ @lots[0] ], upcoming: [ @lots[1] ], ended: [ @lots[2] ] }, results(f))
  end

  test "combines query category status type and date range" do
    f = filters(q: "  cAmErA  ", category: "กล้อง", status: "ongoing", auction_type: "english",
      from: "2026-11-11T09:59", to: "2026-11-11T09:59")
    assert_equal({ ongoing: [ @lots[0] ] }, results(f))
  end

  test "matches search wildcards literally" do
    assert_equal [ @lots[2] ], results(filters(q: "%")).values.flatten
    assert_empty results(filters(q: "_")).values.flatten
  end

  test "filters inclusive closing times in Thai timezone" do
    f = filters(date_field: "ends_at", from: "2026-11-11T10:01", to: "2026-11-11T10:01:00")
    assert_equal [ @lots[0] ], results(f).values.flatten
  end

  test "supports either missing date endpoint" do
    assert_equal [ @lots[1] ], results(filters(from: "2026-11-11T10:00")).values.flatten
    assert_equal [ @lots[2] ], results(filters(to: "2026-11-11T09:58")).values.flatten
  end

  test "returns no matches without removing selected section" do
    assert_equal({ upcoming: [] }, results(filters(q: "missing", status: "upcoming")))
  end

  test "rejects invalid enum and category values" do
    { category: "unknown", status: "live", auction_type: "unknown", date_field: "name" }.each do |field, value|
      f = filters(field => value)
      assert_empty results(f).values.flatten
      assert f.errors[field].any?, field.to_s
    end
  end

  test "rejects non-scalar parameters for every field" do
    Catalog::Filters::FIELDS.each do |field|
      [ [ "english" ], { "x" => "y" } ].each do |value|
        f = filters(field => value)
        assert_empty results(f).values.flatten
        assert f.errors[field].any?, field.to_s
      end
    end
  end

  test "rejects invalid dates times zones and reversed ranges" do
    [ "2026-02-30T10:00", "2026-11-11T24:00", "2026-11-11T10:61", "2026-11-11", "2026-11-11T10:00Z", "garbage" ].each do |value|
      f = filters(from: value)
      assert_empty results(f).values.flatten
      assert f.errors[:from].any?
    end
    f = filters(from: "2026-11-12T10:00", to: "2026-11-11T10:00")
    assert_empty results(f).values.flatten
    assert f.errors[:to].any?
  end

  test "rejects oversized query and category" do
    [ :q, :category ].each do |field|
      f = filters(field => "a" * 101)
      assert_empty results(f).values.flatten
      assert f.errors[field].any?
    end
  end

  private
    def filters(attributes = {})
      Catalog::Filters.new(attributes, categories: [ "กล้อง", "นาฬิกา" ])
    end

    def results(filter)
      filter.sections(lots: @lots, now: @now)
    end
end
