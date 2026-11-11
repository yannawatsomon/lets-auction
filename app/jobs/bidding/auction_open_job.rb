module Bidding
  # Enqueued for auction.starts_at when the admin schedules (#35). If it runs early (clock skew,
  # rescheduling) it waits again until the start; late is fine.
  class AuctionOpenJob < ApplicationJob
    queue_as :default

    def perform(auction_id)
      auction = Auction.find_by(id: auction_id)
      return unless auction&.scheduled?

      now = Time.current
      return self.class.set(wait_until: auction.starts_at).perform_later(auction_id) if now < auction.starts_at

      OpenAuction.call(auction:, now:)
    end
  end
end
