require "test_helper"

class ThaiNationalIdTest < ActiveSupport::TestCase
  # Fake ID: first 12 digits chosen, 13th computed by the mod 11 rule.
  VALID = "1234567890121".freeze

  test "accepts an ID with a correct checksum" do
    assert ThaiNationalId.valid?(VALID)
  end

  test "accepts dashes and spaces and normalizes to 13 digits" do
    assert ThaiNationalId.valid?("1-2345-67890-12-1")
    assert_equal VALID, ThaiNationalId.normalize("1-2345 67890 12-1")
  end

  test "rejects a wrong check digit" do
    assert_not ThaiNationalId.valid?("1234567890122")
  end

  test "rejects wrong length, letters and blank" do
    [ "123456789012", "12345678901211", "12345678901ab", "", nil ].each do |value|
      assert_not ThaiNationalId.valid?(value), "expected #{value.inspect} to be invalid"
    end
  end

  test "masks all but the last 4 digits for display (docs/decision/user-onboarding.md)" do
    assert_equal "X-XXXX-XXXX0-12-1", ThaiNationalId.mask(VALID)
    assert_equal "X-XXXX-XXXX0-12-1", ThaiNationalId.mask("1-2345-67890-12-1")
  end
end
