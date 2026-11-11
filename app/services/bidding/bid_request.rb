module Bidding
  # What sealed (#31) and English (#32) bid placement share: the idempotency key, the amount
  # text → satang, and replaying an earlier bid for the same key.
  module BidRequest
    private

    def check_key!(key)
      return if key.present? && key.length <= 200

      raise Error.new("idempotency_key_required", "คำขอไม่สมบูรณ์ ยังไม่ได้ยื่นราคา ลองโหลดหน้าใหม่แล้วยื่นอีกครั้ง", :bad_request)
    end

    def parse_amount!(text)
      amount = Baht.parse(text)
      return amount if amount&.positive?

      raise Error.new("amount_invalid", "ราคาต้องเป็นจำนวนเงินบาท ทศนิยมไม่เกิน 2 ตำแหน่ง ยังไม่ได้ยื่นราคา", :unprocessable_content)
    end

    # The same buyer + key: the first bid again if it was for this lot and amount, else a conflict.
    def replay(user:, key:, lot:, amount:)
      earlier = Bid.find_by(user_id: user.id, idempotency_key: key)
      return unless earlier
      return earlier if earlier.lot_id == lot.id && earlier.amount == amount

      raise Error.new("idempotency_conflict", "คำขอนี้ถูกใช้กับราคาอื่นแล้ว ราคาเดิมของคุณยังอยู่ครบ โหลดหน้าใหม่แล้วตรวจสอบ", :conflict)
    end

    def check_not_seller!(lot, user)
      return unless lot.item&.seller_id == user.id

      raise Error.new("own_item", "เสนอราคาในสินค้าของตัวเองไม่ได้", :forbidden)
    end
  end
end
