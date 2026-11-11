require "test_helper"

class CatalogDemoLotsTest < ActiveSupport::TestCase
  test "start and closing times are stable across requests" do
    first = Catalog::DemoLots.call(now: Time.utc(2026, 11, 11, 16))
    later = Catalog::DemoLots.call(now: Time.utc(2026, 11, 11, 17))
    assert_equal first.map(&:starts_at), later.map(&:starts_at)
    assert_equal first.map(&:ends_at), later.map(&:ends_at)
  end

  test "same lots transition at exact server start and closing times" do
    base = Time.utc(2026, 11, 11, 16)
    lots = Catalog::DemoLots.call(now: base)
    at_close = Catalog::Sections.call(lots: lots, now: base + 15.minutes)
    assert_equal [ 10, 15, 20 ], at_close.values.map(&:size)
    at_start = Catalog::Sections.call(lots: lots, now: base + 30.minutes)
    assert_equal [ 15, 10, 20 ], at_start.values.map(&:size)
    ids = at_start.values.flatten.map(&:id)
    assert_equal 45, ids.size
    assert_equal ids.uniq, ids
  end
end
