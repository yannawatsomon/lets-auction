# Catalog Sections Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Implement the approved grouping and sorting service for the first part of #39.

**Architecture:** A stateless Ruby service groups already-authorized lots using one explicit server timestamp. It does not create auction models or expose a route; integration remains dependent on #28/#35.

**Tech Stack:** Ruby 4.0.5, Rails 8.1, Minitest.

**Spec:** `docs/specs/2026-11-11-catalog-sections-design.md` (approved by user in chat).

## Global Constraints

- Work on `feat/fon-feature-test` in the current checkout as requested.
- `Catalog::Sections.call(lots:, now:)` returns ordered keys `ongoing`, `upcoming`, `ended` containing the original lot objects.
- Consume unique integer IDs and Time-compatible `starts_at`/`ends_at`; reject missing/invalid IDs, timestamps, duplicate IDs, and start >= close with ArgumentError.
- Use latest effective closing times supplied by the caller; visibility filtering remains the caller's responsibility.
- Do not mark #39 complete until model and page integration are implemented.

## Review Focus

- Exact start and closing instants go into ongoing and ended respectively.
- Equal timestamps use ID ascending, including ended descending-time order.
- Extended closing times override the previous boundary.
- Empty input and frozen input preserve the contract without mutation.
- Malformed IDs/times fail clearly rather than yielding misleading sections.

### Task 1: Group and order catalog lots

**Files:** Create `app/services/catalog/sections.rb`; test `test/services/catalog/sections_test.rb`.

**Interfaces:** Consume objects with `id`, `starts_at`, `ends_at`; produce `Catalog::Sections.call(lots:, now:) -> Hash<Symbol, Array>`.

- [x] Write tests covering status boundaries, ordered groups, time ordering, tie-breaking, extensions, input immutability, and invalid inputs; derive expected IDs explicitly.
- [x] Run `bin/rails test test/services/catalog/sections_test.rb` and observe failure before implementation (missing Catalog service).
- [x] Implement the service without persistence or additional dependencies.
- [x] Run targeted tests then `bin/rails db:test:prepare test`, `bin/rubocop`, and `bin/brakeman`; investigate failures before claiming success.
- [x] Review the diff against the approved spec and record remaining integration work. Leave changes uncommitted for user review.

## Results

- Targeted suite: 12 tests, 28 assertions, no failures/errors.
- Full suite: 13 tests, 29 assertions, no failures/errors.
- RuboCop: 28 files, no offenses. Brakeman: no warnings/errors.
- Independent review: no critical/important findings. Minor deferred: test actual
  ActiveSupport::TimeWithZone explicitly; current offset-Time test covers instant equality.
- #39 remains In progress pending auction model and page integration.
