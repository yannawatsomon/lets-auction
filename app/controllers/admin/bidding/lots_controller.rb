module Admin
  module Bidding
    class LotsController < BaseController
      before_action :set_auction

      def create
        item = AuctionItems.find(params[:item_id])
        increment = nil
        if @auction.english?
          increment = Baht.parse(params[:bid_increment])
          raise Auction::Error, "The bid increment must be an amount in baht above 0, with up to 2 decimal places." unless increment&.positive?
        end
        lot = @auction.add_item!(item, bid_increment_cents: increment)
        audit!("auction.lot_added", @auction, { lot_id: lot.id, item_id: lot.item_id })
        redirect_to admin_bidding_auction_path(@auction), notice: "Item added."
      end

      def destroy
        lot = @auction.lots.find(params[:id])
        @auction.remove_lot!(lot)
        audit!("auction.lot_removed", @auction, { lot_id: lot.id, item_id: lot.item_id })
        redirect_to admin_bidding_auction_path(@auction), notice: "Item removed."
      end

      private

      def set_auction
        @auction = Auction.find(params[:auction_id])
      end
    end
  end
end
