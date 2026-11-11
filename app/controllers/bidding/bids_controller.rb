module Bidding
  # Sealed bids (issue #31). HTML: form → review (nothing saved) → create. JSON:
  # POST /bidding/lots/:lot_id/bids with header Idempotency-Key and { amount, accept_terms }.
  # Errors are { error, message } with a Thai message.
  class BidsController < ApplicationController
    layout "bidding"
    PER_PAGE = 20

    before_action :require_login
    before_action :set_lot, only: %i[review create]

    def index
      @page = [ params[:page].to_i, 1 ].max
      rows = Bid.where(user_id: current_user.id).includes(lot: :auction).order(created_at: :desc)
        .limit(PER_PAGE + 1).offset((@page - 1) * PER_PAGE).to_a
      @next_page = rows.size > PER_PAGE
      @bids = rows.first(PER_PAGE)
    end

    # Shows the amount back for a last check. Saves nothing.
    def review
      @amount = Baht.parse(params[:amount])
      @amount_text = params[:amount].to_s
      @idempotency_key = params[:idempotency_key].presence || SecureRandom.uuid
      if @amount.nil? || !@amount.positive?
        redirect_to bidding_lot_path(@lot), alert: "ราคาต้องเป็นจำนวนเงินบาท ทศนิยมไม่เกิน 2 ตำแหน่ง ยังไม่ได้ยื่นซอง"
      elsif @amount < @lot.min_price_cents
        redirect_to bidding_lot_path(@lot), alert: "ราคาต้องไม่ต่ำกว่าราคาเริ่มต้นขั้นต่ำ ฿ #{Baht.format(@lot.min_price_cents)} ยังไม่ได้ยื่นซอง"
      end
    end

    def create
      result = PlaceSealedBid.call(
        lot: @lot, user: current_user, amount_text: params[:amount],
        idempotency_key: request.headers["Idempotency-Key"].presence || params[:idempotency_key],
        accept_terms: params[:accept_terms]
      )
      respond_to do |f|
        f.html { redirect_to bidding_lot_path(@lot), notice: result.replayed ? "ซองนี้ยื่นไว้แล้ว" : "ยื่นซองเรียบร้อย ราคาถูกเข้ารหัสและปิดผนึกแล้ว" }
        f.json { render json: receipt_json(result.bid), status: result.replayed ? :ok : :created }
      end
    rescue Bidding::Error => e
      respond_to do |f|
        f.html { redirect_to bidding_lot_path(@lot), alert: e.message }
        f.json { render json: { error: e.code, message: e.message }, status: e.http_status }
      end
    end

    private

    def set_lot
      @lot = AuctionLot.includes(:auction).find_by(id: params[:lot_id])
      head(:not_found) unless @lot && @lot.auction.visible_to?(current_user)
    end

    def receipt_json(bid)
      { bid: { receipt_no: bid.lot.receipt_no_for(bid), lot_id: bid.lot_id,
               submitted_at: bid.created_at.iso8601(3), amount_cents: bid.amount } }
    end
  end
end
