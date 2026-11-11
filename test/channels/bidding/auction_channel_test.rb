require "test_helper"

class Bidding::AuctionChannelTest < ActionCable::Channel::TestCase
  include ActionCable::TestHelper

  ADMIN = MockData.user(1)
  A = MockData.user(21)

  setup do
    OnboardingStore.reset!
    BuyerStanding.reset!
    ProductOnboarding::Store.reset!
  end

  def english
    a = Auction.create!(title: "E", auction_type: "english", starts_at: 1.hour.from_now, ends_at: 1.day.from_now, created_by_id: 1)
    lot = a.add_item!(MockData.approved_items.max_by(&:min_price_cents), bid_increment_cents: 20_000_000)
    a.schedule!
    [ a, lot ]
  end

  def sealed
    a = Auction.create!(title: "S", auction_type: "sealed_first_price", starts_at: 1.hour.from_now, ends_at: 1.day.from_now, created_by_id: 1)
    lot = a.add_item!(MockData.approved_items.min_by(&:min_price_cents))
    a.schedule!
    [ a, lot ]
  end

  test "guests and buyers who aren't participants are rejected" do
    a, = english
    stub_connection current_user: nil
    subscribe auction_id: a.id
    assert subscription.rejected?

    stub_connection current_user: MockData.user(23)
    subscribe auction_id: a.id
    assert subscription.rejected?
  end

  test "an invited buyer who hasn't accepted is rejected; after accepting they get lot.state" do
    a, lot = english
    inv = AuctionParticipant.invite!(auction: a, user: A, admin: ADMIN)
    stub_connection current_user: A
    subscribe auction_id: a.id
    assert subscription.rejected?

    inv.accept!(user: A)
    subscribe auction_id: a.id
    assert subscription.confirmed?
    assert_has_stream "bidding:auction:#{a.id}"
    assert_has_stream "bidding:auction:#{a.id}:user:#{A.id}"
    state = transmissions.last
    assert_equal "lot.state", state["type"]
    assert state["server_time"].present?
    assert_equal lot.id, state["lots"].first["id"]
    assert_equal lot.next_minimum_cents, state["lots"].first["next_minimum_cents"]
  end

  test "admins can watch any scheduled auction" do
    a, = sealed
    stub_connection current_user: ADMIN
    subscribe auction_id: a.id
    assert subscription.confirmed?
  end

  test "sealed lot.state carries no bid information" do
    a, lot = sealed
    AuctionParticipant.register!(auction: a, user: MockData.user(23))
    stub_connection current_user: MockData.user(23)
    subscribe auction_id: a.id
    entry = transmissions.last["lots"].first
    assert_equal %w[ends_at id lot_no min_price_cents status], entry.keys.sort
    assert_equal lot.id, entry["id"]
  end
end
