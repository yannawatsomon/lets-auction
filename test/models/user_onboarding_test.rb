require "test_helper"

class UserOnboardingTest < ActiveSupport::TestCase
  test "a new onboarding starts as not_started and is not completed" do
    onboarding = UserOnboarding.new(user_id: 26)

    assert_equal "not_started", onboarding.status
    assert_not onboarding.completed?
  end

  test "completed? is true only for the completed status" do
    assert UserOnboarding.new(status: "completed").completed?
    assert_not UserOnboarding.new(status: "scored").completed?
  end

  test "rejects an unknown status" do
    onboarding = UserOnboarding.new(user_id: 26, status: "approved")

    assert_not onboarding.valid?
    assert onboarding.errors.added?(:status, :inclusion, value: "approved")
  end

  test "rejects an unknown occupation but allows it to be blank before step 2" do
    assert_not UserOnboarding.new(user_id: 26, occupation: "astronaut").valid?
    assert UserOnboarding.new(user_id: 26, occupation: nil).valid?
  end

  test "inspect never shows the raw national ID" do
    onboarding = UserOnboarding.new(user_id: 26, national_id: "1100000000075")

    assert_not_includes onboarding.inspect, "1100000000075"
  end
end
