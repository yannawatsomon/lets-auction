require "test_helper"

# Needs a database with row locks (Postgres). SQLite serialises writers but ignores
# `SELECT ... FOR UPDATE`, so this cannot prove the lock there; it is skipped, not passed.
class ItemMediaConcurrencyTest < ActiveSupport::TestCase
  self.use_transactional_tests = false

  setup do
    skip "needs Postgres row locks (database is #{ActiveRecord::Base.connection.adapter_name})" if
      ActiveRecord::Base.connection.adapter_name == "SQLite"

    @item = Item.create!(
      seller: users(:seller), category: categories(:watches),
      title: "Concurrent", description: "d", min_price_cents: 100_000
    )
  end

  teardown { @item&.destroy }

  test "concurrent sync_media! calls never leave more than 5 images or duplicate rows" do
    @item.sync_media!(media_entries(images: 4))
    lists = Array.new(2) { @item.item_media.order(:sort_order).map { |m| { kind: "image", signed_id: m.file.blob.signed_id } } + media_entries(images: 1) }

    threads = lists.map do |entries|
      Thread.new do
        ActiveRecord::Base.connection_pool.with_connection do
          Item.find(@item.id).sync_media!(entries)
          :ok
        rescue ActiveRecord::RecordInvalid
          :rejected
        end
      end
    end
    threads.each(&:join)

    assert_equal 5, @item.item_media.where(kind: "image").count
  end
end
