module Bidding
  # POST /bidding/auctions/:auction_id/registration — sealed only (issue #29).
  class RegistrationsController < ApplicationController
    before_action :require_login

    def create
      auction = Auction.find_by(id: params[:auction_id])
      return head(:not_found) unless auction&.visible_to?(current_user)

      participant = AuctionParticipant.register!(auction:, user: current_user)
      respond_to do |f|
        f.html { redirect_to bidding_auction_path(auction), notice: "ลงทะเบียนเข้าร่วมงานแล้ว" }
        f.json { render json: { status: participant.status, auction_id: auction.id }, status: :created }
      end
    rescue AuctionParticipant::Error => e
      render_participation_error(e, bidding_auction_path(auction))
    end
  end
end
