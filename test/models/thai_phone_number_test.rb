require "test_helper"

class ThaiPhoneNumberTest < ActiveSupport::TestCase
  test "normalizes local, dashed and international forms to +66" do
    [ "0812345678", "081-234-5678", "081 234 5678", "+66812345678", "66812345678" ].each do |value|
      assert_equal "+66812345678", ThaiPhoneNumber.normalize(value), value
    end
  end

  test "accepts mobile prefixes 06, 08 and 09" do
    %w[0612345678 0812345678 0912345678].each { |v| assert ThaiPhoneNumber.valid?(v), v }
  end

  test "rejects other prefixes, wrong length, letters and blank" do
    %w[0212345678 0712345678 081234567 08123456789 08123abc78].push("", nil).each do |v|
      assert_not ThaiPhoneNumber.valid?(v), "expected #{v.inspect} to be invalid"
    end
  end

  test "normalize returns nil for invalid input" do
    assert_nil ThaiPhoneNumber.normalize("12345")
  end
end
