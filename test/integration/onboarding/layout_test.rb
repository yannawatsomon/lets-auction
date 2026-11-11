require "test_helper"

# Onboarding look (K-Onboarding mockup): 4-step bar, card, back/next bar.
class Onboarding::LayoutTest < ActionDispatch::IntegrationTest
  COMPLETED_BUYER = 21
  FRESH_BUYER = 26

  setup { OnboardingStore.reset! }

  def login(id) = post(mock_session_path(user_id: id))

  test "step 1 shows the 4-step bar with step 1 as the current step" do
    login(FRESH_BUYER)
    get edit_onboarding_identity_path

    assert_select "ol.ob-steps > li", 4
    assert_select "ol.ob-steps > li[aria-current=step]", 1
    assert_select "ol.ob-steps > li[aria-current=step]", text: /ยืนยันตัวตน/
    assert_select "section.card form .ob-nav" do
      assert_select "a.btn", text: "ย้อนกลับ"
      assert_select "input.btn.primary[type=submit]"
    end
  end

  test "the overview marks done steps and points the current step at the next one" do
    onboarding = OnboardingStore.find(FRESH_BUYER)
    onboarding.update_identity(national_id: "1100000000075", phone: "0812345678", consent: "1")
    OnboardingStore.save(onboarding)
    login(FRESH_BUYER)

    get onboarding_path
    assert_select "ol.ob-steps > li.done", 1
    assert_select "ol.ob-steps > li[aria-current=step]", text: /อาชีพและรายได้/
  end

  test "a completed buyer sees every step done, no current step, and the score" do
    login(COMPLETED_BUYER)
    get onboarding_path

    assert_select "ol.ob-steps > li.done", 4
    assert_select "ol.ob-steps > li[aria-current=step]", 0
    assert_select ".ob-score", text: /86/
  end
end
