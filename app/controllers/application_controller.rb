class ApplicationController < ActionController::Base
  # Only allow modern browsers supporting webp images, web push, badges, import maps, CSS nesting, and CSS :has.
  allow_browser versions: :modern

  # Changes to the importmap will invalidate the etag for HTML responses
  stale_when_importmap_changes

  before_action :set_current_user
  helper_method :current_user, :mock_login_enabled?

  private

  def require_login
    return if current_user

    respond_to do |f|
      f.html { redirect_to(mock_login_enabled? ? new_mock_session_path : root_path, alert: "กรุณาเข้าสู่ระบบก่อน") }
      f.json { render json: { error: "login_required", message: "กรุณาเข้าสู่ระบบก่อน" }, status: :unauthorized }
    end
  end

  # One error shape for the whole app: { "error": "snake_code", "message": "<Thai>" }.
  def render_participation_error(e, fallback_path)
    respond_to do |f|
      f.html { redirect_to fallback_path, alert: e.message }
      f.json { render json: { error: e.code, message: e.message }, status: e.http_status }
    end
  end

  def current_user = Current.user

  # MOCK login: only outside production, until real auth lands (ai/knowledge/mock-data.md).
  def mock_login_enabled? = Rails.env.local?

  # The mock product-onboarding pages and the seller-only mock login. Also on in production when
  # MOCK_PRODUCT_ONBOARDING=true (docs/decision/product-onboarding.md).
  def mock_onboarding_enabled? = mock_login_enabled? || Rails.configuration.x.mock_product_onboarding

  # Outside development/test only sellers may be the mock user, so admin pages stay 404.
  def mock_user_allowed?(user) = user.present? && (mock_login_enabled? || user.seller?)

  def set_current_user
    user = MockData.user(session[:mock_user_id]) if mock_onboarding_enabled?
    Current.user = mock_user_allowed?(user) ? user : nil
  end
end
