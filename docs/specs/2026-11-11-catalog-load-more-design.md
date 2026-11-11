# Catalog load more — #42

Add independent server-rendered Load more links to the existing catalog. Use cumulative
GET pagination so the page remains usable without JavaScript or a new endpoint.

- Show 12 cards per section initially; each click adds up to 12 cards in that section.
- Params: `ongoing_page`, `upcoming_page`, `ended_page`; omitted/blank means 1.
  Accept decimal strings from 1 to 100; reject arrays, hashes, zero, negatives,
  oversized numbers and malformed strings with HTTP 422 and a visible message.
- Preserve all seven filter fields and the other section page counts in Load more links.
- Filter form submissions contain no page params, resetting every section to page 1;
  Clear filters also resets pagination.
- Filter and sort the complete authorized input before slicing. Counts represent total
  matching lots, with a displayed/total count per section. Never paginate before sorting.
- Hide Load more when exhausted; if the safety cap of 100 pages is reached while items
  remain, prompt users to narrow filters instead of claiming all items are displayed.
- A typed `Catalog::InventoryUnavailable` from the provider renders HTTP 503, a clear
  error, no misleading zero-result counts, and a retry link preserving filters/pages.
  Other programming exceptions continue to surface normally.
- Expand demo inventory to 15 lots per status for manual verification.
- Updated user request (2026-11-11): deploy with read-only synthetic catalog data on Railway.
  Production demo is temporarily enabled by default; `CATALOG_DEMO=false` hides it.
  Always show the sample-data banner when demo lots are enabled. This does not enable
  mock login, bidding, admin access or the preview endpoint in production.
- No changes to production data visibility, live refresh, Highlights, or database queries.

Tests cover independent expansion, order across page boundaries, filter preservation/reset,
malformed page params, counts, exhausted sections, empty results, and failure/retry recovery.
