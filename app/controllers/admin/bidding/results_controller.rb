module Admin
  module Bidding
    # Ranking and approval (#36, mockup A3). Rankings are visible only once the auction has
    # closed (bidding.md); one admin approves, and every step is audit-logged.
    class ResultsController < BaseController
      rescue_from ::Bidding::Error do |e|
        redirect_to results_admin_bidding_auction_path(params[:auction_id] || params[:id]), alert: e.message, status: :see_other
      end

      def show
        @auction = Auction.find(params[:id])
        unless @auction.awaiting_approval? || @auction.published?
          return redirect_to(admin_bidding_auction_path(@auction), alert: "ดูอันดับได้หลังปิดรับเท่านั้น", status: :see_other)
        end

        @lots = @auction.lots.to_a
        AuditLog.record!(action: "auction.results_viewed", entity: @auction, actor: current_user)
      end

      def approve
        auction = Auction.find(params[:id])
        ::Bidding::Results.approve!(auction:, admin: current_user)
        redirect_to results_admin_bidding_auction_path(auction), notice: "อนุมัติผลแล้ว แจ้งผู้ชนะแล้ว (ชำระภายใน 48 ชั่วโมง)", status: :see_other
      end

      def disqualify
        lot = AuctionLot.find_by!(id: params[:id], auction_id: params[:auction_id])
        ::Bidding::Results.disqualify!(lot:, user_id: params[:user_id], reason: params[:reason], admin: current_user)
        redirect_to results_admin_bidding_auction_path(lot.auction_id), notice: "ตัดสิทธิ์แล้ว อันดับถัดไปจะได้รับข้อเสนอเมื่ออนุมัติผล", status: :see_other
      end

      def mark_paid
        order = ::Bidding::OrderStore.find(params[:id])
        return redirect_to(admin_bidding_auctions_path, alert: "ไม่พบรายการนี้ (ข้อมูล mock หายเมื่อ restart)", status: :see_other) unless order

        ::Bidding::Results.mark_paid!(order_id: params[:id], admin: current_user)
        redirect_to results_admin_bidding_auction_path(order.auction_id), notice: "บันทึกว่าชำระแล้ว (mock)", status: :see_other
      end
    end
  end
end
