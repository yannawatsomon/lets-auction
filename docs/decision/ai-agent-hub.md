# AI agent hub

**Status:** Decided · **Effort:** S · **Deadline risk:** Low

## Context

Collaborators use Claude Code and possibly other agents. They share project knowledge and a few
hard rules, but each person already has their own agent rules, skills and habits that suit them.

## Decisions

- **`AGENTS.md` is the single vendor-neutral entry point, and it holds hard rules only.** What:
  `CLAUDE.md` imports it with `@AGENTS.md`; Copilot and Cursor files only point to it. It lists
  the few rules that protect shared, hard-to-undo things (`agent-boundaries.md`) plus project
  facts; it does not prescribe a workflow. Why: unknown agent mix; one file to maintain; extra
  mandatory process slowed other people's agents. Alternative rejected: separate full rule files
  per tool (they drift apart). Source: user, 2026-11-10; narrowed by user, 2026-11-11.
- **Shared knowledge lives in `ai/`; decisions in `docs/decision/`. Both are reference, not
  mandatory reading.** What: `ai/context`, `ai/knowledge`, `ai/playbooks`. Why: one
  discoverable place, reviewed via PRs. Trade-off: needs discipline to keep current. Alternative
  rejected: wiki (not versioned with code, not visible to agents). Source: user, 2026-11-10.
- **Only two own skills ship in `.claude/skills/`: `security-review` and `record-decision`.**
  What: both optional. No third-party skills are vendored (the 15 copies of `obra/superpowers`
  and `mattpocock/skills`, `THIRD_PARTY.md` and `licenses/` were removed 2026-11-11), and
  `decision-first` and `update-ai-hub` were dropped. Why: collaborators install the skills they
  like; committed copies forced one workflow on everyone, duplicated plugins people already had
  and added about 3,000 lines. Trade-off: no shared skill set; the path stays Claude-named.
  Alternative rejected: keeping the vendored set as optional (still loaded and listed in every
  agent's context). Source: user, 2026-11-11 (supersedes the 2026-11-10 decision to commit
  third-party skills).

## Open questions

- Add a CI check that tool pointer files still reference `AGENTS.md`?
