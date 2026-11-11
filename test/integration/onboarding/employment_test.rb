require "test_helper"

# Step 2 pages (#18). Buyer 26 hasn't started, buyer 21 is completed (grade A).
class Onboarding::EmploymentTest < ActionDispatch::IntegrationTest
  SELLER = 11
  COMPLETED_BUYER = 21
  FRESH_BUYER = 26

  setup do
    OnboardingStore.reset!
    Onboarding::IdentitiesController::RATE_LIMIT_STORE.clear
  end

  def login(id) = post(mock_session_path(user_id: id))

  def finish_step_1
    patch onboarding_identity_path, params: { identity: { national_id: "1100000000075", phone: "0812345678", consent: "1" } }
  end

  def submit(**over)
    patch onboarding_employment_path, params: { employment: {
      occupation: "private_employee", monthly_income: "45000", years_experience_total: "6", years_in_current_job: "2"
    }.merge(over) }
  end

  test "lives at /user-onboarding/employment" do
    assert_equal "/user-onboarding/employment/edit", edit_onboarding_employment_path
  end

  test "sellers and guests get 404" do
    get edit_onboarding_employment_path
    assert_response :not_found
    login(SELLER)
    submit
    assert_response :not_found
  end

  test "a buyer who skipped step 1 is sent back to it" do
    login(FRESH_BUYER)

    get edit_onboarding_employment_path
    assert_redirected_to edit_onboarding_identity_path
    submit
    assert_redirected_to edit_onboarding_identity_path
    assert_nil OnboardingStore.find(FRESH_BUYER).occupation
  end

  test "after step 1 the buyer fills step 2 and lands on the overview" do
    login(FRESH_BUYER)
    finish_step_1

    get edit_onboarding_employment_path
    assert_response :success
    assert_select "ol.ob-steps > li[aria-current=step]", text: /อาชีพและรายได้/
    assert_select "select[name='employment[occupation]'] option", UserOnboarding::OCCUPATIONS.size + 1

    submit
    assert_redirected_to onboarding_path
    onboarding = OnboardingStore.find(FRESH_BUYER)
    assert_equal 4_500_000, onboarding.monthly_income_cents
    assert_equal "employment_done", onboarding.status
  end

  test "invalid answers re-render with errors and keep what was typed" do
    login(FRESH_BUYER)
    finish_step_1
    submit(monthly_income: "abc", years_experience_total: "99")

    assert_response :unprocessable_content
    assert_select ".field-error", minimum: 2
    assert_select "input[name='employment[monthly_income]'][value=abc]"
  end

  test "a completed buyer is warned that changing score answers needs a new score" do
    login(COMPLETED_BUYER)
    get edit_onboarding_employment_path

    assert_select ".ob-note", text: /คำนวณคะแนน/
    assert_select "input[name='employment[monthly_income]'][value='1000000']"
  end

  test "the overview links step 2 once step 1 is done" do
    login(FRESH_BUYER)
    finish_step_1
    get onboarding_path

    assert_select "a[href='#{edit_onboarding_employment_path}']"
  end
end
