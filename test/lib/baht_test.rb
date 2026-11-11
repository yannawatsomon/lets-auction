require "test_helper"

class BahtTest < ActiveSupport::TestCase
  test "whole baht gets .00" do
    assert_equal 50_000, Baht.parse("500")
  end

  test "one or two decimals and thousands separators" do
    assert_equal 50_050, Baht.parse("500.5")
    assert_equal 125_075, Baht.parse("1,250.75")
    assert_equal 125_075, Baht.parse("  1250.75 ")
  end

  test "rejects more than two decimals, negatives and junk" do
    [ "500.123", "-5", "abc", "", nil, "1e3", "5.", ".5" ].each do |bad|
      assert_nil Baht.parse(bad), "expected #{bad.inspect} to be rejected"
    end
  end

  test "formats satang as baht" do
    assert_equal "1,250.75", Baht.format(125_075)
    assert_equal "20,000,000.00", Baht.format(2_000_000_000)
    assert_equal "0.05", Baht.format(5)
  end
end
