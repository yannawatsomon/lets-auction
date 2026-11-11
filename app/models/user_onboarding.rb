# A buyer's onboarding answers and progress (docs/decision/user-onboarding.md).
# MOCK DATA: plain ActiveModel kept in OnboardingStore (memory) until the database lands,
# see ai/knowledge/mock-data.md. Money is satang. Never log or show the raw national ID.
class UserOnboarding
  include ActiveModel::Model
  include ActiveModel::Attributes

  STATUSES = %w[not_started identity_done employment_done scored completed].freeze
  OCCUPATIONS = %w[government private_employee business_owner retired freelancer student other].freeze

  attribute :user_id, :integer
  attribute :national_id, :string
  attribute :phone, :string
  attribute :phone_verified_at, :datetime
  attribute :occupation, :string
  attribute :monthly_income_cents, :integer
  attribute :years_in_current_job, :integer
  attribute :years_experience_total, :integer
  attribute :status, :string, default: "not_started"
  attribute :consent_at, :datetime
  attribute :confirmed_at, :datetime

  validates :user_id, presence: true
  validates :status, inclusion: { in: STATUSES }
  validates :occupation, inclusion: { in: OCCUPATIONS }, allow_nil: true

  OCCUPATION_LABELS = {
    "government" => "ข้าราชการ / รัฐวิสาหกิจ", "private_employee" => "พนักงานบริษัทเอกชน",
    "business_owner" => "เจ้าของกิจการ", "retired" => "เกษียณ", "freelancer" => "ฟรีแลนซ์",
    "student" => "นักศึกษา", "other" => "อื่นๆ"
  }.freeze
  MAX_MONTHLY_INCOME_BAHT = 1_000_000_000
  MAX_YEARS = 60
  # Step 2 answers that feed the score; changing one after scoring needs a new score.
  SCORE_INPUTS = %w[occupation monthly_income_cents years_experience_total].freeze

  def completed? = status == "completed"

  # Step 4 (#20). Only from scored; the buyer must declare the answers true. Completed buyers
  # count as onboarded for bidding (BuyerStanding). Returns false with errors otherwise.
  def confirm(declaration:, now: Time.current)
    errors.clear
    if status != "scored"
      errors.add(:base, "ยืนยันผลได้หลังคำนวณคะแนนแล้วเท่านั้น")
      return false
    end
    unless ActiveModel::Type::Boolean.new.cast(declaration)
      errors.add(:declaration, "กรุณารับรองว่าข้อมูลเป็นความจริงก่อนยืนยัน")
      return false
    end

    self.confirmed_at = now
    self.status = "completed"
    true
  end

  # Saved income in whole baht, for the form.
  def monthly_income = monthly_income_cents && monthly_income_cents / 100

  # Step 2 (#18). Income is whole baht (commas/spaces allowed), stored as satang. Changing an
  # answer that feeds the score after scoring sends the buyer back to employment_done; years in
  # the current job don't feed the score. Returns false with errors and changes nothing.
  def update_employment(occupation:, monthly_income:, years_experience_total:, years_in_current_job:)
    errors.clear
    if status == "not_started"
      errors.add(:base, "กรุณายืนยันตัวตนในขั้นที่ 1 ก่อน")
      return false
    end

    errors.add(:occupation, "กรุณาเลือกอาชีพ") unless OCCUPATIONS.include?(occupation)
    income = whole_number(monthly_income.to_s.gsub(/[\s,]/, ""), 0..MAX_MONTHLY_INCOME_BAHT)
    errors.add(:monthly_income, "กรอกรายได้เป็นจำนวนเต็มบาท 0 ถึง 1,000,000,000") unless income
    total = whole_number(years_experience_total, 0..MAX_YEARS)
    errors.add(:years_experience_total, "กรอกจำนวนปี 0 ถึง #{MAX_YEARS}") unless total
    current = years_in_current_job.to_s.strip.empty? ? nil : whole_number(years_in_current_job, 0..MAX_YEARS)
    if years_in_current_job.to_s.strip.present? && current.nil?
      errors.add(:years_in_current_job, "กรอกจำนวนปี 0 ถึง #{MAX_YEARS}")
    elsif current && total && current > total
      errors.add(:years_in_current_job, "ต้องไม่เกินประสบการณ์รวม")
    end
    return false if errors.any?

    before = attributes.slice(*SCORE_INPUTS)
    assign_attributes(occupation: occupation, monthly_income_cents: income * 100,
      years_experience_total: total, years_in_current_job: current)
    score_changed = before != attributes.slice(*SCORE_INPUTS)
    self.status = "employment_done" if status == "identity_done" || (score_changed && %w[scored completed].include?(status))
    true
  end

  # Step 1 (#17). A blank national_id keeps the saved one. The ID is locked once completed
  # (an admin fixes mistakes); the phone can change any time without a new score. Consent is
  # asked once, before the ID is first stored. Returns false with errors and changes nothing.
  def update_identity(national_id:, phone:, consent:, now: Time.current)
    errors.clear
    typed_id = national_id.to_s.strip.presence
    new_phone = ThaiPhoneNumber.normalize(phone)

    check_national_id(typed_id)
    errors.add(:phone, "เบอร์มือถือไม่ถูกต้อง (10 หลัก ขึ้นต้น 06, 08 หรือ 09)") unless new_phone
    if consent_at.nil? && !ActiveModel::Type::Boolean.new.cast(consent)
      errors.add(:consent, "กรุณายินยอมให้เก็บและใช้ข้อมูลก่อน")
    end
    return false if errors.any?

    self.national_id = ThaiNationalId.normalize(typed_id) if typed_id
    self.phone = new_phone
    self.consent_at ||= now
    self.status = "identity_done" if status == "not_started"
    true
  end

  def inspect
    shown = attributes.merge("national_id" => national_id.present? ? ThaiNationalId.mask(national_id) : nil)
    "#<#{self.class.name} #{shown.map { |k, v| "#{k}: #{v.inspect}" }.join(", ")}>"
  end

  private

  # "12" → 12 when it is a whole number inside range; anything else → nil (reject, don't fix).
  def whole_number(value, range)
    text = value.to_s.strip
    return nil unless text.match?(/\A\d+\z/)

    number = text.to_i
    range.cover?(number) ? number : nil
  end

  def check_national_id(typed_id)
    if typed_id.nil?
      errors.add(:national_id, "กรุณากรอกเลขบัตรประชาชน") if national_id.blank?
    elsif !ThaiNationalId.valid?(typed_id)
      errors.add(:national_id, "เลขบัตรประชาชนไม่ถูกต้อง")
    elsif completed? && ThaiNationalId.normalize(typed_id) != national_id
      errors.add(:national_id, "แก้เลขบัตรประชาชนไม่ได้หลังยืนยันแล้ว ติดต่อแอดมิน")
    end
  end
end
