module ApplicationCable
  # Who is on the other end of a WebSocket. Same rules as ApplicationController#mock_user_allowed?:
  # every mock user in development/test or in an unlocked bidding demo (MOCK_BIDDING + password);
  # otherwise sellers only, with MOCK_PRODUCT_ONBOARDING=true. Anyone else connects anonymously and
  # every bidding subscription refuses them. Replace with real auth (docs/decision/auth.md).
  class Connection < ActionCable::Connection::Base
    identified_by :current_user

    def self.user_from_session(session)
      session ||= {}
      config = Rails.configuration.x
      local = Rails.env.local?
      demo = config.mock_bidding == true && session["bidding_demo_unlocked"] == true
      return unless local || demo || config.mock_product_onboarding

      user = MockData.user(session["mock_user_id"])
      user if user && (local || demo || user.seller?)
    end

    def connect
      self.current_user = self.class.user_from_session(cookies.encrypted[Rails.application.config.session_options[:key]])
    end
  end
end
