Rails.application.routes.draw do
  get "up" => "rails/health#show", as: :rails_health_check

  # MOCK login: development/test, or production with MOCK_PRODUCT_ONBOARDING=true, where only
  # sellers can sign in (ai/knowledge/mock-data.md).
  if Rails.env.local? || Rails.configuration.x.mock_product_onboarding
    resource :mock_session, only: %i[new create destroy], path: "mock-login"
  end

  # Bidding milestone (#27–#37): every bidding page lives under /bidding or /admin/bidding.
  namespace :admin do
    namespace :bidding do
      resources :auctions, except: :destroy do
        member do
          post :schedule
          post :cancel
        end
        resources :lots, only: %i[create destroy]
        resources :invitations, only: :create do
          post :revoke, on: :member
        end
      end
    end
  end

  namespace :bidding do
    resources :auctions, only: %i[index show] do
      resource :registration, only: :create
    end
    resources :invitations, only: :index do
      post :accept, on: :member
    end
  end

  get "payment", to: "payments#show"
  get "payment/quote", to: "payments#quote"
  post "payment/preview", to: "payments#preview"

  # Product onboarding milestone: http://127.0.0.1:3000/product-onboarding (mock data; in production only with MOCK_PRODUCT_ONBOARDING=true).
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
    resource :employment, only: %i[edit update]
    resource :score, only: %i[show create]
    resource :confirmation, only: %i[show create]
  end

  root "home#index"

  if Rails.env.development?
    get "catalog-preview", to: "catalog_previews#show"
  end
end
