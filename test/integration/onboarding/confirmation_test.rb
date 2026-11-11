require "test_helper"

# Step 4 pages (#20). Buyer 26 hasn't started; 21 is completed (A); 25 is completed (E).
class Onboarding::ConfirmationTest < ActionDispatch::IntegrationTest
  SELLER = 11
  COMPLETED_A = 21
  COMPLETED_E = 25
  FRESH_BUYER = 26

  setup do
    OnboardingStore.reset!
    Onboarding::IdentitiesController::RATE_LIMIT_STORE.clear
  end

  def login(id) = post(mock_session_path(user_id: id))

  def score_with_income(baht)
    patch onboarding_identity_path, params: { identity: { national_id: "1100000000075", phone: "0812345678", consent: "1" } }
    patch onboarding_employment_path, params: { employment: {
      occupation: "private_employee", monthly_income: baht.to_s, years_experience_total: "6", years_in_current_job: "2" } }
    post onboarding_score_path
  end

  test "lives at /user-onboarding/confirmation" do
    assert_equal "/user-onboarding/confirmation", onboarding_confirmation_path
  end

  test "sellers and guests get 404" do
    get onboarding_confirmation_path
    assert_response :not_found
    login(SELLER)
    post onboarding_confirmation_path, params: { confirmation: { declaration: "1" } }
    assert_response :not_found
  end

  test "a buyer who hasn't been scored is sent to step 3" do
    login(FRESH_BUYER)
    get onboarding_confirmation_path
    assert_redirected_to onboarding_score_path
  end

  test "a scored buyer sees the result, what the grade unlocks, and a declaration box" do
    login(FRESH_BUYER)
    score_with_income(45_000) # 42 → D

    get onboarding_confirmation_path
    assert_response :success
    assert_select "ol.ob-steps > li[aria-current=step]", text: /ยืนยันผล/
    assert_select ".ob-score", text: /42/
    assert_select ".ob-access", text: /sealed/
    assert_select "input[type=checkbox][name='confirmation[declaration]']"
  end

  test "confirming without the declaration is refused" do
    login(FRESH_BUYER)
    score_with_income(45_000)

    post onboarding_confirmation_path, params: { confirmation: { declaration: "0" } }
    assert_response :unprocessable_content
    assert_select ".field-error"
    assert_equal "scored", OnboardingStore.find(FRESH_BUYER).status
  end

  test "confirming completes onboarding and shows the success page" do
    login(FRESH_BUYER)
    score_with_income(45_000)

    post onboarding_confirmation_path, params: { confirmation: { declaration: "1" } }
    assert_redirected_to onboarding_confirmation_path
    assert OnboardingStore.find(FRESH_BUYER).completed?
    assert BuyerStanding.onboarded?(MockData.user(FRESH_BUYER))

    follow_redirect!
    assert_select ".ob-done-panel h2", text: /ยืนยันเรียบร้อย/
    assert_select "a.btn.primary[href='#{root_path}']", text: /ไปดูสินค้า/
  end

  test "a completed grade E buyer is told they can't bid yet and offered a way to re-score" do
    login(COMPLETED_E)
    get onboarding_confirmation_path

    assert_select ".ob-access", text: /ยังเข้าประมูลไม่ได้/
    assert_select "a[href='#{edit_onboarding_employment_path}']"
  end

  test "a completed grade A buyer is told about proof of income for English lots" do
    login(COMPLETED_A)
    get onboarding_confirmation_path

    assert_select ".ob-access", text: /หลักฐานรายได้/
  end

  test "the overview links step 4 once scored" do
    login(FRESH_BUYER)
    score_with_income(45_000)
    get onboarding_path

    assert_select "a.btn.primary[href='#{onboarding_confirmation_path}']"
  end
end
