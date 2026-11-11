module ProductOnboarding
  # Product onboarding runs on mock data (ai/knowledge/product-onboarding-integration-points.md),
  # so like the mock login its pages exist only outside production.
  class BaseController < ApplicationController
    layout "product_onboarding"
    before_action { head :not_found unless mock_login_enabled? }
  end
end
