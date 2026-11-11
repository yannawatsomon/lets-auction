module Bidding
  # Places one English (ascending) bid (issue #32, docs/decision/bidding.md).
  #
  # In one transaction: lock the lot row → invited buyer who accepted → open by server time
  # (no extensions: the lot ends at the auction's end) → not the seller → not already leading →
  # amount ≥ next minimum (first bid: minimum price; then current price + increment) → insert →
  # move the lot's price, leader and count → audit log. Broadcasting comes after commit (#33).
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

      bid = ActiveRecord::Base.transaction do
        @lot.lock!
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
      Result.new(bid:, replayed: false)
    rescue ActiveRecord::RecordNotUnique
      earlier = replay(user: @user, key: @key, lot: @lot, amount:)
      return Result.new(bid: earlier, replayed: true) if earlier

      raise outbid_meanwhile
    end

    private

    def check_participant!
      raise Error.new("wrong_auction_type", "ล็อตนี้ไม่ใช่การประมูลแบบ English", :unprocessable_content) unless @lot.auction.english?

      participant = @lot.auction.participants.find_by(user_id: @user.id)
      return if participant&.accepted? && @user.buyer?

      message = participant&.invited? ? "ตอบรับคำเชิญก่อนจึงจะเสนอราคาได้ ยังไม่ได้ยื่นราคา" : "งานนี้เปิดเฉพาะผู้ที่ได้รับเชิญ ยังไม่ได้ยื่นราคา"
      raise Error.new("not_invited", message, :forbidden)
    end

    def check_open!
      return if @lot.accepting_bids?(@now)

      message = @now < @lot.auction.starts_at ? "ยังไม่ถึงเวลาเปิดประมูล ยังไม่ได้ยื่นราคา" : "ปิดประมูลแล้ว ยังไม่ได้ยื่นราคา"
      raise Error.new("bidding_closed", message, :conflict)
    end

    def check_not_leading!
      return unless @lot.leader_bid&.user_id == @user.id

      raise Error.new("already_leading", "คุณเป็นผู้นำอยู่แล้ว ไม่ต้องเสนอราคาซ้ำ", :conflict)
    end

    def check_amount!(amount)
      minimum = @lot.next_minimum_cents
      return if amount >= minimum

      raise Error.new("bid_too_low", "ราคาต้องไม่ต่ำกว่า ฿ #{Baht.format(minimum)} ยังไม่ได้ยื่นราคา", :unprocessable_content)
    end

    def outbid_meanwhile
      Error.new("price_moved", "มีผู้เสนอราคาเข้ามาพร้อมกันพอดี ราคาของคุณยังไม่ถูกบันทึก โหลดหน้าใหม่แล้วดูราคาล่าสุด", :conflict)
    end
  end
end
