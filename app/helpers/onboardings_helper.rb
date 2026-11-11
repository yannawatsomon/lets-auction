module OnboardingsHelper
  STEP_LABELS = [ "ยืนยันตัวตน", "อาชีพและรายได้", "คำนวณคะแนน", "ยืนยันผล" ].freeze

  # Steps finished so far (0–4), read from the status order in UserOnboarding::STATUSES.
  def onboarding_done_count(onboarding) = UserOnboarding::STATUSES.index(onboarding.status)

  # The step a buyer works on next, or nil once every step is done.
  def onboarding_next_step(onboarding)
    done = onboarding_done_count(onboarding)
    done < STEP_LABELS.size ? done + 1 : nil
  end
end
