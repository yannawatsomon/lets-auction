# Bidding (sealed + English)

**Status:** Open (partly Decided, see below) · **Effort:** L · **Deadline risk:** High — every bidding model, endpoint, job
and test in the `bidding` milestone (#28–#37) depends on these answers

## Context

The `bidding` milestone covers both auction types from `scope.md`: first-price sealed bid and
invite-only English. Two sources describe bidding and disagree on several points:

- **Design draft**: [`docs/design/milestone-1-api-and-database.md`](../design/milestone-1-api-and-database.md)
  (2026-11-11).
- **SPEC**: a product spec (`SPEC.md` + `CLAUDE.md`) from a design session and team workshop
  (Nov 2026), shared by @guy127. It is not in the repo. It was written for a Go backend, so its
  stack choice is ignored here (`stack.md` is Decided: Rails); only its bidding rules are used.

The **Decisions** section was confirmed by @guy127 in chat on 2026-11-11 (issue #27).
Everything under **Proposals** is still a proposal; each bullet becomes Decided only when a
collaborator confirms it in a PR (see `README.md`).

## Decisions

- **Money is an integer number of satang.** What: `bigint` columns named `*_cents` (e.g.
  `amount_cents`, `min_price_cents`), formatted as THB with two decimals in views. Input
  without decimals gets `.00` added automatically: typing `500` means 500.00 THB =
  `50000` satang; `500.5` means 500.50 THB. More than two decimals is rejected. Why: no
  rounding errors in bid comparison or fees; one rule for every money column; users can type
  whole baht. Trade-off: deviates from the draft's `numeric(14,2)`; every column and API field
  needs the unit in its name; the form/API must convert baht text to satang. Alternative
  rejected: `numeric(14,2)` (exact too, but mixing it with integer math in Ruby invites bugs).
  Source: SPEC invariant 4; confirmed by @guy127, 2026-11-11.
- **Sealed: bidders never see the bid count before results are published.** What: no
  bidder-facing page, API response or channel shows how many bids (or bidders) a sealed lot
  has, nor anyone else's amount; a bidder sees only their own bid receipt. Admin pages may
  show the count. Once the auction is `published`, bidders may see the bid count. Why: the count leaks demand and helps nobody bid honestly. Trade-off: less
  "activity" signal for bidders. Alternative rejected: SPEC's public `bid_count`. Source:
  draft; confirmed by @guy127, 2026-11-11.
- **Sealed amounts are encrypted at rest, no nonce column.** What: Active Record Encryption on
  the sealed amount column; ranking decrypts in `LotCloseJob` only. No `nonce` column, since
  the commitment hash is not being built. Why: a DB dump or a stray query must not reveal open
  bids; Rails ships this, no new gem. Trade-off: can't sort or index by amount in SQL for
  sealed lots, so ranking happens in Ruby (≤ a few hundred bids per lot, fine); adding a hash
  later needs a migration and old bids would have none. Alternative rejected: plain column +
  DB permissions only (draft) — weaker against dumps and admin queries. Source: SPEC invariant
  6; confirmed by @guy127, 2026-11-11.
- **English extensions stop 30 minutes after the original end.** What: the anti-sniping rule
  (a bid with ≤ 120 s left moves `ends_at` to `now() + 120 s`) applies only while the new
  `ends_at` would be ≤ `original_ends_at + 30 min`; the lot keeps `original_ends_at` for this.
  The last extension is clamped to that limit. Why: a lot must not run forever in a bidding
  war. Trade-off: a bid in the final seconds after the cap can still "snipe". Alternative
  rejected: no cap (earlier proposal); cap by number of extensions. Source: confirmed by
  @guy127, 2026-11-11.
- **No deposit or KYC for now, including ฿20M+ English lots.** What: invite + accept is the
  only gate. Why: no collateral system exists; the admin chooses who is invited. Trade-off: a
  winner who never pays costs time (the lot passes to the next rank). Source: confirmed by
  @guy127, 2026-11-11 ("not yet"; revisit before real high-value use).
- **No two-admin reveal and no commitment hash.** What: one admin can view sealed rankings
  once the lot is `closed`; bid receipts carry no hash. Why: few admins; the hash only adds
  value if bidders verify it. Trade-off: one person can see sealed amounts before results
  are published; no user-verifiable proof a bid wasn't changed. Alternative rejected: SPEC
  phase 2 two-admin reveal and `sha256(...)` receipt. Source: confirmed by @guy127, 2026-11-11.

## Proposals — both auction types
- **Server time only.** What: open/close checks use the database `now()`; bid ordering uses
  `clock_timestamp()` at insert. Clients get `server_time` for countdowns and never send a
  time. Source: draft and SPEC agree.
- **Ties go to the earliest bid.** What: rank by `amount DESC, created_at ASC`. Source: draft
  and SPEC agree.
- **Bids are append-only and cannot be withdrawn.** What: no update/delete in the model; in
  production the app's DB role has no `UPDATE`/`DELETE` on `bids`. Why: bids are the evidence
  for every result. Source: draft (append-only); SPEC (no withdrawal).
- **Every bid needs an `Idempotency-Key` header.** What: `UNIQUE(user_id, idempotency_key)`;
  a repeat key returns the first response. Source: draft and SPEC agree.
- **Sellers cannot bid on their own items.** What: checked inside the bid transaction, and
  sellers cannot register for or accept an invitation to an event that contains their item.
  Detecting linked accounts (same IP/device) is out of scope for this milestone. Source: draft
  and SPEC; linked-account detection is SPEC phase 3.
- **No OTP, deposit, credit limit or tier check before bidding in this milestone.** Why: no
  SMS provider or collateral system exists yet; `scope.md` proposes no deposit/KYC for
  Milestone 1. Trade-off: no protection against a winner who doesn't pay (see Open questions).
  Alternative rejected: SPEC's OTP + credit-lock flow (blocked on providers and on the
  collateral decision). Source: draft; SPEC lists collateral as undecided.
- **One endpoint for both types.** What: `POST /lots/:id/bids`; the logic branches on the
  auction type. WebSocket only pushes state. Why: validation and idempotency live in one place.
  Source: draft, `realtime.md`.

## Proposals — sealed (first-price)

- **One bid per user per lot, enforced by the database.** What: partial unique index on
  `bids (lot_id, user_id)` for sealed lots, not only a check in Ruby. Source: draft and SPEC
  agree.
- **Bid amount must be ≥ the lot's minimum price.** No upper limit in this milestone (the
  SPEC's "≤ remaining credit" depends on the credit system above).
- Visibility, encryption, commitment hash and admin reveal: see **Decisions** above.

## Proposals — English (invite-only)

- **Admin invites each buyer; the buyer must accept before bidding.** Source: draft, `scope.md`.
- **Fixed increment per lot.** What: the admin sets `bid_increment_cents` per lot; a bid must be
  ≥ `current_price + increment` (first bid ≥ minimum price). Alternative rejected: tiered
  increments by price band (more rules, not needed for 3 lots). Source: draft.
- **The current leader cannot bid again.** Source: draft.
- **Anti-sniping extension.** What: a bid with ≤ 120 s left moves that lot's `ends_at` to
  `now() + 120 s`, capped at 30 minutes after the original end (see **Decisions**). Source:
  draft, `scope.md`.
- **No proxy/auto-bid.** Why: keeps the bid path simple and auditable. Source: proposed here.
- **Concurrency via row lock.** What: `SELECT … FOR UPDATE` on the lot row, then validate,
  insert the bid, update `current_price` / `leader_bid_id` / `bid_count`, write the audit log,
  commit, and only then broadcast. Source: draft.
- **Visible during bidding:** current price, next minimum bid, bid count, masked leader name,
  masked bid history. Source: draft.
- **Ranking uses each bidder's highest bid only.** Source: draft.

## Rules / examples

Bid validation order (one transaction):

| Step | Sealed | English |
|---|---|---|
| 1 | buyer, active, `registered` participant | buyer, active, `accepted` participant |
| 2 | lot `live` and `now() < ends_at` | same, after `FOR UPDATE` on the lot |
| 3 | not the item's seller | not the item's seller |
| 4 | `amount >= min_price`; no previous bid (DB index backs this) | `amount >= current_price + increment` (or `>= min_price` for the first bid); not the current leader |
| 5 | — | extend `ends_at` if ≤ 120 s left, to `min(now() + 120 s, original_ends_at + 30 min)` |
| 6 | insert bid + audit log, commit | insert bid, update lot + audit log, commit, broadcast |

Error codes (`{ "error": "...", "message": "<Thai>" }`): `not_registered`, `not_invited`,
`bidding_closed`, `own_item`, `amount_below_start`, `already_bid`, `bid_too_low`,
`already_leading`, `idempotency_conflict`.

Amount input → satang:

| Typed | Means | Stored `*_cents` |
|---|---|---|
| `500` | 500.00 THB | `50000` |
| `500.5` | 500.50 THB | `50050` |
| `1,250.75` | 1,250.75 THB | `125075` |
| `500.123` | rejected (more than two decimals) | — |

## Open questions

- **Remaining proposals** (everything under Proposals) still need a collaborator to confirm.
- **Deposit or KYC** — revisit before real ฿20M+ use (decided "not yet").
- Real-time and job runtime: see `realtime.md` (proposal: Solid Queue inside Puma at first).
