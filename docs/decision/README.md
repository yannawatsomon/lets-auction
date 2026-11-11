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
| Scope | [scope.md](scope.md) | Open | Milestone 1 rules proposed: sealed + invite-only English auctions, admin-approved results, slip payments |
| Bidding | [bidding.md](bidding.md) | Open | Sealed + invite-only English rules: satang `bigint`, encrypted sealed amounts, no bid count before publish, row-lock + 2-min extension for English (#27) |
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
