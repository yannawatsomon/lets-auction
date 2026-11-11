module ProductOnboarding
  # One admin decision about a product. Append-only: `build!` returns a frozen object, so it can
  # be neither changed nor removed from the product's history.
  class Review
    include ActiveModel::Model
    include ActiveModel::Attributes

    ACTIONS = %w[approve reject request_info].freeze
    NOTE_REQUIRED = %w[reject request_info].freeze

    attribute :admin_id, :integer
    attribute :action, :string
    attribute :note, :string
    attribute :created_at, :datetime, default: -> { Time.current }

    validates :action, inclusion: { in: ACTIONS }
    validates :note, presence: true, if: -> { NOTE_REQUIRED.include?(action) }
    validate :reviewer_is_an_admin

    def self.build!(**attributes)
      new(**attributes).tap do |review|
        review.validate!
        review.freeze
      end
    end

    private

    def reviewer_is_an_admin
      errors.add(:admin_id, "must belong to an admin account") unless MockData.user(admin_id)&.admin?
    end
  end
end
