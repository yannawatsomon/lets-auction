# Product onboarding: mock parts and where to connect real ones

Last verified: 2026-11-11 (branch for #48; SQLite, mock data).

## Summary

The item data model (`Item`, `ItemMedium`, `ItemReview`, `Category`) is built against
placeholders so it works today and can be wired to the real services later. This note lists
each placeholder and the one place to change.

## Details

| Part | Mock today | Connect the real one by |
| --- | --- | --- |
| Accounts and roles | `User` model with `email` and `role` (buyer, seller, admin), created by `db/migrate/20261111100001_create_users.rb`. Placeholder for the user-onboarding milestone (#16) | Replace that migration and `app/models/user.rb` with the real model. Keep `role` values and `has_many :items, foreign_key: :seller_id`. `Item` and `ItemReview` only call `user.seller?` and `user.admin?` |
| Authentication | None. No controllers use `Current.user` yet | Decide in `docs/decision/auth.md`; the seller and admin controllers (later tasks) read the current user from one place |
| File storage | Active Storage with the local disk service (`config/storage.yml`, `tmp/storage` in tests) | Add an S3-compatible service in `config/storage.yml` and set `config.active_storage.service` for production. No model change. Needs a gem, so ask first (#49) |
| Database | SQLite (Rails default) | Switch the adapter in `config/database.yml` and add the gem. Migrations use only portable column types and `CHECK` constraints. The row-lock test (`test/models/item_media_concurrency_test.rb`) starts running on Postgres |
| Data | `db/seeds/mock_products.rb`: mock sellers, an admin, 3 categories and 3 products (`pending_review`, `info_requested`, `approved`). Never loaded in production | Delete the file and its `load` line in `db/seeds.rb` once real data exists. Tests use `test/fixtures` instead |
| Money | `items.min_price_cents`, integer satang | Matches the proposal in `docs/decision/bidding.md`. Convert from THB only in forms and views |
| Auction lots | None | The lots work (#28) reads `Item.approved` and moves items with `Item#transition!(:in_auction)` |

Run the app with mock data: `bin/rails db:setup` (loads the schema and seeds).

## Gotchas

- `Item#sync_media!` replaces the whole file list in one call and keeps files that are still in
  the list. Pass signed blob ids (`blob.signed_id`) in display order; the first image is the cover.
- SQLite ignores `SELECT ... FOR UPDATE`, so the "two requests cannot exceed a limit" rule is
  only proven on Postgres. The test is skipped, not passed, on SQLite.
- `lock_version` is only a column so far. Bumping it when media changes, and checking it in the
  admin decision, comes with the admin verification task (#52).
- Shell setup in WSL: put rbenv on `PATH` first (see `rails-wsl-gotchas.md`), otherwise the
  system Ruby is used and `bundle` is missing.

## References

- [`docs/decision/product-onboarding.md`](../../docs/decision/product-onboarding.md)
- [`docs/design/product-onboarding-flow.md`](../../docs/design/product-onboarding-flow.md)
- [`docs/plans/2026-11-11-product-onboarding.md`](../../docs/plans/2026-11-11-product-onboarding.md)
