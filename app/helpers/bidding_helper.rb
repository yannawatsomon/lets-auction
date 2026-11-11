# View helpers for the bidding milestone. Rails shares helpers across all views, so every
# method starts with `bidding_` to avoid clashing with other milestones (e.g. CatalogHelper).
module BiddingHelper
  STATUS_LABELS = {
    "draft" => "ร่าง", "scheduled" => "เผยแพร่แล้ว", "live" => "กำลังประมูล",
    "awaiting_approval" => "รอประกาศผล", "published" => "ประกาศผลแล้ว", "cancelled" => "ยกเลิก"
  }.freeze
  TYPE_LABELS = { "sealed_first_price" => "ยื่นซอง · ราคาเดียว", "english" => "English · ขึ้นราคา (เชิญเท่านั้น)" }.freeze
  PARTICIPANT_LABELS = { "registered" => "ลงทะเบียนแล้ว", "invited" => "รอตอบรับ", "accepted" => "ตอบรับแล้ว", "revoked" => "ยกเลิกสิทธิ์แล้ว" }.freeze
  THAI_MONTHS = %w[ม.ค. ก.พ. มี.ค. เม.ย. พ.ค. มิ.ย. ก.ค. ส.ค. ก.ย. ต.ค. พ.ย. ธ.ค.].freeze

  def bidding_status_chip(auction)
    tag.span(STATUS_LABELS.fetch(auction.status), class: [ "bidding-chip", "bidding-chip--#{auction.status}" ])
  end

  def bidding_type_label(auction_or_type)
    type = auction_or_type.respond_to?(:auction_type) ? auction_or_type.auction_type : auction_or_type
    TYPE_LABELS.fetch(type.to_s)
  end

  def bidding_baht(cents) = baht(cents)

  # 15 พ.ย. 2026 18:00 (Asia/Bangkok)
  def bidding_time(time)
    return "—" unless time

    t = time.in_time_zone
    "#{t.day} #{THAI_MONTHS[t.month - 1]} #{t.year} #{t.strftime('%H:%M')}"
  end

  def bidding_datetime_field_value(time)
    time&.in_time_zone&.strftime("%Y-%m-%dT%H:%M")
  end
end
