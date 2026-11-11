# A product a seller lists. It is verified by an admin before it can go into an auction lot.
# Rules: docs/decision/product-onboarding.md and docs/design/product-onboarding-flow.md.
class Item < ApplicationRecord
  class InvalidTransition < StandardError; end

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

  MAX_PRICE_CENTS = (2**63) - 1

  enum :status, TRANSITIONS.keys.index_with(&:itself), validate: true

  belongs_to :seller, class_name: "User", inverse_of: :items
  belongs_to :category
  has_many :item_media, class_name: "ItemMedium", dependent: :destroy, inverse_of: :item
  has_many :item_reviews, dependent: :restrict_with_exception

  validates :title, :description, presence: true
  validates :min_price_cents,
    numericality: { only_integer: true, greater_than: 0, less_than_or_equal_to: MAX_PRICE_CENTS }
  validate :seller_must_be_a_seller

  def editable? = pending_review? || info_requested?

  def transition!(to)
    to = to.to_s
    unless TRANSITIONS.fetch(status, []).include?(to)
      raise InvalidTransition, "cannot move an item from #{status} to #{to}"
    end

    update!(status: to)
  end

  # Replaces the item's files with `entries`, in order (the first image is the cover).
  # Each entry is { kind: "image" | "video" | "document", signed_id: <Active Storage signed blob id> }.
  # Files already attached stay (their blobs are not deleted); files left out are removed.
  # Runs under a row lock so two requests cannot leave the item over a limit.
  def sync_media!(entries)
    entries = entries.map { |entry| { kind: entry.fetch(:kind).to_s, signed_id: entry.fetch(:signed_id) } }

    with_lock do
      validate_media_entries!(entries)
      blobs = entries.map { |entry| ActiveStorage::Blob.find_signed!(entry[:signed_id]) }
      existing = item_media.includes(file_attachment: :blob).index_by { |medium| medium.file.blob.id }

      existing.each { |blob_id, medium| medium.destroy! unless blobs.any? { |blob| blob.id == blob_id } }
      entries.zip(blobs).each_with_index do |(entry, blob), position|
        if (medium = existing[blob.id])
          medium.update!(sort_order: position)
        else
          item_media.create!(kind: entry[:kind], sort_order: position, file: blob)
        end
      end
    end
    item_media.reset
  end

  private

  def seller_must_be_a_seller
    errors.add(:seller, "must be a seller account") unless seller&.seller?
  end

  def validate_media_entries!(entries)
    errors.clear
    counts = entries.pluck(:kind).tally

    (counts.keys - ItemMedium.kinds.keys).each { |kind| errors.add(:base, "Unknown media kind: #{kind}") }
    MEDIA_LIMITS.each do |kind, range|
      errors.add(:base, "Add #{range.min} to #{range.max} #{kind.pluralize}") unless range.cover?(counts.fetch(kind, 0))
    end
    errors.add(:base, "The same file can be added only once") if entries.pluck(:signed_id).uniq.size != entries.size

    raise ActiveRecord::RecordInvalid, self if errors.any?
  end
end
