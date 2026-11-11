# Step 3: calculate the score (#19). The 3-in-30-days limit lives in OnboardingScoring.
module Onboarding
  class ScoresController < BaseController
    before_action :require_step_2

    def show
      @assessment = OnboardingStore.latest_assessment(current_user.id) if @onboarding.status.in?(%w[scored completed])
      @tries_left = OnboardingScoring.tries_left(current_user.id)
    end

    def create
      result = OnboardingScoring.call(current_user.id)
      if result.ok?
        redirect_to onboarding_path, notice: "คำนวณแล้ว: #{result.assessment.score} คะแนน เกรด #{result.assessment.grade}"
      else
        redirect_to onboarding_score_path, alert: result.error
      end
    end

    private

    def require_step_2
      @onboarding = find_onboarding
      return unless @onboarding.status.in?(%w[not_started identity_done])

      redirect_to edit_onboarding_employment_path, alert: "กรุณากรอกอาชีพและรายได้ในขั้นที่ 2 ก่อน"
    end
  end
end
