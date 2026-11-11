require "test_helper"

class ProductOnboardingUploadsTest < ActionDispatch::IntegrationTest
  Store = ProductOnboarding::UploadStore

  setup { Store.reset! }

  def login(id) = post(mock_session_path(user_id: id))

  def request_upload(**overrides)
    post product_onboarding_uploads_path,
      params: { kind: "image", filename: "a.jpg", content_type: "image/jpeg", size: 100 }.merge(overrides), as: :json
  end

  def put_file(key, body: "x" * 100, type: "image/jpeg")
    put product_onboarding_upload_path(key), params: body, headers: { "CONTENT_TYPE" => type }
  end

  test "guests, buyers and admins get 404 and nothing is stored" do
    request_upload
    assert_response :not_found
    [ 21, 1 ].each do |id|
      login(id)
      request_upload
      assert_response :not_found
    end
    assert_empty Store.all
  end

  test "a seller gets a key and an upload target, then uploads the file" do
    login(11)
    request_upload
    assert_response :created
    key = response.parsed_body["key"]
    assert_equal product_onboarding_upload_path(key), response.parsed_body.dig("direct_upload", "url")
    assert_equal "PUT", response.parsed_body.dig("direct_upload", "method")

    put_file(key)
    assert_response :no_content
    assert Store.find(key).uploaded
  end

  test "rejected files get 422 with a reason and no key is issued" do
    login(11)
    [ { size: 10.megabytes + 1 }, { content_type: "image/svg+xml" }, { kind: "audio" }, { size: nil } ].each do |bad|
      request_upload(**bad)
      assert_response :unprocessable_content, bad.inspect
      assert response.parsed_body["error"].present?
    end
    assert_empty Store.all
  end

  test "an upload that does not match what was declared is refused" do
    login(11)
    request_upload
    key = response.parsed_body["key"]

    put_file(key, type: "text/html")
    assert_response :unprocessable_content
    put_file(key, body: "x" * 99)
    assert_response :unprocessable_content
    assert_not Store.find(key).uploaded
  end

  test "someone else's target and unknown keys are 404" do
    login(11)
    request_upload
    key = response.parsed_body["key"]

    login(12)
    put_file(key)
    assert_response :not_found
    put_file("unknown")
    assert_response :not_found
    assert_not Store.find(key).uploaded
  end
end
