require "test_helper"

class PaymentSubmissionTest < ActiveSupport::TestCase
  test "accepts the milestone payment and delivery methods" do
    %w[qr online_banking card cheque cash].each do |method|
      assert submission(payment_method: method).valid?, "#{method} should be valid"
    end
  end

  test "rejects unknown payment and delivery methods" do
    assert_not submission(payment_method: "bitcoin").valid?
    assert_not submission(delivery_method: "courier").valid?
  end

  test "rejects cash with shipping" do
    assert_not submission(payment_method: "cash", delivery_method: "shipping").valid?
  end

  test "does not require invoice details when invoice is unchecked" do
    assert submission(tax_invoice: false).valid?
  end

  test "requires a valid tax invoice when requested" do
    assert_not submission(tax_invoice: true).valid?
    assert submission(
      tax_invoice: true,
      tax_id: "1234567890123",
      branch: "สำนักงานใหญ่",
      address: "ที่อยู่ตัวอย่าง 1",
      email: "buyer@example.test"
    ).valid?
  end

  test "rejects malformed tax invoice details" do
    assert_not submission(
      tax_invoice: true,
      tax_id: "123",
      branch: "สำนักงานใหญ่",
      address: "ที่อยู่ตัวอย่าง 1",
      email: "not-an-email"
    ).valid?
  end

  test "rejects tax invoice fields that exceed their length limits" do
    assert_not submission(
      tax_invoice: true,
      tax_id: "1234567890123",
      branch: "x" * 101,
      address: "ที่อยู่",
      email: "buyer@example.test"
    ).valid?
  end

  private

  def submission(**overrides)
    PaymentSubmission.new({
      payment_method: "qr",
      delivery_method: "self_pickup",
      tax_invoice: false
    }.merge(overrides))
  end
end
