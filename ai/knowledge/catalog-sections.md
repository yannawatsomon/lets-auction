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
- Map auction start time and lot-specific closing time from the auction model
  once #28 is implemented; do not assume the event closing time includes lot extensions.
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

Demo inventory now contains 45 synthetic lots (15 per status) to exercise
pagination; the initial page displays up to 12 per section, or 36 cards total.

## Independent Load more

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

`/catalog-preview` renders nine synthetic lots through the real sections service.
The route and controller are restricted to development and do not persist data.
The sample times are relative to each request, so reloading recreates the sample
schedule; this preview does not demonstrate live status transitions. It is a
throwaway visual aid, not completion of #39 or the product-card issue.

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
