require "test_helper"

class PaymentQuoteTest < ActiveSupport::TestCase
  test "calculates pickup subtotal and VAT in satang" do
    quote = PaymentQuote.new(
      winning_bid_satang: 10_000_000,
      buyer_premium_satang: 500_000,
      shipping_fee_satang: 500_00,
      delivery_method: "self_pickup"
    )

    assert_equal 10_500_000, quote.subtotal_satang
    assert_equal 735_000, quote.vat_satang
    assert_equal 11_235_000, quote.total_satang
  end

  test "includes shipping in the subtotal and VAT" do
    quote = PaymentQuote.new(
      winning_bid_satang: 10_000_000,
      buyer_premium_satang: 500_000,
      shipping_fee_satang: 50_000,
      delivery_method: "shipping"
    )

    assert_equal 10_550_000, quote.subtotal_satang
    assert_equal 738_500, quote.vat_satang
    assert_equal 11_288_500, quote.total_satang
  end

  test "rounds VAT to the nearest satang" do
    quote = PaymentQuote.new(
      winning_bid_satang: 8,
      buyer_premium_satang: 0,
      shipping_fee_satang: 0,
      delivery_method: "self_pickup"
    )

    assert_equal 1, quote.vat_satang
  end

  test "rejects an unknown delivery method" do
    assert_raises(ArgumentError) do
      PaymentQuote.new(
        winning_bid_satang: 10_000_000,
        buyer_premium_satang: 500_000,
        shipping_fee_satang: 50_000,
        delivery_method: "courier"
      )
    end
  end

  test "rejects negative or fractional amounts" do
    [ -1, 0.5 ].each do |amount|
      assert_raises(ArgumentError) do
        PaymentQuote.new(
          winning_bid_satang: amount,
          buyer_premium_satang: 0,
          shipping_fee_satang: 0,
          delivery_method: "self_pickup"
        )
      end
    end
  end
end
