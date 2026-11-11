class MockPaymentOrder
  attr_reader :item_title, :item_image_alt, :winning_bid_satang, :buyer_premium_satang,
    :shipping_fee_satang, :pickup_location, :pickup_hours, :pickup_time_slot,
    :shipping_address, :shipping_carrier

  def self.demo
    new(
      item_title: "แหวนเพชรเม็ดใหญ่ (ตัวอย่าง)",
      item_image_alt: "ภาพตัวอย่างแหวนเพชร",
      winning_bid_satang: 10_000_000,
      buyer_premium_satang: 500_000,
      shipping_fee_satang: 50_000,
      pickup_location: "ศูนย์รับสินค้า Lets Auction, กรุงเทพฯ",
      pickup_hours: "จันทร์–เสาร์ 09:00–18:00 น.",
      pickup_time_slot: "เลือกวันและเวลารับสินค้าหลังชำระเงิน",
      shipping_address: "ที่อยู่จัดส่งตัวอย่าง — เพิ่มที่อยู่จริงภายหลัง",
      shipping_carrier: "ขนส่งมาตรฐาน (ตัวอย่าง)"
    )
  end

  def initialize(item_title:, item_image_alt:, winning_bid_satang:, buyer_premium_satang:,
    shipping_fee_satang:, pickup_location:, pickup_hours:, pickup_time_slot:,
    shipping_address:, shipping_carrier:)
    @item_title = item_title
    @item_image_alt = item_image_alt
    @winning_bid_satang = winning_bid_satang
    @buyer_premium_satang = buyer_premium_satang
    @shipping_fee_satang = shipping_fee_satang
    @pickup_location = pickup_location
    @pickup_hours = pickup_hours
    @pickup_time_slot = pickup_time_slot
    @shipping_address = shipping_address
    @shipping_carrier = shipping_carrier
  end

  def quote(delivery_method:)
    PaymentQuote.new(
      winning_bid_satang: winning_bid_satang,
      buyer_premium_satang: buyer_premium_satang,
      shipping_fee_satang: shipping_fee_satang,
      delivery_method: delivery_method
    )
  end
end
