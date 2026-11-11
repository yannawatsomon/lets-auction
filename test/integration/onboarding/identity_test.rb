require "test_helper"

# Step 1 pages (#17). Mock login: buyer 26 hasn't started, buyer 21 is completed (grade A).
class Onboarding::IdentityTest < ActionDispatch::IntegrationTest
  ADMIN = 1
  SELLER = 11
  COMPLETED_BUYER = 21
  FRESH_BUYER = 26
  NEW_ID = "1100000000075"

  setup do
    OnboardingStore.reset!
    Onboarding::IdentitiesController::RATE_LIMIT_STORE.clear
  end

  def login(id) = post(mock_session_path(user_id: id))

  def submit(national_id: NEW_ID, phone: "0812345678", consent: "1")
    patch onboarding_identity_path, params: { identity: { national_id:, phone:, consent: } }
  end

  test "pages live under /user-onboarding, apart from /product-onboarding" do
    assert_equal "/user-onboarding", onboarding_path
    assert_equal "/user-onboarding/identity/edit", edit_onboarding_identity_path
    assert_equal "/user-onboarding/identity", onboarding_identity_path
  end

  test "guests, sellers and admins get 404" do
    get edit_onboarding_identity_path
    assert_response :not_found

    [ SELLER, ADMIN ].each do |id|
      login(id)
      get edit_onboarding_identity_path
      assert_response :not_found
      submit
      assert_response :not_found
    end
    assert_equal "not_started", OnboardingStore.find(SELLER).status
  end

  test "a new buyer fills step 1 and lands on the onboarding page" do
    login(FRESH_BUYER)
    get edit_onboarding_identity_path
    assert_response :success
    assert_select "input[type=checkbox][name='identity[consent]']"

    submit
    assert_redirected_to onboarding_path
    onboarding = OnboardingStore.find(FRESH_BUYER)
    assert_equal NEW_ID, onboarding.national_id
    assert_equal "identity_done", onboarding.status

    follow_redirect!
    assert_response :success
    assert_includes response.body, "X-XXXX-XXXX0-07-5"
    assert_not_includes response.body, NEW_ID
  end

  test "invalid answers re-render the form with errors and never echo the typed ID" do
    login(FRESH_BUYER)
    submit(national_id: "1100000000076", consent: "0")

    assert_response :unprocessable_content
    assert_select ".field-error", minimum: 2
    assert_not_includes response.body, "1100000000076"
    assert_equal "not_started", OnboardingStore.find(FRESH_BUYER).status
  end

  test "a national ID used by another account is refused" do
    login(FRESH_BUYER)
    submit(national_id: OnboardingStore.find(COMPLETED_BUYER).national_id)

    assert_response :unprocessable_content
    assert_includes response.body, "บัญชีอื่น"
  end

  test "step 1 submits are limited to 10 an hour per buyer, so IDs can't be probed" do
    login(FRESH_BUYER)
    10.times { submit(national_id: "1100000000076") }
    assert_response :unprocessable_content

    submit
    assert_response :too_many_requests
    assert_equal "not_started", OnboardingStore.find(FRESH_BUYER).status
  end

  test "a malformed identity param is a 400, not a crash" do
    login(FRESH_BUYER)
    patch onboarding_identity_path, params: { identity: "1100000000075" }

    assert_response :bad_request
  end

  test "a completed buyer sees only the masked ID and can still change the phone" do
    login(COMPLETED_BUYER)
    raw = OnboardingStore.find(COMPLETED_BUYER).national_id

    get edit_onboarding_identity_path
    assert_response :success
    assert_not_includes response.body, raw
    assert_includes response.body, ThaiNationalId.mask(raw)
    assert_select "input[name='identity[national_id]']", 0

    submit(national_id: nil, phone: "0899999999", consent: nil)
    assert_redirected_to onboarding_path
    assert_equal "+66899999999", OnboardingStore.find(COMPLETED_BUYER).phone
    assert_equal "completed", OnboardingStore.find(COMPLETED_BUYER).status
  end
end
