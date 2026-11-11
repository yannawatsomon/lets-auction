---
name: security-review
description: Optional security checklist for lets-auction (a public auction app). Use only if the user asks for a security review, e.g. of a change touching bidding, money, authentication, user input, file uploads, secrets or configuration.
---

# Security review (lets-auction)

This repo is **public** and an auction app handles bids, money and accounts. Review the diff
(`git diff main...HEAD`) against the checklist. Report findings as: file:line, what is wrong,
how to exploit it, suggested fix. Say "none found" per section if clean — don't pad.

> Stack is Rails (`docs/decision/stack.md`). CI runs `bin/brakeman` and `bin/bundler-audit`;
> they do not replace this checklist. Add Rails-specific items to `ai/knowledge/` as they
> come up. Merging to `main` deploys to production (`docs/decision/deployment.md`).

## 1. Secrets and data in git
- No keys, tokens, passwords, `.env` files, connection strings or personal data in code, tests,
  fixtures, logs, docs or commit history. A secret that reached a public repo is compromised:
  rotate it, don't just delete it.
- `.env.example` has placeholders only.

## 2. Authentication and authorization
- Every endpoint/action checks *who* is calling and *whether they may* (seller vs bidder vs admin).
  Check ownership server-side — never trust IDs or roles sent by the client.
- Passwords hashed with a modern adaptive algorithm; sessions/tokens expire and can be revoked.
- No account enumeration through login/reset error messages.

## 3. Bidding and money integrity (highest risk)
- Bid validation happens on the server: amount ≥ current price + minimum increment, auction is
  open, bidder is not the seller, bidder is allowed to bid.
- Concurrent bids cannot both win: the check-and-write is atomic (transaction, lock or
  compare-and-set). Think through two bids arriving in the same millisecond.
- Closing time is decided by the server clock, not the client. Define behaviour for late or
  last-second bids (anti-sniping rule, if any) and test it.
- Money uses integer minor units or a decimal type, never floating point. Currency is explicit.
- Bids and results are auditable: who, what, when, from where; history is append-only.

## 4. Input and output
- Validate type, range and length of all input on the server; reject, don't "fix".
- Injection: parameterized queries; no string-built SQL/commands/paths.
- Output is escaped for its context (HTML, URL, JSON) — stored XSS via item titles,
  descriptions and usernames is the classic auction bug.
- File uploads: check type and size server-side, store outside the web root, never serve
  user-controlled filenames or content types unchecked.

## 5. Abuse and availability
- Rate-limit login, bidding and any expensive endpoint. Consider shill-bidding and bid-spam.
- No unbounded queries or responses (pagination, limits).

## 6. Dependencies and config
- New dependencies are necessary, maintained and pinned; check for known vulnerabilities.
- Debug modes, verbose errors and permissive CORS are off outside local development.
- HTTPS only; cookies `Secure`, `HttpOnly`, `SameSite`.

## 7. Process
- Security-relevant decisions (auth model, bid-closing rules) belong in `docs/decision/`.
- If you find a vulnerability in already-public code, report it privately to the maintainer
  first rather than opening a public issue.
