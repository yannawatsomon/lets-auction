module ProductOnboardingHelper
  STATUS_LABELS = {
    "pending_review" => "รอตรวจสอบ", "info_requested" => "ขอหลักฐานเพิ่ม", "approved" => "อนุมัติแล้ว",
    "rejected" => "ไม่อนุมัติ", "in_auction" => "อยู่ในงานประมูล", "sold" => "ขายแล้ว", "withdrawn" => "ถอนแล้ว"
  }.freeze
  KIND_LABELS = { "image" => "รูปภาพ", "video" => "วิดีโอ", "document" => "เอกสารยืนยัน" }.freeze

  def product_status_chip(item) = tag.span(STATUS_LABELS.fetch(item.status), class: [ "chip", item.status ])

  def kind_label(kind) = KIND_LABELS.fetch(kind)

  # "1–5 ไฟล์ (จำเป็น)", "0–2 ไฟล์ (ไม่บังคับ)", or just "ไม่บังคับ" when there is no count limit yet.
  def media_count_rule(kind)
    range = ProductOnboarding::Item::MEDIA_LIMITS[kind]
    return "ไม่บังคับ" unless range

    "#{range.min}–#{range.max} ไฟล์ (#{range.min.zero? ? 'ไม่บังคับ' : 'จำเป็น'})"
  end

  FIELD_ERRORS = {
    title: "กรอกชื่อสินค้า", description: "กรอกรายละเอียดสินค้า", category: "เลือกหมวดสินค้า",
    min_price_cents: "ราคาขั้นต่ำต้องมากกว่า 0 บาท (เช่น 85000 หรือ 1,250.50)"
  }.freeze

  # `errors` is a list of [attribute, message]; field errors are shown in Thai, media errors as written.
  def form_error_messages(errors) = errors.map { |attribute, message| FIELD_ERRORS.fetch(attribute.to_sym, message) }.uniq

  def category_options = (MockData.items.map(&:category) + ProductOnboarding::Store.all.map(&:category)).uniq.sort

  # What the wizard's JavaScript needs to check a file before uploading it (the server checks again).
  def wizard_limits
    ProductOnboarding::UploadPolicy::LIMITS.to_h do |kind, rule|
      [ kind, { max: ProductOnboarding::Item::MEDIA_LIMITS.fetch(kind).max, types: rule[:types], typesLabel: rule[:types_label],
                maxBytes: rule[:max_bytes], maxLabel: ProductOnboarding::UploadPolicy.max_label(kind) } ]
    end
  end

  def seller_name(item) = MockData.user(item.seller_id)&.display_name || "—"

  def media_summary(item)
    ProductOnboarding::Item::KINDS.map { |kind| "#{kind_label(kind)} #{item.media_count(kind)}" }.join(" · ")
  end
end
