# Scope (Milestone 1)

**Status:** Open · **Effort:** L · **Deadline risk:** High — every model, endpoint and screen depends on it

## Context

What Milestone 1 must do. The rules below come from the design draft
[`docs/design/milestone-1-api-and-database.md`](../design/milestone-1-api-and-database.md)
(2026-11-11). They are **proposals**: Why / Trade-off / Alternative are filled in where the
draft gives them, and each bullet becomes Decided only when a collaborator confirms it in a PR.

## Proposals

- **Two auction types in one app.** What: first-price sealed bid for items up to 20,000 THB;
  English (ascending) auction, invite-only, for 3 items of 20M THB or more. Trade-off: two
  bidding rule sets in one codebase. Source: design draft, 2026-11-11.
- **One account = one role** (buyer, seller or admin), chosen at sign-up. Trade-off: someone
  who both buys and sells needs two accounts. Source: design draft, 2026-11-11.
- **Seller sets the minimum price; admin cannot change it.** What: admin can only approve,
  reject or request more evidence. Source: design draft, 2026-11-11.
- **An event holds up to 10 lots that start and end together; each lot has its own winner.**
  English lots can be extended individually (see bidding rules). Why: an unsold item can be
  listed again in a new event, so items and lots are separate records. Source: design draft,
  2026-11-11.
- **Participation.** What: sealed — buyer registers for the event before bidding; English —
  admin invites each buyer. No deposit or KYC in Milestone 1. Trade-off: no protection against
  a winner who never pays on a 20M THB lot. Source: design draft, 2026-11-11.
- **Sealed bidding.** What: one bid per lot, nobody's amount or the bid count is visible until
  results are published; a tie goes to the earliest bid. Source: design draft, 2026-11-11.
- **English bidding.** What: live price updates; a bid in the last 2 minutes extends that lot by
  2 minutes, up to 30 minutes past the original end (`bidding.md`). Why: stops last-second
  sniping. Source: design draft, 2026-11-11; cap confirmed by @guy127, 2026-11-11.
- **Results need admin approval; winner pays within 48 hours.** What: if the winner doesn't pay
  or declines, the next rank is offered the lot at their own bid, as long as it is at or above
  the minimum price; if nobody is left the lot is unsold. Source: design draft, 2026-11-11.
- **Payment by uploaded slip.** What: buyer uploads a transfer slip (cash only for pickup),
  admin verifies it, the platform holds the money and records the payout to the seller.
  Trade-off: manual admin work per order. Alternative rejected: payment gateway (not in
  Milestone 1). Source: design draft, 2026-11-11.

- **Product media limits.** What: each item has 1 to 5 images (required) and 0 to 2 videos
  (optional); verification documents are separate and have no limit yet. The API enforces the
  counts. Why: the draft already caps images at 5; a minimum of 1 means buyers and the admin
  always have something to look at. Trade-off: a seller with only a video or a document cannot
  list. Source: onboarding flow draft
  [`docs/design/product-onboarding-flow.md`](../design/product-onboarding-flow.md), 2026-11-11
  (the 5-image cap is from the Milestone 1 design draft; the video cap and image minimum are new).
  File formats, sizes, documents and the rest of the onboarding rules are proposed in
  [`product-onboarding.md`](product-onboarding.md).

## Open questions

- Product media: file formats and sizes, a limit on documents, and whether the 20M THB English
  items must include documents → answered as proposals in
  [`product-onboarding.md`](product-onboarding.md), waiting for a collaborator to confirm.
- Page 6 shows a credit card option, but Milestone 1 uses slips. Hide it until a gateway exists?
- Is there a platform fee (deducted from the seller or added for the buyer)? If yes, `orders`
  and `payouts` need a `fee` column.
- Is "next rank pays their own bid" correct?
- ~~Deposit or KYC for the 20M THB English lots — needed before launch?~~ Not for now, see `bidding.md` Decisions (2026-11-11).
- Who confirms these proposals? (Then fill `ai/context/project.md`.)
