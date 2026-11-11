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

  root "home#index"
end
