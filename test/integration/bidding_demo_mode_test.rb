require "test_helper"

# The Railway bidding demo (MOCK_BIDDING + demo password). Production behaviour is simulated by
# switching Rails.env, like test/integration/product_onboarding/page_test.rb does.
class BiddingDemoModeTest < ActionDispatch::IntegrationTest
  PASSWORD = "demo-password-123"

  setup do
    Rails.application.reload_routes_unless_loaded
    MockSessionsController::UNLOCK_RATE_LIMIT_STORE.clear
    @env = Rails.env
    @x = Rails.configuration.x
    @saved = [ @x.mock_bidding, @x.mock_bidding_password, @x.mock_product_onboarding ]
  end

  teardown do
    Rails.env = @env
    @x.mock_bidding, @x.mock_bidding_password, @x.mock_product_onboarding = @saved
  end

  def production!(bidding: false, onboarding: false)
    Rails.env = "production"
    @x.mock_bidding = bidding
    @x.mock_bidding_password = bidding ? PASSWORD : ""
    @x.mock_product_onboarding = onboarding
  end

  test "flags off in production: no mock login and admin pages are 404" do
    production!
    get new_mock_session_path
    assert_response :not_found
    get admin_bidding_auctions_path
    assert_response :not_found
  end

  test "demo on: nobody can pick a user before typing the demo password" do
    production!(bidding: true)
    get new_mock_session_path
    assert_response :success
    assert_select "form[action=?] input[type=password]", unlock_mock_session_path
    assert_select "button", text: /\(admin\)/, count: 0
    post mock_session_path(user_id: 1)
    get admin_bidding_auctions_path
    assert_response :not_found

    post unlock_mock_session_path, params: { password: "wrong-password-0" }
    assert_match "ไม่ถูกต้อง", flash[:alert]
    get admin_bidding_auctions_path
    assert_response :not_found
  end

  test "demo on: after the password every role can log in; the banner says it's a demo" do
    production!(bidding: true)
    post unlock_mock_session_path, params: { password: PASSWORD }
    get new_mock_session_path
    assert_select "button", text: /\(admin\)/
    assert_select "button", text: /\(buyer\)/

    post mock_session_path(user_id: 1)
    assert_redirected_to admin_bidding_auctions_path
    get admin_bidding_auctions_path
    assert_response :success
    assert_select ".bidding-demo-banner", /เดโม/

    post mock_session_path(user_id: 21)
    assert_redirected_to bidding_auctions_path
    delete mock_session_path
    get new_mock_session_path
    assert_select "button", text: /\(buyer\)/, message: "logging out keeps the demo unlocked"
  end

  test "demo password guessing is rate limited" do
    production!(bidding: true)
    10.times { post unlock_mock_session_path, params: { password: "nope-nope-nope" } }
    post unlock_mock_session_path, params: { password: PASSWORD }
    assert_match "หลายครั้งเกินไป", flash[:alert]
    get admin_bidding_auctions_path
    assert_response :not_found
  end

  test "product-onboarding flag alone still allows sellers only" do
    production!(onboarding: true)
    post mock_session_path(user_id: 1)
    get admin_bidding_auctions_path
    assert_response :not_found
    post unlock_mock_session_path, params: { password: PASSWORD }
    assert_response :not_found
  end

  test "the cable connection follows the same rules" do
    production!(bidding: true)
    assert_nil ApplicationCable::Connection.user_from_session({ "mock_user_id" => 21 })
    assert_equal 21, ApplicationCable::Connection.user_from_session({ "mock_user_id" => 21, "bidding_demo_unlocked" => true }).id
    production!
    assert_nil ApplicationCable::Connection.user_from_session({ "mock_user_id" => 21, "bidding_demo_unlocked" => true })
  end

  test "the flag fails closed: needs MOCK_BIDDING=true and a 12+ character password" do
    file = Rails.root.join("config/initializers/mock_bidding_demo.rb")
    { [ "true", "short" ] => false, [ "true", "" ] => false, [ "yes", PASSWORD ] => false, [ "true", PASSWORD ] => true }.each do |(flag, pw), expected|
      with_env("MOCK_BIDDING" => flag, "MOCK_BIDDING_PASSWORD" => pw) { load file }
      assert_equal expected, Rails.configuration.x.mock_bidding, "MOCK_BIDDING=#{flag} password=#{pw.inspect}"
    end
  end

  private

  def with_env(vars)
    old = vars.keys.to_h { |k| [ k, ENV[k] ] }
    vars.each { |k, v| ENV[k] = v }
    yield
  ensure
    old.each { |k, v| v.nil? ? ENV.delete(k) : ENV[k] = v }
  end
end
