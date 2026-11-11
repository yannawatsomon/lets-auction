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

  def inspect
    shown = attributes.merge("national_id" => national_id.present? ? ThaiNationalId.mask(national_id) : nil)
    "#<#{self.class.name} #{shown.map { |k, v| "#{k}: #{v.inspect}" }.join(", ")}>"
  end
end
