module Bidding
  # Closes every lot of an auction at its end time and ranks the bidders (#35). No extensions:
  # all lots close at auction.ends_at (bidding.md).
  #
  # Per lot: a lot with bids becomes `closed` (its ranking is `AuctionLot#results`, computed from
  # the bids, no table); no bids → `unsold` and the item goes back to `approved` (product
  # onboarding's rule). When done the auction is `awaiting_approval` for the
  # admin (#36). Idempotent: running it again changes nothing; it never runs before ends_at.
  class CloseAuction
    def self.call(...) = new(...).call

    def initialize(auction:, now: Time.current)
      @auction = auction
      @now = now
    end

    # Returns true if it closed the auction now.
    def call
      closed_lots = []
      closed = false
      @auction.with_lock do
        next unless (@auction.scheduled? || @auction.live?) && @now >= @auction.ends_at

        @auction.lots.where(status: %w[scheduled live]).find_each do |lot|
          close_lot(lot)
          closed_lots << lot
        end
        @auction.update_columns(status: "awaiting_approval", updated_at: @now)
        AuditLog.record!(action: "auction.closed", entity: @auction,
          data: { at: @now.iso8601(3), lots: closed_lots.map { |l| { id: l.id, status: l.status } } })
        closed = true
      end
      closed_lots.each { |lot| Broadcaster.lot_closed(lot) }
      closed
    end

    private

    def close_lot(lot)
      if lot.bids.exists?
        lot.update_columns(status: "closed", updated_at: @now)
      else
        lot.update_columns(status: "unsold", updated_at: @now)
        AuctionItems.release!(lot.item)
      end
    end
  end
end
