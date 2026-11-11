require "test_helper"

class MockPaymentOrderTest < ActiveSupport::TestCase
  test "demo order includes item, price, pickup, and shipping details" do
    order = MockPaymentOrder.demo

    assert_equal "แหวนเพชรเม็ดใหญ่ (ตัวอย่าง)", order.item_title
    assert_equal "ภาพตัวอย่างแหวนเพชร", order.item_image_alt
    assert_equal 10_000_000, order.winning_bid_satang
    assert_equal 500_000, order.buyer_premium_satang
    assert_equal 50_000, order.shipping_fee_satang
    assert_not_empty order.pickup_location
    assert_not_empty order.pickup_hours
    assert_not_empty order.pickup_time_slot
    assert_not_empty order.shipping_address
    assert_not_empty order.shipping_carrier
  end

  test "quote uses server-owned item and delivery values" do
    order = MockPaymentOrder.demo

    assert_equal 11_288_500, order.quote(delivery_method: "shipping").total_satang
  end
end
