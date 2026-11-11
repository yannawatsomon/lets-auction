module Bidding
  # Opens a scheduled auction at its start time (#35): auction and lots become `live`.
  # Server time only. Safe to run twice or late; does nothing before starts_at.
  class OpenAuction
    def self.call(...) = new(...).call

    def initialize(auction:, now: Time.current)
      @auction = auction
      @now = now
    end

    # Returns true if it opened the auction now.
    def call
      opened = false
      @auction.with_lock do
        next unless @auction.scheduled? && @now >= @auction.starts_at && @now < @auction.ends_at

        @auction.lots.where(status: "scheduled").update_all(status: "live", updated_at: @now)
        @auction.update_columns(status: "live", updated_at: @now)
        AuditLog.record!(action: "auction.opened", entity: @auction, data: { at: @now.iso8601(3) })
        opened = true
      end
      Broadcaster.auction_state(@auction.reload, now: @now) if opened
      opened
    end
  end
end
