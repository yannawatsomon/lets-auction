require "test_helper"
require_relative "../../models/product_onboarding/support"

class ProductOnboardingWizardTest < ActionDispatch::IntegrationTest
  include ProductOnboardingTestSupport

  UploadStore = ProductOnboarding::UploadStore
  Store = ProductOnboarding::Store

  setup { UploadStore.reset! }

  def login(id) = post(mock_session_path(user_id: id))

  # A file that finished uploading, as the wizard's JavaScript leaves it.
  def uploaded(kind = "image", seller_id: 11)
    type = ProductOnboardingTestSupport::CONTENT_TYPES.fetch(kind)
    upload = UploadStore.issue!(seller_id: seller_id, kind: kind, filename: "#{kind}.bin", content_type: type, size: 100)
    UploadStore.receive!(upload.key, seller_id: seller_id, content_type: type, byte_size: 100)
    upload.key
  end

  def submit(keys:, **item)
    post product_onboarding_items_path,
      params: { item: { title: "Pocket watch", category: "นาฬิกา", description: "Silver, working", price: "85,000.50" }.merge(item),
                upload_keys: keys }
  end

  test "only sellers see the form" do
    get new_product_onboarding_item_path
    assert_response :not_found
    [ 21, 1 ].each do |id|
      login(id)
      get new_product_onboarding_item_path
      assert_response :not_found
      submit(keys: [])
      assert_response :not_found
    end
  end

  test "a seller sees the four steps and the add link on the page" do
    login(11)
    get product_onboarding_root_path
    assert_select "a[href=?]", new_product_onboarding_item_path

    get new_product_onboarding_item_path
    assert_response :success
    assert_select "fieldset[data-product-wizard-target=step]", count: 4
    assert_select "input[name='item[price]']"
  end

  test "submitting creates a pending product with the files in order and the price in satang" do
    login(11)
    first = uploaded
    second = uploaded
    doc = uploaded("document")

    assert_difference -> { Store.all.size }, 1 do
      submit(keys: [ second, first, doc ])
    end

    assert_redirected_to product_onboarding_root_path
    item = Store.all.last
    assert item.pending_review?
    assert_equal 8_500_050, item.min_price_cents
    assert_equal 11, item.seller_id
    assert_equal [ second, first, doc ], item.media.map(&:key)
    assert_equal second, item.cover.key
    assert UploadStore.find(first).attached
  end

  test "a product without images or with a bad price is refused and keeps what was typed" do
    login(11)
    video = uploaded("video")

    assert_no_difference -> { Store.all.size } do
      submit(keys: [ video ])
      assert_response :unprocessable_content
      assert_select ".flash.alert", text: /Add 1 to 5 images/

      submit(keys: [ uploaded ], price: "abc", title: "Kept title")
      assert_response :unprocessable_content
      assert_select ".flash.alert", text: /ราคาขั้นต่ำ/
      assert_select "input[name='item[title]'][value=?]", "Kept title"
    end
  end

  test "files that have not finished uploading or belong to someone else are refused" do
    login(11)
    unfinished = UploadStore.issue!(seller_id: 11, kind: "image", filename: "a.jpg", content_type: "image/jpeg", size: 100).key
    theirs = uploaded("image", seller_id: 12)

    assert_no_difference -> { Store.all.size } do
      submit(keys: [ unfinished ])
      assert_response :unprocessable_content
      submit(keys: [ theirs ])
      assert_response :not_found
    end
    assert_not UploadStore.find(theirs).attached
  end
end
