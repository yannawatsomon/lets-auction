# MOCK login for development and test. In production the routes exist only when
# MOCK_PRODUCT_ONBOARDING=true, and then only sellers are offered and accepted; the controller
# refuses to run otherwise as a second guard. Replace with real auth (docs/decision/auth.md).
class MockSessionsController < ApplicationController
  before_action { head :not_found unless mock_onboarding_enabled? }

  def new
    @users = MockData.users.select { |user| mock_user_allowed?(user) }
  end

  def create
    user = MockData.user(params[:user_id])
    return redirect_to(new_mock_session_path, alert: "ไม่พบผู้ใช้") unless mock_user_allowed?(user)

    reset_session
    session[:mock_user_id] = user.id
    redirect_to(after_login_path(user), notice: "เข้าสู่ระบบเป็น #{user.display_name}")
  end

  def destroy
    reset_session
    redirect_to new_mock_session_path, notice: "ออกจากระบบแล้ว"
  end

  private

  def after_login_path(user)
    return admin_auctions_path if user.admin?

    mock_login_enabled? ? root_path : product_onboarding_root_path
  end
end
