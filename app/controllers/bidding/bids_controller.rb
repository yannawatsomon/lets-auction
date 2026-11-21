module Bidding
  # Bids (sealed #31, English #32): one endpoint, the logic branches on the auction type.
  # Sealed HTML: form → review (nothing saved) → create. English HTML: one confirmed form.
  # JSON: POST /bidding/lots/:lot_id/bids with header Idempotency-Key and { amount, accept_terms }.
  # Errors are { error, message } with a Thai message.
  class BidsController < ApplicationController
    layout "bidding"
    PER_PAGE = 20

    before_action :require_login
    before_action :set_lot, only: %i[review create]

    # Bid spam guard (#37, security-review §5): per buyer, across all lots. In-process store like
    # Onboarding::IdentitiesController's; move to the shared cache with the database.
    RATE_LIMIT_STORE = ActiveSupport::Cache::MemoryStore.new
    RATE_LIMIT = 30
    rate_limit to: RATE_LIMIT, within: 1.minute, only: %i[review create], store: RATE_LIMIT_STORE,
      by: -> { current_user.id }, with: -> { too_many_requests }

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
        redirect_to bidding_lot_path(@lot), alert: "Enter an amount in baht with up to 2 decimal places. Your bid was not placed."
      elsif @amount < @lot.min_price_cents
        redirect_to bidding_lot_path(@lot), alert: "Your bid must be at least the starting price of ฿ #{Baht.format(@lot.min_price_cents)}. Your bid was not placed."
      end
    end

    def create
      key = request.headers["Idempotency-Key"].presence || params[:idempotency_key]
      result =
        if @lot.auction.english?
          PlaceEnglishBid.call(lot: @lot, user: current_user, amount_text: params[:amount], idempotency_key: key)
        else
          PlaceSealedBid.call(lot: @lot, user: current_user, amount_text: params[:amount], idempotency_key: key,
            accept_terms: params[:accept_terms])
        end
      respond_to do |f|
        f.html { redirect_to bidding_lot_path(@lot), notice: placed_notice(result), status: :see_other }
        f.json { render json: receipt_json(result.bid), status: result.replayed ? :ok : :created }
      end
    rescue Bidding::Error => e
      respond_to do |f|
        f.html { redirect_to bidding_lot_path(@lot), alert: e.message, status: :see_other }
        f.json { render json: { error: e.code, message: e.message }, status: e.http_status }
      end
    end

    private

    def too_many_requests
      message = "Too many bids too quickly. This request was not saved; wait a minute and try again."
      respond_to do |f|
        f.html { redirect_to(@lot ? bidding_lot_path(@lot) : bidding_auctions_path, alert: message, status: :see_other) }
        f.json { render json: { error: "rate_limited", message: }, status: :too_many_requests }
      end
    end

    def set_lot
      @lot = AuctionLot.includes(:auction).find_by(id: params[:lot_id])
      head(:not_found) unless @lot && @lot.auction.visible_to?(current_user)
    end

    def placed_notice(result)
      return "This request was already saved." if result.replayed

      @lot.auction.english? ? "Bid placed. You're the highest bidder." : "Your bid is sealed. The amount is encrypted."
    end

    def receipt_json(bid)
      { bid: { receipt_no: bid.lot.receipt_no_for(bid), lot_id: bid.lot_id,
               submitted_at: bid.created_at.iso8601(3), amount_cents: bid.amount } }
    end
  end
end
