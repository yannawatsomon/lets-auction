module ProductOnboarding
  # MOCK store for products: in memory, seeded from db/mock/product_items.yml, reset on every
  # server restart and code reload. It stands in for the `items` table until the data model
  # structure is agreed. Controllers and other milestones reach products only through this
  # module, so replacing it with ActiveRecord is one place (see
  # ai/knowledge/product-onboarding-integration-points.md).
  module Store
    LOCK = Monitor.new
    EXTENSIONS = { "image" => "jpg", "video" => "mp4", "document" => "pdf" }.freeze
    CONTENT_TYPES = { "image" => "image/jpeg", "video" => "video/mp4", "document" => "application/pdf" }.freeze

    class << self
      def all = synchronize { items.values.sort_by(&:id) }

      def find(id) = synchronize { items[id.to_i] }

      def find!(id) = find(id) || raise(NotFound, "No product with id #{id.inspect}")

      def for_seller(seller_id, status: nil)
        all.select { |item| item.seller_id == seller_id.to_i && (status.nil? || item.status == status.to_s) }
      end

      # Same readers as MockData::Item, so bidding can read these instead of MockData.approved_items.
      def approved = all.select(&:approved?)

      # Validates first, then stores. Raises ActiveModel::ValidationError and stores nothing on failure.
      def create!(attributes, media:)
        item = Item.new(attributes.to_h.symbolize_keys.except(:id, :status))
        item.validate!
        item.sync_media!(media)
        synchronize do
          item.id = next_id
          items[item.id] = item
        end
        item
      end

      def reset!
        synchronize do
          @items = load_mock_items.index_by(&:id)
        end
        self
      end

      def synchronize(&) = LOCK.synchronize(&)

      private

      def items = @items || reset!.then { @items }

      def next_id = ([ items.keys.max.to_i, 1000 ].max) + 1

      def load_mock_items
        YAML.load_file(Rails.root.join("db/mock/product_items.yml")).map { |row| build_from_row(row.symbolize_keys) }
      end

      def build_from_row(row)
        item = Item.new(row.slice(:id, :seller_id, :category, :title, :description, :min_price_cents,
                                  :status, :contact_channel))
        item.sync_media!(mock_files(row))
        row.fetch(:reviews, []).each { |review| item.record_review!(**review.symbolize_keys) }
        item
      end

      # `images: 3` in the YAML becomes three mock image files.
      def mock_files(row)
        Item::KINDS.flat_map do |kind|
          Array.new(row.fetch(:"#{kind}s", 0)) do |index|
            { kind: kind, key: "mock-#{row[:id]}-#{kind}-#{index + 1}", filename: "#{kind}-#{index + 1}.#{EXTENSIONS[kind]}",
              content_type: CONTENT_TYPES[kind], byte_size: 1_000 }
          end
        end
      end
    end
  end
end
