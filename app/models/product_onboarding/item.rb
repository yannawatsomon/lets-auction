module ProductOnboarding
  # A product a seller lists. An admin verifies it before it can go into an auction lot.
  # Rules: docs/decision/product-onboarding.md, docs/design/product-onboarding-flow.md.
  #
  # MOCK-BACKED: a plain Ruby object (no table), held by ProductOnboarding::Store. When the data
  # model structure is agreed, an ActiveRecord model with the same public methods replaces it
  # (see ai/knowledge/product-onboarding-integration-points.md). The readers `id`, `seller_id`,
  # `category`, `title`, `min_price_cents`, `status` match MockData::Item, so bidding code can
  # read approved products from the Store.
  class Item
    include ActiveModel::Model
    include ActiveModel::Attributes

    class InvalidTransition < StandardError; end

    KINDS = %w[image video document].freeze
    # Allowed number of files per kind. Documents have no limit yet (decision still Open).
    MEDIA_LIMITS = { "image" => 1..5, "video" => 0..2 }.freeze

    TRANSITIONS = {
      "pending_review" => %w[approved rejected info_requested withdrawn],
      "info_requested" => %w[pending_review withdrawn],
      "approved" => %w[withdrawn in_auction],
      "in_auction" => %w[sold approved],
      "rejected" => [],
      "sold" => [],
      "withdrawn" => []
    }.freeze
    STATUSES = TRANSITIONS.keys.freeze

    MAX_PRICE_CENTS = (2**63) - 1

    # Money is an integer number of satang (docs/decision/bidding.md).
    attribute :id, :integer
    attribute :seller_id, :integer
    attribute :category, :string
    attribute :title, :string
    attribute :description, :string
    attribute :contact_channel, :string
    attribute :min_price_cents, :big_integer
    attribute :status, :string, default: "pending_review"

    validates :title, :description, :category, presence: true
    validates :status, inclusion: { in: STATUSES }
    validate :price_is_a_positive_whole_number
    validate :seller_is_a_seller

    attr_reader :media, :reviews

    STATUSES.each { |name| define_method(:"#{name}?") { status == name } }

    def initialize(attributes = {})
      @media = [].freeze
      @reviews = [].freeze
      @lock = Monitor.new
      super
    end

    # Keep what was typed: casting "1.5" to an integer would hide a bad value from validation.
    def min_price_cents=(value)
      @min_price_raw = value
      super
    end

    def editable? = pending_review? || info_requested?

    def transition!(to)
      to = to.to_s
      @lock.synchronize do
        unless TRANSITIONS.fetch(status, []).include?(to)
          raise InvalidTransition, "cannot move a product from #{status} to #{to}"
        end

        self.status = to
      end
      self
    end

    def media_count(kind) = media.count { |file| file.kind == kind.to_s }

    # The first image is the cover.
    def cover = media.find { |file| file.kind == "image" }

    # Replaces the whole file list, in order. Each entry is a hash (or MediaFile) with `kind`,
    # `key`, and optionally `filename`, `content_type`, `byte_size`. Enforces both the minimum
    # and the maximum per kind. Runs under the item's lock, like a row lock.
    def sync_media!(entries)
      files = entries.map { |entry| MediaFile.new(**entry.to_h.symbolize_keys) }
      @lock.synchronize do
        validate_media!(files)
        @media = files.freeze
      end
      self
    end

    # Adds one file at the end. Enforces only the maximum, so a form can add files one at a time.
    def add_media!(entry)
      file = MediaFile.new(**entry.to_h.symbolize_keys)
      @lock.synchronize do
        files = media + [ file ]
        validate_media!(files, check_minimum: false)
        @media = files.freeze
      end
      file
    end

    def record_review!(admin_id:, action:, note: nil)
      review = Review.build!(admin_id: admin_id, action: action, note: note)
      @lock.synchronize { @reviews = (reviews + [ review ]).freeze }
      review
    end

    private

    def price_is_a_positive_whole_number
      raw = @min_price_raw
      value = raw.is_a?(Integer) ? raw : (Integer(raw, 10, exception: false) if raw.is_a?(String))
      errors.add(:min_price_cents, "must be a whole number of satang above 0") unless value&.between?(1, MAX_PRICE_CENTS)
    end

    def seller_is_a_seller
      errors.add(:seller_id, "must belong to a seller account") unless MockData.user(seller_id)&.seller?
    end

    def validate_media!(files, check_minimum: true)
      errors.clear
      counts = files.map(&:kind).tally

      (counts.keys - KINDS).each { |kind| errors.add(:base, "Unknown media kind: #{kind}") }
      MEDIA_LIMITS.each do |kind, range|
        count = counts.fetch(kind, 0)
        next unless count > range.max || (check_minimum && count < range.min)

        errors.add(:base, "Add #{range.min} to #{range.max} #{kind.pluralize}")
      end
      errors.add(:base, "The same file can be added only once") if files.map(&:key).uniq.size != files.size

      raise ActiveModel::ValidationError, self if errors.any?
    end
  end
end
