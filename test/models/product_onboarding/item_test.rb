require "test_helper"
require_relative "support"

class ProductOnboardingItemTest < ActiveSupport::TestCase
  include ProductOnboardingTestSupport

  setup { @item = build_item }

  # --- media limits ---

  test "accepts 1 to 5 images" do
    (1..5).each do |n|
      @item.sync_media!(media_entries(images: n))
      assert_equal n, @item.media_count("image")
    end
  end

  test "rejects a sixth image and keeps the existing five" do
    @item.sync_media!(media_entries(images: 5))

    assert_raises(ActiveModel::ValidationError) { @item.sync_media!(media_entries(images: 6)) }
    assert_equal 5, @item.media_count("image")
  end

  test "rejects zero images" do
    assert_raises(ActiveModel::ValidationError) { @item.sync_media!(media_entries(images: 0)) }
    assert_empty @item.media
  end

  test "allows zero videos and two videos" do
    @item.sync_media!(media_entries(images: 1, videos: 0))
    @item.sync_media!(media_entries(images: 1, videos: 2))
    assert_equal 2, @item.media_count("video")
  end

  test "rejects a third video" do
    assert_raises(ActiveModel::ValidationError) { @item.sync_media!(media_entries(images: 1, videos: 3)) }
  end

  test "does not limit documents yet" do
    @item.sync_media!(media_entries(images: 1, documents: 12))
    assert_equal 12, @item.media_count("document")
  end

  test "rejects an unknown media kind" do
    entries = media_entries(images: 1) + [ media_entry("audio") ]
    assert_raises(ActiveModel::ValidationError) { @item.sync_media!(entries) }
  end

  test "rejects the same file listed twice" do
    entry = media_entry
    assert_raises(ActiveModel::ValidationError) { @item.sync_media!([ entry, entry ]) }
  end

  test "keeps the new list order and the first image is the cover" do
    entries = media_entries(images: 3)
    @item.sync_media!(entries)
    @item.sync_media!(entries.reverse)

    assert_equal entries.reverse.pluck(:key), @item.media.map(&:key)
    assert_equal entries.last[:key], @item.cover.key
  end

  test "media is read-only from outside" do
    @item.sync_media!(media_entries(images: 1))
    assert_raises(FrozenError) { @item.media << :x }
  end

  test "add_media! appends one file and refuses a sixth image or a third video" do
    @item.sync_media!(media_entries(images: 4))
    @item.add_media!(media_entry("image"))
    assert_equal 5, @item.media_count("image")
    assert_raises(ActiveModel::ValidationError) { @item.add_media!(media_entry("image")) }

    @item.add_media!(media_entry("video"))
    @item.add_media!(media_entry("video"))
    assert_raises(ActiveModel::ValidationError) { @item.add_media!(media_entry("video")) }
    assert_equal 5, @item.media_count("image")
    assert_equal 2, @item.media_count("video")
  end

  # --- minimum price ---

  test "min price must be a positive whole number of satang" do
    [ 0, -1, nil, "abc", "1.5", 1.5 ].each do |bad|
      item = build_item(min_price_cents: bad)
      assert_not item.valid?, "expected #{bad.inspect} to be invalid"
      assert item.errors[:min_price_cents].any?
    end
  end

  test "min price above the bigint range is invalid" do
    assert_not build_item(min_price_cents: 2**63).valid?
  end

  test "min price accepts an integer or a digit string" do
    assert build_item(min_price_cents: 100_000).valid?
    assert_equal 100_000, build_item(min_price_cents: "100000").min_price_cents
  end

  # --- details and seller ---

  test "title, description and category are required" do
    %i[title description category].each do |field|
      assert_not build_item(field => " ").valid?, field.to_s
    end
  end

  test "only a mock seller account can own an item" do
    assert_not build_item(seller_id: 21).valid?, "buyer"
    assert_not build_item(seller_id: 1).valid?, "admin"
    assert_not build_item(seller_id: 999).valid?, "unknown user"
    assert build_item(seller_id: 12).valid?
  end

  # --- status ---

  test "a new item is pending_review" do
    assert @item.pending_review?
  end

  test "editable only in pending_review or info_requested" do
    ProductOnboarding::Item::STATUSES.each do |status|
      item = build_item(status: status)
      assert_equal %w[pending_review info_requested].include?(status), item.editable?, status
    end
  end

  test "transition! follows the allowed transitions" do
    %i[info_requested pending_review approved in_auction approved withdrawn].each { |to| @item.transition!(to) }
    assert @item.withdrawn?
  end

  test "transition! raises on a move that is not allowed and leaves the status alone" do
    @item.transition!(:approved)

    assert_raises(ProductOnboarding::Item::InvalidTransition) { @item.transition!(:pending_review) }
    assert @item.approved?
  end

  test "rejected, sold and withdrawn are final" do
    %w[rejected sold withdrawn].each do |final|
      item = build_item(status: final)
      ProductOnboarding::Item::STATUSES.each do |target|
        assert_raises(ProductOnboarding::Item::InvalidTransition, "#{final} -> #{target}") { item.transition!(target) }
      end
    end
  end

  test "an item in an auction cannot be withdrawn" do
    assert_raises(ProductOnboarding::Item::InvalidTransition) { build_item(status: "in_auction").transition!(:withdrawn) }
  end

  test "an unknown status is invalid" do
    assert_not build_item(status: "lost").valid?
  end

  # --- review history ---

  test "record_review! appends to the history in order and returns the review" do
    first = @item.record_review!(admin_id: 1, action: "request_info", note: "Add the serial number")
    second = @item.record_review!(admin_id: 2, action: "approve")

    assert_equal [ first, second ], @item.reviews
    assert_raises(FrozenError) { @item.reviews << :x }
  end

  test "record_review! does not store an invalid review" do
    assert_raises(ActiveModel::ValidationError) { @item.record_review!(admin_id: 1, action: "reject") }
    assert_empty @item.reviews
  end
end
