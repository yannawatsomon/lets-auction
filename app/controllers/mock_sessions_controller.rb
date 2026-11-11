# MOCK login. Development/test: every mock user. Production: only when MOCK_PRODUCT_ONBOARDING=true
# (sellers only) or MOCK_BIDDING=true with a demo password (every role, after the password).
# The routes exist only in those cases, and the controller refuses to run otherwise as a second
# guard. Replace with real auth (docs/decision/auth.md).
class MockSessionsController < ApplicationController
  before_action { head :not_found unless mock_session_enabled? }

  # Guessing the demo password: 10 tries per 15 minutes per IP.
  UNLOCK_RATE_LIMIT_STORE = ActiveSupport::Cache::MemoryStore.new
  rate_limit to: 10, within: 15.minutes, only: :unlock, store: UNLOCK_RATE_LIMIT_STORE,
    with: -> { redirect_to new_mock_session_path, alert: "ลองรหัสผิดหลายครั้งเกินไป รอ 15 นาทีแล้วลองใหม่", status: :see_other }

  def new
    @needs_unlock = mock_bidding_enabled? && !mock_bidding_unlocked? && !mock_login_enabled?
    @users = MockData.users.select { |user| mock_user_allowed?(user) }
  end

  # POST /mock-login/unlock — the bidding demo password (production demo only).
  def unlock
    return head(:not_found) unless mock_bidding_enabled?

    typed = params[:password].to_s
    expected = Rails.configuration.x.mock_bidding_password
    if ActiveSupport::SecurityUtils.secure_compare(typed, expected)
      session[:bidding_demo_unlocked] = true
      redirect_to new_mock_session_path, notice: "ปลดล็อกเดโมแล้ว เลือกผู้ใช้จำลองได้", status: :see_other
    else
      redirect_to new_mock_session_path, alert: "รหัสเดโมไม่ถูกต้อง", status: :see_other
    end
  end

  def create
    user = MockData.user(params[:user_id])
    return redirect_to(new_mock_session_path, alert: "ไม่พบผู้ใช้") unless mock_user_allowed?(user)

    unlocked = session[:bidding_demo_unlocked]
    reset_session
    session[:bidding_demo_unlocked] = unlocked if unlocked
    session[:mock_user_id] = user.id
    redirect_to(after_login_path(user), notice: "เข้าสู่ระบบเป็น #{user.display_name}")
  end

  def destroy
    unlocked = session[:bidding_demo_unlocked]
    reset_session
    session[:bidding_demo_unlocked] = unlocked if unlocked
    redirect_to new_mock_session_path, notice: "ออกจากระบบแล้ว"
  end

  private

  def after_login_path(user)
    return admin_bidding_auctions_path if user.admin?
    return bidding_auctions_path if user.buyer? && (mock_login_enabled? || mock_bidding_unlocked?)
    return root_path if mock_login_enabled?

    mock_onboarding_enabled? ? product_onboarding_root_path : bidding_auctions_path
  end
end
