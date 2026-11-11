module Bidding
  # A buyer's English invitations (/bidding/invitations, issue #29). Only your own: anyone
  # else's id is 404.
  class InvitationsController < ApplicationController
    layout "bidding"
    before_action :require_login

    def index
      @invitations = AuctionParticipant.via_invited.where(user_id: current_user.id)
        .where.not(status: "revoked").includes(:auction).order(created_at: :desc).limit(50)
    end

    def accept
      invitation = AuctionParticipant.via_invited.find_by(id: params[:id], user_id: current_user.id)
      return head(:not_found) unless invitation

      invitation.accept!(user: current_user)
      respond_to do |f|
        f.html { redirect_to bidding_auction_path(invitation.auction), notice: "ตอบรับคำเชิญแล้ว" }
        f.json { render json: { status: invitation.status }, status: :ok }
      end
    rescue AuctionParticipant::Error => e
      render_participation_error(e, bidding_invitations_path)
    end
  end
end
