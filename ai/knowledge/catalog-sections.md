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
