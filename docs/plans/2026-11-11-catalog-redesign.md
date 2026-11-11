# Catalog Redesign Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use executing-plans to implement this plan task-by-task.

**Goal:** Match the supplied HTML design and keep each overview section to one row.

**Architecture:** Shared Rails page/card/filter partials keep existing state handling. A separate Catalog listing action reuses the same page with full pagination, while overview sections are capped and responsive. Native dialogs provide read-only card details.

**Tech Stack:** Existing Rails, ERB, CSS, Stimulus, Minitest; no dependencies.

**Spec:** `docs/specs/2026-11-11-catalog-redesign.md`.

## Global Constraints

- Reference design drives visual styling; preserve current domain/filter semantics.
- 3/2/1 cards per overview row at desktop/tablet/mobile, section links preserve filters.
- Prices are optional integer satang; all data remains clearly marked demo inventory.
- Work on `nutthavara-feat-catalog-redesign`, do not commit/deploy without a request.

## Review Focus

- Extra cards cannot wrap or receive focus on collapsed overview.
- Section links keep all filter criteria except replacing status and resetting counters.
- Listing navigation, validation, counts, outages and retry keep existing contracts.
- Missing prices do not invent a value; dialogs escape data and remain keyboard accessible.
- Styles stay scoped to Catalog to avoid changing onboarding/admin screens.

### Task 1: Overview/listing navigation

**Files:** Catalog controller, shared concern/helper/page, routes; homepage/load-more request tests.
**Interfaces:** `prepare_catalog(url:, overview: false)`; `/catalog` lists matches; overview flag caps cards at three before CSS.

- [x] Write failing navigation/overview tests and adapt existing listing request tests to `/catalog`.
- [x] Implement overview/listing split while retaining pagination/errors.

### Task 2: Reference UI and cards

**Files:** catalog CSS/page/filter/card, demo lots, detail Stimulus controller, card tests.
**Interfaces:** card adds optional `min_price_cents`; native dialog opens via Stimulus; demo adapter supplies prices.

- [x] Write failing optional-price tests, then implement styling and details.
- [x] Run full tests/lint/security and rendered HTTP checks; visually verify if available.
- [x] Review changes and record limits, leaving work uncommitted.

## Verification and limits

- Full suite: 412 tests, 2187 assertions, no failures/errors. Existing unrelated
  upload-policy missing-assertions warning remains.
- RuboCop: 180 files, no offenses. Brakeman: zero warnings/errors. JS syntax passed.
- HTTP: homepage 9 total cards/3 section links, listing 12 then 15 cards; prices and
  dialog markup present. Filter-preserving section navigation covered by request tests.
- Independent review: no critical/important findings.
- Browser host unavailable; desktop/tablet/mobile screenshot comparison and dialog
  focus/Escape/backdrop/focus-return behavior still require real browser QA.
- No commit, push or deployment performed for this redesign.
