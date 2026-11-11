module Bidding
  # Buyer-facing auction pages (/bidding/auctions). English (invite-only) auctions are 404
  # unless you're invited.
  class AuctionsController < ApplicationController
    layout "bidding"
    PER_PAGE = 20

    def index
      @page = [ params[:page].to_i, 1 ].max
      rows = Auction.listed_for_buyers.order(:starts_at).includes(:lots).limit(PER_PAGE + 1).offset((@page - 1) * PER_PAGE).to_a
      @next_page = rows.size > PER_PAGE
      @auctions = rows.first(PER_PAGE)
    end

    def show
      @auction = Auction.find_by(id: params[:id])
      return head(:not_found) unless @auction&.visible_to?(current_user)

      @participant = current_user && @auction.participants.find_by(user_id: current_user.id)
      @ineligible = current_user && AuctionParticipant.ineligibility(auction: @auction, user: current_user)
    end
  end
end
