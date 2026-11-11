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
- Encrypted attributes are filtered from logs automatically; the `amount` **request param** is
  filtered too (`config/initializers/filter_parameter_logging.rb`, #31). Keep it that way.
- Append-only is enforced in the model (`readonly?` once saved, `before_update` /
  `before_destroy` raise). `Bid.delete_all` / `update_all` skip callbacks, so never call them;
  on Postgres the app's DB role should get no `UPDATE`/`DELETE` on `bids`. SQLite can't revoke
  privileges, and triggers would be lost by `schema.rb`, so it's model-only for now.
- `created_at` is written by Rails with microseconds (precision 6). On Postgres switch the
  default to `clock_timestamp()` as the design draft says.
- No SQL `ORDER BY amount`: the ciphertext sorts randomly. Always rank with `Bid.ranking`.

## Placing a sealed bid (#31)

- `Bidding::PlaceSealedBid` runs the checks in one transaction (participant → open by server
  time → not the seller → ≥ minimum → no earlier bid → insert → `AuditLog`).
- Open/closed is decided by **time**: `AuctionLot#accepting_bids?(now)` = auction and lot not
  cancelled/closed and `starts_at <= now < ends_at`. Bids work before the open/close jobs
  (#35) exist; the jobs only move statuses.
- Idempotency: `Idempotency-Key` header (JSON) or the form's hidden `idempotency_key`. Same
  buyer + key + lot + amount → the first bid again (200); same key, different lot/amount →
  409 `idempotency_conflict`.
- HTML flow: bid room `/bidding/lots/:id` → `POST …/bids/review` (saves nothing) →
  `POST …/bids`. Countdown (`bidding-countdown` Stimulus controller) uses the server time
  sent with the page, never the browser clock as truth.

## Placing an English bid (#32)

- Same endpoint (`POST /bidding/lots/:id/bids`); `Bidding::PlaceEnglishBid` when the auction is
  English. Shared bits (key, baht → satang, replay, not-the-seller) live in
  `Bidding::BidRequest`.
- Order in one transaction: `lock!` the lot → invited **and accepted** → open by server time
  (no extensions) → not the seller → not the current leader → amount ≥
  `AuctionLot#next_minimum_cents` (first bid = minimum price, then current price + increment)
  → insert → update `current_price_cents`, `leader_bid_id`, `bid_count` → audit log.
- The lot update is a compare-and-set on `bid_count`; if another bid moved the lot first, the
  bid is rolled back with `price_moved` (409). This keeps it correct even where row locks are
  ignored (SQLite) — Rails 8 also runs SQLite write transactions as IMMEDIATE.
- Error codes: `not_invited`, `bidding_closed`, `own_item`, `already_leading`, `bid_too_low`,
  `price_moved`, `idempotency_conflict`.
- Gotcha for tests: `travel_to` drops sub-seconds, so `travel_to(auction.ends_at)` can land
  just *before* the end. Use `ends_at + 1.second` to test "closed".

## Live updates (#33)

- `Bidding::AuctionChannel` (`{ channel: "Bidding::AuctionChannel", auction_id }`): admins, or
  active participants (registered sealed / accepted English). Everyone else is rejected.
  Streams: `bidding:auction:<id>` and, for buyers, `bidding:auction:<id>:user:<user_id>`.
- `Bidding::Broadcaster` builds every message. `lot.state` on subscribe (with `server_time`);
  `bid.accepted` + `bid.outbid` (to the old leader only) after an English bid **commits**;
  `lot_closed` / `result_published` are ready for #35 / #36. Sealed auctions get no bid events
  and their `lot.state` has no price or count. Leaders are masked as "ผู้ประมูล N" (position in
  the participant list).
- `ApplicationCable::Connection` reads the mock user from the encrypted session cookie with the
  same rules as `ApplicationController` (production: sellers only, behind the flag).
- Gotchas: the cable test cookie jar can't hold encrypted cookies, so the session lookup is
  `Connection.user_from_session` and is tested directly, plus one integration test that decrypts
  the real login cookie. When building an `HTTP_COOKIE` header by hand, `CGI.escape` the value.

## English live room (#34)

- `bidding/lots/_english_panel` renders the current state; the `bidding-live-lot` Stimulus
  controller (`app/javascript/controllers/bidding_live_lot_controller.js`) subscribes to
  `Bidding::AuctionChannel` and updates price, next minimum, count, masked leader, "you're
  leading" / outbid, closed state, and reloads the history fragment after each `bid.accepted`.
  On reconnect the channel re-sends `lot.state`, so the page catches up.
- "Am I leading?" works without user ids on the socket: the page gets the viewer's own masked
  label (`BidHistory#viewer_label`) and compares it with the broadcast leader.
- History: `GET /bidding/lots/:id/bids` (`LotsController#history`), English only, invited or
  admin, newest first, 20 per page, HTML fragment or JSON. Sealed lots → 404.
- `@rails/actioncable` is pinned from the Rails gem's own `actioncable.esm.js` (no npm, no gem).
- The bid form stays in the page while you lead (hidden), so it can reappear when you're outbid.
- No browser/system tests yet (`test/system/` doesn't exist); the JS is checked by
  `node --check` only. Try it by hand: two browsers, two invited buyers, one English lot.

## Opening, closing and ranking (#35)

- `Auction#schedule!` enqueues `Bidding::AuctionOpenJob` at `starts_at` and
  `Bidding::AuctionCloseJob` at `ends_at`. A job that runs early re-enqueues itself for the right
  time; one for a cancelled/missing auction does nothing.
- `Bidding::OpenAuction` → auction and lots `live`, broadcasts `lot.state`.
  `Bidding::CloseAuction` → every open lot closes together (no extensions): a lot with bids →
  `closed`, no bids → `unsold` and the product back to `approved`; auction →
  `awaiting_approval`; `lot.closed` broadcast after commit. Both are idempotent and audit-logged.
- Ranking is **not stored**: `AuctionLot#results` computes it from `bids` with `Bid.ranking`
  (English: each bidder's best), rank 1 = would-be winner. No `lot_results` table (created by
  #96, dropped by `20261111130000_drop_lot_results`) — the team
  adds no new tables for now (`bidding.md`); offers/payment state for #36 go in mock data.
- Safety net: `bidding_auction_sweep` in `config/recurring.yml` (production, every minute)
  runs `Bidding::AuctionSweepJob` for anything due.
- `Result#amount_cents` reads the amount through the bid; it stays encrypted in `bids`.
- Bids never wait for these jobs: `AuctionLot#accepting_bids?` checks server time itself, and
  a lot that the job has closed refuses bids too.
- **Production needs a job runner:** set `SOLID_QUEUE_IN_PUMA=1` on Railway (or run a separate
  worker) or nothing opens/closes and the sweep never runs. A human sets it (agents don't touch
  Railway); see `docs/decision/realtime.md`.

## Audit log (shared)

`audit_logs` / `AuditLog.record!(action:, entity:, actor:, data:)` is append-only and meant for
every milestone. `data` is **plain text**: store ids and public facts, never sealed amounts,
national IDs or slips.

## References

- `app/models/bid.rb`, `db/migrate/20261111100000_create_bids.rb`, `test/models/bid_test.rb`
