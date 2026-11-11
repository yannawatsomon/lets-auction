# AGENTS.md — entry point for every AI coding agent

This file is vendor-neutral. Claude Code, Codex, Cursor, Copilot and any other agent should
read it first. Tool-specific files (`CLAUDE.md`, `.github/copilot-instructions.md`,
`.cursor/rules/`) only point back here — **do not duplicate rules in them.**

## Before any work

1. Read [`docs/decision/README.md`](docs/decision/README.md) — what is decided, what is open.
2. Read [`ai/context/project.md`](ai/context/project.md) — what lets-auction is and its constraints.
3. Skim [`ai/README.md`](ai/README.md) — map of the shared AI hub.
4. If your change contradicts a **Decided** entry, update/supersede the decision doc *first*,
   in the same PR. Never silently diverge.

## The shared AI hub (single source of truth)

| What | Where | Purpose |
|---|---|---|
| Decisions | `docs/decision/` | What was decided and why (ADR-style, one file per topic) |
| Context | `ai/context/` | Project background, domain, glossary, constraints |
| Knowledge | `ai/knowledge/` | Reusable how-it-works notes, gotchas, references |
| Playbooks | `ai/playbooks/` | Step-by-step procedures (e.g. how to add a feature, how to release) |
| Skills | `.claude/skills/<name>/SKILL.md` | Reusable agent skills (open SKILL.md format; any agent may read them) |

Agents that can't auto-load skills: open the relevant `SKILL.md` and follow it manually.

## Skills

All skills are committed in `.claude/skills/<name>/SKILL.md`, so every collaborator gets the
same ones whatever tool they use. Third-party ones are listed in
[`THIRD_PARTY.md`](THIRD_PARTY.md). **Before doing the kind of work in the "When" column, open
and follow that skill.**

| Skill | When |
|---|---|
| `decision-first` | Starting a project area or large feature; discuss and record decisions before code |
| `record-decision` | A decision is made or must change → `docs/decision/` |
| `update-ai-hub` | You learned something non-obvious → `ai/` |
| `brainstorming` | Before any new feature or behavior change |
| `grilling` | Stress-testing a plan or idea |
| `domain-modeling` | Naming domain terms (bid, lot, reserve...) and their relationships |
| `writing-plans` | Turning a spec into a step-by-step task plan |
| `executing-plans` / `subagent-driven-development` | Carrying out a written plan (inline / with sub-agents) |
| `using-git-worktrees` | Isolating feature work from your current checkout |
| `test-driven-development` | Implementing any feature or bugfix |
| `systematic-debugging` | Any bug, failing test or unexpected behavior, before proposing a fix |
| `verification-before-completion` | Before saying work is done, fixed or passing |
| `requesting-code-review` / `receiving-code-review` | Asking for a review / acting on review feedback |
| `code-review` | Reviewing a branch or PR against standards and the originating issue |
| `security-review` | Any change touching bidding, money, auth, user input, secrets or config |
| `resolving-merge-conflicts` | An in-progress merge or rebase conflict |
| `finishing-a-development-branch` | Work is done and tests pass; deciding how to integrate |

Not added yet: frontend/design (UI approach is undecided), testing-strategy and deploy skills.
Add them via PR when needed.

## Working rules

- Branch from `main`; never push to `main` directly. Open a PR (see `CONTRIBUTING.md`).
- Name branches `<github-handle>-<type>-[<issue>-]<detail>` in lowercase, type =
  `feat|fix|docs|chore|refactor|test|ci`, detail = 2-5 words of `a-z0-9-` (no underscores or
  dates), e.g. `yannawatsomon-fix-add-db-schema`. Use the GitHub handle of the human you work
  for. Details: `docs/decision/repo-and-collaboration.md`. CI (`branch_name`) rejects other names.
- Keep branches short-lived: rebase your own branch on the latest `main` before opening the PR
  (`git push --force-with-lease` if already pushed, never `--force`), delete it after merge.
- Small, focused PRs. One concern per PR.
- Never commit secrets, tokens, `.env` files or personal data — **this repo is public.**
- Stack is **Ruby on Rails** (see `docs/decision/stack.md`), deployed to Railway from `main`
  (see `docs/decision/deployment.md`). Do not introduce another language, framework or build
  tool without a Decided entry.
- Before opening a PR run `bin/rails db:test:prepare test`, `bin/rubocop` and `bin/brakeman`
  (CI runs the same). **Merging to `main` deploys to production.**
- When you learn something non-obvious (a gotcha, a convention, a reason), write it down in
  `ai/knowledge/` or `docs/decision/` instead of leaving it in chat.
- Language: files are written in English; Thai is welcome in discussion and in `ai/context/glossary.md`.
