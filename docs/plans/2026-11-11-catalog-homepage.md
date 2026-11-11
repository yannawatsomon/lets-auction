# Catalog Homepage Implementation Plan

**Goal:** Replace the homepage with the existing catalog page requested by the user.

**Architecture:** Shared controller concern and page partial serve both homepage and development preview. Demo lots move into a provider that returns no data outside local environments.

**Tech Stack:** Existing Rails, ERB, Minitest.

**Spec:** `docs/specs/2026-11-11-catalog-homepage-design.md`.

## Global Constraints

- GET forms and clear links on homepage use `/`.
- No demo inventory in production; no new dependencies or production preview route.
- Leave changes uncommitted until requested.

## Review Focus

- Root displays catalog rather than placeholder content.
- Filters submit and clear at root.
- Invalid filters retain field errors and return HTTP 422.
- Preview stays development-only.
- Production renders no synthetic product cards or preview banner.

### Task 1: Share catalog rendering and switch homepage

**Files:** home/preview controllers and views, `app/controllers/concerns/catalog_page.rb`, `app/services/catalog/demo_lots.rb`, `app/views/catalog/_page.html.erb`, homepage tests and knowledge notes.
**Interfaces:** `Catalog::DemoLots.call(now:)` returns local-only lots; `prepare_catalog(url:)` provides common view state.

- [x] Write failing homepage tests, then verify production-boundary coverage.
- [x] Extract provider/page preparation/partial and wire both pages.
- [x] Run tests, lint/security checks and local HTTP checks; review the diff.

## Verification

- Targeted homepage suite: 4 tests, 29 assertions, no failures/errors.
- Full suite: 171 tests, 709 assertions, no failures/errors. Existing upload-policy
  test warns about missing assertions; suite exits successfully.
- RuboCop: 86 files, no offenses. Brakeman: no warnings/errors.
- HTTP checks: homepage, filtered homepage, and preview all HTTP 200 with expected
  card counts and correct form/clear URLs.
- Independent review: no critical/important findings. Minor deferred: automated
  development-preview URL regression test (covered by manual HTTP check).
- No browser visual check; production data integration remains outstanding.
