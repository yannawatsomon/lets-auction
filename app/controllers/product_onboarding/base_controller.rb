module ProductOnboarding
  # Product onboarding runs on mock data (ai/knowledge/product-onboarding-integration-points.md),
  # so like the mock login its pages exist only outside production, unless MOCK_PRODUCT_ONBOARDING
  # is set (docs/decision/product-onboarding.md).
  class BaseController < ApplicationController
    layout "product_onboarding"
    before_action { head :not_found unless mock_onboarding_enabled? }
  end
end
