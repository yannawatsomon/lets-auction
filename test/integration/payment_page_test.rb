require "test_helper"

class PaymentPageTest < ActionDispatch::IntegrationTest
  test "renders the demo checkout with itemized amount and payment options" do
    get "/payment"

    assert_response :success
    assert_includes response.body, "แหวนเพชรเม็ดใหญ่ (ตัวอย่าง)"
    assert_includes response.body, "role=\"img\""
    assert_includes response.body, "ราคาประมูล"
    assert_includes response.body, "ค่าบริการผู้ซื้อ"
    assert_includes response.body, "ค่าขนส่ง"
    assert_includes response.body, "ภาษีมูลค่าเพิ่ม 7%"
    assert_includes response.body, "รวมทั้งสิ้น"
    assert_includes response.body, "QR พร้อมเพย์"
    assert_includes response.body, "โอนผ่านธนาคารออนไลน์"
    assert_includes response.body, "บัตรเครดิต / เดบิต"
    assert_includes response.body, "เช็ค"
    assert_includes response.body, "เงินสด"
    assert_includes response.body, "เลขประจำตัวผู้เสียภาษี"
    assert_includes response.body, "เวลาชำระที่เหลือ"
    assert_includes response.body, "ดำเนินการชำระ"
    assert_includes response.body, "ไม่มีการเรียกเก็บเงินจริง"
    assert_not_includes response.body, "ชำระเงินสำเร็จ"
  end

  test "shows shipping details and server-calculated total when shipping is selected" do
    get "/payment", params: { delivery_method: "shipping" }

    assert_response :success
    assert_includes response.body, "ขนส่งมาตรฐาน (ตัวอย่าง)"
    assert_includes response.body, "ที่อยู่จัดส่งตัวอย่าง"
    assert_includes response.body, "฿ 112,885.00"
  end
end
