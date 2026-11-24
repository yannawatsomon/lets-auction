require "test_helper"

class MockQrPaymentStoreTest < ActiveSupport::TestCase
  setup do
    MockQrPaymentStore.reset!
    @now = Time.zone.parse("2026-11-24 12:00")
    @payment = MockQrPaymentStore.create!(amount_satang: 11_235_000, delivery_method: "self_pickup", now: @now)
  end

  test "makes a single-use QR for the exact amount with a reference and a 10 minute window" do
    assert_match MockQrPaymentStore::REFERENCE_FORMAT, @payment.reference
    assert_equal 11_235_000, @payment.amount_satang
    assert @payment.pending?
    assert_equal 600, @payment.seconds_left(@now)
    assert_not_equal @payment.reference,
      MockQrPaymentStore.create!(amount_satang: 1, delivery_method: "shipping", now: @now).reference
  end

  test "rejects a zero or non-integer amount" do
    assert_raises(ArgumentError) { MockQrPaymentStore.create!(amount_satang: 0, delivery_method: "shipping") }
    assert_raises(ArgumentError) { MockQrPaymentStore.create!(amount_satang: 1.5, delivery_method: "shipping") }
  end

  test "a QR past its time is expired and cannot be paid" do
    later = @now + 10.minutes

    assert MockQrPaymentStore.find(@payment.reference, now: later).expired?
    paid = pay(@payment, now: later)
    assert paid.expired?
    assert_nil paid.receipt_number
  end

  test "a paid QR gets sequential unique receipt numbers" do
    other = MockQrPaymentStore.create!(amount_satang: 500, delivery_method: "shipping", now: @now)

    first = pay(@payment)
    second = pay(other)

    assert first.paid?
    assert_equal "RC-2026-000001", first.receipt_number
    assert_equal "RC-2026-000002", second.receipt_number
  end

  test "a duplicate webhook does not process the payment twice" do
    pay(@payment, event_id: "evt-1")
    again = pay(@payment, event_id: "evt-1")
    other_event = pay(@payment, event_id: "evt-2")

    assert_equal "RC-2026-000001", again.receipt_number
    assert_equal "RC-2026-000001", other_event.receipt_number
    assert_equal [ "evt-1" ], again.event_ids
  end

  test "a wrong amount fails with a message and the QR cannot be paid afterwards" do
    failed = MockQrPaymentStore.apply_event!(@payment.reference, event_id: "evt-1", outcome: "paid",
      amount_satang: @payment.amount_satang - 100, now: @now)

    assert failed.failed?
    assert_includes failed.failure, "ยอดที่โอนไม่ตรง"
    assert pay(@payment, event_id: "evt-2").failed?
  end

  test "a bank decline fails" do
    failed = MockQrPaymentStore.apply_event!(@payment.reference, event_id: "evt-1", outcome: "failed",
      amount_satang: @payment.amount_satang, now: @now)

    assert failed.failed?
    assert_includes failed.failure, "ปฏิเสธ"
  end

  test "find returns a copy" do
    copy = MockQrPaymentStore.find(@payment.reference, now: @now)
    copy.status = "paid"

    assert MockQrPaymentStore.find(@payment.reference, now: @now).pending?
  end

  test "keeps at most MAX_PAYMENTS in memory" do
    MockQrPaymentStore::MAX_PAYMENTS.times { MockQrPaymentStore.create!(amount_satang: 1, delivery_method: "shipping", now: @now) }

    assert_nil MockQrPaymentStore.find(@payment.reference, now: @now)
    assert_equal MockQrPaymentStore::MAX_PAYMENTS, MockQrPaymentStore.payments.size
  end

  private

  def pay(payment, event_id: SecureRandom.uuid, now: @now)
    MockQrPaymentStore.apply_event!(payment.reference, event_id:, outcome: "paid",
      amount_satang: payment.amount_satang, now:)
  end
end
