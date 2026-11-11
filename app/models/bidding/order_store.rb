module Bidding
  # MOCK orders and offers for results (#36): in memory, like OnboardingStore and
  # ProductOnboarding::Store, because the team adds no new tables for now (bidding.md). A server
  # restart forgets them; the ranking itself is never lost (AuctionLot#results comes from bids).
  #
  # One order = the lot offered to one bidder at the amount they bid, due 48 hours later.
  # Fields follow bidding.md: lot, buyer, seller, amount_cents, rank, payment_due_at, status.
  # Totals (premium, shipping, VAT) are the payment milestone's job (#45).
  module OrderStore
    PAYMENT_WINDOW = 48.hours
    STATUSES = %w[awaiting_payment paid expired declined].freeze
    LOCK = Monitor.new

    Order = Struct.new(:id, :lot_id, :auction_id, :buyer_id, :seller_id, :amount_cents, :rank,
      :offered_at, :payment_due_at, :status, :closed_at, keyword_init: true) do
      def awaiting_payment? = status == "awaiting_payment"
      def paid? = status == "paid"
      def lot = AuctionLot.find_by(id: lot_id)
      def buyer = MockData.user(buyer_id)
      def due?(now = Time.current) = awaiting_payment? && now >= payment_due_at
    end

    module_function

    def synchronize(&) = LOCK.synchronize(&)

    def reset!
      synchronize do
        @orders = {}
        @skips = Hash.new { |h, k| h[k] = {} }
        @next_id = 0
      end
    end

    def find(id) = synchronize { orders[id.to_i]&.dup }
    def for_lot(lot_id) = synchronize { orders.values.select { |o| o.lot_id == lot_id }.sort_by(&:rank).map(&:dup) }
    def for_buyer(user_id) = synchronize { orders.values.select { |o| o.buyer_id == user_id }.sort_by(&:offered_at).reverse.map(&:dup) }
    def current_for_lot(lot_id) = for_lot(lot_id).find(&:awaiting_payment?)
    def all_due(now) = synchronize { orders.values.select { |o| o.due?(now) }.map(&:dup) }

    # Admin took a bidder out before approving (reason kept for the audit trail).
    def disqualify!(lot_id, user_id, reason) = synchronize { skips[lot_id][user_id] = reason }
    def disqualified(lot_id) = synchronize { skips[lot_id].dup }

    # Offers the lot to the best-ranked bidder who hasn't been offered it yet and isn't
    # disqualified. Returns the new order, or nil when nobody is left.
    def offer_next!(lot, now:)
      synchronize do
        taken = orders.values.select { |o| o.lot_id == lot.id }.map(&:buyer_id)
        result = lot.results.find { |r| !taken.include?(r.user_id) && !skips[lot.id].key?(r.user_id) }
        return nil unless result

        id = @next_id = (@next_id || 0) + 1
        orders[id] = Order.new(id:, lot_id: lot.id, auction_id: lot.auction_id, buyer_id: result.user_id,
          seller_id: lot.item&.seller_id, amount_cents: result.amount_cents, rank: result.rank,
          offered_at: now, payment_due_at: now + PAYMENT_WINDOW, status: "awaiting_payment")
        orders[id].dup
      end
    end

    # Moves an awaiting order to paid / expired / declined. Returns the updated order, or nil if
    # it was no longer awaiting payment (someone else got there first).
    def close!(id, status, now:)
      raise ArgumentError, "unknown status #{status}" unless STATUSES.include?(status) && status != "awaiting_payment"

      synchronize do
        order = orders[id.to_i]
        next nil unless order&.awaiting_payment?

        order.status = status
        order.closed_at = now
        order.dup
      end
    end

    def orders = (@orders ||= {})
    def skips = (@skips ||= Hash.new { |h, k| h[k] = {} })
    private_class_method :orders, :skips
  end
end
