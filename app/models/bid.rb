# One bid on one lot (issue #30, docs/decision/bidding.md).
#
# - Append-only: once saved it can't be updated or destroyed (bids are the evidence for every
#   result). The bid endpoints (#31 sealed, #32 English) only ever create.
# - The amount is satang, encrypted at rest in a text column (Active Record Encryption, both
#   auction types). Nothing can sort or filter by it in SQL; use `Bid.ranking` in Ruby.
# - Sealed: one bid per buyer per lot (partial unique index). Every bid: unique
#   (user_id, idempotency_key), so a retried request can't create a second bid.
# - Validation of *who* may bid and *when* lives in the bid endpoints, inside their transaction.
class Bid < ApplicationRecord
  class AppendOnly < StandardError; end

  # Kept as a string column; cast to Integer on read. Encrypted (non-deterministic).
  encrypts :amount_cents

  belongs_to :lot, class_name: "AuctionLot", inverse_of: :bids

  enum :auction_type, { sealed_first_price: "sealed_first_price", english: "english" }, validate: true

  validates :user_id, :idempotency_key, presence: true
  validates :idempotency_key, length: { maximum: 200 }
  validate :amount_is_positive_whole_satang
  validate :type_matches_auction, on: :create

  before_validation :copy_auction_type, on: :create
  before_update { raise AppendOnly, "bids can't be changed" }
  before_destroy { raise AppendOnly, "bids can't be deleted" }

  def readonly? = persisted? || super

  def user = MockData.user(user_id)

  def amount = Integer(amount_cents.to_s, 10)

  def amount=(cents)
    self.amount_cents = cents.nil? ? nil : Integer(cents).to_s
  end

  # Ranked bids for a lot, best first: amount desc, then earliest (server time), then lowest id.
  # English keeps only each bidder's highest bid (bidding.md). Decrypts in Ruby; fine for the
  # few hundred bids a lot gets.
  def self.ranking(bids, one_per_user: false)
    sorted = bids.sort_by { |b| [ -b.amount, b.created_at, b.id ] }
    one_per_user ? sorted.uniq(&:user_id) : sorted
  end

  private

  def copy_auction_type
    self.auction_type ||= lot&.auction&.auction_type
  end

  def type_matches_auction
    return unless lot&.auction && auction_type

    errors.add(:auction_type, "must match the auction") unless auction_type == lot.auction.auction_type
  end

  def amount_is_positive_whole_satang
    value = Integer(amount_cents.to_s, 10)
    errors.add(:amount_cents, "ต้องมากกว่า 0") unless value.positive?
  rescue ArgumentError, TypeError
    errors.add(:amount_cents, "ต้องเป็นจำนวนเต็มหน่วยสตางค์")
  end
end
