# Bidding (sealed + English)

**Status:** Open · **Effort:** L · **Deadline risk:** High — every bidding model, endpoint, job
and test in the `bidding` milestone (#28–#37) depends on these answers

## Context

The `bidding` milestone covers both auction types from `scope.md`: first-price sealed bid and
invite-only English. Two sources describe bidding and disagree on several points:

- **Design draft**: [`docs/design/milestone-1-api-and-database.md`](../design/milestone-1-api-and-database.md)
  (2026-11-11).
- **SPEC**: a product spec (`SPEC.md` + `CLAUDE.md`) from a design session and team workshop
  (Nov 2026), shared by @guy127. It is not in the repo. It was written for a Go backend, so its
  stack choice is ignored here (`stack.md` is Decided: Rails); only its bidding rules are used.

Everything below is a **proposal**. Each bullet becomes Decided only when a collaborator
confirms it in a PR (see `README.md`). Tracking issue: #27.

## Proposals — both auction types

- **Money is an integer number of satang.** What: `bigint` columns named `*_cents` (e.g.
  `amount_cents`, `min_price_cents`), formatted as THB only in views. Why: no rounding errors in
  bid comparison or fees; one rule for every money column. Trade-off: deviates from the draft's
  `numeric(14,2)`; every column and API field needs the unit in its name. Alternative rejected:
  `numeric(14,2)` (exact too, but mixing it with integer math in Ruby invites bugs). Source:
  SPEC invariant 4.
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
- **Nothing about other bids is visible before results are published.** What: no API,
  page or channel returns other people's amounts **or the bid count** for a sealed lot until
  the auction is `published`. A bidder sees only their own bid receipt. Why: the count leaks
  demand and helps nobody bid honestly. Trade-off: the SPEC allows showing `bid_count`.
  Alternative rejected: showing the count (SPEC). Source: draft.
- **Sealed amounts are encrypted at rest.** What: Active Record Encryption on the sealed
  amount column; ranking decrypts in `LotCloseJob` only. Why: a DB dump or a stray query must
  not reveal open bids; Rails ships this, no new gem. Trade-off: can't sort or index by amount
  in SQL for sealed lots, so ranking happens in Ruby (≤ a few hundred bids per lot, fine).
  Alternative rejected: plain column + DB permissions only (draft) — weaker against dumps and
  admin queries. Source: SPEC invariant 6 (encrypt the amount).
- **Commitment hash is deferred.** What: SPEC's
  `sha256(lot_id | user_id | amount | nonce | submitted_at)` on the bid receipt is not built in
  this milestone. Why: it adds value only once bidders can verify it after reveal; the receipt
  page can add it later without a data migration if the nonce column exists from the start.
  Trade-off: no user-verifiable proof that a bid wasn't changed. Proposed: add a `nonce`
  column now, compute the hash later. Source: SPEC; deferral proposed here.
- **One admin can view rankings once the lot is closed; two-admin reveal is deferred.**
  What: the admin results page works when the lot is `closed`. Why: the team has few admins
  for now and the draft assumes one. Trade-off: one person can see sealed amounts before
  results are published. Alternative rejected for now: SPEC's two different admins approving
  the reveal (SPEC phase 2). Source: draft.

## Proposals — English (invite-only)

- **Admin invites each buyer; the buyer must accept before bidding.** Source: draft, `scope.md`.
- **Fixed increment per lot.** What: the admin sets `bid_increment_cents` per lot; a bid must be
  ≥ `current_price + increment` (first bid ≥ minimum price). Alternative rejected: tiered
  increments by price band (more rules, not needed for 3 lots). Source: draft.
- **The current leader cannot bid again.** Source: draft.
- **Anti-sniping extension.** What: a bid with ≤ 120 s left moves that lot's `ends_at` to
  `now() + 120 s`. No cap on the number of extensions (see Open questions). Source: draft,
  `scope.md`.
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
| 5 | — | extend `ends_at` if ≤ 120 s left |
| 6 | insert bid + audit log, commit | insert bid, update lot + audit log, commit, broadcast |

Error codes (`{ "error": "...", "message": "<Thai>" }`): `not_registered`, `not_invited`,
`bidding_closed`, `own_item`, `amount_below_start`, `already_bid`, `bid_too_low`,
`already_leading`, `idempotency_conflict`.

## Open questions

- **Deposit or KYC for the ฿20M+ English lots** before real use? Without it a winner who never
  pays only costs time (the lot passes to the next rank). Owner: team. Blocks: launch, not code.
- **Cap on English extensions?** (e.g. stop extending after 30 minutes past the original end.)
  Blocks: #32.
- **Confirm satang `bigint`** over the draft's `numeric(14,2)`. This also affects
  `items.min_price` in the product onboarding milestone. Blocks: #28, #30.
- **Confirm "no bid count before publish"** for sealed lots (draft) over SPEC's `bid_count`.
  Blocks: #31.
- **Confirm encryption of sealed amounts** (and adding `nonce` now). Blocks: #30.
- **When to add two-admin reveal and commitment hash** — next milestone or later?
- Real-time and job runtime: see `realtime.md` (proposal: Solid Queue inside Puma at first).
