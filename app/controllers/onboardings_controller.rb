# The buyer's onboarding overview: which steps are done and what comes next.
class OnboardingsController < Onboarding::BaseController
  def show
    @onboarding = find_onboarding
    @assessment = OnboardingStore.latest_assessment(current_user.id)
  end
end
