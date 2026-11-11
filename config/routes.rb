Rails.application.routes.draw do
  get "up" => "rails/health#show", as: :rails_health_check

  # MOCK login, never in production (ai/knowledge/mock-data.md).
  if Rails.env.local?
    resource :mock_session, only: %i[new create destroy], path: "mock-login"
  end

  namespace :admin do
    resources :auctions, except: :destroy do
      member do
        post :schedule
        post :cancel
      end
      resources :lots, controller: "auction_lots", only: %i[create destroy]
    end
  end

  get "payment", to: "payments#show"
  get "payment/quote", to: "payments#quote"
  post "payment/preview", to: "payments#preview"

  # Product onboarding milestone: http://127.0.0.1:3000/product-onboarding (mock data, not in production).
  namespace :product_onboarding, path: "product-onboarding" do
    root "items#index"
    resources :items, only: %i[new create]
    resources :uploads, only: %i[create update], param: :key
  end

  # Buyer onboarding (docs/decision/user-onboarding.md). Buyers only; others get 404.
  # URL says "user-onboarding" to keep it apart from /product-onboarding; helpers stay onboarding_*.
  resource :onboarding, only: :show, path: "user-onboarding"
  namespace :onboarding, path: "user-onboarding" do
    resource :identity, only: %i[edit update]
  end

  root "home#index"

  if Rails.env.development?
    get "catalog-preview", to: "catalog_previews#show"
  end
end
