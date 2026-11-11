class ApplicationController < ActionController::Base
  # Only allow modern browsers supporting webp images, web push, badges, import maps, CSS nesting, and CSS :has.
  allow_browser versions: :modern

  # Changes to the importmap will invalidate the etag for HTML responses
  stale_when_importmap_changes

  before_action :set_current_user
  helper_method :current_user, :mock_login_enabled?

  private

  def current_user = Current.user

  # MOCK login: only outside production, until real auth lands (ai/knowledge/mock-data.md).
  def mock_login_enabled? = Rails.env.local?

  def set_current_user
    Current.user = mock_login_enabled? ? MockData.user(session[:mock_user_id]) : nil
  end
end
