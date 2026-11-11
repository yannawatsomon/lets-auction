require "test_helper"

class CatalogCardTest < ActionView::TestCase
  Lot = Data.define(:name, :category, :starts_at, :ends_at)

  setup do
    @lot = Lot.new("กล้องตัวอย่าง", "กล้อง", Time.utc(2026, 11, 11, 3), Time.utc(2026, 11, 11, 4))
  end

  test "renders product information and adjacent status and auction type labels" do
    card
    assert_select "h3", "กล้องตัวอย่าง"
    assert_select ".catalog-card__category", "กล้อง"
    assert_select ".catalog-card__labels" do
      assert_select "span", "กำลังประมูล"
      assert_select "span", "English"
    end
    assert_select "time[datetime='2026-11-11T03:00:00Z']", "11/11/2026 10:00"
    assert_select "time", text: "11/11/2026 11:00"
  end

  test "renders sealed type and all auction statuses" do
    { ongoing: "กำลังประมูล", upcoming: "ยังไม่เริ่ม", ended: "จบแล้ว" }.each do |status, label|
      card(status: status, auction_type: "sealed_first_price")
      assert_select ".catalog-card__labels span", text: label
      assert_select ".catalog-card__labels span", text: "First-price sealed-bid"
    end
  end

  test "shows fallback and no link when image and detail paths are missing" do
    card
    assert_select ".catalog-card__fallback", text: /ไม่มีรูปสินค้า/
    assert_select "img", count: 0
    assert_select "a", count: 0
  end

  test "renders lazy image and prepares fallback on loading error" do
    card(image_path: "/images/camera.png")
    assert_select "img[src='/images/camera.png'][loading='lazy'][alt='กล้องตัวอย่าง']"
    assert_select "img[data-action='error->catalog-image#fallback']"
    assert_select "[data-catalog-image-target='placeholder'][hidden]"
  end

  test "links product title only to supplied local detail path" do
    card(detail_path: "/lots/1")
    assert_select "h3 a[href='/lots/1']", "กล้องตัวอย่าง"
  end

  test "rejects unsafe image and detail paths" do
    [ "javascript:alert(1)", "//example.com/image", "/\\example.com", "https://example.com", "/path\nunsafe" ].each do |path|
      card(image_path: path, detail_path: path)
      assert_select "img", count: 0
      assert_select "a", count: 0
    end
  end

  test "escapes product content and preserves long names" do
    name = "<script>alert(1)</script>" + "ชื่อสินค้าที่ยาวมาก" * 30
    @lot = @lot.with(name: name)
    card
    assert_select "script", count: 0
    assert_select "h3", text: name
  end

  test "rejects unknown auction type or status" do
    error = assert_raises(ActionView::Template::Error) { card(auction_type: "unknown") }
    assert_kind_of KeyError, error.cause
    error = assert_raises(ActionView::Template::Error) { card(status: :unknown) }
    assert_kind_of KeyError, error.cause
  end

  test "shows supplied starting price in baht without inventing missing prices" do
    card(min_price_cents: 1_234_567)
    assert_select ".catalog-card__price", "12,345.67 ฿"
    card
    assert_select ".catalog-card__price", count: 0
  end

  private
    def card(**options)
      render partial: "catalog/card", locals: {
        lot: @lot, status: :ongoing, auction_type: "english",
        image_path: nil, detail_path: nil
      }.merge(options)
    end
end
