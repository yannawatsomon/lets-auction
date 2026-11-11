# Catalog Cards Implementation Plan

**Goal:** Reusable responsive cards based on the approved preview appearance for #40.

**Architecture:** Rails partial/helper, CSS grid, and a small Stimulus image-error handler. Preview supplies synthetic data and reuses the partial; no database or detail routes are invented.

**Tech Stack:** Existing Rails, Minitest, Stimulus; no dependencies added.

**Spec:** `docs/specs/2026-11-11-catalog-cards-design.md`.

## Global Constraints

- Work in `feat/fon-feature-test`; preserve existing uncommitted work.
- Keep status/type labels side by side; support `english` and `sealed_first_price`.
- Use Asia/Bangkok display time and escaped output.
- Optional image/detail paths must be local absolute paths.

## Review Focus

- Missing/broken images retain a visible fallback.
- Long names wrap without horizontal overflow.
- Unknown type/status must not silently display a different known value.
- HTML in names is escaped and unsafe paths do not become links/images.
- UTC timestamps display as Thai local time.

### Task 1: Extract and verify reusable cards

**Files:** Create `app/views/catalog/_card.html.erb`, `app/helpers/catalog_helper.rb`, `app/assets/stylesheets/catalog.css`, `app/javascript/controllers/catalog_image_controller.js`, and `test/views/catalog/card_test.rb`. Modify preview view/controller/CSS.

**Interfaces:** Partial locals `lot`, `status`, `auction_type`, optional `image_path` and `detail_path`; helper resolves labels and validates paths; Stimulus handles image error without inline script.

- [x] Write view tests for content, images/fallback, labels, timestamps, safe links, escaping, unknown enums, and long names.
- [x] Observe targeted tests fail before implementing the partial/helper.
- [x] Implement partial/helper/styles/image handler and reuse the partial in Preview.
- [x] Run targeted/full tests, RuboCop, Brakeman, and verify rendered Preview.
- [x] Review the implementation; leave changes uncommitted and record remaining data/detail integration.

## Results and limits

- Full suite: 21 tests, 84 assertions, no failures/errors. RuboCop: 31 files, no offenses.
- Brakeman: no warnings/errors. JavaScript syntax check passed.
- Preview: HTTP 200, 3 sections, 9 cards, 1 accessible sample image asset and 8 missing-image fallbacks.
- Independent review found no critical/important defects.
- Browser verification remains: responsive layout at mobile widths and execution of the broken-image Stimulus fallback. View tests verify the markup/wiring, not browser behavior.
- Real model and detail-page integration remain dependent on the owning features. Issue #40 remains In progress until outstanding verification/integration is resolved.
