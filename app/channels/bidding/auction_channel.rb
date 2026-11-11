module Bidding
  # Live auction state (issue #33, docs/decision/realtime.md). Read-only: bids still go through
  # POST /bidding/lots/:id/bids. Subscribe with { channel: "Bidding::AuctionChannel", auction_id }.
  #
  # Who may subscribe: a logged-in admin, or a buyer who is an active participant (registered
  # for sealed, accepted for English). Everyone else is rejected.
  #
  # Events: `lot.state` (on subscribe, with server_time), `bid.accepted`, `bid.outbid` (only to
  # the buyer who lost the lead), `lot.closed`, `auction.result_published`. Sealed auctions never
  # get bid events — they would leak bid activity (bidding.md).
  class AuctionChannel < ApplicationCable::Channel
    def subscribed
      @auction = Auction.find_by(id: params[:auction_id])
      return reject unless @auction && allowed?

      stream_from Broadcaster.auction_stream(@auction)
      stream_from Broadcaster.user_stream(@auction, current_user) unless current_user.admin?
      transmit Broadcaster.lot_state(@auction)
    end

    private

    def allowed?
      user = current_user
      return false unless user
      return true if user.admin? && !@auction.draft?

      @auction.participants.active.exists?(user_id: user.id) && !@auction.cancelled?
    end
  end
end
