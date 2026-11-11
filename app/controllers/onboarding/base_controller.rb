# Buyer onboarding pages (docs/decision/user-onboarding.md). Data lives in OnboardingStore
# (mock, in memory) until the database lands. Styling waits for the team's design system.
module Onboarding
  class BaseController < ApplicationController
    layout "onboarding"
    before_action :require_buyer

    private

    # 404 like the admin pages: only buyers onboard (sellers and admins skip it).
    def require_buyer
      head :not_found unless current_user&.buyer?
    end

    def find_onboarding = OnboardingStore.find(current_user.id)
  end
end
