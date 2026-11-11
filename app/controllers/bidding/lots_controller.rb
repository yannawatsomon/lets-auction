module Bidding
  # The bid room for one lot (/bidding/lots/:id, adapted from mockup "SealedBid").
  # Shows only the viewer's own bid; nothing about anyone else's (bidding.md).
  class LotsController < ApplicationController
    layout "bidding"

    def show
      @lot = AuctionLot.includes(:auction).find_by(id: params[:id])
      return head(:not_found) unless @lot && @lot.auction.visible_to?(current_user)

      @auction = @lot.auction
      @now = Time.current
      @participant = current_user && @auction.participants.find_by(user_id: current_user.id)
      @my_bid = current_user && @lot.bids.where(user_id: current_user.id).order(:created_at).last
      @idempotency_key = SecureRandom.uuid
    end
  end
end
