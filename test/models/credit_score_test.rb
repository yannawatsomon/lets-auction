require "test_helper"

# Score v1 table from docs/decision/user-onboarding.md (#19).
class CreditScoreTest < ActiveSupport::TestCase
  setup { OnboardingStore.reset! }

  def onboarding(occupation: "private_employee", baht: 45_000, years: 6, phone_verified: false)
    UserOnboarding.new(user_id: 26, occupation: occupation, monthly_income_cents: baht * 100,
      years_experience_total: years, phone_verified_at: (Time.zone.parse("2026-11-11") if phone_verified))
  end

  def points(part, **answers) = CreditScore.calculate(onboarding(**answers))[:reasons][part]

  test "income bands, checked at every edge" do
    { 0 => 0, 1 => 4, 14_999 => 4, 15_000 => 10, 49_999 => 10, 50_000 => 18, 99_999 => 18,
      100_000 => 26, 199_999 => 26, 200_000 => 34, 499_999 => 34, 500_000 => 42, 999_999 => 42,
      1_000_000 => 50, 9_000_000 => 50 }.each do |baht, expected|
      assert_equal expected, points(:income, baht: baht), "income #{baht} THB"
    end
  end

  test "occupation points" do
    { "government" => 25, "private_employee" => 21, "business_owner" => 17, "retired" => 13,
      "freelancer" => 10, "student" => 4, "other" => 4 }.each do |occupation, expected|
      assert_equal expected, points(:occupation, occupation: occupation), occupation
    end
  end

  test "total experience bands, checked at every edge" do
    { 0 => 3, 1 => 3, 2 => 7, 4 => 7, 5 => 11, 9 => 11, 10 => 15, 40 => 15 }.each do |years, expected|
      assert_equal expected, points(:experience, years: years), "#{years} years"
    end
  end

  test "a verified phone adds 10, an unverified one 0" do
    assert_equal 0, points(:phone)
    assert_equal 10, points(:phone, phone_verified: true)
  end

  test "the score is the sum of the parts and carries version 1 and an input snapshot" do
    result = CreditScore.calculate(onboarding(occupation: "government", baht: 500_000, years: 10))

    assert_equal 82, result[:score]
    assert_equal "A", result[:grade]
    assert_equal 1, result[:score_version]
    assert_equal({ "occupation" => "government", "monthly_income_cents" => 50_000_000,
      "years_experience_total" => 10, "phone_verified" => false }, result[:inputs])
  end

  test "grade bands, checked at every edge" do
    { 100 => "A", 80 => "A", 79 => "B", 65 => "B", 64 => "C", 50 => "C", 49 => "D", 35 => "D",
      34 => "E", 0 => "E" }.each do |score, grade|
      assert_equal grade, CreditScore.grade_for(score), "score #{score}"
    end
  end

  test "every seeded assessment matches the formula" do
    OnboardingStore.all.select(&:completed?).each do |seeded|
      stored = OnboardingStore.latest_assessment(seeded.user_id)
      result = CreditScore.calculate(seeded)

      assert_equal [ stored.score, stored.grade ], [ result[:score], result[:grade] ], "user #{seeded.user_id}"
      assert_equal stored.reasons.transform_keys(&:to_s), result[:reasons].transform_keys(&:to_s), "user #{seeded.user_id}"
    end
  end
end
