require "test_helper"

class ApplicationCable::ConnectionTest < ActionCable::Connection::TestCase
  test "no session means an anonymous connection" do
    connect
    assert_nil connection.current_user
  end

  test "the session's mock user is identified in development/test" do
    assert_equal 21, ApplicationCable::Connection.user_from_session({ "mock_user_id" => 21 }).id
    assert_nil ApplicationCable::Connection.user_from_session({ "mock_user_id" => 999 })
    assert_nil ApplicationCable::Connection.user_from_session(nil)
  end

  test "outside development/test only sellers are identified, and only with the product-onboarding flag" do
    original_env = Rails.env
    original_flag = Rails.configuration.x.mock_product_onboarding
    Rails.env = "production"

    Rails.configuration.x.mock_product_onboarding = false
    assert_nil ApplicationCable::Connection.user_from_session({ "mock_user_id" => 11 })

    Rails.configuration.x.mock_product_onboarding = true
    assert_nil ApplicationCable::Connection.user_from_session({ "mock_user_id" => 1 }), "an admin is never identified in production"
    assert_nil ApplicationCable::Connection.user_from_session({ "mock_user_id" => 21 }), "nor a buyer"
    assert_equal 11, ApplicationCable::Connection.user_from_session({ "mock_user_id" => 11 }).id
  ensure
    Rails.env = original_env
    Rails.configuration.x.mock_product_onboarding = original_flag
  end
end
