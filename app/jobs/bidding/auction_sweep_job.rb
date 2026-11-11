module Bidding
  # Safety net (#35), every minute from config/recurring.yml: opens and closes any auction whose
  # time has come, in case a scheduled job was lost. Bids never depend on it — the bid check uses
  # server time itself (AuctionLot#accepting_bids?).
  class AuctionSweepJob < ApplicationJob
    queue_as :default

    def perform(now: Time.current)
      Auction.where(status: "scheduled").where(starts_at: ..now).where("ends_at > ?", now).find_each { |a| OpenAuction.call(auction: a, now:) }
      Auction.where(status: %w[scheduled live]).where(ends_at: ..now).find_each { |a| CloseAuction.call(auction: a, now:) }
    end
  end
end
