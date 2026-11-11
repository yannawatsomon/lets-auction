# Project structure

**Status:** Open · **Effort:** M · **Deadline risk:** Low — conventions only, no code has to move now

## Context

The app grew milestone by milestone (catalog, payment, user onboarding, product onboarding,
bidding) and each team picked its own layout for names, files and data. Nothing says where a new
module goes or how modules may reach each other, and bidding is the only one with written
naming rules (`ai/knowledge/bidding-conventions.md`). What exists today is in
[`ai/knowledge/module-map.md`](../../ai/knowledge/module-map.md). This file proposes the rules;
it is about how the code is laid out, not about anyone's agent workflow or tools.

## Decisions

All of these are **proposed**. A collaborator confirms them (Open → Decided) in a PR.

- **A module is one milestone with one short name, and everything it adds carries that name.**
  What: URL prefix, route helpers, controller namespace, view directory, layout, CSS prefix,
  helper methods, `app/services/<module>/` and jobs all use the same name, as bidding already
  does (`bidding-conventions.md` is the template). Why: names can't clash and a module can be
  found by searching its name. Trade-off: some existing code (user onboarding, payment) doesn't
  match yet. Alternative rejected: renaming everything at once (a big PR that conflicts with
  every open branch); instead, rename a module only when its team is already changing it.
- **Modules reach each other only through a named seam.** What: one class or method per
  direction, documented in the seams table of `module-map.md` (today `AuctionItems`,
  `BuyerStanding`, `Bidding::CatalogFeed`). A module does not read another module's tables,
  stores or private classes directly, and a seam returns only what the other side needs (the
  catalog feed never carries bid amounts). Why: the consumer changes in one place when the
  producer's mock data becomes a real table. Trade-off: one more small class per link.
  Alternative rejected: calling models across modules freely (what makes mock-data replacement
  touch every module).
- **Shared platform code is listed, and changed with care.** What: the list in `module-map.md`
  ("Shared platform"). A module may add to `application.css` or the shared helpers only if the
  addition is generic; module-specific styles go in the module's own stylesheet and are scoped
  to it (Propshaft loads all stylesheets on every page). Why: one module's selector must not
  restyle another module's page.
- **Mock data stays behind its seam and is listed.** What: every mock store is named in
  `ai/knowledge/mock-data.md` with the step that replaces it. Why: the mock layer is temporary
  and is the main coupling between modules today.
- **Where things are written down.** What: the cross-module picture is
  `ai/knowledge/module-map.md`; per-module naming and gotchas go in
  `ai/knowledge/<module>-conventions.md`; choices with a reason go in `docs/decision/`. Update
  the map when a seam, URL prefix or layout is added or changed.

## Rules / examples

New module `payment` following the first rule: `/payment`, helpers `payment_*`, controllers
`Payment::*`, views `app/views/payment/`, layout `payment`, `payment.css` with `payment-*`
classes, `app/services/payment/`. Today it is `PaymentsController` and `application.css`; that is
fine until the payment team next changes it.

## Open questions

- Name for the buyer flow: keep `Onboarding::` in code with `/user-onboarding` in the URL, or
  rename code to `UserOnboarding::` to sit beside `ProductOnboarding::`? Owner: user onboarding
  team.
- Is `app/services/<module>/` the home for domain logic (bidding, catalog) or `app/models/`
  (user onboarding, payment)? Pick one for new code.
- Admin pages: always `Admin::<Module>::` with a `<module>_admin` layout (bidding), or one shared
  admin area? Product onboarding needs admin review pages soon.
- Which module owns `/` once the catalog uses real lots?
