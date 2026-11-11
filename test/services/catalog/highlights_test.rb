require "test_helper"

class CatalogHighlightsTest < ActiveSupport::TestCase
  Lot = Data.define(:id, :min_price_cents)

  test "ranks public starting prices descending with stable id ties and caps selection at five" do
    lots = (1..7).map { |id| Lot.new(id, id == 7 ? 600 : id * 100) }.reverse.freeze
    entries = Catalog::Highlights.call(sections: { ongoing: lots })
    assert_equal [ 6, 7, 5, 4, 3 ], entries.map { |entry| entry.lot.id }
    assert entries.all? { |entry| entry.status == :ongoing }
    assert_equal 7, lots.size
  end

  test "excludes missing invalid and nonpositive prices and handles fewer or no eligible lots" do
    lots = [ nil, 0, -100, "500", 1.5, 100 ].each_with_index.map { |price, id| Lot.new(id, price) }
    assert_equal [ 5 ], Catalog::Highlights.call(sections: { ongoing: lots }).map { |entry| entry.lot.id }
    assert_empty Catalog::Highlights.call(sections: {})
    assert_empty Catalog::Highlights.call(sections: { ongoing: lots.first(5) })
  end

  test "selects only ongoing products even when other statuses have higher prices" do
    lot = Lot.new(1, 500)
    entries = Catalog::Highlights.call(sections: { ongoing: [ lot, lot ], upcoming: [ Lot.new(2, 800) ], ended: [ Lot.new(3, 900) ] })
    assert_equal [ [ 1, :ongoing ] ], entries.map { |entry| [ entry.lot.id, entry.status ] }
  end
end
