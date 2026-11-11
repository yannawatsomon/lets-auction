# Catalog refresh implementation plan

**Goal:** Implement #43 with server-authoritative state and 30-second visible-page polling.
**Spec:** `docs/specs/2026-11-11-catalog-refresh.md`.
**Branch:** `nutthavara-feat-43-catalog-refresh`.

1. Write failing Ruby tests for fixed demo timestamps and boundary/filtered transitions;
   freeze existing catalog request tests at the fixture anchor.
2. Make demo timestamps fixed, expose a results fragment and server update timestamp,
   and render a canonical refresh URL with filters but no page counters.
3. Write Node built-in tests for a framework-independent refresh loop, then implement
   its timeout/overlap/cancellation/retry lifecycle and wire it through Stimulus.
4. Verify Rails suite, Node tests, RuboCop, Brakeman, JS syntax and HTTP behavior.
5. Review and document results/limits. Leave changes uncommitted until requested.

## Results

- Rails: 417 tests, 2220 assertions, no failures/errors. The existing upload-policy
  missing-assertions warning remains unrelated.
- Node refresh-loop tests: 5 passed. JavaScript syntax and workflow YAML parse passed.
- RuboCop: 182 files, no offenses. Brakeman: no warnings/errors.
- HTTP checks: canonical refresh URL retains filters/removes pages; fragment and assets
  load; fixed schedules remain stable; invalid filters disable polling.
- Self-review checked cancellation, visibility, dialog/focus deferral, error recovery,
  first-page/history consistency, and importmap wiring.
- Browser host unavailable; native Safari access timed out. Real browser visibility,
  focus preservation and DOM replacement QA remain pending. No independent agent review.
- No commit, push, PR or deployment in this task. Issue #43 remains In progress.
