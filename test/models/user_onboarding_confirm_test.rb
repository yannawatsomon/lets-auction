require "test_helper"

# Step 4: confirm the result with a truth declaration (#20).
class UserOnboardingConfirmTest < ActiveSupport::TestCase
  NOW = Time.zone.parse("2026-11-20 10:00")

  def onboarding(status) = UserOnboarding.new(user_id: 26, status: status)

  test "a scored buyer who declares the answers true becomes completed" do
    o = onboarding("scored")

    assert o.confirm(declaration: "1", now: NOW)
    assert_equal "completed", o.status
    assert_equal NOW, o.confirmed_at
  end

  test "the declaration is required" do
    [ "0", nil, "" ].each do |value|
      o = onboarding("scored")
      assert_not o.confirm(declaration: value, now: NOW), "expected #{value.inspect} to be refused"
      assert o.errors[:declaration].any?
      assert_equal "scored", o.status
      assert_nil o.confirmed_at
    end
  end

  test "only a scored buyer can confirm" do
    %w[not_started identity_done employment_done completed].each do |status|
      o = onboarding(status)
      assert_not o.confirm(declaration: "1", now: NOW), "expected #{status} to be refused"
      assert o.errors[:base].any?
      assert_equal status, o.status
    end
  end
end
