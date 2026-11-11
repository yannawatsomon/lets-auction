module AuctionsHelper
  STATUS_LABELS = {
    "draft" => "ร่าง", "scheduled" => "เผยแพร่แล้ว", "live" => "กำลังประมูล",
    "awaiting_approval" => "รอประกาศผล", "published" => "ประกาศผลแล้ว", "cancelled" => "ยกเลิก"
  }.freeze
  TYPE_LABELS = { "sealed_first_price" => "ยื่นซอง · ราคาเดียว", "english" => "English · ขึ้นราคา (เชิญเท่านั้น)" }.freeze

  def auction_status_chip(auction)
    tag.span(STATUS_LABELS.fetch(auction.status), class: [ "chip", auction.status ])
  end

  def auction_type_label(auction_or_type)
    type = auction_or_type.respond_to?(:auction_type) ? auction_or_type.auction_type : auction_or_type
    TYPE_LABELS.fetch(type.to_s)
  end

  def baht(cents) = "฿ #{Baht.format(cents)}"

  # 15 พ.ย. 2026 18:00 (Asia/Bangkok, Buddhist-era-free to match the mockup)
  THAI_MONTHS = %w[ม.ค. ก.พ. มี.ค. เม.ย. พ.ค. มิ.ย. ก.ค. ส.ค. ก.ย. ต.ค. พ.ย. ธ.ค.].freeze
  def thai_time(time)
    return "—" unless time

    t = time.in_time_zone
    "#{t.day} #{THAI_MONTHS[t.month - 1]} #{t.year} #{t.strftime('%H:%M')}"
  end

  def datetime_field_value(time)
    time&.in_time_zone&.strftime("%Y-%m-%dT%H:%M")
  end
end
