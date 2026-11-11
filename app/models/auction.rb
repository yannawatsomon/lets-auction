# An auction event: up to 10 lots that open together (docs/decision/scope.md, bidding.md).
# Admins build it as a draft, then schedule or cancel it. Opening/closing by time is #35.
class Auction < ApplicationRecord
  MAX_LOTS = 10

  # Raised for a rule a user can break; the message is Thai and safe to show.
  class Error < StandardError; end

  enum :auction_type, { sealed_first_price: "sealed_first_price", english: "english" }, validate: true
  enum :visibility, { public: "public", invite_only: "invite_only" }, prefix: :visibility, validate: true
  enum :status, {
    draft: "draft", scheduled: "scheduled", live: "live",
    awaiting_approval: "awaiting_approval", published: "published", cancelled: "cancelled"
  }, default: "draft", validate: true

  has_many :lots, -> { order(:lot_no) }, class_name: "AuctionLot", inverse_of: :auction, dependent: :restrict_with_exception

  before_validation :force_english_invite_only

  validates :title, presence: true, length: { maximum: 200 }
  validates :starts_at, :ends_at, :created_by_id, presence: true
  validates :extension_window_sec, :extension_sec, :extension_cap_sec,
    numericality: { only_integer: true, greater_than_or_equal_to: 0 }
  validate :ends_after_starts
  validate :only_draft_is_editable, on: :update
  validate :type_fixed_once_lots_exist, on: :update

  after_update :sync_lot_end_times, if: -> { draft? && saved_change_to_ends_at? }

  def created_by = MockData.user(created_by_id)
  def lots_full? = lots.size >= MAX_LOTS

  # Item ids already in this auction, for the "add item" list.
  def item_ids = lots.map(&:item_id)

  def add_item!(item, bid_increment_cents: nil)
    raise Error, "แก้ไขได้เฉพาะงานที่ยังเป็นร่าง" unless draft?
    raise Error, "ใส่ได้เฉพาะสินค้าที่ Approve แล้ว" unless item&.approved?
    raise Error, "งานนี้มีสินค้าครบ #{MAX_LOTS} ชิ้นแล้ว" if lots_full?
    raise Error, "สินค้านี้อยู่ในงานนี้แล้ว" if item_ids.include?(item.id)

    lot = lots.create!(
      item_id: item.id,
      lot_no: next_lot_no,
      min_price_cents: item.min_price_cents,
      bid_increment_cents: english? ? bid_increment_cents : nil,
      ends_at: ends_at,
      original_ends_at: ends_at
    )
    lots.reset
    lot
  rescue ActiveRecord::RecordNotUnique
    # Another admin took the lot number or the item at the same moment; the DB indexes win.
    raise Error, "สินค้านี้อยู่ในงานอื่นที่ยังไม่จบ หรือมีการแก้ไขพร้อมกัน ลองใหม่อีกครั้ง"
  rescue ActiveRecord::StatementInvalid => e
    raise unless e.message.include?("auction_lots_max_ten")
    raise Error, "งานนี้มีสินค้าครบ #{MAX_LOTS} ชิ้นแล้ว"
  end

  def remove_lot!(lot)
    raise Error, "แก้ไขได้เฉพาะงานที่ยังเป็นร่าง" unless draft?

    lot.destroy!
    lots.reset
  end

  def schedule!(now: Time.current)
    with_lock do
      raise Error, "เผยแพร่ได้เฉพาะงานที่ยังเป็นร่าง" unless draft?
      raise Error, "ต้องมีสินค้าอย่างน้อย 1 ชิ้น" if lots.empty?
      raise Error, "เวลาเริ่มต้องอยู่ในอนาคต" unless starts_at > now
      if english? && lots.any? { |l| l.bid_increment_cents.blank? }
        raise Error, "ทุกล็อตแบบ English ต้องกำหนดขั้นบิดขั้นต่ำ"
      end

      update_columns(status: "scheduled", scheduled_at: now, updated_at: now)
    end
  end

  def cancel!(reason:, now: Time.current)
    raise Error, "ต้องระบุเหตุผลการยกเลิก" if reason.to_s.strip.empty?

    with_lock do
      raise Error, "ยกเลิกได้เฉพาะงานที่ยังไม่เริ่ม" unless draft? || scheduled?

      lots.each { |l| l.update!(status: "cancelled") }
      update_columns(status: "cancelled", cancel_reason: reason.strip, cancelled_at: now, updated_at: now)
    end
  end

  private

  def next_lot_no
    ((1..MAX_LOTS).to_a - lots.map(&:lot_no)).first
  end

  def force_english_invite_only
    self.visibility = "invite_only" if english?
  end

  def ends_after_starts
    return if starts_at.blank? || ends_at.blank?

    errors.add(:ends_at, "ต้องหลังเวลาเริ่ม") unless ends_at > starts_at
  end

  def only_draft_is_editable
    return if status_was == "draft"
    return if (changed - %w[status updated_at]).empty?

    errors.add(:base, "แก้ไขได้เฉพาะงานที่ยังเป็นร่าง")
  end

  def type_fixed_once_lots_exist
    return unless auction_type_changed? && lots.exists?

    errors.add(:auction_type, "เปลี่ยนวิธีประมูลไม่ได้เมื่อมีสินค้าในงานแล้ว")
  end

  def sync_lot_end_times
    lots.each { |l| l.update!(ends_at: ends_at, original_ends_at: ends_at) }
  end
end
