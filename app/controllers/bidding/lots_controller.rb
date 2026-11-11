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
      @history = BidHistory.new(lot: @lot, viewer: current_user, page: params[:history_page]) if @auction.english?
    end

    # GET /bidding/lots/:id/bids — English only, masked bidders, paginated (#34).
    # HTML returns the list fragment the live page swaps in; JSON for other clients.
    def history
      @lot = AuctionLot.includes(:auction).find_by(id: params[:id])
      return head(:not_found) unless @lot&.auction&.english? && @lot.auction.visible_to?(current_user)

      @history = BidHistory.new(lot: @lot, viewer: current_user, page: params[:page])
      respond_to do |f|
        f.html { render partial: "bidding/lots/history", locals: { lot: @lot, history: @history } }
        f.json do
          render json: { page: @history.page, next_page: @history.next_page?,
                         bids: @history.rows.map { |r| { bidder: r.bidder, mine: r.mine, amount_cents: r.amount_cents, placed_at: r.placed_at.iso8601(3) } } }
        end
      end
    end
  end
end
