# Product Catalog verification — issue #44

Status: automated verification passed; browser QA and real inventory integration remain open.
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

- [ ] At 1280px, 768px and 390px, inspect spacing, no page overflow, one regular row per
      status (3/2/1 visible cards), readable long names, badges and Thai timestamps.
- [ ] Swipe Highlights, tab to the track and use arrow keys; activate previous/next via
      keyboard. Check visible focus and reduced-motion OS preference.
- [ ] Open/close product details, use Escape and backdrop clicks, and confirm focus returns.
- [ ] Break an image request and verify fallback appears without disrupting card layout.
- [ ] Wait through automatic refresh, hide/show the tab, focus the carousel and open a dialog;
      confirm interaction is preserved, counts update and closed highlights disappear.
- [ ] Simulate refresh failure, verify old content remains, then retry successfully.
- [ ] Verify URL/form/history behavior after filtering, pagination and refresh.

Do not close #44 or claim browser QA is complete until these are checked. #39/#42/#43/#63
also retain their applicable browser/integration acceptance checks. English auctions close
on time without extensions under the current bidding decision; stale extension wording
in older issues is not a requirement to implement extensions.
