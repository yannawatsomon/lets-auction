# Opt-in switch that serves the MOCK product-onboarding pages (and a seller-only mock login) in
# production. Off unless the Railway variable MOCK_PRODUCT_ONBOARDING is exactly "true".
# See docs/decision/product-onboarding.md and ai/knowledge/mock-data.md.
Rails.application.config.x.mock_product_onboarding = ENV["MOCK_PRODUCT_ONBOARDING"] == "true"
