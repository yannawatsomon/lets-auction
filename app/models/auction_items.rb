# The one place bidding reads products from (issue #28 follow-up, 2026-11-11).
#
# Products come from product onboarding's store (`ProductOnboarding::Store`, ids 201+): an item
# an admin approves there shows up in "Add สินค้าเข้างาน". Bidding's own demo products
# (`db/mock/items.yml`, ids 101–108, incl. the ฿20M+ English items) stay as extra mock stock
# until real data exists. When the `items` table lands, this module becomes `Item.approved` /
# `Item.find_by` (see ai/knowledge/mock-data.md).
#
# Status follows product onboarding's rules: `approved` → `in_auction` when its auction is
# scheduled, `in_auction` → `approved` when the auction is cancelled or the lot ends unsold.
# Only store items change status; the YAML demo items are read-only.
module AuctionItems
  module_function

  def approved = ProductOnboarding::Store.approved + MockData.approved_items

  def find(id) = ProductOnboarding::Store.find(id) || MockData.item(id)

  def seller(item) = item && MockData.user(item.seller_id)

  def mark_in_auction!(item) = transition(item, from: "approved", to: "in_auction")

  def release!(item) = transition(item, from: "in_auction", to: "approved")

  def transition(item, from:, to:)
    return unless item.respond_to?(:transition!)
    return unless item.status == from

    item.transition!(to)
  end
end
