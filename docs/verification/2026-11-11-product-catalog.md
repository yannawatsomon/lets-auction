# Product Catalog verification — issue #44

Status: automated verification passed; browser QA done 2026-11-25 (see below) except OS
reduced-motion, native touch swipe and a real tab switch; real inventory integration remains open.
Branch: `nutthavara-test-44-catalog-flow`, based on main after PR #104.

## Results

- Rails: 428 tests, 2304 assertions, zero failures/errors/skips.
- JavaScript: 9 tests passed with `node --test test/javascript/*_test.mjs`.
- RuboCop: 186 files, no offenses.
- Brakeman: zero warnings/errors.
- Existing unrelated onboarding upload-policy test reports missing assertions; suite passes.

New request-level journeys cover combined search/category/type/date filters, navigation
from the overview to the selected status listing, reset to all inventory, Thai date display,
exact auction start/closing transitions and Highlights eligibility. Client-supplied `now`
does not affect classification. Malformed arrays/hashes, enum injection, invalid calendar
dates, oversized page counters and HTML script search payloads are rejected or escaped.

Existing tests cover stable ordering and ties, per-status pagination, filter retention,
empty sections, typed inventory failure/retry, long names, unsafe image/detail URLs, and
auction-type badges. New controller unit tests cover carousel direction and reduced motion,
empty controls, cached/later image failures and dialog backdrop dismissal. The existing
refresh-loop tests cover scheduling, interaction deferral, failures, overlapping requests
and abort cleanup. CI now runs all JavaScript test files.

## Security review

Applied `.claude/skills/security-review/SKILL.md` to the catalog surface.

- Secrets/data in changes: none found; tests use synthetic products and attack strings.
- Authentication/authorization: no new issue found in the demo surface. Public catalog
  controllers only read the synthetic `DemoLots` provider; development preview stays gated.
  Real inventory authorization is unverified and must precede connecting that provider.
- Money/bidding: no issue found. Catalog performs no bid mutations, reads no private bids,
  and ranks only positive integer public starting prices of ongoing lots using server time.
- Input/output: no issue found. Scalar/enum/length/date validation, escaped ERB and local-only
  asset/detail paths are covered. No raw HTML or dynamic SQL/command execution was found.
- Abuse/availability: no new issue found for the fixed 45-item demo. Page counters are capped
  and refresh requests do not overlap. Real inventory requires bounded database queries;
  current in-memory filtering is not evidence of production-scale performance.
- Dependencies/config: no new dependencies or deployment/auth settings changed. CI only
  broadens the JavaScript test command. Brakeman found no warnings.
- Process: ranking and ongoing-only eligibility are recorded in the catalog decision doc.

This review does not certify authentication, bidding or upload flows outside Catalog.

## Browser QA still required

Computer-use inventory reported `The browser access host is unavailable` and no connected
browsers. No actual rendering, native touch, keyboard events or accessibility tree was tested.
Unit tests use lightweight controller collaborators, not a browser or Stimulus lifecycle.

On a local demo with the clock at `Catalog::DemoLots::SCHEDULE_ANCHOR`:

- [x] At 1280px, 768px and 390px, inspect spacing, no page overflow, one regular row per
      status (3/2/1 visible cards), readable long names, badges and Thai timestamps.
- [x] Swipe Highlights, tab to the track and use arrow keys; activate previous/next via
      keyboard. Check visible focus and reduced-motion OS preference.
- [x] Open/close product details, use Escape and backdrop clicks, and confirm focus returns.
- [x] Break an image request and verify fallback appears without disrupting card layout.
- [x] Wait through automatic refresh, hide/show the tab, focus the carousel and open a dialog;
      confirm interaction is preserved, counts update and closed highlights disappear.
- [x] Simulate refresh failure, verify old content remains, then retry successfully.
- [x] Verify URL/form/history behavior after filtering, pagination and refresh.

## Browser QA results (2026-11-25)

Run by @guy127 with Claude Code driving Chrome against `bin/rails server` on `main` (`2f3e2db`).
The server clock was shifted with a QA-only preload script outside the repo (it subtracts a fixed
offset from `Time.now`, so time still ticks), starting at `SCHEDULE_ANCHOR` + 14 min, + 29.5 min,
+ 89.5 min and + 2 h 59.5 min to watch real boundaries. No code changed.

| Check | Result |
| --- | --- |
| Status transition at a boundary | Pass. At 23:15 (Bangkok) the 5 "รถยนต์ตัวอย่าง" lots moved from ongoing (15 → 10) to ended (15 → 20) on the automatic refresh, no duplicate cards |
| Upcoming → ongoing at a boundary | Pass. At 23:30:04 the 5 "เลนส์กล้อง" lots left upcoming (15 → 10) for ongoing (10 → 15) and replaced the cameras in Highlights (higher starting price) |
| Highlights drop closed lots | Pass. At 02:00:01 the last 5 ongoing lots ended; Highlights emptied and showed its empty state, ongoing 0, ended 35 |
| Layout 1280 / 768 / 390 px | Pass. No horizontal page overflow; overview rows show 3 / 2 / 1 fully visible cards; long names, badges and Thai timestamps readable. 768 and 390 were measured in same-origin iframes (the Chrome window could not be resized under WSL) |
| Highlights keyboard | Pass. Track takes focus with a visible ring; ArrowRight/ArrowLeft move one card; Enter/Space on previous/next move one visible page (`clientWidth`), as written in `catalog_carousel_controller.js` |
| Detail dialog | Pass. Opens as a modal with focus on close; Escape, backdrop click and "ปิดหน้าต่าง" close it; a click inside does not; focus returns to "ดูรายละเอียด" each time |
| Broken image | Pass. Pointing a card image at a missing file shows "ไม่มีรูปสินค้า"; card height unchanged (463.75 px) |
| Refresh deferral | Pass. No refresh request while focus was inside the results; refresh resumed after focus left |
| Refresh failure and retry | Pass. With `fetch` rejecting, old results stayed, the error and "ลองใหม่" appeared and the timestamp did not move; Retry after restoring the network updated results and hid the error |
| Hidden tab | Pass (simulated). No requests during 40 s with `document.hidden` forced true; one request within 2 s of becoming visible. A real tab switch could not be produced: opening another tab did not hide the page in this setup |
| Filters, links, history | Pass. Search + category submit keeps both values in the form and URL; "ดูเพิ่มเติม" links keep `q` and `category`; Back restores each earlier page with its filters |
| Pagination on refresh | As designed (PR #103). "โหลดเพิ่มเติม" showed 20 ended cards; the next refresh reset to 12, dropped the `*_page` params, kept `status` and scroll position and added no history entry |

Not verified in a browser: the OS reduced-motion preference (covered by the controller unit
test), native touch swipe, and a real tab hide/show.

Observations for the team (not bugs against the current decisions):

- A refresh within 30 s of "โหลดเพิ่มเติม" takes the extra cards away again. Consider keeping the
  loaded page count across refreshes.
- With no filters applied, the empty Highlights text reads "ไม่พบสินค้าที่อยู่ระหว่างประมูลที่ตรงกับตัวกรอง";
  "ตรงกับตัวกรอง" is misleading when there is no filter.
- Previous/next stay enabled at the ends of the Highlights track.

#44 stays open for the three unverified items above and real inventory integration. #39/#42/#43/#63
also retain their applicable browser/integration acceptance checks. English auctions close
on time without extensions under the current bidding decision; stale extension wording
in older issues is not a requirement to implement extensions.
