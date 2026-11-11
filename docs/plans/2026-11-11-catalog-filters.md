# Catalog Filters Implementation Plan

**Goal:** Search and combine catalog filters for #41 and the type-filter portion of #63.

**Architecture:** Catalog::Filters validates GET inputs and filters caller-authorized lots in memory before delegating time grouping/sorting to Catalog::Sections. Preview renders a reusable filter form and the resulting sections.

**Tech Stack:** Rails, ActiveModel, Minitest; existing assets and helpers.

**Spec:** `docs/specs/2026-11-11-catalog-filters-design.md`.

## Global Constraints

- Branch `nutthavara-feat-41-catalog-filters`, based on current main.
- Params and allowed values follow the spec; no new dependencies/schema or production routes.
- Validate on the server and escape form output.
- Work remains uncommitted until requested; do not close #63 (Highlights remain).

## Review Focus

- Array/hash params return field errors rather than crashing or widening results.
- Literal search treats wildcard characters as text.
- Inclusive date bounds are interpreted in Thai time and reject impossible dates.
- Combined filters preserve sorting and selected section behavior.
- Empty/invalid results retain controls and offer a clear-filter link.

### Task 1: Filter validation and matching

**Files:** `app/services/catalog/filters.rb`, `test/services/catalog/filters_test.rb`.
**Interfaces:** `Catalog::Filters.new(attributes, categories:)`; `.sections(lots:, now:)` returns section hash; `.errors` and scalar readers drive the form.

- [x] Write and run failing tests for matching, bounds, defaults, invalid inputs, and ordering.
- [x] Implement validation/matching with no database dependencies; run targeted tests.

### Task 2: Preview form and end-to-end behavior

**Files:** `app/views/catalog/_filters.html.erb`, preview controller/view/CSS, filter view tests.
**Interfaces:** form locals `filters`, `categories`, `url`; controller supplies only explicit filter keys.

- [x] Write failing form-render tests, then implement GET controls, field errors, and clear link.
- [x] Add counts/empty messages and wire controller to filtering service.
- [x] Run full Rails tests, RuboCop, Brakeman, and development HTTP checks.
- [x] Review and document integration limits; leave work uncommitted.

## Verification and remaining work

- Targeted suite: 12 tests, 113 assertions, no failures/errors.
- Full suite: 125 tests, 480 assertions, no failures/errors.
- RuboCop: 68 files, no offenses. Brakeman: no warnings/errors.
- Eight HTTP scenarios passed: defaults, query/status, category/type, status/type,
  no matches, an empty date range, invalid date, and nonscalar query input.
- Independent review: no critical/important findings. Deferred minor checks:
  mobile/native datetime browser QA; direct invalid `to` test; explicit multi-item
  ordering assertion after filtering (ordering itself is tested in Sections).
- Preview still uses synthetic data. Production data/visibility integration is not
  completed, and #63 still needs Highlights. No commit, push, or PR in this task.
