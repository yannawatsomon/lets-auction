module Admin
  module Bidding
    # Admin invites grade-A buyers to English auctions and revokes participants (issue #29).
    class InvitationsController < BaseController
      before_action :set_auction

      def create
        user = MockData.user(params[:user_id])
        participant = AuctionParticipant.invite!(auction: @auction, user:, admin: current_user)
        audit!("participant.invited", participant, { auction_id: @auction.id, user_id: participant.user_id, grade: participant.grade_at_entry })
        redirect_to admin_bidding_auction_path(@auction), notice: "ส่งคำเชิญแล้ว"
      rescue AuctionParticipant::Error => e
        redirect_to admin_bidding_auction_path(@auction), alert: e.message
      end

      def revoke
        participant = @auction.participants.find(params[:id])
        participant.revoke!(admin: current_user)
        audit!("participant.revoked", participant, { auction_id: @auction.id, user_id: participant.user_id })
        redirect_to admin_bidding_auction_path(@auction), notice: "ยกเลิกสิทธิ์แล้ว"
      rescue AuctionParticipant::Error => e
        redirect_to admin_bidding_auction_path(@auction), alert: e.message
      end

      private

      def set_auction
        @auction = Auction.find(params[:auction_id])
      end
    end
  end
end
