module Bidding
  # Places one English (ascending) bid (issue #32, docs/decision/bidding.md).
  #
  # In one transaction: lock the lot row → invited buyer who accepted → open by server time
  # (no extensions: the lot ends at the auction's end) → not the seller → not already leading →
  # amount ≥ next minimum (first bid: minimum price; then current price + increment) → insert →
  # move the lot's price, leader and count → audit log → commit → broadcast (#33).
  #
  # Concurrency: `lock!` is SELECT … FOR UPDATE on Postgres; SQLite runs write transactions as
  # IMMEDIATE, so they queue. The lot update is also a compare-and-set on `bid_count`, so two
  # bids can never both win the same price on any database.
  class PlaceEnglishBid
    include BidRequest

    Result = Data.define(:bid, :replayed)

    def self.call(...) = new(...).call

    def initialize(lot:, user:, amount_text:, idempotency_key:, now: Time.current)
      @lot = lot
      @user = user
      @amount_text = amount_text
      @key = idempotency_key.to_s.strip
      @now = now
    end

    def call
      check_key!(@key)
      amount = parse_amount!(@amount_text)
      if (earlier = replay(user: @user, key: @key, lot: @lot, amount:))
        return Result.new(bid: earlier, replayed: true)
      end

      previous_leader_id = nil
      bid = ActiveRecord::Base.transaction do
        @lot.lock!
        previous_leader_id = @lot.leader_bid&.user_id
        check_participant!
        check_open!
        check_not_seller!(@lot, @user)
        check_not_leading!
        check_amount!(amount)

        created = Bid.create!(lot: @lot, user_id: @user.id, amount:, idempotency_key: @key, created_at: @now)
        moved = AuctionLot.where(id: @lot.id, bid_count: @lot.bid_count)
          .update_all(current_price_cents: amount, leader_bid_id: created.id, bid_count: @lot.bid_count + 1, updated_at: @now)
        raise outbid_meanwhile if moved != 1

        AuditLog.record!(action: "bid.placed", entity: created, actor: @user,
          data: { lot_id: @lot.id, auction_id: @lot.auction_id, auction_type: "english" })
        created
      end
      @lot.reload
      # After commit only (#33): nobody hears about a bid that was rolled back.
      Broadcaster.bid_accepted(lot: @lot, previous_leader_id:)
      Result.new(bid:, replayed: false)
    rescue ActiveRecord::RecordNotUnique
      earlier = replay(user: @user, key: @key, lot: @lot, amount:)
      return Result.new(bid: earlier, replayed: true) if earlier

      raise outbid_meanwhile
    end

    private

    def check_participant!
      raise Error.new("wrong_auction_type", "This lot is not an English auction.", :unprocessable_content) unless @lot.auction.english?

      participant = @lot.auction.participants.find_by(user_id: @user.id)
      return if participant&.accepted? && @user.buyer?

      message = participant&.invited? ? "Accept the invitation before you bid. Your bid was not placed." : "This auction is open to invited buyers only. Your bid was not placed."
      raise Error.new("not_invited", message, :forbidden)
    end

    def check_open!
      return if @lot.accepting_bids?(@now)

      message = @now < @lot.auction.starts_at ? "Bidding hasn't opened yet. Your bid was not placed." : "Bidding is closed. Your bid was not placed."
      raise Error.new("bidding_closed", message, :conflict)
    end

    def check_not_leading!
      return unless @lot.leader_bid&.user_id == @user.id

      raise Error.new("already_leading", "You're already the highest bidder.", :conflict)
    end

    def check_amount!(amount)
      minimum = @lot.next_minimum_cents
      return if amount >= minimum

      raise Error.new("bid_too_low", "Your bid must be at least ฿ #{Baht.format(minimum)}. Your bid was not placed.", :unprocessable_content)
    end

    def outbid_meanwhile
      Error.new("price_moved", "Someone bid at the same moment, so your bid was not saved. Reload to see the latest price.", :conflict)
    end
  end
end
