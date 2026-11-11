module Bidding
  # English bid history for one lot (issue #34), newest first, with bidders masked as
  # "ผู้ประมูล N" (same numbering as Broadcaster.masked_leader). The viewer's own bids say "คุณ".
  # Never used for sealed lots: their amounts stay secret until results are published.
  class BidHistory
    PER_PAGE = 20
    Row = Data.define(:bidder, :mine, :amount_cents, :placed_at)

    def initialize(lot:, viewer:, page: 1)
      @lot = lot
      @viewer = viewer
      @page = [ page.to_i, 1 ].max
    end

    attr_reader :page

    def rows
      @rows ||= begin
        bids = @lot.bids.order(created_at: :desc, id: :desc).limit(PER_PAGE + 1).offset((@page - 1) * PER_PAGE).to_a
        @next_page = bids.size > PER_PAGE
        bids.first(PER_PAGE).map { |b| to_row(b) }
      end
    end

    def next_page?
      rows
      @next_page
    end

    # The viewer's own masked label, so the live page can tell "you're leading" from a broadcast.
    def viewer_label = label_for(@viewer&.id)

    private

    def to_row(bid)
      mine = @viewer && bid.user_id == @viewer.id
      Row.new(bidder: mine ? "คุณ" : label_for(bid.user_id), mine: !!mine, amount_cents: bid.amount, placed_at: bid.created_at)
    end

    def label_for(user_id)
      return unless user_id

      position = participant_ids.index(user_id)
      position ? "ผู้ประมูล #{position + 1}" : nil
    end

    def participant_ids
      @participant_ids ||= @lot.auction.participants.order(:id).pluck(:user_id)
    end
  end
end
