module Bidding
  # A buyer's own result for a lot (#36, mockup B6). Before the admin publishes: 403
  # not_revealed. After: won (with the offer and its 48-hour deadline) or not, and their rank.
  class ResultsController < ApplicationController
    layout "bidding"
    before_action :require_login

    def show
      @lot = AuctionLot.includes(:auction).find_by(id: params[:id])
      return head(:not_found) unless @lot && @lot.auction.visible_to?(current_user)

      @auction = @lot.auction
      unless @auction.published?
        return respond_to do |f|
          f.html { render :not_revealed, status: :forbidden }
          f.json { render json: { error: "not_revealed", message: "ยังไม่ประกาศผล" }, status: :forbidden }
        end
      end

      @results = @lot.results
      @mine = @results.find { |r| r.user_id == current_user.id }
      @orders = OrderStore.for_lot(@lot.id)
      @my_offer = @orders.find { |o| o.buyer_id == current_user.id }
      @winning = @orders.find(&:paid?) || @orders.find(&:awaiting_payment?)
      respond_to do |f|
        f.html
        f.json { render json: result_json }
      end
    end

    def decline
      order = OrderStore.find(params[:id])
      Results.decline!(order_id: params[:id], buyer: current_user)
      redirect_to result_bidding_lot_path(order.lot_id), notice: "สละสิทธิ์แล้ว สิทธิ์จะไปที่อันดับถัดไป", status: :see_other
    rescue Bidding::Error => e
      respond_to do |f|
        f.html { redirect_to bidding_bids_path, alert: e.message, status: :see_other }
        f.json { render json: { error: e.code, message: e.message }, status: e.http_status }
      end
    end

    private

    def result_json
      { lot_id: @lot.id, bid_count: @results.size, my_rank: @mine&.rank, my_amount_cents: @mine&.amount_cents,
        offer: @my_offer && { status: @my_offer.status, amount_cents: @my_offer.amount_cents, payment_due_at: @my_offer.payment_due_at.iso8601 } }
    end
  end
end
