# Step 2: occupation, monthly income and experience (#18).
module Onboarding
  class EmploymentsController < BaseController
    before_action :require_step_1

    def edit
      @onboarding = @saved
    end

    def update
      answers = params.expect(employment: %i[occupation monthly_income years_experience_total years_in_current_job])
      @onboarding = find_onboarding

      if @onboarding.update_employment(
          occupation: answers[:occupation], monthly_income: answers[:monthly_income],
          years_experience_total: answers[:years_experience_total], years_in_current_job: answers[:years_in_current_job]
        ) && OnboardingStore.save(@onboarding)
        redirect_to onboarding_path, notice: "บันทึกข้อมูลอาชีพและรายได้แล้ว"
      else
        render :edit, status: :unprocessable_content
      end
    end

    private

    def require_step_1
      @saved = find_onboarding
      return unless @saved.status == "not_started"

      redirect_to edit_onboarding_identity_path, alert: "กรุณายืนยันตัวตนในขั้นที่ 1 ก่อน"
    end
  end
end
