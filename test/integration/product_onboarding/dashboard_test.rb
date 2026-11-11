require "test_helper"
require_relative "../../models/product_onboarding/support"

class ProductOnboardingDashboardTest < ActionDispatch::IntegrationTest
  include ProductOnboardingTestSupport

  Store = ProductOnboarding::Store
  UploadStore = ProductOnboarding::UploadStore

  # Seeded in db/mock/product_items.yml: 201 pending (seller 11), 202 info requested (11), 203 approved (12).
  PENDING = 201
  INFO_REQUESTED = 202
  APPROVED = 203

  setup { UploadStore.reset! }

  def login(id) = post(mock_session_path(user_id: id))

  def uploaded(kind = "image", seller_id: 11)
    type = ProductOnboardingTestSupport::CONTENT_TYPES.fetch(kind)
    upload = UploadStore.issue!(seller_id: seller_id, kind: kind, filename: "#{kind}.bin", content_type: type, size: 100)
    UploadStore.receive!(upload.key, seller_id: seller_id, content_type: type, byte_size: 100)
    upload.key
  end

  def update(id, keys:, **item)
    patch product_onboarding_item_path(id),
      params: { item: { title: "Edited title", category: "นาฬิกา", description: "Edited", price: "90,000" }.merge(item), upload_keys: keys }
  end

  test "a seller sees only their own products, with the actions each status allows" do
    login(11)
    get product_onboarding_root_path

    assert_select "table.list tbody tr", count: 2
    assert_select "td", text: /Vintage dress watch/
    assert_select "td", text: /Oil painting/, count: 0
    assert_select "a[href=?]", edit_product_onboarding_item_path(PENDING)
    assert_select "form[action=?]", resubmit_product_onboarding_item_path(INFO_REQUESTED)
    assert_select "form[action=?]", resubmit_product_onboarding_item_path(PENDING), count: 0
  end

  test "another seller's, a buyer's or a guest's request is 404 and changes nothing" do
    login(12)
    get edit_product_onboarding_item_path(PENDING)
    assert_response :not_found
    update(PENDING, keys: [ uploaded("image", seller_id: 12) ])
    assert_response :not_found
    post resubmit_product_onboarding_item_path(INFO_REQUESTED)
    assert_response :not_found
    delete product_onboarding_item_path(PENDING)
    assert_response :not_found

    login(21)
    delete product_onboarding_item_path(PENDING)
    assert_response :not_found
    assert_equal %w[pending_review info_requested], [ Store.find(PENDING), Store.find(INFO_REQUESTED) ].map(&:status)
    assert_equal "Vintage dress watch, 1972 (sample)", Store.find(PENDING).title
  end

  test "the edit form is filled with the product's details and files" do
    login(11)
    get edit_product_onboarding_item_path(PENDING)

    assert_response :success
    assert_select "input[name='item[title]'][value=?]", "Vintage dress watch, 1972 (sample)"
    assert_select "input[name='item[price]'][value=?]", "85,000.00"
    assert_select "form[data-product-wizard-existing-value*=?]", "mock-201-image-1"
  end

  test "saving an edit changes the details, keeps old files and adds new ones in order" do
    login(11)
    item = Store.find(PENDING)
    kept = item.media.select { |file| file.kind == "image" }.last.key
    added = uploaded

    update(PENDING, keys: [ added, kept ])

    assert_redirected_to product_onboarding_root_path
    assert_equal "Edited title", item.title
    assert_equal 9_000_000, item.min_price_cents
    assert_equal [ added, kept ], item.media.map(&:key)
    assert UploadStore.find(added).attached
    assert item.pending_review?
  end

  test "an invalid edit is refused, keeps what was typed and changes nothing" do
    login(11)
    item = Store.find(PENDING)
    before = [ item.title, item.media.map(&:key) ]

    update(PENDING, keys: [], title: "Kept title")

    assert_response :unprocessable_content
    assert_select ".flash.alert", text: /Add 1 to 5 images/
    assert_select "input[name='item[title]'][value=?]", "Kept title"
    assert_equal before, [ item.title, item.media.map(&:key) ]
  end

  test "an approved product cannot be edited" do
    login(12)
    get edit_product_onboarding_item_path(APPROVED)
    assert_redirected_to product_onboarding_root_path
    update(APPROVED, keys: [ uploaded("image", seller_id: 12) ])

    assert_redirected_to product_onboarding_root_path
    assert_not_equal "Edited title", Store.find(APPROVED).title
  end

  test "resubmit sends a product the admin asked about back to review, and only that" do
    login(11)
    post resubmit_product_onboarding_item_path(INFO_REQUESTED)
    assert Store.find(INFO_REQUESTED).pending_review?

    post resubmit_product_onboarding_item_path(PENDING)
    assert_redirected_to product_onboarding_root_path
    assert_equal "ทำรายการนี้ไม่ได้ในสถานะปัจจุบันของสินค้า", flash[:alert]
    assert Store.find(PENDING).pending_review?
  end

  test "withdraw works until the product is in an auction" do
    login(11)
    delete product_onboarding_item_path(PENDING)
    assert Store.find(PENDING).withdrawn?

    Store.find(INFO_REQUESTED).tap { |item| item.status = "in_auction" }
    delete product_onboarding_item_path(INFO_REQUESTED)
    assert_equal "in_auction", Store.find(INFO_REQUESTED).status
    assert flash[:alert].present?

    login(12)
    delete product_onboarding_item_path(APPROVED)
    assert Store.find(APPROVED).withdrawn?
  end
end
