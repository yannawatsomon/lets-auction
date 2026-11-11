class PaymentQuote
  VAT_PERCENT = 7
  DELIVERY_METHODS = %w[self_pickup shipping].freeze

  attr_reader :subtotal_satang, :vat_satang, :total_satang

  def initialize(winning_bid_satang:, buyer_premium_satang:, shipping_fee_satang:, delivery_method:)
    unless DELIVERY_METHODS.include?(delivery_method)
      raise ArgumentError, "delivery method is invalid"
    end

    [ winning_bid_satang, buyer_premium_satang, shipping_fee_satang ].each do |amount|
      raise ArgumentError, "amount must be a non-negative integer" unless amount.is_a?(Integer) && amount >= 0
    end

    delivery_fee = delivery_method == "shipping" ? shipping_fee_satang : 0
    @subtotal_satang = winning_bid_satang + buyer_premium_satang + delivery_fee
    @vat_satang = (@subtotal_satang * VAT_PERCENT + 50) / 100
    @total_satang = @subtotal_satang + @vat_satang
  end
end
