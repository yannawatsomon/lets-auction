# Catalog sections service

Last verified: 2026-11-11

## Contract

`Catalog::Sections.call(lots:, now:)` returns arrays under ordered keys
`ongoing`, `upcoming`, and `ended`. It accepts objects exposing unique integer
`id`, `starts_at`, and `ends_at`, using Time-compatible timestamps. The caller
supplies one server timestamp and the latest effective lot closing time.

## Integration boundaries

- This service does not load records, filter visibility, or authorize requests.
  Supply only eligible lots after applying viewer access and draft/cancelled rules.
- Use the provider's start/closing timestamps when integrating real inventory. Current
  `AuctionLot` delegates both to `Auction`; English extensions have been removed by the
  bidding decision. Do not recreate extension columns for Catalog.
- Missing or malformed timestamps, duplicate/non-integer IDs, and invalid intervals
  raise `ArgumentError`. Do not feed unscheduled lots into the service.
- The service sorts in memory. Paginating inputs before grouping would produce
  incorrect section ordering/counts; future database integration must account for this.
- #39 remains incomplete until data loading and page integration exist.

## References

- [Approved service design](../../docs/specs/2026-11-11-catalog-sections-design.md)
- [Implementation](../../app/services/catalog/sections.rb)

## Temporary development preview

The homepage `/` now renders the same catalog page through `catalog/page` and the
`CatalogPage` controller concern. Home filter submissions and clear links use `/`;
the development preview keeps its own URL. `Catalog::DemoLots.call(now:)` returns
synthetic inventory in local environments and, temporarily, in production by default
at the user's request. `CATALOG_DEMO=false` disables the production demo and restores
empty sections with no demo banner. This does not enable login or bidding.

Demo inventory contains 45 synthetic lots, initially 15 per status at its fixed fixture
anchor. Overview shows one responsive row per section; listings start with up to 12 per
section. Counts change as server time advances through the schedule.

## Independent Load more

The latest reference redesign changes the homepage into an overview: three cards are
rendered per status, with CSS showing only two at <=900px and one at <=600px. Extra
overview cards use `display:none`, including their interactive children. Matching counts
still represent the complete result set. “ดูเพิ่มเติม” links to `/catalog` with the chosen
status and all other filters, resetting counters. `/catalog` keeps the 12-item cumulative
pagination described below; homepage requests no longer expand section rows.

The reference is the user-supplied `auction-redesign.html`: cream/white/ink/gold styling,
Google-hosted IBM Plex Sans Thai and Inter with system fallbacks, metadata dividers and
starting-price footers. Demo prices are integer satang and use `Baht.format`. Cards with
no detail URL use a native read-only `<dialog>` via `catalog-detail` Stimulus; callers with
real data must supply an authorized detail URL. All demo labels remain explicit.

If a long-running dev server predates a new autoload directory such as `app/lib`, restart
it after updating the checkout; otherwise new constants can fail despite fresh test runs passing.

`Catalog::Pagination` accepts `ongoing_page`, `upcoming_page`, and `ended_page` as
decimal strings from 1 through 100; missing values start at 1. Counters are cumulative:
page 2 displays the first 24 matching lots, not a replacement page. Filtering and
sorting happen before slicing. The shared view retains full section totals separately.

Load more is a normal GET link that preserves all seven filter fields and other section
counters, with a section anchor. Filter submissions do not carry page counters, so they
reset all sections. At 100 pages, users are prompted to narrow filters if more items remain.

Inventory providers may raise `Catalog::InventoryUnavailable` for a transient outage.
The shared page returns HTTP 503, suppresses result counts, and offers a retry preserving
filters/counters. Other exceptions are not swallowed. This is a server-side inventory
failure path; total network loss still uses normal browser navigation recovery.

Tests that temporarily set `Rails.env = "production"` must first call
`Rails.application.reload_routes_unless_loaded`. Otherwise lazy route loading can build
production routes in a test worker, removing mock-login helpers from later tests.

`/catalog-preview` renders the same responsive overview through the real sections service.
The route and controller are restricted to development and do not persist data.
Sample times are fixed relative to `Catalog::DemoLots::SCHEDULE_ANCHOR`
(`2026-11-11T16:00:00Z`) and identical across requests/workers. The fixture naturally
transitions and eventually ends; update the dated fixture deliberately for a new demo
schedule rather than resetting it with each request.

The preview now renders the reusable `catalog/card` partial from #40. Pass the
domain auction type (`english` or `sealed_first_price`), status, and optional
local `image_path`/`detail_path` locals. The caller supplies authorized data.
Missing paths show a placeholder/plain title; do not invent a detail route.
The `catalog-image` Stimulus controller reveals the placeholder on image failure,
including cached failures detected on connect. `catalog.css` owns shared card/grid
styles; `catalog_preview.css` contains only preview page styles.

## Combined filters

`Catalog::Filters.new(attributes, categories:)` validates the seven explicit GET
fields `q`, `category`, `status`, `auction_type`, `date_field`, `from`, and `to`.
Call `sections(lots:, now:)` with already-authorized lots and one server timestamp.
It returns the usual sorted section hash, narrowed to one section if status is selected.
It exposes ActiveModel errors and sanitized scalar readers for the `catalog/filters` form.
Invalid inputs yield empty results with field errors; the preview responds with HTTP 422.

Pass the complete eligible category list, not categories derived from filtered results,
so the dropdown remains stable. Search is a case-insensitive literal substring, not SQL
wildcards. Date bounds are inclusive Thai local timestamps (minutes or seconds), with
either endpoint optional. Minute-only timestamps need `:00` appended before Ruby's strict
`Time.iso8601` parser. No browser timezone conversion is applied.

On a checkout newly updated from main, prepare the local development database with
`bin/rails db:migrate`; otherwise Rails blocks the preview with PendingMigrationError
even though the preview itself does not query auction tables.

## Homepage highlights (#63, 2026-11-11)

The overview renders Highlights above its three status sections. Full `/catalog` listings
retain their existing pagination without repeating Highlights. `Catalog::Highlights` consumes
the complete filtered sections before overview truncation or pagination, and retains each
lot's status from `Catalog::Sections`. It ranks public positive integer `min_price_cents`
descending, breaks ties by ascending lot ID, deduplicates IDs and selects at most five total.
Only the filtered ongoing section is eligible (`starts_at <= server now < ends_at`).
Upcoming and ended status filters therefore produce empty Highlights. The existing section
classifier owns time boundaries; refresh removes closed products automatically. Absent,
zero, negative or malformed prices are omitted.
It never reads bids or private valuation fields. Highlights may repeat products from the
regular sections; the result count counts unique regular inventory only.

The horizontal track supports native touch scrolling and focused keyboard scrolling, with
progressively enhanced previous/next buttons and reduced-motion support. It lives inside
the refreshed results fragment, so the same filters and server clock apply on every refresh.
Browser visual, touch and keyboard interaction verification remains part of #44.
