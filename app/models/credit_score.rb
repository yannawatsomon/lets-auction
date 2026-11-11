# The lets-auction score, version 1 (docs/decision/user-onboarding.md, "Rules / examples").
# Pure and deterministic: the same answers always give the same score. Not a bureau score.
# A new formula gets a new VERSION; stored assessments keep the version they were made with.
module CreditScore
  VERSION = 1

  # [minimum whole baht a month, points], highest first
  INCOME_BANDS = [
    [ 1_000_000, 50 ], [ 500_000, 42 ], [ 200_000, 34 ], [ 100_000, 26 ],
    [ 50_000, 18 ], [ 15_000, 10 ], [ 1, 4 ], [ 0, 0 ]
  ].freeze
  OCCUPATION_POINTS = {
    "government" => 25, "private_employee" => 21, "business_owner" => 17, "retired" => 13,
    "freelancer" => 10, "student" => 4, "other" => 4
  }.freeze
  # [minimum total years, points], highest first
  EXPERIENCE_BANDS = [ [ 10, 15 ], [ 5, 11 ], [ 2, 7 ], [ 0, 3 ] ].freeze
  PHONE_VERIFIED_POINTS = 10
  # [minimum score, grade], highest first
  GRADE_BANDS = [ [ 80, "A" ], [ 65, "B" ], [ 50, "C" ], [ 35, "D" ], [ 0, "E" ] ].freeze

  module_function

  # Returns { score:, grade:, score_version:, inputs:, reasons: } for a step-2-complete onboarding.
  def calculate(onboarding)
    baht = onboarding.monthly_income_cents.to_i / 100
    reasons = {
      income: band(INCOME_BANDS, baht),
      occupation: OCCUPATION_POINTS.fetch(onboarding.occupation),
      experience: band(EXPERIENCE_BANDS, onboarding.years_experience_total.to_i),
      phone: onboarding.phone_verified_at ? PHONE_VERIFIED_POINTS : 0
    }
    score = reasons.values.sum
    {
      score: score, grade: grade_for(score), score_version: VERSION, reasons: reasons,
      inputs: {
        "occupation" => onboarding.occupation, "monthly_income_cents" => onboarding.monthly_income_cents,
        "years_experience_total" => onboarding.years_experience_total, "phone_verified" => onboarding.phone_verified_at.present?
      }
    }
  end

  def grade_for(score) = band(GRADE_BANDS, score)

  def band(bands, value) = bands.find { |min, _| value >= min }.last
end
