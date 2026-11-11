# One admin decision about an item. Append-only: once saved it can be neither changed nor deleted.
class ItemReview < ApplicationRecord
  ACTIONS = %w[approve reject request_info].freeze
  NOTE_REQUIRED = %w[reject request_info].freeze

  belongs_to :item
  belongs_to :admin, class_name: "User"

  validates :action, inclusion: { in: ACTIONS }
  validates :note, presence: true, if: -> { NOTE_REQUIRED.include?(action) }
  validate :reviewer_must_be_admin

  def readonly? = persisted? || super

  private

  def reviewer_must_be_admin
    errors.add(:admin, "must be an admin") unless admin&.admin?
  end
end
