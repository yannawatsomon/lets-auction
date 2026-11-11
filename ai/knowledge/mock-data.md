# Mock users and items (temporary)
Last verified: 2026-11-11

**Why:** the `bidding` milestone (#28–#37) started before `users` (auth / user onboarding) and
`items` (product onboarding) exist on `main`. The user chose to build bidding on mock data
instead of waiting or stubbing those tables (2026-11-11).

**What exists:**

- `db/mock/users.yml`, `db/mock/items.yml` — fake people and products only (public repo).
  Money is satang (`min_price_cents`), see `docs/decision/bidding.md`.
- `MockData` (`app/models/mock_data.rb`) — read-only `MockData.user(id)`, `MockData.item(id)`,
  `MockData.approved_items`. Bidding code reaches users/items only through these, plus
  `AuctionLot#item` and `Auction#created_by`.
- Mock login at `/mock-login/new` (`MockSessionsController`): pick a user, stored in
  `session[:mock_user_id]`, exposed as `Current.user`.
- **User onboarding (#16):** `OnboardingStore` (`app/models/onboarding_store.rb`) keeps
  `UserOnboarding` and `CreditAssessment` in memory, seeded from
  `db/mock/user_onboardings.yml`. Unlike `MockData` it is writable: `find` returns a copy,
  `save` validates and enforces one national ID per account, `add_assessment` only appends.
  Seeded buyers: 21 → A, 22 → B, 23 → C, 24 → D, 25 → E (all `completed`), 26 → not started.
  National IDs are fake but pass the mod 11 check.

**Safety:** the mock login route is drawn only when `Rails.env.local?` (development/test), and
`ApplicationController#mock_login_enabled?` returns false in production, so production has no
logged-in user and every admin page answers 404. Do not add an env-var switch that enables the
full mock login in production.

**One exception (2026-11-11, `docs/decision/product-onboarding.md`):** setting the Railway
variable `MOCK_PRODUCT_ONBOARDING=true` (`config/initializers/mock_product_onboarding.rb`)
serves `/product-onboarding` and the mock login in production, but only **sellers** can sign in
there (`ApplicationController#set_current_user` drops any other mock user outside
development/test). Admin pages therefore stay 404. Remove the variable when real auth lands.

**Gotchas:**

- `auctions.created_by_id` and `auction_lots.item_id` have no foreign key yet. Mock items never
  change status, so an item added to a lot stays `approved` in the YAML; the partial unique
  index `one_open_lot_per_item` is what stops it being in two unfinished lots.
- IDs are plain integers (SQLite default), not the design draft's UUIDs.
- `OnboardingStore` lives in process memory: a server restart resets it, and each Puma worker
  or parallel test process has its own copy. Tests call `OnboardingStore.reset!` in `setup`.
- The step 1 rate limit (`Onboarding::IdentitiesController::RATE_LIMIT_STORE`) is also an
  in-process `MemoryStore`, because the test env's cache is `:null_store` and would never
  limit. Integration tests clear it in `setup`. Move it to the shared cache with the database.

**Replacing it (when users/items land):**

1. Swap `MockData.user` / `MockData.item` calls for `User` / `Item` (search for `MockData`).
2. Add foreign keys: `auctions.created_by_id → users`, `auction_lots.item_id → items`.
3. Set `items.status` to `in_auction` when a lot is scheduled, back to `approved` when it
   ends unsold or is cancelled (design draft state machine).
4. Onboarding: add `user_onboardings` (national ID encrypted + digest unique) and
   `credit_assessments` (append-only) tables, make `UserOnboarding` an ActiveRecord model, and
   replace `OnboardingStore` calls (search for `OnboardingStore`).
5. Delete `db/mock/`, `MockData`, `OnboardingStore`, `MockSessionsController`, its view and
   route, and this file.
