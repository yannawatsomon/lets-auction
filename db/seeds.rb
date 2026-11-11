# Mock data for local development and tests only. It is never loaded in production.
# Real accounts come from the user-onboarding milestone (#16); real files from the storage
# service chosen in #49. Until then these mocks let the seller and admin screens be built and
# demoed. Safe to run repeatedly (`bin/rails db:seed`).
load Rails.root.join("db/seeds/mock_products.rb") unless Rails.env.production?
