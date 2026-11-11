require "test_helper"

class OnboardingStoreTest < ActiveSupport::TestCase
  FRESH_BUYER = 26 # seeded user with no onboarding yet

  setup { OnboardingStore.reset! }

  test "find returns a not_started onboarding for a buyer who has none" do
    onboarding = OnboardingStore.find(FRESH_BUYER)

    assert_equal FRESH_BUYER, onboarding.user_id
    assert_equal "not_started", onboarding.status
  end

  test "save stores the onboarding so find returns it" do
    onboarding = OnboardingStore.find(FRESH_BUYER)
    onboarding.phone = "+66800000026"
    onboarding.status = "identity_done"

    assert OnboardingStore.save(onboarding)
    assert_equal "+66800000026", OnboardingStore.find(FRESH_BUYER).phone
    assert_equal "identity_done", OnboardingStore.find(FRESH_BUYER).status
  end

  test "changing a found onboarding without save does not change the store" do
    OnboardingStore.find(21).status = "not_started"

    assert_equal "completed", OnboardingStore.find(21).status
  end

  test "save refuses an invalid onboarding" do
    onboarding = OnboardingStore.find(FRESH_BUYER)
    onboarding.status = "approved"

    assert_not OnboardingStore.save(onboarding)
    assert_equal "not_started", OnboardingStore.find(FRESH_BUYER).status
  end

  test "save refuses a national ID that another user already uses, even written with dashes" do
    taken = OnboardingStore.find(21).national_id
    onboarding = OnboardingStore.find(FRESH_BUYER)
    onboarding.national_id = taken.dup.insert(1, "-")

    assert_not OnboardingStore.save(onboarding)
    assert onboarding.errors.added?(:national_id, :taken)
  end

  test "a user can save again with their own national ID" do
    onboarding = OnboardingStore.find(21)
    onboarding.phone = "+66800000099"

    assert OnboardingStore.save(onboarding)
  end

  test "assessments are appended in order and the latest is the last one added" do
    first = CreditAssessment.new(user_id: FRESH_BUYER, score: 11, grade: "E", score_version: 1,
      inputs: {}, reasons: {}, created_at: Time.zone.parse("2026-11-11 10:00"))
    second = first.with(score: 38, grade: "D", created_at: Time.zone.parse("2026-11-11 11:00"))

    OnboardingStore.add_assessment(first)
    OnboardingStore.add_assessment(second)

    assert_equal [ 11, 38 ], OnboardingStore.assessments(FRESH_BUYER).map(&:score)
    assert_equal "D", OnboardingStore.latest_assessment(FRESH_BUYER).grade
  end

  test "assessments cannot be changed or removed through the store" do
    assessments = OnboardingStore.assessments(21)

    assert assessments.frozen?
    assert_raises(NoMethodError) { assessments.first.score = 0 }
    assert_not_respond_to OnboardingStore, :delete_assessment
  end

  test "reset! brings back the seed data" do
    onboarding = OnboardingStore.find(21)
    onboarding.status = "scored"
    OnboardingStore.save(onboarding)

    OnboardingStore.reset!

    assert_equal "completed", OnboardingStore.find(21).status
  end

  test "seeded buyers cover every grade A to E with valid, unique fake IDs" do
    seeded = OnboardingStore.all.select(&:completed?)

    assert_equal %w[A B C D E], seeded.map { |o| OnboardingStore.latest_assessment(o.user_id).grade }.sort
    ids = seeded.map(&:national_id)
    assert ids.all? { |id| ThaiNationalId.valid?(id) }
    assert_equal ids.size, ids.uniq.size
  end

  test "every seeded onboarding belongs to a mock buyer" do
    OnboardingStore.all.each do |onboarding|
      assert MockData.user(onboarding.user_id)&.buyer?, "user #{onboarding.user_id} is not a mock buyer"
    end
    assert MockData.user(FRESH_BUYER)&.buyer?
  end
end
