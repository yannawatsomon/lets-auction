# Step 4: review the result, declare the answers true, confirm (#20). Once completed the same
# URL shows the success page.
module Onboarding
  class ConfirmationsController < BaseController
    before_action :require_score

    def show; end

    def create
      declaration = params.dig(:confirmation, :declaration)
      confirmed = OnboardingStore.transaction do
        @onboarding = find_onboarding
        @onboarding.confirm(declaration: declaration) && OnboardingStore.save(@onboarding)
      end

      if confirmed
        redirect_to onboarding_confirmation_path, notice: "ยืนยันผลเรียบร้อย"
      else
        render :show, status: :unprocessable_content
      end
    end

    private

    def require_score
      @onboarding = find_onboarding
      unless @onboarding.status.in?(%w[scored completed])
        return redirect_to onboarding_score_path, alert: "กรุณาคำนวณคะแนนในขั้นที่ 3 ก่อน"
      end

      @assessment = OnboardingStore.latest_assessment(current_user.id)
      @tries_left = OnboardingScoring.tries_left(current_user.id)
    end
  end
end
