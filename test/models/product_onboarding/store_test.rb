require "test_helper"
require_relative "support"

class ProductOnboardingStoreTest < ActiveSupport::TestCase
  include ProductOnboardingTestSupport

  Store = ProductOnboarding::Store

  test "mock data has one product in each state a seller sees before and after verification" do
    assert_equal %w[approved info_requested pending_review], Store.all.map(&:status).sort
  end

  test "every mock product is valid, owned by a mock seller and within the media limits" do
    Store.all.each do |item|
      assert item.valid?, "#{item.id}: #{item.errors.full_messages.to_sentence}"
      assert item.media_count("image").between?(1, 5), "#{item.id}: images"
      assert_operator item.media_count("video"), :<=, 2
    end
  end

  test "find returns a product by id and nil for an unknown id, find! raises" do
    first = Store.all.first

    assert_equal first, Store.find(first.id)
    assert_nil Store.find(999_999)
    assert_raises(ProductOnboarding::NotFound) { Store.find!(999_999) }
  end

  test "create! stores a new product as pending_review with the next id" do
    item = Store.create!({ seller_id: 11, category: "ศิลปะ", title: "Print", description: "Signed", min_price_cents: 50_000 },
                         media: media_entries(images: 2))

    assert item.pending_review?
    assert_equal item, Store.find(item.id)
    assert_equal 2, item.media_count("image")
    assert_equal Store.all.map(&:id).uniq.size, Store.all.size
  end

  test "create! with no images raises and stores nothing" do
    assert_no_difference -> { Store.all.size } do
      assert_raises(ActiveModel::ValidationError) do
        Store.create!({ seller_id: 11, category: "ศิลปะ", title: "Print", description: "Signed", min_price_cents: 50_000 },
                      media: [])
      end
    end
  end

  test "create! with an invalid price raises and stores nothing" do
    assert_no_difference -> { Store.all.size } do
      assert_raises(ActiveModel::ValidationError) do
        Store.create!({ seller_id: 11, category: "ศิลปะ", title: "Print", description: "Signed", min_price_cents: 0 },
                      media: media_entries)
      end
    end
  end

  test "for_seller returns only that seller's products and can filter by status" do
    mine = Store.for_seller(11)

    assert mine.any?
    assert mine.all? { |item| item.seller_id == 11 }
    assert_equal [ "info_requested" ], Store.for_seller(11, status: "info_requested").map(&:status)
    assert_empty Store.for_seller(21)
  end

  test "approved returns only approved products, readable like MockData items" do
    approved = Store.approved

    assert approved.any?
    assert approved.all?(&:approved?)
    assert_equal %i[id seller_id category title min_price_cents status], MockData::Item.members
    approved.each { |item| MockData::Item.members.each { |member| assert_respond_to item, member } }
  end

  test "reset! discards changes" do
    item = Store.all.first
    item.transition!(:withdrawn) if item.pending_review?
    Store.reset!

    assert_equal %w[approved info_requested pending_review], Store.all.map(&:status).sort
  end
end
