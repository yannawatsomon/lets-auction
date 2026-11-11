# Step 3 (#19): calculate a buyer's score and append it, at most MAX_TRIES times in WINDOW.
# Check-and-append runs inside OnboardingStore.transaction, so two clicks can't both pass the
# limit. Only a buyer at employment_done can be scored: scored/completed means nothing changed.
module OnboardingScoring
  MAX_TRIES = 3
  WINDOW = 30.days

  Result = Data.define(:assessment, :error) do
    def ok? = error.nil?
  end

  module_function

  def call(user_id, now: Time.current)
    OnboardingStore.transaction do
      onboarding = OnboardingStore.find(user_id)
      next Result.new(nil, "กรุณากรอกอาชีพและรายได้ในขั้นที่ 2 ก่อน") unless onboarding.status == "employment_done"
      next Result.new(nil, "คำนวณคะแนนได้ไม่เกิน #{MAX_TRIES} ครั้งใน 30 วัน กรุณาลองใหม่ภายหลัง") if tries_left(user_id, now: now).zero?

      assessment = CreditAssessment.new(user_id: onboarding.user_id, created_at: now, **CreditScore.calculate(onboarding))
      OnboardingStore.add_assessment(assessment)
      onboarding.status = "scored"
      OnboardingStore.save(onboarding)
      Result.new(assessment, nil)
    end
  end

  def tries_left(user_id, now: Time.current)
    used = OnboardingStore.assessments(user_id).count { |a| a.created_at > now - WINDOW }
    [ MAX_TRIES - used, 0 ].max
  end
end
