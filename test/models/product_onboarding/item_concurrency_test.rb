require "test_helper"
require_relative "support"

class ProductOnboardingItemConcurrencyTest < ActiveSupport::TestCase
  include ProductOnboardingTestSupport

  # The mock store holds items in memory behind a per-item lock, so this runs on any database.
  # The real model needs a row lock (Postgres) to give the same guarantee.
  test "concurrent add_media! calls never push an item over 5 images" do
    item = build_item
    item.sync_media!(media_entries(images: 1))
    entries = Array.new(12) { media_entry("image") }

    results = entries.map do |entry|
      Thread.new do
        item.add_media!(entry)
        :added
      rescue ActiveModel::ValidationError
        :rejected
      end
    end.map(&:value)

    assert_equal 5, item.media_count("image")
    assert_equal 4, results.count(:added)
    assert_equal 8, results.count(:rejected)
  end
end
