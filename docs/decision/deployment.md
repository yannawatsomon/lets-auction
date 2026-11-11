# Deployment

**Status:** Decided · **Effort:** S · **Deadline risk:** Medium — production DB unresolved

## Context

The app needs a public URL. The owner already connected the repo to Railway.

## Decisions

- **Railway deploys automatically from `main`.** What: every push/merge to `main` triggers a
  Railway build (Docker, using the repo `Dockerfile`) and deploy. Why: user-configured
  (2026-11-11). Trade-off: merging a PR = shipping to production, so `main` must stay
  releasable. Alternative rejected: manual deploys. Source: user statement, 2026-11-11.
- **`main` is protected and CI must pass before merge**, so a red build cannot be merged and
  deployed. See `repo-and-collaboration.md`.
- The generator's Kamal config (`config/deploy.yml`, `.kamal/`) is not the deploy path; Railway
  is. Leave it alone unless Kamal is adopted deliberately.

## Rules / examples

- Secrets (`RAILS_MASTER_KEY`, `DATABASE_URL`, ...) are Railway variables, never committed.
  `config/master.key` is git-ignored and stays that way.
- Optional Railway variable `MOCK_PRODUCT_ONBOARDING=true` shows the mock product-onboarding
  pages in production (sellers only; see `product-onboarding.md`). Unset by default.
- Catalog demo listings are temporarily enabled by default at the user's request
  (2026-11-11). Set `CATALOG_DEMO=false` to hide them. This controls read-only synthetic
  catalog inventory only, not mock login, admin access, or bidding. See `product-catalog.md`.
- Optional bidding demo (2026-11-11, `bidding.md`): `MOCK_BIDDING=true` **and**
  `MOCK_BIDDING_PASSWORD` (12+ characters) let the team try the bidding pages on the Railway URL:
  visitors type the demo password, then pick any mock user (admin, buyer, seller). Off if
  either is missing. Bidding also needs `ACTIVE_RECORD_ENCRYPTION_PRIMARY_KEY`,
  `ACTIVE_RECORD_ENCRYPTION_DETERMINISTIC_KEY`, `ACTIVE_RECORD_ENCRYPTION_KEY_DERIVATION_SALT`
  (bids) and `SOLID_QUEUE_IN_PUMA=1` (auctions open/close on time). Demo data:
  `bin/rails bidding:demo_seed`. Steps: `ai/knowledge/bidding-demo-on-railway.md`.
- The app's health endpoint is `/up` (whether Railway uses it as a health check is open).

## Open questions

- Railway "Wait for CI" for the GitHub trigger: enabled? (The `main` rulesets already block
  merging red PRs, but the admin bypass, currently `always`, would still allow a direct push
  that deploys.)
- Production database (see `stack.md`): Postgres service vs SQLite volume.
- Port mapping: the Rails 8 Dockerfile listens on 80 via Thruster; confirm Railway's `PORT`.
- Custom domain, staging environment, rollback procedure.
