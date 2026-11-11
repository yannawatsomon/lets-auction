# Bidding milestone: names and boundaries
Last verified: 2026-11-11

## Summary

Everything the bidding milestone (#27–#37) adds to the web app is named `bidding`, so it
can't clash with other milestones (catalog, product onboarding, user onboarding, payment).

## Details

| Kind | Bidding uses | Example |
|---|---|---|
| URLs | `/bidding/...` (buyers), `/admin/bidding/...` (admins) | `/bidding/auctions/5`, `/admin/bidding/auctions/new` |
| Route helpers | `bidding_*`, `admin_bidding_*` | `bidding_auction_path`, `admin_bidding_auction_lots_path` |
| Controllers | `Bidding::`, `Admin::Bidding::` (base: `Admin::Bidding::BaseController`) | `Bidding::InvitationsController` |
| Views | `app/views/bidding/`, `app/views/admin/bidding/` | |
| Layouts | `bidding` (buyers), `bidding_admin` | `<body class="bidding">` |
| CSS | `app/assets/stylesheets/bidding.css`; tokens `--bidding-*` on `.bidding`; classes `bidding-<block>`, `bidding-<block>--<modifier>`, `bidding-<block>__<part>` | `bidding-btn bidding-btn--primary` |
| Helpers | `BiddingHelper`, methods `bidding_*` (Rails shares helpers across all views) | `bidding_baht(cents)`, `bidding_time(t)` |
| Flash partial | `bidding/_flash` | |

Shared domain models keep plain names because other milestones read them: `Auction`,
`AuctionLot`, `AuctionParticipant`, `Baht`, `AuctionItems`. The catalog (#63) reuses
`Auction.auction_types` and can reuse `BiddingHelper::TYPE_LABELS` for display labels.

## Feeding the catalog

`Bidding::CatalogFeed.call(viewer: current_user)` (`app/services/bidding/catalog_feed.rb`)
returns real auction lots with the same readers as `Catalog::DemoLots::Lot` (`id`, `name`,
`category`, `auction_type`, `starts_at`, `ends_at`) plus `min_price_cents` (public, for
Highlights) and `detail_path` (`/bidding/auctions/:id`, pass it to `catalog/_card` as
`detail_path:`). To switch the catalog to real data, the catalog team replaces
`Catalog::DemoLots.call(now: @now)` in `CatalogPage#prepare_catalog` with it; bidding doesn't
edit catalog code.

- Shown: lots of sealed auctions that are `scheduled`, `live`, `awaiting_approval` or
  `published`; English lots only to admins and invited buyers (their pages are 404 otherwise).
- Never shown: drafts, cancelled auctions or lots, bid amounts, bid counts, participants.
- Lot ids are bidding's own; don't mix the feed with `DemoLots` in one list (ids can collide).
- Times are the auction's: lots never extend (`bidding.md`).

## Gotchas

- `application.css` (the generic `.topbar`, `.btn`, `.card`… from #28) and
  `shared/_flash` / `MoneyHelper#baht` are **shared**: product onboarding builds on them.
  Bidding pages no longer use them (they use `bidding.css`), but don't delete or rename them.

- Propshaft's `stylesheet_link_tag :app` loads **every** file in `app/assets/stylesheets` on
  **every** page. Never put unscoped selectors (`body`, `.card`, `.btn`, `:root` tokens) in
  `bidding.css`; scope under `.bidding` or prefix with `bidding-`.
- The mock login (`/mock-login`) is shared by milestones (product onboarding also serves it in
  production, sellers only, behind `MOCK_PRODUCT_ONBOARDING`), so it keeps the shared look;
  only the admin redirect points at `/admin/bidding/auctions`. See `mock-data.md`.

## References

- `docs/decision/bidding.md`, `ai/knowledge/mock-data.md`
