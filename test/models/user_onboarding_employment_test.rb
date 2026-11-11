require "test_helper"

# Step 2: occupation, monthly income (THB, stored as satang), experience (#18).
class UserOnboardingEmploymentTest < ActiveSupport::TestCase
  setup { OnboardingStore.reset! }

  def identity_done
    onboarding = OnboardingStore.find(26)
    onboarding.update_identity(national_id: "1100000000075", phone: "0812345678", consent: "1")
    onboarding
  end

  def completed = OnboardingStore.find(21) # private_employee, 1,000,000 THB, 12 / 5 years

  def answers(**over)
    { occupation: "private_employee", monthly_income: "45,000", years_experience_total: "6", years_in_current_job: "2" }.merge(over)
  end

  test "valid answers are stored, income in satang, and the status moves to employment_done" do
    onboarding = identity_done

    assert onboarding.update_employment(**answers)
    assert_equal "private_employee", onboarding.occupation
    assert_equal 4_500_000, onboarding.monthly_income_cents
    assert_equal 6, onboarding.years_experience_total
    assert_equal 2, onboarding.years_in_current_job
    assert_equal "employment_done", onboarding.status
  end

  test "needs step 1 first" do
    onboarding = OnboardingStore.find(26)

    assert_not onboarding.update_employment(**answers)
    assert onboarding.errors[:base].any?
    assert_equal "not_started", onboarding.status
  end

  test "rejects an unknown or missing occupation" do
    [ "astronaut", "" ].each do |value|
      onboarding = identity_done
      assert_not onboarding.update_employment(**answers(occupation: value)), "expected #{value.inspect} to be rejected"
      assert onboarding.errors[:occupation].any?
    end
  end

  test "income must be whole baht from 0 up to 1,000,000,000, and is required" do
    [ "", "-1", "12.50", "abc", "1000000001" ].each do |value|
      onboarding = identity_done
      assert_not onboarding.update_employment(**answers(monthly_income: value)), "expected #{value.inspect} to be rejected"
      assert onboarding.errors[:monthly_income].any?
    end
    assert identity_done.update_employment(**answers(monthly_income: "0"))
    assert identity_done.update_employment(**answers(monthly_income: " 1 000 000 "))
  end

  test "total experience is required, a whole number from 0 to 60" do
    [ "", "-1", "61", "2.5" ].each do |value|
      onboarding = identity_done
      assert_not onboarding.update_employment(**answers(years_experience_total: value)), "expected #{value.inspect} to be rejected"
      assert onboarding.errors[:years_experience_total].any?
    end
  end

  test "years in the current job are optional but can't exceed total experience" do
    onboarding = identity_done
    assert onboarding.update_employment(**answers(years_in_current_job: ""))
    assert_nil onboarding.years_in_current_job

    onboarding = identity_done
    assert_not onboarding.update_employment(**answers(years_experience_total: "3", years_in_current_job: "4"))
    assert onboarding.errors[:years_in_current_job].any?
  end

  test "a rejected update changes nothing" do
    onboarding = identity_done

    assert_not onboarding.update_employment(**answers(occupation: "private_employee", monthly_income: "abc"))
    assert_nil onboarding.occupation
    assert_equal "identity_done", onboarding.status
  end

  test "changing a score input after completed sends the buyer back to employment_done" do
    onboarding = completed

    assert onboarding.update_employment(**answers(occupation: "private_employee", monthly_income: "500000",
      years_experience_total: "12", years_in_current_job: "5"))
    assert_equal "employment_done", onboarding.status
  end

  test "changing only years in the current job keeps the status, because it doesn't feed the score" do
    onboarding = completed

    assert onboarding.update_employment(**answers(occupation: "private_employee", monthly_income: "1,000,000",
      years_experience_total: "12", years_in_current_job: "7"))
    assert_equal "completed", onboarding.status
  end

  test "monthly_income shows the saved satang as whole baht for the form" do
    assert_equal 1_000_000, completed.monthly_income
    assert_nil identity_done.monthly_income
  end
end
