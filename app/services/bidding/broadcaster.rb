module Bidding
  # Builds and sends AuctionChannel messages (issue #33). Call only after the database
  # transaction has committed, so nobody hears about a bid that was rolled back.
  # Messages carry public facts only: never sealed amounts or sealed bid counts, never who a
  # bidder is (English leaders are masked as "ผู้ประมูล N").
  module Broadcaster
    module_function

    def auction_stream(auction) = "bidding:auction:#{auction.id}"

    def user_stream(auction, user) = "bidding:auction:#{auction.id}:user:#{user.id}"

    def lot_state(auction, now: Time.current)
      {
        type: "lot.state",
        server_time: now.iso8601(3),
        auction: { id: auction.id, status: auction.status, auction_type: auction.auction_type,
                   starts_at: auction.starts_at.iso8601, ends_at: auction.ends_at.iso8601 },
        lots: auction.lots.map { |lot| lot_json(lot) }
      }
    end

    # English only. Sealed bids are never broadcast.
    def bid_accepted(lot:, previous_leader_id:)
      return unless lot.auction.english?

      ActionCable.server.broadcast(auction_stream(lot.auction), { type: "bid.accepted", lot: lot_json(lot) })
      return if previous_leader_id.nil? || previous_leader_id == lot.leader_bid&.user_id

      loser = MockData.user(previous_leader_id)
      return unless loser

      ActionCable.server.broadcast(user_stream(lot.auction, loser),
        { type: "bid.outbid", lot_id: lot.id, current_price_cents: lot.current_price_cents,
          next_minimum_cents: lot.next_minimum_cents })
    end

    # For the close job (#35).
    def lot_closed(lot)
      ActionCable.server.broadcast(auction_stream(lot.auction), { type: "lot.closed", lot_id: lot.id })
    end

    # For the results approval (#36). Clients then fetch their own result.
    def result_published(auction)
      ActionCable.server.broadcast(auction_stream(auction), { type: "auction.result_published", auction_id: auction.id })
    end

    def lot_json(lot)
      base = { id: lot.id, lot_no: lot.lot_no, status: lot.status, min_price_cents: lot.min_price_cents,
               ends_at: lot.ends_at.iso8601 }
      return base unless lot.auction.english?

      base.merge(current_price_cents: lot.current_price_cents, bid_count: lot.bid_count,
        next_minimum_cents: lot.next_minimum_cents, bid_increment_cents: lot.bid_increment_cents,
        leader: masked_leader(lot))
    end

    # "ผู้ประมูล 2": the leader's position in the auction's participant list, so bidders can tell
    # leaders apart without learning who they are.
    def masked_leader(lot)
      leader_id = lot.leader_bid&.user_id
      return unless leader_id

      ids = lot.auction.participants.order(:id).pluck(:user_id)
      position = ids.index(leader_id)
      position ? "ผู้ประมูล #{position + 1}" : "ผู้ประมูล"
    end
  end
end
