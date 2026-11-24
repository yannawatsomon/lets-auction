require "test_helper"

class PaymentQrFlowTest < ActionDispatch::IntegrationTest
  setup { MockQrPaymentStore.reset! }

  test "choosing QR opens the QR modal with amount, account, reference and countdown" do
    post "/payment/preview", params: { payment_method: "qr", delivery_method: "self_pickup" }

    assert_response :redirect
    follow_redirect!
    assert_response :success
    assert_includes response.body, "สแกน QR พร้อมเพย์"
    assert_includes response.body, "ยอดชำระ"
    assert_includes response.body, "฿ 112,350.00"
    assert_includes response.body, MockQrPaymentStore::ACCOUNT_NAME
    assert_includes response.body, current_payment.reference
    assert_includes response.body, "10:00"
    assert_includes response.body, "สแกนจ่ายไม่ได้"
  end

  test "other payment methods keep the demo notice" do
    post "/payment/preview", params: { payment_method: "card", delivery_method: "self_pickup" }

    assert_response :success
    assert_includes response.body, "ยังไม่มีการเรียกเก็บเงินจริง"
    assert_empty MockQrPaymentStore.payments
  end

  test "the amount comes from the server quote, not the request" do
    post "/payment/preview", params: { payment_method: "qr", delivery_method: "shipping", total_satang: 1 }

    assert_equal 11_288_500, current_payment.amount_satang
  end

  test "status reports pending, then the simulated webhook pays it and the receipt opens" do
    payment = start_qr

    get "/payment/qr/#{payment.reference}/status"
    assert_equal "pending", response.parsed_body["status"]

    post "/payment/qr/#{payment.reference}/simulate", params: { outcome: "paid", event_id: "evt-1" }, as: :json
    body = response.parsed_body
    assert_equal "paid", body["status"]
    assert_equal "/payment/qr/#{payment.reference}/receipt", body["receipt_url"]

    post "/payment/qr/#{payment.reference}/simulate", params: { outcome: "paid", event_id: "evt-1" }, as: :json
    assert_equal "RC-#{Time.current.year}-000001", current_payment.receipt_number

    get body["receipt_url"]
    assert_response :success
    assert_includes response.body, "ใบเสร็จรับเงิน"
    assert_includes response.body, "RC-#{Time.current.year}-000001"
    assert_includes response.body, "ดาวน์โหลด PDF"
    assert_includes response.body, "แจ้งผู้ขายแล้ว"
  end

  test "an amount mismatch shows an error and a new QR can be made" do
    payment = start_qr

    post "/payment/qr/#{payment.reference}/simulate", params: { outcome: "amount_mismatch" }, as: :json
    assert_equal "failed", response.parsed_body["status"]
    assert_includes response.parsed_body["message"], "ยอดที่โอนไม่ตรง"

    get "/payment/qr/#{payment.reference}"
    assert_includes response.body, "ยอดที่โอนไม่ตรง"
    assert_includes response.body, "สร้าง QR ใหม่"

    post "/payment/qr/#{payment.reference}/renew"
    assert_response :redirect
    assert_not_equal payment.reference, current_payment.reference
    assert current_payment.pending?
  end

  test "an expired QR is greyed out and cannot be paid" do
    payment = start_qr
    post "/payment/qr/#{payment.reference}/simulate", params: { outcome: "expire" }, as: :json
    assert_equal "expired", response.parsed_body["status"]

    post "/payment/qr/#{payment.reference}/simulate", params: { outcome: "paid" }, as: :json
    assert_equal "expired", response.parsed_body["status"]

    get "/payment/qr/#{payment.reference}"
    assert_includes response.body, "is-inactive"
    assert_includes response.body, "QR หมดอายุแล้ว"

    get "/payment/qr/#{payment.reference}/receipt"
    assert_redirected_to "/payment/qr/#{payment.reference}"
  end

  test "renewing a pending QR keeps it" do
    payment = start_qr

    post "/payment/qr/#{payment.reference}/renew"

    assert_redirected_to "/payment/qr/#{payment.reference}"
    assert_equal 1, MockQrPaymentStore.payments.size
  end

  test "an unknown QR goes back to the payment page or answers 404 json" do
    get "/payment/qr/QRZZZZZZZZZZ"
    assert_redirected_to "/payment"

    get "/payment/qr/QRZZZZZZZZZZ/status"
    assert_response :not_found
    assert_equal "qr_not_found", response.parsed_body["error"]
  end

  test "an unknown simulate outcome is rejected" do
    payment = start_qr

    post "/payment/qr/#{payment.reference}/simulate", params: { outcome: "refund" }, as: :json

    assert_response :unprocessable_entity
    assert current_payment.pending?
  end

  private

  def start_qr
    post "/payment/preview", params: { payment_method: "qr", delivery_method: "self_pickup" }
    current_payment
  end

  def current_payment
    reference = MockQrPaymentStore.payments.keys.last
    MockQrPaymentStore.find(reference)
  end
end
