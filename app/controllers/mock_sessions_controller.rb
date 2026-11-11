# MOCK login for development and test only. Routes are not drawn in production, and the
# controller refuses to run there as a second guard. Replace with real auth (docs/decision/auth.md).
class MockSessionsController < ApplicationController
  before_action { head :not_found unless mock_login_enabled? }

  def new
    @users = MockData.users
  end

  def create
    user = MockData.user(params[:user_id])
    return redirect_to(new_mock_session_path, alert: "ไม่พบผู้ใช้") unless user

    reset_session
    session[:mock_user_id] = user.id
    redirect_to(user.admin? ? admin_auctions_path : root_path, notice: "เข้าสู่ระบบเป็น #{user.display_name}")
  end

  def destroy
    reset_session
    redirect_to new_mock_session_path, notice: "ออกจากระบบแล้ว"
  end
end
