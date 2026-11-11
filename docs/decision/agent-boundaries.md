# Agent boundaries

**Status:** Decided · **Effort:** S · **Deadline risk:** Low — guardrails only

## Context

`main` auto-deploys to production (`deployment.md`), the repo is public, six people can push
branches (Write role), and AI agents are a primary way code gets written here. The rulesets on
`main` (see `repo-and-collaboration.md`) require a PR and green CI but no approval, and the
Repository admin role can bypass them (mode `always`).

The first version of this decision (2026-11-11) also made commits, pushes, PRs, gem changes and
CI edits "ask first" for every agent, and bundled 15 third-party skills with a mandatory skill
table. In practice that slowed everyone's agents and overrode the habits and rules each
collaborator already has. It was cut back the same day (see Decisions).

## Decisions

- **Agents never force-push or delete remote branches.** What: an AI agent must not run
  `git push --force`, `-f`, `+refspec` or `--force-with-lease`, and must not delete a remote
  branch (`git push --delete`, `git push origin :branch`, `gh api -X DELETE`), even if asked in
  chat. A human does these by hand. Why: both rewrite or destroy shared history that other
  people and the deploy pipeline rely on, and can't be undone from the repo. Trade-off: a
  human runs a few commands an agent could have run. Source: user, 2026-11-11.
- **Agents do not push to `main`, and touch production or GitHub/Railway settings only when
  asked.** What: no direct push to `main` (open a PR; merging deploys); changing Railway
  settings, secrets or production data, GitHub settings (repo, rulesets, collaborators,
  secrets) or merging a PR happens only when a human asks for that action. Why: these ship code
  to production or change shared settings. Trade-off: a prompt for those few commands.
  Source: user, 2026-11-11.
- **Never commit secrets, tokens, `.env` files or personal data.** Why: the repo is public and
  history is permanent. Source: `repo-and-collaboration.md`.
- **Everything else is each collaborator's own choice.** What: whether an agent asks before
  committing, pushing, opening a PR, adding gems or editing CI, and which skills or workflow it
  uses, is set by each person in their own tool config (for Claude Code, the git-ignored
  `.claude/settings.local.json` and `CLAUDE.local.md`). Why: everyone already has rules that
  suit them, and shared mandatory process made agents slower and less familiar to their owners.
  Trade-off: no shared commit/push gate; the PR, CI and the human's own review are what stand
  between a change and production. Alternative rejected: shared ask-first rules and a shared
  mandatory skill set (the 2026-11-11 first version). Source: user, 2026-11-11.
- **Enforcement.** What: `.claude/settings.json` has `deny` for the never-list and `ask` only
  for merge, repo/secret/variable changes, `railway`, `kamal` and `RAILS_ENV=production`. It
  covers Claude Code only; other agents read `AGENTS.md` and nothing else. Source: user,
  2026-11-11.

## Rules / examples

| Action | Agent may… |
|---|---|
| `git push --force-with-lease`, `git push origin :old-branch`, delete a remote branch | **never** |
| Push to `main` | **never** (PR only) |
| `gh pr merge`, `gh repo edit`, `gh secret`, `railway …`, production DB | only when asked |
| Commit, push a feature branch, open a PR, change gems or CI | your own call |
| Rebase a pushed branch | rebase locally; the **human** runs the `--force-with-lease` push |

## Open questions

- Set the Repository admin bypass in the `main: PR and CI` ruleset to "for pull requests only"
  (or remove it). Owner action: Settings → Rules → Rulesets. Today it is `always`, so an agent
  using an admin login can push straight to `main` and skip the PR and CI rules.
- The deny patterns in `.claude/settings.json` were written from the documented syntax and not
  exercised against every command form (`git -C … push`, aliases, scripts).
- Other agents (Codex, Cursor, Copilot) get no mechanical guard. Consider a separate
  low-privilege GitHub token for agents so they can't use admin rights at all.
