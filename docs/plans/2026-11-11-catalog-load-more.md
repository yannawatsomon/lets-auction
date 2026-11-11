# Catalog Load More Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use executing-plans to implement this plan task-by-task.

**Goal:** Independent Load more and retry behavior for #42.

**Architecture:** Pagination validates bounded GET counters and slices sorted section arrays. Shared catalog preparation keeps totals separate from displayed cards and handles a typed inventory outage. Normal GET links preserve state and work without JavaScript.

**Tech Stack:** Existing Rails, ERB, Minitest; no new dependencies.

**Spec:** `docs/specs/2026-11-11-catalog-load-more-design.md`.

## Global Constraints

- Branch `nutthavara-feat-42-catalog-load-more`; 12 items per section per increment, max 100 pages.
- Maintain filter semantics and the production demo on/off boundary; user later requested
  production read-only demo inventory, disabled with `CATALOG_DEMO=false`.
- Never return misleading totals on inventory failure; only rescue the typed provider error.
- Leave changes uncommitted until requested.

## Review Focus

- Expanding one section preserves the others.
- Page links preserve scalar filters; submitting filters resets page counters.
- Sorting/ties remain stable before slicing, with no duplicate cards.
- Nonscalar or huge page values fail safely.
- An inventory outage renders retry rather than no-results text and recovers on retry.

### Task 1: Pagination and rendering

**Files:** pagination service/tests, catalog page concern/helper/view/CSS, demo data, homepage tests.
**Interfaces:** `Catalog::Pagination.new(attributes)`, `.items(status, lots)`, `.more?(status, lots)`, `.query`, `.next_query(status)`, `.errors`; `Catalog::InventoryUnavailable` is the provider failure contract.

- [x] Write failing service and request tests for bounded pages, independent expansion, filters, totals, empty sections and failure/retry.
- [x] Implement the service and wire the catalog page after filtering/sorting.
- [x] Expand local demo lots and preserve the production guard.
- [x] Run full tests, RuboCop, Brakeman and HTTP checks; review and document limitations.

## Verification and limits

- Full suite: 182 tests, 793 assertions, no failures/errors. The existing upload-policy
  missing-assertions warning remains unrelated to this feature.
- RuboCop: 91 files, no offenses. Brakeman: no warnings/errors.
- HTTP: verified initial 12/12/12 cards, then independent expansion to 15/12/12,
  15/15/12, and 15/15/15. Invalid page returns HTTP 422 with recovery link.
- Initial full suite exposed three missing mock-login route helpers in other tests;
  preloading routes before the homepage production test fixes lazy-route contamination.
  Both original failing seed 57174 and the final standard suite pass.
- Independent review: no critical/important findings. Deferred minor checks:
  all-seven-fields link assertion, rendered page-cap warning assertion, and browser/mobile QA.
- Updated user deployment request: production now supports read-only demo inventory by
  default, with explicit off switch and visible banner. Actual inventory integration is
  still outstanding; in-memory filtering needs adaptation for database-backed pagination.
- Final pre-rebase checks with production demo: 183 tests, 801 assertions, no failures/errors;
  RuboCop 92 files, no offenses. Commit/push/PR/deployment authorized by the later user request.
