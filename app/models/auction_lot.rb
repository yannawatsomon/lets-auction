# One item inside one auction. min_price_cents is a snapshot taken when the item was added,
# so a later change to the item never moves a running lot's minimum (scope.md).
class AuctionLot < ApplicationRecord
  OPEN_STATUSES = %w[scheduled live closed].freeze

  belongs_to :auction, inverse_of: :lots

  enum :status, {
    scheduled: "scheduled", live: "live", closed: "closed",
    sold: "sold", unsold: "unsold", cancelled: "cancelled"
  }, default: "scheduled", validate: true

  validates :item_id, :ends_at, :original_ends_at, presence: true
  validates :lot_no, numericality: { only_integer: true, in: 1..Auction::MAX_LOTS }
  validates :min_price_cents, numericality: { only_integer: true, greater_than: 0 }
  validates :bid_increment_cents, numericality: { only_integer: true, greater_than: 0 }, allow_nil: true

  def item = MockData.item(item_id)
end
