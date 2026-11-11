# Real-time updates and scheduled jobs

**Status:** Open · **Effort:** M · **Deadline risk:** High — English auction correctness depends on it

## Context

`stack.md` lists the real-time mechanism as open. The design draft
[`docs/design/milestone-1-api-and-database.md`](../design/milestone-1-api-and-database.md)
needs live price updates for English lots and timed jobs (open auction, close lot, expire
order, payment reminders). Its first version named BullMQ / pg-boss, which are Node.js
libraries and conflict with `stack.md`. The Rails app already ships `solid_cable` and
`solid_queue` (`Gemfile`, `config/cable.yml`, `config/environments/production.rb`).

## Proposals

- **Live updates via Action Cable on Solid Cable.** What: an `AuctionChannel` per auction pushes
  `lot.state`, `bid.accepted`, `bid.outbid`, `lot.extended`, `lot.closed`,
  `auction.result_published`. Bids are still placed with `POST /lots/:id/bids` so validation and
  idempotency live in one place. Why: already in the stack, no extra service. Trade-off: Solid
  Cable polls the database (0.1 s in `config/cable.yml`); fine for a few live lots, revisit if
  load grows. Alternative rejected: a separate Node WebSocket server (violates `stack.md`).
- **Timed work via Active Job on Solid Queue.** What: `AuctionOpenJob`, `LotCloseJob`,
  `OrderExpireJob`, `PaymentReminderJob`, scheduled with `set(wait_until:)`. Because an English
  lot's `ends_at` can move, `LotCloseJob` re-reads `ends_at` when it runs and re-enqueues itself
  if the lot was extended, instead of cancelling jobs. Trade-off: needs a worker running in
  production. Alternative rejected: BullMQ / pg-boss (Node.js, violates `stack.md`).

- **Sealed lots use no WebSocket for bids.** What: `AuctionChannel` sends only `lot.state`,
  `lot.closed` and `auction.result_published` for sealed lots; the page counts down from
  `server_time`. Why: any per-bid event would leak bid activity (see `bidding.md`). Source:
  design draft, `bidding.md` proposal (#27).
- **Run Solid Queue inside Puma at first.** What: `SOLID_QUEUE_IN_PUMA` (already wired in
  `config/puma.rb`), one Railway service. Why: simplest setup for a few live lots. Trade-off:
  a web restart also restarts the job runner; `LotCloseJob` must be idempotent anyway.
  Alternative: a separate worker service, once load or reliability needs it. Source: proposed
  in `bidding.md` (#27).

## Open questions

- Railway: run jobs inside Puma (`SOLID_QUEUE_IN_PUMA`, already wired in `config/puma.rb`) or as
  a separate worker service?
- Raw Action Cable JSON vs Turbo Streams — depends on the frontend approach in `stack.md`.
- Production database for the cable and queue tables (see `stack.md`).
