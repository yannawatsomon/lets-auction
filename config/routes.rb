Rails.application.routes.draw do
  get "up" => "rails/health#show", as: :rails_health_check

  # MOCK login: development/test; production with MOCK_PRODUCT_ONBOARDING=true (sellers only) or
  # MOCK_BIDDING=true + demo password (every role) (ai/knowledge/mock-data.md).
  if Rails.env.local? || Rails.configuration.x.mock_product_onboarding || Rails.configuration.x.mock_bidding
    resource :mock_session, only: %i[new create destroy], path: "mock-login" do
      post :unlock
    end
  end

  # Bidding milestone (#27–#37): every bidding page lives under /bidding or /admin/bidding.
  namespace :admin do
    namespace :bidding do
      resources :auctions, except: :destroy do
        member do
          post :schedule
          post :cancel
          get :results, to: "results#show"          # #36: ranking + approve (mockup A3)
          post :approve_results, to: "results#approve"
        end
        resources :lots, only: %i[create destroy] do
          post :disqualify, on: :member, to: "results#disqualify"
        end
        resources :invitations, only: :create do
          post :revoke, on: :member
        end
      end
      resources :orders, only: [] do
        post :mark_paid, on: :member, to: "results#mark_paid" # MOCK until payment records real payments
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
    resources :lots, only: :show do
      get :bids, on: :member, action: :history # English bid history (#34)
      get :result, on: :member, to: "results#show" # buyer's own result (#36, mockup B6)
      resources :bids, only: :create do
        post :review, on: :collection
      end
    end
    resources :bids, only: :index
    resources :orders, only: [] do
      post :decline, on: :member, to: "results#decline"
    end
  end

  get "payment", to: "payments#show"
  get "payment/quote", to: "payments#quote"
  post "payment/preview", to: "payments#preview"

  # Product onboarding milestone: http://127.0.0.1:3000/product-onboarding (mock data; in production only with MOCK_PRODUCT_ONBOARDING=true).
  namespace :product_onboarding, path: "product-onboarding" do
    root "items#index"
    resources :items, only: %i[new create edit update destroy] do
      post :resubmit, on: :member
    end
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
  get "catalog", to: "catalog#index", as: :catalog

  if Rails.env.development?
    get "catalog-preview", to: "catalog_previews#show"
  end
end
