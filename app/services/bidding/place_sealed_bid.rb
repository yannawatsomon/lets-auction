module Bidding
  # Places one sealed (first-price) bid (issue #31). Everything happens in one transaction, in
  # the order of docs/decision/bidding.md: participant → open by server time → not the seller →
  # amount ≥ minimum → no earlier bid (the DB index backs this) → insert → audit log.
  #
  # Idempotency: the same buyer + key returns the first bid again (`replayed: true`); the same
  # key with a different lot or amount is a conflict. Never logs or audits the amount.
  class PlaceSealedBid
    include BidRequest

    Result = Data.define(:bid, :replayed)

    def self.call(...) = new(...).call

    def initialize(lot:, user:, amount_text:, idempotency_key:, accept_terms: true, now: Time.current)
      @lot = lot
      @user = user
      @amount_text = amount_text
      @key = idempotency_key.to_s.strip
      @accept_terms = ActiveModel::Type::Boolean.new.cast(accept_terms)
      @now = now
    end

    def call
      check_key!(@key)
      amount = parse_amount!(@amount_text)

      if (earlier = replay(user: @user, key: @key, lot: @lot, amount:))
        return Result.new(bid: earlier, replayed: true)
      end
      raise Error.new("terms_not_accepted", "กรุณายืนยันว่าเข้าใจกติกาก่อนยื่นซอง ยังไม่ได้ยื่นซอง", :unprocessable_content) unless @accept_terms

      bid = ActiveRecord::Base.transaction do
        check_participant!
        check_open!
        check_not_seller!(@lot, @user)
        check_amount!(amount)
        check_no_earlier_bid!
        created = Bid.create!(lot: @lot, user_id: @user.id, amount:, idempotency_key: @key, created_at: @now)
        AuditLog.record!(action: "bid.placed", entity: created, actor: @user,
          data: { lot_id: @lot.id, auction_id: @lot.auction_id, auction_type: "sealed_first_price" })
        created
      end
      Result.new(bid:, replayed: false)
    rescue ActiveRecord::RecordNotUnique
      # Two requests at once: the database let only one through.
      earlier = replay(user: @user, key: @key, lot: @lot, amount:)
      return Result.new(bid: earlier, replayed: true) if earlier

      raise already_bid
    end

    private

    def check_participant!
      raise Error.new("wrong_auction_type", "ล็อตนี้ไม่ใช่การประมูลแบบยื่นซอง", :unprocessable_content) unless @lot.auction.sealed_first_price?
      participant = @lot.auction.participants.find_by(user_id: @user.id)
      return if participant&.registered? && @user.buyer?

      raise Error.new("not_registered", "คุณยังไม่ได้ลงทะเบียนเข้างานนี้ ยังไม่ได้ยื่นซอง ลงทะเบียนที่หน้างานก่อน", :forbidden)
    end

    def check_open!
      return if @lot.accepting_bids?(@now)

      message = @now < @lot.auction.starts_at ? "ยังไม่ถึงเวลาเปิดรับซอง ยังไม่ได้ยื่นซอง" : "ปิดรับซองแล้ว ยังไม่ได้ยื่นซอง"
      raise Error.new("bidding_closed", message, :conflict)
    end

    def check_amount!(amount)
      return if amount >= @lot.min_price_cents

      raise Error.new("amount_below_start", "ราคาต้องไม่ต่ำกว่าราคาเริ่มต้นขั้นต่ำ ฿ #{Baht.format(@lot.min_price_cents)} ยังไม่ได้ยื่นซอง", :unprocessable_content)
    end

    def check_no_earlier_bid!
      raise already_bid if @lot.bids.exists?(user_id: @user.id)
    end

    def already_bid
      Error.new("already_bid", "คุณยื่นซองล็อตนี้ไปแล้ว ซองเดิมของคุณยังอยู่ครบ ยื่นได้ครั้งเดียวและแก้ไขไม่ได้", :conflict)
    end
  end
end
