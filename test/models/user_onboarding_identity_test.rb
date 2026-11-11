require "test_helper"

# Step 1: national ID, phone and consent (#17, docs/decision/user-onboarding.md).
class UserOnboardingIdentityTest < ActiveSupport::TestCase
  NEW_ID = "1100000000075" # fake, valid check digit, not in the seed
  NOW = Time.zone.parse("2026-11-12 09:00")

  setup { OnboardingStore.reset! }

  def fresh = OnboardingStore.find(26)
  def completed = OnboardingStore.find(21)

  test "valid answers are normalized, consent is recorded and the status moves to identity_done" do
    onboarding = fresh

    assert onboarding.update_identity(national_id: "1-1000-00000-07-5", phone: "081-234-5678", consent: "1", now: NOW)
    assert_equal NEW_ID, onboarding.national_id
    assert_equal "+66812345678", onboarding.phone
    assert_equal NOW, onboarding.consent_at
    assert_equal "identity_done", onboarding.status
  end

  test "rejects a national ID with a wrong check digit and changes nothing" do
    onboarding = fresh

    assert_not onboarding.update_identity(national_id: "1100000000076", phone: "0812345678", consent: "1", now: NOW)
    assert onboarding.errors[:national_id].any?
    assert_nil onboarding.national_id
    assert_equal "not_started", onboarding.status
  end

  test "requires a national ID when none is saved yet" do
    onboarding = fresh

    assert_not onboarding.update_identity(national_id: "", phone: "0812345678", consent: "1", now: NOW)
    assert onboarding.errors[:national_id].any?
  end

  test "rejects a phone that is not a Thai mobile number" do
    onboarding = fresh

    assert_not onboarding.update_identity(national_id: NEW_ID, phone: "021234567", consent: "1", now: NOW)
    assert onboarding.errors[:phone].any?
  end

  test "requires consent before the first save" do
    onboarding = fresh

    assert_not onboarding.update_identity(national_id: NEW_ID, phone: "0812345678", consent: "0", now: NOW)
    assert onboarding.errors[:consent].any?
  end

  test "does not ask for consent again and keeps the first consent time" do
    onboarding = completed
    first_consent = onboarding.consent_at

    assert onboarding.update_identity(national_id: "", phone: "0899999999", consent: nil, now: NOW)
    assert_equal first_consent, onboarding.consent_at
  end

  test "after completed the phone can change and the status stays completed" do
    onboarding = completed

    assert onboarding.update_identity(national_id: "", phone: "0899999999", consent: nil, now: NOW)
    assert_equal "+66899999999", onboarding.phone
    assert_equal "completed", onboarding.status
  end

  test "after completed the national ID is locked" do
    onboarding = completed
    original = onboarding.national_id

    assert_not onboarding.update_identity(national_id: NEW_ID, phone: "0899999999", consent: nil, now: NOW)
    assert onboarding.errors[:national_id].any?
    assert_equal original, onboarding.national_id
  end

  test "after completed typing the same national ID again is fine" do
    onboarding = completed

    assert onboarding.update_identity(national_id: onboarding.national_id, phone: "0899999999", consent: nil, now: NOW)
  end

  test "before completed the national ID can still change" do
    onboarding = fresh
    onboarding.update_identity(national_id: NEW_ID, phone: "0812345678", consent: "1", now: NOW)

    assert onboarding.update_identity(national_id: "1100000000083", phone: "0812345678", consent: nil, now: NOW)
    assert_equal "1100000000083", onboarding.national_id
  end

  test "a later step keeps its status when step 1 is saved again" do
    onboarding = fresh
    onboarding.update_identity(national_id: NEW_ID, phone: "0812345678", consent: "1", now: NOW)
    onboarding.status = "employment_done"

    assert onboarding.update_identity(national_id: "", phone: "0899999999", consent: nil, now: NOW)
    assert_equal "employment_done", onboarding.status
  end

  test "the same phone can be used by two accounts" do
    onboarding = fresh
    onboarding.update_identity(national_id: NEW_ID, phone: completed.phone, consent: "1", now: NOW)

    assert OnboardingStore.save(onboarding)
  end

  test "national_id is filtered from logs" do
    filter = ActiveSupport::ParameterFilter.new(Rails.application.config.filter_parameters)

    assert_equal "[FILTERED]", filter.filter("identity" => { "national_id" => NEW_ID })["identity"]["national_id"]
  end
end
