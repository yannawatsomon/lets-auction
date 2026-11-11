# Step 1: national ID, phone and consent (#17).
module Onboarding
  class IdentitiesController < BaseController
    # "Already used by another account" tells a buyer that an ID is registered, so cap tries per
    # buyer to stop probing other people's IDs (PDPA). In-process store, like OnboardingStore;
    # move to the shared cache when the database lands.
    RATE_LIMIT_STORE = ActiveSupport::Cache::MemoryStore.new
    rate_limit to: 10, within: 1.hour, only: :update, by: -> { current_user.id }, store: RATE_LIMIT_STORE

    def edit
      @onboarding = @saved = find_onboarding
    end

    def update
      answers = params.expect(identity: %i[national_id phone consent])
      @saved = find_onboarding
      @onboarding = find_onboarding

      if @onboarding.update_identity(national_id: answers[:national_id], phone: answers[:phone], consent: answers[:consent]) &&
          OnboardingStore.save(@onboarding)
        redirect_to onboarding_path, notice: "บันทึกข้อมูลยืนยันตัวตนแล้ว"
      else
        render :edit, status: :unprocessable_content
      end
    end
  end
end
