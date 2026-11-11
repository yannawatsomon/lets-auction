# One item inside one auction. min_price_cents is a snapshot taken when the item was added,
# so a later change to the item never moves a running lot's minimum (scope.md).
class AuctionLot < ApplicationRecord
  OPEN_STATUSES = %w[scheduled live closed].freeze

  belongs_to :auction, inverse_of: :lots
  belongs_to :leader_bid, class_name: "Bid", optional: true
  has_many :bids, foreign_key: :lot_id, inverse_of: :lot, dependent: :restrict_with_exception

  enum :status, {
    scheduled: "scheduled", live: "live", closed: "closed",
    sold: "sold", unsold: "unsold", cancelled: "cancelled"
  }, default: "scheduled", validate: true

  validates :item_id, presence: true
  validates :lot_no, numericality: { only_integer: true, in: 1..Auction::MAX_LOTS }
  validates :min_price_cents, numericality: { only_integer: true, greater_than: 0 }
  validates :bid_increment_cents, numericality: { only_integer: true, greater_than: 0 }, allow_nil: true

  def item = AuctionItems.find(item_id)

  # Server time decides (bidding.md): open from the auction's start until its end, as long as
  # neither the auction nor the lot was cancelled or already closed. Statuses move with the
  # open/close jobs (#35); time is checked here so a late job never lets a bid in early or late.
  def accepting_bids?(now = Time.current)
    (auction.scheduled? || auction.live?) && (scheduled? || live?) &&
      auction.starts_at <= now && now < auction.ends_at
  end

  # English: the lowest amount the next bid may be (bidding.md). First bid: the minimum price.
  def next_minimum_cents
    bid_count.zero? || current_price_cents.nil? ? min_price_cents : current_price_cents + bid_increment_cents.to_i
  end

  # Receipt number printed on the bid receipt, e.g. "L12-B345".
  def receipt_no_for(bid) = "L#{id}-B#{bid.id}"

  # Every lot ends with its auction; English lots never extend (bidding.md, 2026-11-11).
  delegate :starts_at, :ends_at, to: :auction
end
