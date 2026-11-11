module Admin
  module Bidding
    class AuctionsController < BaseController
      PER_PAGE = 20

      before_action :set_auction, only: %i[show edit update schedule cancel]

      def index
        @page = [ params[:page].to_i, 1 ].max
        @status = params[:status].presence_in(Auction.statuses.keys)
        scope = Auction.order(starts_at: :desc)
        scope = scope.where(status: @status) if @status
        @auctions = scope.includes(:lots).limit(PER_PAGE + 1).offset((@page - 1) * PER_PAGE).to_a
        @next_page = @auctions.size > PER_PAGE
        @auctions = @auctions.first(PER_PAGE)
      end

      def show
        @available_items = AuctionItems.approved.reject { |i| @auction.item_ids.include?(i.id) }
        @busy_item_ids = AuctionLot.where(status: AuctionLot::OPEN_STATUSES).where.not(auction_id: @auction.id).pluck(:item_id)
        @participants = @auction.participants.order(:created_at).limit(200)
        @invitable_users = @auction.english? ? AuctionParticipant.invitable_users(@auction) : []
      end

      def new
        @auction = Auction.new(auction_type: "sealed_first_price",
          starts_at: 1.day.from_now.change(min: 0), ends_at: 3.days.from_now.change(min: 0))
      end

      def create
        @auction = Auction.new(auction_params.merge(created_by_id: current_user.id))
        if @auction.save
          audit!("auction.created", @auction, { auction_type: @auction.auction_type })
          redirect_to admin_bidding_auction_path(@auction), notice: "สร้างงานแล้ว เลือกสินค้าเข้างานได้เลย"
        else
          render :new, status: :unprocessable_content
        end
      end

      def edit
        redirect_to admin_bidding_auction_path(@auction), alert: "แก้ไขได้เฉพาะงานที่ยังเป็นร่าง" unless @auction.draft?
      end

      def update
        if @auction.update(auction_params)
          audit!("auction.updated", @auction, { changed: @auction.saved_changes.keys - %w[updated_at] })
          redirect_to admin_bidding_auction_path(@auction), notice: "บันทึกแล้ว"
        else
          render :edit, status: :unprocessable_content
        end
      end

      def schedule
        @auction.schedule!
        audit!("auction.scheduled", @auction, { lots: @auction.lots.map(&:id) })
        redirect_to admin_bidding_auction_path(@auction), notice: "เผยแพร่งานแล้ว จะเริ่มตามเวลาที่ตั้งไว้"
      end

      def cancel
        @auction.cancel!(reason: params[:cancel_reason])
        audit!("auction.cancelled", @auction, { reason: @auction.cancel_reason })
        redirect_to admin_bidding_auction_path(@auction), notice: "ยกเลิกงานแล้ว"
      end

      private

      def set_auction
        @auction = Auction.find(params[:id])
      end

      def auction_params
        p = params.expect(auction: %i[title description auction_type starts_at ends_at])
        p[:auction_type] = nil if p.key?(:auction_type) && !Auction.auction_types.key?(p[:auction_type])
        p
      end
    end
  end
end
