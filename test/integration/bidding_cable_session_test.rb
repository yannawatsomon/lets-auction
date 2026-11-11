require "test_helper"

# The cable connection reads the mock user from the encrypted session cookie. This checks the
# real cookie the login sets can be read that way (the cable test cookie jar can't encrypt).
class BiddingCableSessionTest < ActionDispatch::IntegrationTest
  test "the session cookie set by the mock login identifies the cable user" do
    post mock_session_path(user_id: 21)
    key = Rails.application.config.session_options[:key]
    env = Rails.application.env_config.merge("HTTP_COOKIE" => "#{key}=#{CGI.escape(cookies[key])}")
    session = ActionDispatch::Request.new(env).cookie_jar.encrypted[key]
    assert_equal 21, ApplicationCable::Connection.user_from_session(session).id
  end
end
