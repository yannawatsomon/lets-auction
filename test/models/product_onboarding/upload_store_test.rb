require "test_helper"

class ProductOnboardingUploadStoreTest < ActiveSupport::TestCase
  Store = ProductOnboarding::UploadStore
  Policy = ProductOnboarding::UploadPolicy

  setup { Store.reset! }

  def issue(seller_id: 11, **overrides)
    Store.issue!(seller_id: seller_id, **{ kind: "image", filename: "a.jpg", content_type: "image/jpeg", size: 1_000 }.merge(overrides))
  end

  def receive(upload, seller_id: 11, content_type: "image/jpeg", byte_size: 1_000)
    Store.receive!(upload.key, seller_id: seller_id, content_type: content_type, byte_size: byte_size)
  end

  test "issue! returns a unique key, keeps only the file name, and stores nothing when the policy rejects" do
    first = issue(filename: "../../etc/a.jpg")

    assert_not_equal first.key, issue.key
    assert_equal "a.jpg", first.filename
    assert_no_difference -> { Store.all.size } do
      assert_raises(Policy::Rejected) { issue(content_type: "text/html") }
    end
  end

  test "receive! marks the file uploaded only when type and size match what was declared" do
    upload = issue
    assert_raises(Policy::Rejected) { receive(upload, content_type: "text/html") }
    assert_raises(Policy::Rejected) { receive(upload, byte_size: 999) }
    assert_not Store.find(upload.key).uploaded

    receive(upload)
    assert Store.find(upload.key).uploaded
  end

  test "another seller or an unknown key is not found" do
    upload = issue
    assert_raises(ProductOnboarding::NotFound) { receive(upload, seller_id: 12) }
    assert_raises(ProductOnboarding::NotFound) { Store.receive!("nope", seller_id: 11, content_type: "image/jpeg", byte_size: 1) }
  end

  test "attach! needs uploaded files and is all or nothing" do
    mine = issue
    theirs = issue(seller_id: 12)
    assert_raises(Policy::Rejected) { Store.attach!([ mine.key ], seller_id: 11) }

    receive(mine)
    assert_raises(ProductOnboarding::NotFound) { Store.attach!([ mine.key, theirs.key ], seller_id: 11) }
    assert_not Store.find(mine.key).attached

    Store.attach!([ mine.key ], seller_id: 11)
    assert Store.find(mine.key).attached
  end

  test "purge_orphans! removes unattached files older than 48 hours and keeps the rest" do
    orphan = issue
    attached = issue
    receive(attached)
    Store.attach!([ attached.key ], seller_id: 11)

    travel_to(49.hours.from_now) do
      young = issue
      assert_equal 1, Store.purge_orphans!

      assert_nil Store.find(orphan.key)
      assert Store.find(attached.key)
      assert Store.find(young.key)
    end
  end
end
