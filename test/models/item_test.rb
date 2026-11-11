require "test_helper"

class ItemTest < ActiveSupport::TestCase
  setup do
    @item = Item.create!(
      seller: users(:seller), category: categories(:watches),
      title: "Rare watch", description: "Boxed, 1970s", min_price_cents: 100_000
    )
  end

  def image_count = @item.item_media.where(kind: "image").count

  # --- media limits ---

  test "accepts 1 to 5 images" do
    (1..5).each do |n|
      @item.sync_media!(media_entries(images: n))
      assert_equal n, image_count
    end
  end

  test "rejects a sixth image and keeps the existing five" do
    @item.sync_media!(media_entries(images: 5))

    assert_raises(ActiveRecord::RecordInvalid) { @item.sync_media!(media_entries(images: 6)) }
    assert_equal 5, image_count
  end

  test "rejects zero images" do
    assert_raises(ActiveRecord::RecordInvalid) { @item.sync_media!(media_entries(images: 0)) }
    assert_equal 0, @item.item_media.count
  end

  test "allows zero videos and two videos" do
    @item.sync_media!(media_entries(images: 1, videos: 0))
    @item.sync_media!(media_entries(images: 1, videos: 2))
    assert_equal 2, @item.item_media.where(kind: "video").count
  end

  test "rejects a third video" do
    assert_raises(ActiveRecord::RecordInvalid) { @item.sync_media!(media_entries(images: 1, videos: 3)) }
  end

  test "rejects an unknown media kind" do
    entries = media_entries(images: 1) + [ { kind: "audio", signed_id: new_blob.signed_id } ]
    assert_raises(ActiveRecord::RecordInvalid) { @item.sync_media!(entries) }
  end

  test "rejects the same file listed twice" do
    entry = media_entries(images: 1).first
    assert_raises(ActiveRecord::RecordInvalid) { @item.sync_media!([ entry, entry ]) }
  end

  test "keeps files that stay in the list and does not delete their blobs" do
    first = media_entries(images: 1).first
    @item.sync_media!([ first ])
    medium = @item.item_media.first

    @item.sync_media!([ first ] + media_entries(images: 1))

    assert_equal 2, image_count
    assert @item.item_media.exists?(medium.id)
    assert ActiveStorage::Blob.exists?(medium.file.blob.id)
  end

  test "orders media by position in the list, first image is the cover" do
    entries = media_entries(images: 3)
    @item.sync_media!(entries)
    @item.sync_media!(entries.reverse)

    cover = @item.item_media.order(:sort_order).first
    assert_equal entries.last[:signed_id], cover.file.blob.signed_id
  end

  # --- minimum price ---

  test "min price must be a positive whole number of satang" do
    [ 0, -1, nil, "abc", "1.5" ].each do |bad|
      item = @item.dup.tap { |i| i.min_price_cents = bad }
      assert_not item.valid?, "expected #{bad.inspect} to be invalid"
      assert item.errors[:min_price_cents].any?
    end
  end

  test "min price above the bigint range is invalid, not a crash" do
    item = @item.dup.tap { |i| i.min_price_cents = 2**63 }
    assert_not item.valid?
  end

  test "database rejects min price 0 even if validations are bypassed" do
    assert_raises(ActiveRecord::CheckViolation) { @item.update_column(:min_price_cents, 0) }
  end

  # --- seller ---

  test "only a seller account can own an item" do
    item = @item.dup.tap { |i| i.seller = users(:buyer) }
    assert_not item.valid?
    assert item.errors[:seller].any?
  end

  # --- status ---

  test "a new item is pending_review" do
    assert @item.pending_review?
  end

  test "editable only in pending_review or info_requested" do
    Item.statuses.each_key do |status|
      @item.status = status
      assert_equal %w[pending_review info_requested].include?(status), @item.editable?, status
    end
  end

  test "transition! follows the allowed transitions" do
    @item.transition!(:info_requested)
    @item.transition!(:pending_review)
    @item.transition!(:approved)
    @item.transition!(:in_auction)
    @item.transition!(:approved)
    @item.transition!(:withdrawn)
    assert @item.withdrawn?
  end

  test "transition! raises on a move that is not allowed and leaves the status alone" do
    @item.transition!(:approved)

    assert_raises(Item::InvalidTransition) { @item.transition!(:pending_review) }
    assert @item.reload.approved?
  end

  test "rejected, sold and withdrawn are final" do
    %w[rejected sold withdrawn].each do |final|
      @item.update_column(:status, final)
      Item.statuses.each_key do |target|
        assert_raises(Item::InvalidTransition, "#{final} -> #{target}") { @item.transition!(target) }
      end
    end
  end

  test "an item in an auction cannot be withdrawn" do
    @item.update_column(:status, "in_auction")
    assert_raises(Item::InvalidTransition) { @item.transition!(:withdrawn) }
  end
end
