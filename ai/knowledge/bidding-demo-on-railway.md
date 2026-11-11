# Bidding demo on Railway
Last verified: 2026-11-11

## Summary

How to let the team try the bidding pages on the Railway URL before real auth exists. A human
does every Railway step (agents don't change Railway). Decision: `docs/decision/bidding.md`
("Bidding demo on Railway behind a flag and a password").

## Details

1. **Railway → the app service → Variables**, add:
   - `MOCK_BIDDING` = `true`
   - `MOCK_BIDDING_PASSWORD` = a password of 12+ characters, shared with the team privately
     (never in the repo, a PR or chat logs)
   - `ACTIVE_RECORD_ENCRYPTION_PRIMARY_KEY`, `ACTIVE_RECORD_ENCRYPTION_DETERMINISTIC_KEY`,
     `ACTIVE_RECORD_ENCRYPTION_KEY_DERIVATION_SALT` — generate locally with
     `bin/rails db:encryption:init` and paste the three values. Keep them: losing or changing them
     makes stored bids unreadable.
   - `SOLID_QUEUE_IN_PUMA` = `1` — runs the open/close/expiry jobs inside the web process.
2. Redeploy (Railway does it when variables change).
3. Optional demo data: Railway → service → run `bin/rails bidding:demo_seed` (Railway shell /
   one-off command). It replaces auctions titled "ตัวอย่าง:" and touches nothing else. Without
   it, log in as an admin and build an auction through the UI.
4. Open `https://<your-app>.up.railway.app/mock-login/new`, type the demo password, pick a user:
   - "แอดมิน A" → `/admin/bidding/auctions`
   - "ผู้ซื้อ B-04" (grade A) → `/bidding/auctions`, the English room, invitations
   - two browsers (two buyers) to watch the English price update live

## Gotchas

- Anyone with the password can act as an admin on production. Treat production as demo data while
  `MOCK_BIDDING` is on; remove both variables when real auth lands.
- Mock users, grades, products and offers live in memory: a redeploy or restart resets them
  (auctions and bids are in the database and stay).
- Railway terminates TLS; `config.force_ssl` / `assume_ssl` are still off (see the #37 review in
  `bidding-bids.md`) — worth turning on before sharing the URL widely.
- `MOCK_PRODUCT_ONBOARDING` is separate: on its own it still allows sellers only.

## References

- `config/initializers/mock_bidding_demo.rb`, `app/controllers/mock_sessions_controller.rb`,
  `lib/tasks/bidding_demo.rake`, `test/integration/bidding_demo_mode_test.rb`
