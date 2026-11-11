class HomeController < ApplicationController
  def index
    @stats = [
      { label: "ประมูลกำลังเปิด", value: "128" },
      { label: "ผู้เข้าชมวันนี้", value: "24K" },
      { label: "ราคาซื้อสูงสุด", value: "฿18.5M" }
    ]

    @featured_auctions = [
      {
        title: "BMW iX 2024",
        category: "รถยนต์",
        current_bid: "฿1,850,000",
        ends_in: "2 ชม. 14 นาที",
        location: "กรุงเทพฯ",
        bids: 18,
        emoji: "🚗",
        tone: "car"
      },
      {
        title: "Rolex Submariner",
        category: "นาฬิกา",
        current_bid: "฿245,000",
        ends_in: "5 ชม. 30 นาที",
        location: "เชียงใหม่",
        bids: 12,
        emoji: "⌚",
        tone: "watch"
      },
      {
        title: "Vintage Camera Leica",
        category: "ของสะสม",
        current_bid: "฿98,500",
        ends_in: "1 ชม. 05 นาที",
        location: "ภูเก็ต",
        bids: 9,
        emoji: "📷",
        tone: "camera"
      }
    ]
  end
end
