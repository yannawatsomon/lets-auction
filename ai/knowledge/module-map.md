# Module map: where each part of the app lives
Last verified: 2026-11-11 (against `main` at `5fc6720`)

## Summary

lets-auction is one Rails app made of milestone "modules". Each module owns a URL prefix, a
layout, some controllers and models, and (for now) mock data. Modules touch each other only at a
few named seams. This file records what exists today; the rules we propose for new code are in
[`docs/decision/project-structure.md`](../../docs/decision/project-structure.md).

## Details

### Modules

| Module | URLs | Controllers | Layout / CSS | Domain code | Data today |
|---|---|---|---|---|---|
| Catalog (home) | `/`, `/catalog-preview` (dev) | `HomeController`, `CatalogPreviewsController`, concern `CatalogPage` | `application` / `catalog.css`, `catalog_preview.css` | `app/services/catalog/` (`DemoLots`, `Filters`, `Pagination`, `Sections`) | Synthetic `Catalog::DemoLots` |
| Payment | `/payment` (+ `quote`, `preview`) | `PaymentsController` | `application` / `application.css` | `MockPaymentOrder`, `PaymentQuote`, `PaymentSubmission` | One mock order |
| User onboarding (buyer) | `/user-onboarding` | `OnboardingsController`, `Onboarding::*` | `onboarding` / `onboarding.css` | `UserOnboarding`, `CreditAssessment`, `CreditScore`, `OnboardingScoring`, `ThaiNationalId`, `ThaiPhoneNumber`, `OnboardingStore` | In-memory, seeded from `db/mock/user_onboardings.yml` |
| Product onboarding (seller) | `/product-onboarding` | `ProductOnboarding::*` | `product_onboarding` / `application.css` | `app/models/product_onboarding/` (`Item`, `Review`, `MediaFile`, `UploadPolicy`, `Store`, `UploadStore`) | In-memory, seeded from `db/mock/product_items.yml` |
| Bidding | `/bidding/...`, `/admin/bidding/...` | `Bidding::*`, `Admin::Bidding::*` | `bidding`, `bidding_admin` / `bidding.css` | `app/services/bidding/` (incl. `Results`), `Auction*`, `Bid`, `AuditLog`, `Bidding::OrderStore`, jobs in `app/jobs/bidding/`, `Bidding::AuctionChannel` | Real tables in `db/schema.rb`; offers and orders are in-memory (`OrderStore`), rankings are computed from bids (no `lot_results` table) |
| Mock login (shared) | `/mock-login` | `MockSessionsController` | `application` | `MockData`, `Current`, `db/mock/users.yml` | YAML |

Naming for bidding is written down in [`bidding-conventions.md`](bidding-conventions.md).

### How the modules connect

```
                    Mock login  --->  Current.user  (every module reads it)

Product onboarding --[ AuctionItems ]--> Bidding <--[ BuyerStanding ]-- User onboarding
  (seller items,       approved items      |         grade + finished      (buyer grade A-E)
   ProductOnboarding::Store)               |         (OnboardingStore)
                                           |
                       [ Bidding::CatalogFeed ] (built, not wired yet)
                                           v
                                        Catalog   (home uses Catalog::DemoLots today)

Payment: standalone mock order. Not connected to bidding's orders (`Bidding::OrderStore`) yet;
admins mark them paid by hand (mock) until payment records real payments.
```

| Seam | Direction | What crosses | Notes |
|---|---|---|---|
| `AuctionItems` | Product onboarding → Bidding | Approved items (ids 201+), then bidding's YAML demo items | Moves a store item to `in_auction` on schedule and back on cancel or unsold |
| `BuyerStanding` | User onboarding → Bidding | Onboarding finished, grade, proof-of-income flag | Sealed needs A–D, English needs A with approved proof. Proof of income is bidding's own mock until #66 |
| `Bidding::CatalogFeed` | Bidding → Catalog | Public lot facts only (never bid amounts, counts, participants) | Catalog swaps `Catalog::DemoLots.call` for it in `CatalogPage#prepare_catalog` |
| `MockData` / `Current.user` | Mock login → all | The signed-in mock user | Replace when real auth lands (`docs/decision/auth.md`) |

Inside bidding: `Bidding::OpenAuction` / `CloseAuction` run from `Auction*Job` (and a
once-a-minute `AuctionSweepJob` in production), then `Bidding::Broadcaster` pushes events to
`Bidding::AuctionChannel`. Bids go through `Bidding::PlaceEnglishBid` / `PlaceSealedBid`.
After close, admins approve results (`Bidding::Results`, `/admin/bidding/auctions/:id/results`);
each lot is offered to rank 1 for 48 hours as an `OrderStore` order, `OrderExpireJob` moves it to
the next rank, and buyers see their own outcome at `/bidding/lots/:id/result`.

### Shared platform (change with care)

`ApplicationController` (mock user, `require_login`, error shape), `layouts/application`,
`application.css` (generic `.topbar`, `.btn`, `.card`, used by payment, product onboarding and
mock login), `shared/_flash`, `ApplicationHelper#baht`, `Baht`, `MockData`, `Current`, Solid
Queue, Solid Cable and the importmap/Stimulus setup. Propshaft loads every stylesheet on every
page, so scope selectors to a module (`.bidding`, `bidding-*`).

## Gotchas

These are facts about today's code, not defects to fix in one go:

- **Naming is uneven.** Only bidding is fully namespaced (`Bidding::`, `Admin::Bidding::`,
  `bidding_*`). The user-onboarding URL is `/user-onboarding` but its code is `Onboarding::`,
  `OnboardingsController` and `onboarding_*` helpers, next to a separate `ProductOnboarding::`.
- **Domain code lives in different places.** Bidding and catalog use `app/services/`; user
  onboarding and payment keep rules in top-level `app/models/`; product onboarding uses a
  `ProductOnboarding::` model namespace.
- **Admin pages exist only for bidding.** `ProductOnboarding::Review` models admin verification
  but has no admin pages yet.
- **Five mock stores, five patterns.** `MockData` (read-only YAML), `OnboardingStore`
  (writable, in memory), `ProductOnboarding::Store` (in memory), `Bidding::OrderStore` (in
  memory) and `BuyerStanding` (its own YAML). All reset on server restart. Replacement steps: [`mock-data.md`](mock-data.md).
- **Home page owner.** `/` is the catalog; there is no separate landing page.

## References

- `config/routes.rb`, `docs/decision/README.md`, `ai/knowledge/mock-data.md`,
  `ai/knowledge/bidding-conventions.md`, `ai/knowledge/catalog-sections.md`,
  `ai/knowledge/product-onboarding-integration-points.md`
