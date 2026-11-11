module Bidding
  # Real auction lots for the product catalog, in the shape `Catalog::Filters#sections` and
  # `catalog/_card` already take (same readers as `Catalog::DemoLots::Lot`), plus a link to the
  # bidding page. The catalog team swaps `Catalog::DemoLots.call(now:)` for
  # `Bidding::CatalogFeed.call(viewer: current_user)` when they're ready; bidding doesn't edit
  # catalog code. See ai/knowledge/bidding-conventions.md.
  #
  # Only public facts leave bidding: titles, category, type, times, the seller's minimum price
  # and the page link. Never bid amounts, bid counts or participants (bidding.md: sealed bids
  # stay secret until results are published).
  class CatalogFeed
    Lot = Data.define(:id, :name, :category, :auction_type, :starts_at, :ends_at, :min_price_cents, :detail_path)

    VISIBLE_STATUSES = %w[scheduled live awaiting_approval published].freeze
    UNCATEGORISED = "อื่นๆ"
    LIMIT = 500

    # viewer: the logged-in user or nil. Sealed auctions are public once published by the admin;
    # English (invite-only) lots show only to invited buyers and admins, like their pages.
    def self.call(viewer: nil) = new(viewer).lots

    def initialize(viewer)
      @viewer = viewer
    end

    def lots
      rows = AuctionLot.joins(:auction).includes(:auction)
        .where(auctions: { status: VISIBLE_STATUSES })
        .where.not(status: "cancelled")
        .order(:id).limit(LIMIT)
      rows.select { |lot| visible?(lot.auction) }.map { |lot| to_catalog(lot) }
    end

    private

    def visible?(auction)
      return true if auction.sealed_first_price?
      return true if @viewer&.admin?

      invited_auction_ids.include?(auction.id)
    end

    def invited_auction_ids
      @invited_auction_ids ||= if @viewer
        AuctionParticipant.where(user_id: @viewer.id).where.not(status: "revoked").pluck(:auction_id).to_set
      else
        Set.new
      end
    end

    def to_catalog(lot)
      item = lot.item
      Lot.new(
        id: lot.id,
        name: item&.title || "สินค้า ##{lot.item_id}",
        category: item&.category.presence || UNCATEGORISED,
        auction_type: lot.auction.auction_type,
        starts_at: lot.auction.starts_at,
        ends_at: lot.auction.ends_at,
        min_price_cents: lot.min_price_cents,
        detail_path: Rails.application.routes.url_helpers.bidding_auction_path(lot.auction_id)
      )
    end
  end
end
