# Catalog server-time refresh — #43

The user approved continuing #43 using server system time on 2026-11-11.

- Server `Time.current` remains the sole source of auction status. Do not accept a client
  time parameter or classify auctions using the browser clock.
- Poll the current catalog view every 30 seconds while visible and refresh on returning
  to the tab. Replace only the results fragment and last-update timestamp; preserve the
  filter form, unfinished edits, scroll position and selected filters.
- Skip replacement while a product dialog is open or focus is inside results. Prevent
  overlapping requests and abort on navigation/disconnect or a hidden tab.
- Successful refresh resets listing pagination to the first page; remove page counters
  from the URL only after success. Overview remains one 3/2/1-card row per status.
- On network/server/parse failure keep previous results visible and offer Retry. Do not
  turn an outage into empty results. Disable automatic refresh for invalid initial inputs.
- Keep demo start/closing times fixed across requests and workers using a dated shared
  fixture anchor (`2026-11-11T16:00:00Z`). The fixture naturally transitions and eventually
  ends; changing its schedule requires changing the fixture, never each page request.
- Existing bidding decisions prohibit English extensions. The old issue's extension
  acceptance criterion is superseded by `docs/decision/bidding.md`; no extension feature
  is introduced. Refresh always uses whatever effective closing time the provider supplies.
- No production data adapter, schema, dependency, auth or deployment changes in this task.

Verify timestamp stability, exact transitions, filtered counts, no duplicate cards, ignored
client-time params, refresh URL/reset policy, timer/visibility lifecycle, overlap prevention,
retry and cancellation. Browser visual/focus QA remains separate from source/unit checks.
