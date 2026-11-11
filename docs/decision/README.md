# Decision log — lets-auction

Read this before any work. Update the relevant topic file **before** changing code that
contradicts it. Template: [`_template.md`](_template.md). Skill: `record-decision`.

Statuses: `Open` → `Decided` → `Superseded`. Only a human collaborator moves a topic to Decided.

## Index

| Topic | File | Status | Summary |
|---|---|---|---|
| Repo & collaboration | [repo-and-collaboration.md](repo-and-collaboration.md) | Decided | Public GitHub repo, PR flow on `main` via rulesets (PR + CI required, 0 approvals); branches `<handle>-<type>-[<issue>-]<detail>` (CI-checked), short-lived |
| AI agent hub | [ai-agent-hub.md](ai-agent-hub.md) | Decided | `AGENTS.md` entry point + `ai/` hub + `.claude/skills/`; tool files only point back |
| Agent boundaries | [agent-boundaries.md](agent-boundaries.md) | Decided | Agents never force-push or delete remote branches; commits, pushes, PRs, gems, CI, GitHub/Railway changes are ask-first; exception: CI Auto-fix on its own PR branch; enforced via `.claude/settings.json` |
| Stack | [stack.md](stack.md) | Decided | Ruby on Rails (Ruby 4.0.5, Rails 8.1), GitHub Actions CI — confirm with a collaborator |
| Deployment | [deployment.md](deployment.md) | Decided | Railway, auto-deploy from `main`; production DB still open |
| Scope | — | Open | What lets-auction must do |
| Product catalog | [product-catalog.md](product-catalog.md) | Open | ข้อกำหนด Catalog การเชื่อมข้อมูลประมูล และข้อเสนอที่รอยืนยัน (#38, #63) |
| Scope | [scope.md](scope.md) | Open | Milestone 1 rules proposed: sealed + invite-only English auctions, admin-approved results, slip payments |
| Bidding | [bidding.md](bidding.md) | Open (partly Decided) | Decided: satang `bigint` (`.00` auto-added on input), no bid count on bidder pages for sealed lots until published, encrypted bid amounts in a `text` column (no nonce), English lots end on time (no extensions), next rank pays if the winner doesn't, orders are mock for now, no deposit/KYC, no separate auditor (admins do all checking), no two-admin reveal or commitment hash. Rest still proposed (#27) |
| Product onboarding | [product-onboarding.md](product-onboarding.md) | Open | Seller product listing + admin verification: 1-5 images, 0-2 videos, file limits, no draft status, Active Storage direct upload, orphan purge after 48h, note required on reject/request-info (#47). Mock pages can be shown in production (sellers only) with `MOCK_PRODUCT_ONBOARDING=true` |
| User onboarding | [user-onboarding.md](user-onboarding.md) | Decided | Every buyer onboards (national ID, phone, income); rule-based 0–100 score; grade A (with proof of income) → sealed + English, B–D → sealed, E → none; no OTP in M1; national ID encrypted, masked, filtered from logs |
| Auth | [auth.md](auth.md) | Open | JWT API vs Rails built-in session auth; depends on frontend approach |
| Real-time & jobs | [realtime.md](realtime.md) | Open | Proposed Action Cable (Solid Cable) + Solid Queue jobs |
| License | — | Open | Public repo with no license = all rights reserved; pick one deliberately |

## Key decisions at a glance

- Repo: `github.com/yannawatsomon/lets-auction`, public (continues `we-auction`, 2026-11-11).
- Merging to `main` deploys to production (Railway), so CI must be green first. Rulesets
  require a PR and CI but no approval: anyone with Write can merge their own PR (2026-11-11).
- **Agent boundaries (the one rule not to miss):** AI agents never force-push or delete remote
  branches, and do commits, pushes, PRs, gem/CI changes and GitHub/Railway changes only when a
  human explicitly asks for that exact action (2026-11-11); exception: a PR with CI Auto-fix
  on. See `agent-boundaries.md`.
- Branch names: `<github-handle>-<type>-[<issue>-]<detail>`, e.g. `yannawatsomon-fix-add-db-schema`
  (2026-11-11).
- Agent-agnostic: any agent reads `AGENTS.md`; Claude Code is the confirmed primary tool.
- Files in English; Thai terms go in `ai/context/glossary.md`.

## Open questions

- ยืนยันหมวดหมู่ ตัวกรองวันเวลา สิทธิ์และกรณีพิเศษ การโหลดและอัปเดตรายการ และการจัดอันดับ Highlights → [product-catalog.md](product-catalog.md).
- What is lets-auction exactly (scope, users, deadline)? → fill `ai/context/project.md`.
- Production database (Postgres vs SQLite volume)? → `deployment.md`, `stack.md`.
- What is lets-auction exactly (scope, users, deadline)? → `scope.md` (proposed), then fill
  `ai/context/project.md`.
- Production database (Postgres vs SQLite volume)? → `deployment.md`, `stack.md`. The Milestone 1
  design draft assumes Postgres.
- Language: the design drafts in `docs/design/` (Milestone 1 API and database, user
  onboarding) are kept in Thai at the author's request (2026-11-11), against "Files in
  English". Allow Thai for design docs, or translate later?
- Which license? (public repo)
- Who reviews? (CODEOWNERS not set yet)
- Set the ruleset admin bypass to "for pull requests only" (owner only), so an agent on an admin login can't push to `main` → `agent-boundaries.md`.
- Require branches to be up to date before merging? Restrict merge methods to squash? → `repo-and-collaboration.md`.
