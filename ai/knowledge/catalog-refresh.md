# Catalog server-time refresh

Last verified: 2026-11-11

`catalog-refresh` polls every 30 seconds while visible and refreshes immediately when
returning to a visible tab. `CatalogRefreshLoop` owns timers, overlap prevention,
cancellation and retry scheduling. Node built-in tests run locally and in CI with
`node --test test/javascript/catalog_refresh_loop_test.mjs`.

Status classification remains server-only (`Time.current`); client time is never
accepted. The browser replaces only the results fragment and update timestamp, keeping
the filter form, unfinished edits and scroll coordinates. Polling waits while a detail
dialog is open or focus is inside results. Disconnect/hide aborts an in-flight fetch.

The canonical refresh URL preserves applied filters but omits section page counters.
Only after a successful swap does history switch to that first-page URL. Failed requests
keep prior results visible with Retry. Initial invalid inputs or an initial inventory
outage disable polling and retain the existing full-page recovery controls.

Demo timestamps use a fixed dated fixture, documented in [catalog-sections.md](catalog-sections.md).
Request tests freeze time at that anchor; transition tests advance server time through
exact start/closing boundaries. English auctions have no extensions under the current
bidding decision, despite the old #43 issue wording.

Real inventory integration remains separate. Browser tab/focus/DOM behavior still needs
end-to-end QA; current verification covers Ruby requests, pure scheduler tests, rendered
HTTP fragments and importmap asset loading.
