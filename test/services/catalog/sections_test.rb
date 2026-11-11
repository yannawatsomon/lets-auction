require "test_helper"

class CatalogSectionsTest < ActiveSupport::TestCase
  Lot = Data.define(:id, :starts_at, :ends_at)

  setup do
    @now = Time.utc(2026, 11, 11, 10)
  end

  test "returns all sections in display order for empty input" do
    assert_equal({ ongoing: [], upcoming: [], ended: [] }, sections([]))
  end

  test "assigns exact start to ongoing and exact closing to ended" do
    starting = lot(1, 0, 60)
    closing = lot(2, -60, 0)
    upcoming = lot(3, 1, 60)

    result = sections([ closing, upcoming, starting ])

    assert_equal [ :ongoing, :upcoming, :ended ], result.keys
    assert_equal [ starting ], result[:ongoing]
    assert_equal [ upcoming ], result[:upcoming]
    assert_equal [ closing ], result[:ended]
  end

  test "sorts ongoing by earliest closing then ascending id" do
    result = sections([ lot(3, -60, 20), lot(2, -60, 10), lot(1, -60, 10) ])
    assert_equal [ 1, 2, 3 ], result[:ongoing].map(&:id)
  end

  test "sorts upcoming by earliest start then ascending id" do
    result = sections([ lot(3, 20, 60), lot(2, 10, 60), lot(1, 10, 60) ])
    assert_equal [ 1, 2, 3 ], result[:upcoming].map(&:id)
  end

  test "sorts ended by latest closing then ascending id" do
    result = sections([ lot(3, -60, -20), lot(2, -60, -10), lot(1, -60, -10) ])
    assert_equal [ 1, 2, 3 ], result[:ended].map(&:id)
  end

  test "uses effective extended closing time" do
    extended = lot(1, -60, 120)
    result = Catalog::Sections.call(lots: [ extended ], now: @now + 60)
    assert_equal [ extended ], result[:ongoing]
    assert_empty result[:ended]
  end

  test "accepts equivalent timestamps in different time zones" do
    starting = Lot.new(1, @now.getlocal("+07:00"), @now + 60)
    assert_equal [ starting ], sections([ starting ])[:ongoing]
  end

  test "does not reorder or mutate frozen input" do
    later = lot(2, -60, 20)
    earlier = lot(1, -60, 10)
    lots = [ later, earlier ].freeze
    assert_equal [ earlier, later ], sections(lots)[:ongoing]
    assert_equal [ later, earlier ], lots
  end

  test "rejects missing or non-integer ids" do
    [ nil, "1" ].each do |id|
      assert_raises(ArgumentError) { sections([ lot(id, -60, 60) ]) }
    end
  end

  test "rejects duplicate ids" do
    assert_raises(ArgumentError) { sections([ lot(1, -60, 60), lot(1, 10, 60) ]) }
  end

  test "rejects missing or malformed timestamps" do
    [ nil, "2026-11-11", 123 ].each do |invalid|
      assert_raises(ArgumentError) { sections([ Lot.new(1, invalid, @now + 60) ]) }
      assert_raises(ArgumentError) { sections([ Lot.new(1, @now - 60, invalid) ]) }
      assert_raises(ArgumentError) { Catalog::Sections.call(lots: [], now: invalid) }
    end
  end

  test "rejects zero length or reversed auction intervals" do
    assert_raises(ArgumentError) { sections([ lot(1, 0, 0) ]) }
    assert_raises(ArgumentError) { sections([ lot(1, 60, 0) ]) }
  end

  private
    def lot(id, start_offset, end_offset)
      Lot.new(id, @now + start_offset, @now + end_offset)
    end

    def sections(lots)
      Catalog::Sections.call(lots: lots, now: @now)
    end
end
