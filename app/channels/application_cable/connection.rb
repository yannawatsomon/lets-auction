module ApplicationCable
  # Who is on the other end of a WebSocket. Same rules as ApplicationController#set_current_user:
  # the MOCK login (session[:mock_user_id]) only in development/test, or sellers only when
  # MOCK_PRODUCT_ONBOARDING=true. Anyone else connects anonymously and every bidding
  # subscription refuses them. Replace with real auth (docs/decision/auth.md).
  class Connection < ActionCable::Connection::Base
    identified_by :current_user

    def self.user_from_session(session)
      local = Rails.env.local?
      return unless local || Rails.configuration.x.mock_product_onboarding

      user = MockData.user((session || {})["mock_user_id"])
      user if user && (local || user.seller?)
    end

    def connect
      self.current_user = self.class.user_from_session(cookies.encrypted[Rails.application.config.session_options[:key]])
    end
  end
end
