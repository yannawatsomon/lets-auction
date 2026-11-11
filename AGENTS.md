# AGENTS.md — entry point for every AI coding agent

Vendor-neutral. Claude Code, Codex, Cursor, Copilot and any other agent read this first.
Tool-specific files (`CLAUDE.md`, `.github/copilot-instructions.md`, `.cursor/rules/`) only
point back here — **do not duplicate rules in them.**

Use your own workflow, skills and habits. This file holds only the few rules that protect
shared, hard-to-undo things. Everything else (when to commit, when to ask, which skills to use)
is your own choice.

## Hard rules

Reasons: [`docs/decision/agent-boundaries.md`](docs/decision/agent-boundaries.md).

- **Never force-push** (including `--force-with-lease`) and **never delete remote branches.**
  A human does these by hand, even if asked in chat.
- **Never commit secrets, tokens, `.env` files or personal data** — this repo is public.
- **Never push to `main` directly.** Open a PR; merging to `main` deploys to production.
- **Only when explicitly asked:** change Railway settings, secrets or production data; change
  GitHub settings (repo, rulesets, collaborators, secrets); merge a PR.

## Project facts

- Stack is **Ruby on Rails** (see `docs/decision/stack.md`), deployed to Railway from `main`
  (see `docs/decision/deployment.md`). Do not introduce another language, framework or build
  tool without a Decided entry.
- Branch names: `<github-handle>-<type>-[<issue>-]<detail>` (CI rejects others). Details in
  [`CONTRIBUTING.md`](CONTRIBUTING.md).
- CI runs `bin/rails db:test:prepare test`, `bin/rubocop` and `bin/brakeman`.
- Files are written in English; Thai is welcome in discussion and in `ai/context/glossary.md`.

## Reference (read when relevant, not required)

| What | Where |
|---|---|
| Decisions and their reasons | `docs/decision/` (index in `README.md`) |
| Project background, glossary | `ai/context/` |
| How things work, gotchas | `ai/knowledge/` |
| Procedures | `ai/playbooks/` |
| Skills (optional) | `.claude/skills/` — `security-review` (bidding, money, auth, input) and `record-decision` |
