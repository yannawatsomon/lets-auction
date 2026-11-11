module Admin
  class AuctionLotsController < BaseController
    before_action :set_auction

    def create
      item = MockData.item(params[:item_id])
      increment = nil
      if @auction.english?
        increment = Baht.parse(params[:bid_increment])
        raise Auction::Error, "ขั้นบิดขั้นต่ำต้องเป็นจำนวนเงินบาท ทศนิยมไม่เกิน 2 ตำแหน่ง และมากกว่า 0" unless increment&.positive?
      end
      @auction.add_item!(item, bid_increment_cents: increment)
      redirect_to admin_auction_path(@auction), notice: "เพิ่มสินค้าเข้างานแล้ว"
    end

    def destroy
      @auction.remove_lot!(@auction.lots.find(params[:id]))
      redirect_to admin_auction_path(@auction), notice: "เอาสินค้าออกจากงานแล้ว"
    end

    private

    def set_auction
      @auction = Auction.find(params[:auction_id])
    end
  end
end
