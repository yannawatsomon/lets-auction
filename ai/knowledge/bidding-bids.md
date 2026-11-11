# Bids table: encryption and append-only
Last verified: 2026-11-11

## Summary

`bids` (#30) holds every bid for both auction types. The amount (satang) is encrypted with
Active Record Encryption in one `text` column, and bids are append-only. Decisions:
`docs/decision/bidding.md`.

## Details

- `Bid#amount` (Integer) / `#amount=`; the column `amount_cents` holds ciphertext.
- `Bid.ranking(bids, one_per_user:)` sorts in Ruby: amount desc, `created_at` asc, id asc.
  English results use `one_per_user: true` (each bidder's best bid).
- DB rules: one sealed bid per buyer per lot (`one_sealed_bid_per_user`, partial on
  `auction_type`), `UNIQUE(user_id, idempotency_key)`, type CHECK, key length 1–200.
- `auction_lots.leader_bid_id → bids` (English leader).

## Gotchas

- **Production needs three Railway variables before bidding goes live:**
  `ACTIVE_RECORD_ENCRYPTION_PRIMARY_KEY`, `ACTIVE_RECORD_ENCRYPTION_DETERMINISTIC_KEY`,
  `ACTIVE_RECORD_ENCRYPTION_KEY_DERIVATION_SALT` (generate with `bin/rails db:encryption:init`).
  Without them saving a bid raises. A human sets them (agents don't touch Railway). Losing or
  changing the keys makes stored bids unreadable.
- Development and test use fixed, public, non-secret keys in `config/environments/*.rb`.
- Encrypted attributes are filtered from logs automatically, but a **request param** named
  `amount` is not: #31 must add it to `config/initializers/filter_parameter_logging.rb` so
  sealed amounts never reach the logs.
- Append-only is enforced in the model (`readonly?` once saved, `before_update` /
  `before_destroy` raise). `Bid.delete_all` / `update_all` skip callbacks, so never call them;
  on Postgres the app's DB role should get no `UPDATE`/`DELETE` on `bids`. SQLite can't revoke
  privileges, and triggers would be lost by `schema.rb`, so it's model-only for now.
- `created_at` is written by Rails with microseconds (precision 6). On Postgres switch the
  default to `clock_timestamp()` as the design draft says.
- No SQL `ORDER BY amount`: the ciphertext sorts randomly. Always rank with `Bid.ranking`.

## References

- `app/models/bid.rb`, `db/migrate/20261111100000_create_bids.rb`, `test/models/bid_test.rb`
