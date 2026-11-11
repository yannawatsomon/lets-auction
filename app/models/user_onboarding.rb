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

  def completed? = status == "completed"

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
