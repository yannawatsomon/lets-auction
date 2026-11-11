# Product onboarding: mock data and where to connect the real parts

Last verified: 2026-11-11 (branch for #48; SQLite, no schema change, mock data).

## Summary

Product onboarding (seller lists a product, admin verifies it) runs on mock data for now, like
bidding does (`mock-data.md`). There are **no migrations and no `db/schema.rb` change**, so this
work cannot conflict with other milestones' schema. The rules (media limits, status moves,
append-only reviews) are real and tested; only where the data lives is a mock.

## Details

| Part | Mock today | Connect the real one by |
| --- | --- | --- |
| Products | `ProductOnboarding::Item` (plain Ruby, `ActiveModel` validations) held in memory by `ProductOnboarding::Store` | Add an `Item` ActiveRecord model with the same public methods (`sync_media!`, `add_media!`, `transition!`, `editable?`, `record_review!`, `media_count`, `cover`, status predicates). Turn `Store.find/for_seller/approved/create!` into `Item` finders and scopes |
| Review history | `ProductOnboarding::Review`, frozen after `build!` | `ItemReview` table, read-only once saved; note required for `reject` and `request_info` |
| Files | `ProductOnboarding::MediaFile` (`kind`, `key`, `filename`, `content_type`, `byte_size`), no real files | `ItemMedium` with an Active Storage attachment; `key` becomes the signed blob id; storage service chosen in `config/storage.yml` (needs a gem, ask first, #49) |
| Uploads | `UploadPolicy` (pure Ruby, keep as is) and `UploadStore` (in memory, no real files) behind `POST /product-onboarding/uploads` and `PUT /product-onboarding/uploads/:key` | Issue a signed direct-upload URL from the storage service instead of the PUT endpoint; keep `UploadPolicy` before issuing and again on the stored blob; make `purge_orphans!` a recurring job that purges unattached blobs (ask before adding a gem, #49) |
| Wizard | `/product-onboarding/items/new` (4 steps, `product_wizard_controller.js`) posts to `ProductOnboarding::ItemsController#create`, which calls `UploadStore.ready!`, `Store.create!` and `UploadStore.attach!` | Keep the form and JavaScript. Swap those three calls for the real model and storage; the wizard only sends `upload_keys[]`, so with Active Storage the keys become signed blob ids |
| Dashboard actions | `ItemsController` edit/update/destroy/resubmit on `Store` items; `Item#revise!`, `#transition!`, `#can_transition_to?`; seller ownership checked in `set_item` | Same controller on an ActiveRecord `Item`: scope the lookup with `current_user.items.find`, wrap `revise!` in a transaction with the row lock, keep the 404 for other sellers' products |
| Page | `/product-onboarding` (`ProductOnboarding::ItemsController#index`, layout `product_onboarding`), dev and test only | Becomes the seller dashboard (#51); the wizard (#50) and admin review (#52) get their own routes under `/product-onboarding` |
| Accounts | `MockData.user(id)`: sellers have role `seller`, admins `admin` (`db/mock/users.yml`) | Real `User` with `role`; `Item#seller_is_a_seller` and `Review#reviewer_is_an_admin` only call `seller?` / `admin?` |
| Data | `db/mock/product_items.yml`: 3 products (pending review, info requested with the admin's note, approved). Ids start at 201 so they do not clash with bidding's `db/mock/items.yml` (101 to 108) | Delete the file and `Store` once real data exists |
| Bidding link | `ProductOnboarding::Store.approved` has the same readers as `MockData::Item` (`id`, `seller_id`, `category`, `title`, `min_price_cents`, `status`) | Bidding can call it in place of `MockData.approved_items`; with real tables, `Item.approved` |
| Money | `min_price_cents`, integer satang | Matches `docs/decision/bidding.md` |

## Gotchas

- State lives in the server process: it resets on restart and on code reload in development.
  Tests call `ProductOnboarding::Store.reset!` (see `test/models/product_onboarding/support.rb`).
- Each item has a lock (a `Monitor`) around media changes, so the concurrency test runs without
  a database. It does not prove a database row lock; that needs Postgres.
- Items and reviews are mutable shared objects inside one process. Do not hand them to a
  background thread without the lock.
- A bad `min_price_cents` is validated on the raw value, so `"1.5"` is rejected instead of being
  rounded to 1.
- Shell setup in WSL: put rbenv on `PATH` first (see `rails-wsl-gotchas.md`).

## References

- [`docs/decision/product-onboarding.md`](../../docs/decision/product-onboarding.md)
- [`docs/design/product-onboarding-flow.md`](../../docs/design/product-onboarding-flow.md)
- [`docs/plans/2026-11-11-product-onboarding.md`](../../docs/plans/2026-11-11-product-onboarding.md)
- [`mock-data.md`](mock-data.md) (bidding's mock users and items)
