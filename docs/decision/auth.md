# Authentication

**Status:** Open · **Effort:** M · **Deadline risk:** Medium — every non-public endpoint needs it

## Context

`stack.md` lists the auth approach as open. The design draft
[`docs/design/milestone-1-api-and-database.md`](../design/milestone-1-api-and-database.md)
proposes JWT. The right choice depends on the frontend approach (also open in `stack.md`):
a separate client calling a JSON API, or Rails-rendered pages with Hotwire.

## Options

- **A. JWT access + refresh tokens** (design draft). What: `/api/v1/auth/*`, short-lived access
  token, refresh tokens stored hashed in `refresh_tokens` so they can be revoked. Fits: a
  separate SPA or mobile client. Trade-off: needs a gem (e.g. `jwt`) and our own revoke/refresh
  code; more security surface to get right.
- **B. Rails 8 built-in authentication** (`bin/rails generate authentication`). What: cookie
  sessions, `has_secure_password` (bcrypt), password reset mailer. Fits: Rails views / Hotwire.
  Trade-off: awkward for non-browser clients.

Either way (proposed): role checked on every `/seller` and `/admin` request; bids and payments
require an `Idempotency-Key` header.

## Open questions

- Frontend approach (decides A vs B) — see `stack.md`.
- Email provider for password reset.
