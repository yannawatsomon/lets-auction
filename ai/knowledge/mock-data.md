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

**Safety:** the mock login route is drawn only when `Rails.env.local?` (development/test), and
`ApplicationController#mock_login_enabled?` returns false in production, so production has no
logged-in user and every admin page answers 404. Do not add an env-var switch to enable it in
production.

**Gotchas:**

- `auctions.created_by_id` and `auction_lots.item_id` have no foreign key yet. Mock items never
  change status, so an item added to a lot stays `approved` in the YAML; the partial unique
  index `one_open_lot_per_item` is what stops it being in two unfinished lots.
- IDs are plain integers (SQLite default), not the design draft's UUIDs.

**Replacing it (when users/items land):**

1. Swap `MockData.user` / `MockData.item` calls for `User` / `Item` (search for `MockData`).
2. Add foreign keys: `auctions.created_by_id → users`, `auction_lots.item_id → items`.
3. Set `items.status` to `in_auction` when a lot is scheduled, back to `approved` when it
   ends unsold or is cancelled (design draft state machine).
4. Delete `db/mock/`, `MockData`, `MockSessionsController`, its view and route, and this file.
