require "test_helper"

# Step 3 pages (#19). Buyer 26 hasn't started, buyer 21 is completed (grade A).
class Onboarding::ScoreTest < ActionDispatch::IntegrationTest
  SELLER = 11
  COMPLETED_BUYER = 21
  FRESH_BUYER = 26

  setup do
    OnboardingStore.reset!
    Onboarding::IdentitiesController::RATE_LIMIT_STORE.clear
  end

  def login(id) = post(mock_session_path(user_id: id))

  def finish_steps_1_and_2
    patch onboarding_identity_path, params: { identity: { national_id: "1100000000075", phone: "0812345678", consent: "1" } }
    patch onboarding_employment_path, params: { employment: {
      occupation: "private_employee", monthly_income: "45000", years_experience_total: "6", years_in_current_job: "2" } }
  end

  test "lives at /user-onboarding/score" do
    assert_equal "/user-onboarding/score", onboarding_score_path
  end

  test "sellers and guests get 404" do
    get onboarding_score_path
    assert_response :not_found
    login(SELLER)
    post onboarding_score_path
    assert_response :not_found
  end

  test "a buyer who hasn't finished step 2 is sent to it" do
    login(FRESH_BUYER)
    get onboarding_score_path
    assert_redirected_to edit_onboarding_employment_path
    post onboarding_score_path
    assert_redirected_to edit_onboarding_employment_path
    assert_empty OnboardingStore.assessments(FRESH_BUYER)
  end

  test "after step 2 the buyer sees a summary and tries left, then calculates" do
    login(FRESH_BUYER)
    finish_steps_1_and_2

    get onboarding_score_path
    assert_response :success
    assert_select "ol.ob-steps > li[aria-current=step]", text: /คำนวณคะแนน/
    assert_select ".ob-summary", text: /45,000/
    assert_select ".ob-tries", text: /3 จาก 3/
    assert_select "form[action='#{onboarding_score_path}'] button.btn.primary[type=submit]"

    post onboarding_score_path
    assert_redirected_to onboarding_path
    assert_equal "scored", OnboardingStore.find(FRESH_BUYER).status
    follow_redirect!
    assert_select ".flash.notice", text: /คำนวณแล้ว: 42 คะแนน เกรด D/
    assert_select ".ob-score", text: /42/
  end

  test "a scored buyer sees the result without a calculate button" do
    login(FRESH_BUYER)
    finish_steps_1_and_2
    post onboarding_score_path

    get onboarding_score_path
    assert_select ".ob-score", text: /42/
    assert_select "form[action='#{onboarding_score_path}']", 0
  end

  test "when no tries are left the button is gone and a post is refused" do
    login(FRESH_BUYER)
    finish_steps_1_and_2
    3.times { |i| OnboardingStore.add_assessment(CreditAssessment.new(user_id: FRESH_BUYER, score: 42, grade: "D",
      score_version: 1, inputs: {}, reasons: {}, created_at: i.hours.ago)) }

    get onboarding_score_path
    assert_select ".ob-tries", text: /0 จาก 3/
    assert_select "form[action='#{onboarding_score_path}']", 0

    post onboarding_score_path
    assert_redirected_to onboarding_score_path
    assert_equal "employment_done", OnboardingStore.find(FRESH_BUYER).status
  end

  test "the overview links step 3 after step 2" do
    login(FRESH_BUYER)
    finish_steps_1_and_2
    get onboarding_path

    assert_select "a.btn.primary[href='#{onboarding_score_path}']"
  end
end
