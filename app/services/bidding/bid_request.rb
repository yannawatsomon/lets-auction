module Bidding
  # What sealed (#31) and English (#32) bid placement share: the idempotency key, the amount
  # text → satang, and replaying an earlier bid for the same key.
  module BidRequest
    private

    def check_key!(key)
      return if key.present? && key.length <= 200

      raise Error.new("idempotency_key_required", "The request was incomplete, so your bid was not placed. Reload the page and try again.", :bad_request)
    end

    def parse_amount!(text)
      amount = Baht.parse(text)
      return amount if amount&.positive?

      raise Error.new("amount_invalid", "Enter an amount in baht with up to 2 decimal places. Your bid was not placed.", :unprocessable_content)
    end

    # The same buyer + key: the first bid again if it was for this lot and amount, else a conflict.
    def replay(user:, key:, lot:, amount:)
      earlier = Bid.find_by(user_id: user.id, idempotency_key: key)
      return unless earlier
      return earlier if earlier.lot_id == lot.id && earlier.amount == amount

      raise Error.new("idempotency_conflict", "This request was already used with a different amount. Your earlier bid is kept; reload the page to check.", :conflict)
    end

    def check_not_seller!(lot, user)
      return unless lot.item&.seller_id == user.id

      raise Error.new("own_item", "You can't bid on your own item.", :forbidden)
    end
  end
end
