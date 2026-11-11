require "test_helper"

class PaymentsControllerTest < ActionDispatch::IntegrationTest
  test "payment page renders the mock order and server quote" do
    get "/payment"

    assert_response :success
    assert_includes response.body, "แหวนเพชรเม็ดใหญ่ (ตัวอย่าง)"
    assert_includes response.body, "฿ 112,350.00"
  end

  test "quote endpoint recalculates on the server for shipping" do
    get "/payment/quote", params: { delivery_method: "shipping" }

    assert_response :success
    assert_equal(
      {
        "subtotal_satang" => 10_550_000,
        "vat_satang" => 738_500,
        "shipping_fee_satang" => 50_000,
        "total_satang" => 11_288_500
      },
      response.parsed_body
    )
  end

  test "quote endpoint rejects an unknown delivery method" do
    get "/payment/quote", params: { delivery_method: "unknown" }

    assert_response :unprocessable_entity
  end

  test "preview rejects cash with shipping" do
    post "/payment/preview", params: { payment_method: "cash", delivery_method: "shipping" }

    assert_response :unprocessable_entity
    assert_includes response.body, "เงินสดใช้ได้เฉพาะการรับสินค้าเอง"
  end

  test "preview rejects an invalid checked tax invoice" do
    post "/payment/preview", params: {
      payment_method: "qr",
      delivery_method: "self_pickup",
      tax_invoice: "1",
      tax_id: "123",
      branch: "",
      address: "",
      email: "invalid"
    }

    assert_response :unprocessable_entity
  end

  test "valid preview never reports payment success" do
    post "/payment/preview", params: {
      payment_method: "qr",
      delivery_method: "self_pickup",
      tax_invoice: "0"
    }

    assert_response :success
    assert_includes response.body, "ยังไม่มีการเรียกเก็บเงินจริง"
    assert_not_includes response.body, "ชำระเงินสำเร็จ"
  end
end
