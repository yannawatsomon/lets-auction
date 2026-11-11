# Decision log — lets-auction

Read this before any work. Update the relevant topic file **before** changing code that
contradicts it. Template: [`_template.md`](_template.md). Skill: `record-decision`.

Statuses: `Open` → `Decided` → `Superseded`. Only a human collaborator moves a topic to Decided.

## Index

| Topic | File | Status | Summary |
|---|---|---|---|
| Repo & collaboration | [repo-and-collaboration.md](repo-and-collaboration.md) | Decided | Public GitHub repo, PR flow on protected `main` with required CI |
| AI agent hub | [ai-agent-hub.md](ai-agent-hub.md) | Decided | `AGENTS.md` entry point + `ai/` hub + `.claude/skills/`; tool files only point back |
| Stack | [stack.md](stack.md) | Decided | Ruby on Rails (Ruby 4.0.5, Rails 8.1), GitHub Actions CI — confirm with a collaborator |
| Deployment | [deployment.md](deployment.md) | Decided | Railway, auto-deploy from `main`; production DB still open |
| Scope | — | Open | What lets-auction must do |
| Product catalog | [product-catalog.md](product-catalog.md) | Open | ข้อกำหนด Catalog การเชื่อมข้อมูลประมูล และข้อเสนอที่รอยืนยัน (#38, #63) |
| License | — | Open | Public repo with no license = all rights reserved; pick one deliberately |

## Key decisions at a glance

- Repo: `github.com/yannawatsomon/lets-auction`, public (continues `we-auction`, 2026-11-11).
- Merging to `main` deploys to production (Railway), so CI must be green first.
- Agent-agnostic: any agent reads `AGENTS.md`; Claude Code is the confirmed primary tool.
- Files in English; Thai terms go in `ai/context/glossary.md`.

## Open questions

- ยืนยันหมวดหมู่ ตัวกรองวันเวลา สิทธิ์และกรณีพิเศษ การโหลดและอัปเดตรายการ และการจัดอันดับ Highlights → [product-catalog.md](product-catalog.md).
- What is lets-auction exactly (scope, users, deadline)? → fill `ai/context/project.md`.
- Production database (Postgres vs SQLite volume)? → `deployment.md`, `stack.md`.
- Which license? (public repo)
- Who reviews? (CODEOWNERS not set yet)
