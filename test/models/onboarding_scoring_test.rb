require "test_helper"

# Step 3: calculating the score, at most 3 times in 30 days (#19).
class OnboardingScoringTest < ActiveSupport::TestCase
  NOW = Time.zone.parse("2026-11-20 10:00")
  BUYER = 26

  setup do
    OnboardingStore.reset!
    onboarding = OnboardingStore.find(BUYER)
    onboarding.update_identity(national_id: "1100000000075", phone: "0812345678", consent: "1")
    onboarding.update_employment(occupation: "private_employee", monthly_income: "45000",
      years_experience_total: "6", years_in_current_job: "2")
    OnboardingStore.save(onboarding)
  end

  def back_to_employment_done(baht)
    onboarding = OnboardingStore.find(BUYER)
    onboarding.update_employment(occupation: "private_employee", monthly_income: baht.to_s,
      years_experience_total: "6", years_in_current_job: "2")
    OnboardingStore.save(onboarding)
  end

  test "scoring appends a version 1 assessment and moves the status to scored" do
    result = OnboardingScoring.call(BUYER, now: NOW)

    assert result.ok?
    assert_equal 42, result.assessment.score # 10 + 21 + 11 + 0
    assert_equal "D", result.assessment.grade
    assert_equal NOW, result.assessment.created_at
    assert_equal [ result.assessment ], OnboardingStore.assessments(BUYER)
    assert_equal "scored", OnboardingStore.find(BUYER).status
  end

  test "refuses before step 2 is done" do
    other = OnboardingStore.find(26)
    other.status = "identity_done"
    OnboardingStore.save(other)

    result = OnboardingScoring.call(BUYER, now: NOW)
    assert_not result.ok?
    assert_empty OnboardingStore.assessments(BUYER)
  end

  test "refuses when already scored and nothing changed" do
    OnboardingScoring.call(BUYER, now: NOW)

    assert_not OnboardingScoring.call(BUYER, now: NOW + 1.minute).ok?
    assert_equal 1, OnboardingStore.assessments(BUYER).size
  end

  test "allows 3 calculations in 30 days, then refuses the 4th" do
    3.times do |i|
      back_to_employment_done(45_000 + i) unless i.zero?
      assert OnboardingScoring.call(BUYER, now: NOW + i.days).ok?, "calculation #{i + 1}"
    end
    back_to_employment_done(50_000)

    result = OnboardingScoring.call(BUYER, now: NOW + 3.days)
    assert_not result.ok?
    assert_match "3", result.error
    assert_equal "employment_done", OnboardingStore.find(BUYER).status
    assert_equal 0, OnboardingScoring.tries_left(BUYER, now: NOW + 3.days)
  end

  test "calculations older than 30 days no longer count" do
    3.times do |i|
      back_to_employment_done(45_000 + i) unless i.zero?
      OnboardingScoring.call(BUYER, now: NOW + i.days)
    end
    back_to_employment_done(50_000)

    assert_equal 1, OnboardingScoring.tries_left(BUYER, now: NOW + 30.days + 1.second)
    assert OnboardingScoring.call(BUYER, now: NOW + 30.days + 1.second).ok?
  end

  test "tries_left starts at 3" do
    assert_equal 3, OnboardingScoring.tries_left(BUYER, now: NOW)
  end
end
