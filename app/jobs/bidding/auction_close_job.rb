module Bidding
  # Enqueued for auction.ends_at when the admin schedules (#35). Closes all lots together (no
  # extensions). If it runs early it waits again until the end; running twice is harmless.
  class AuctionCloseJob < ApplicationJob
    queue_as :default

    def perform(auction_id)
      auction = Auction.find_by(id: auction_id)
      return unless auction && (auction.scheduled? || auction.live?)

      now = Time.current
      return self.class.set(wait_until: auction.ends_at).perform_later(auction_id) if now < auction.ends_at

      CloseAuction.call(auction:, now:)
    end
  end
end
