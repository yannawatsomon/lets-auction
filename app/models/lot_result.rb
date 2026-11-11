# One bidder's place on a closed lot (#35). Rank 1 is the winner once an admin approves the
# results (#36); if they don't pay, the next rank is offered the lot at their own bid.
class LotResult < ApplicationRecord
  belongs_to :lot, class_name: "AuctionLot", inverse_of: :results
  belongs_to :bid

  enum :status, { pending: "pending", offered: "offered", paid: "paid", expired: "expired", declined: "declined" },
    default: "pending", validate: true

  validates :rank, numericality: { only_integer: true, greater_than_or_equal_to: 1 }

  def user = MockData.user(user_id)
  def amount_cents = bid.amount
end
