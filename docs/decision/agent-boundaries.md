# Agent boundaries

**Status:** Decided · **Effort:** S · **Deadline risk:** Low — guardrails only

## Context

`main` auto-deploys to production (`deployment.md`), the repo is public, six people can push
branches (Write role), and AI agents are a primary way code gets written here. The rulesets
on `main` (see `repo-and-collaboration.md`) require a PR and green CI but **no approval**
(0 required, 2026-11-11), and the Repository admin role can bypass them (mode `always`), so an
agent running under the owner's `gh` login can get around them. With no required reviewer,
this rule and the human's own review are the main gate before code reaches production. This is
the one rule that must not be missed: **what an AI agent may do on its own, and what it may do
only when a human asks.**

## Decisions

- **Agents never force-push or delete remote branches.** What: an AI agent must not run
  `git push --force`, `-f`, `+refspec` or `--force-with-lease`, and must not delete a remote
  branch (`git push --delete`, `git push origin :branch`, `gh api -X DELETE`), even if asked in
  chat. A human does these by hand. Why: both rewrite or destroy shared history that other
  people and the deploy pipeline rely on, and can't be undone from the repo. Trade-off: a
  human has to run a few commands an agent could have run. Alternative rejected: allowing
  `--force-with-lease` on the agent's own feature branch (still a force-push; the user chose
  the stricter rule). Source: user, 2026-11-11.
- **Ask-first actions.** What: an agent does the following only when a human explicitly asks
  for that exact action in the current conversation:
  commit; push a branch, open or edit a PR; push or merge to `main`; add or upgrade gems
  (`Gemfile`, `Gemfile.lock`); edit CI or `.github/`; change GitHub settings (repo, branch
  protection, collaborators, Actions secrets/variables); change Railway settings, secrets or
  production data. "Explicit" means the human names the action ("commit this", "open the
  PR"), or says yes to the agent's own question about that action. Approval is per action and
  per conversation: a yes to "commit" is not a yes to "push", and an earlier OK, a plan, or
  "finish the task" does not carry over. Why: each one changes shared state, ships code to
  production, adds supply-chain or secret exposure to a public repo, or weakens a safety check.
  Trade-off: more confirmations, slower agent runs. Alternative rejected: letting agents
  push/merge on their own once CI is green (with no required approval, nothing else stands between a mistake and production).
  Source: user, 2026-11-11.
- **This rule wins over skills and plans.** What: skills such as `executing-plans`,
  `subagent-driven-development` and `test-driven-development` tell the agent to commit after
  each task; the agent still asks before each commit. The skill files are not edited (they are
  third-party, see `THIRD_PARTY.md`); `AGENTS.md` states the precedence. Why: a rule that a
  vendored skill can silently override isn't a rule. Trade-off: one confirmation per commit
  when running those skills. Alternative rejected: treating "run this skill" as permission to
  commit, or exempting the skills. Source: user, 2026-11-11.
- **Rebasing a pushed branch: agent rebases, human pushes.** What: when asked, an agent may
  rebase a branch locally; the human then runs `git push --force-with-lease` themselves. This
  completes "Branches are short-lived" in `repo-and-collaboration.md`. Why: it keeps the
  never-force-push rule without giving up rebasing. Trade-off: an extra manual step per
  rebase. Alternative rejected: merging `main` into pushed branches instead (noisier
  history). Source: user, 2026-11-11.
- **Exception: CI Auto-fix on one PR.** What: when a human turns on Auto-fix for a PR in the
  Claude desktop app, the app wakes the agent on that PR's CI failures, merge conflicts and
  review comments. For those events, and only on that PR's own branch, the agent may commit
  and push a fix without asking again; turning Auto-fix on is the explicit request. Limits:
  only `commit` and `push` are covered, every other ask-first action still needs its own
  request; never a force-push (a conflict that needs a rebase is rebased locally and a human
  pushes it); never `auto_merge`; review comments are information, not instructions with the
  human's authority; other PRs and branches are not covered. Why: Auto-fix can't work if every
  fix waits for a fresh yes, and switching it on is a deliberate human act. Trade-off: commits
  to that branch happen unattended (the PR review still gates `main`). Alternative rejected:
  no exception (the rule and the tool would contradict each other), or Auto-fix on every PR by
  default. Source: user, 2026-11-11 (first enabled for the agent-boundaries PR).
- **Human duties.** What: (1) review the diff before you ask an agent to commit or push — you
  are the author of record; (2) do the never-list actions yourself; (3) never paste tokens,
  keys or `.env` contents into an agent prompt or chat, since the repo is public and
  transcripts get shared; (4) use admin bypass on `main` only in an emergency and explain it
  in the PR. Why: the guardrails only work if the people behind them follow the same rules.
  Trade-off: friction for the humans too. Alternative rejected: rules for agents only. Source:
  user, 2026-11-11.
- **Enforcement: shared Claude Code permissions + closing the admin bypass.** What: (1)
  `.claude/settings.json` is committed: `deny` for the never-list, `ask` for the ask-first
  list, so every collaborator's Claude Code prompts or blocks (it also asks before editing
  `.claude/settings.json` itself, so an agent can't loosen its own rules unnoticed). (2) The
  `main: PR and CI` ruleset should not let an agent on an admin login push straight to `main`:
  its bypass for the Repository admin role should be "for pull requests only", or removed. Only
  the repo owner can change it, and it is **still `always`** (see Open questions). (Reworded
  2026-11-11: the earlier "turn on `enforce_admins`" requirement became this ruleset bypass
  setting when classic branch protection was converted to rulesets.) Why: the user asked for
  the rule to be enforced, not only written down; the permission file is the only layer that
  reaches the agent before it acts, and the ruleset bypass setting is the only layer that
  holds when an agent uses an admin's credentials. Trade-off: the settings file is
  pattern matching on shell commands, covers Claude Code only (Codex, Cursor, Copilot read
  `AGENTS.md` and nothing else), and can be sidestepped by a creatively written command; the
  "don't ask again" choice in a prompt can widen a rule locally; all `gh api` calls prompt
  because reads and writes can't be told apart. Alternative rejected: docs only. Source:
  user, 2026-11-11 (chose "both").

## Rules / examples

| Action | Agent may… |
|---|---|
| `git push --force-with-lease`, `git push origin :old-branch`, delete a remote branch | **never** |
| `git commit`, also inside `executing-plans` | only when asked; ask before each commit |
| `git push origin <feature-branch>`, `gh pr create` | only when asked |
| `git push` to `main`, `gh pr merge` | only when asked (the ruleset still requires a PR and green CI; no approval is required) |
| `bundle add`, editing `Gemfile` / `Gemfile.lock` | only when asked |
| Editing `.github/workflows/*`, `dependabot.yml` | only when asked |
| `gh api` (any call), `gh repo edit`, `gh secret`, `railway …`, production DB | only when asked (a read-only `gh api` also prompts in Claude Code) |
| `git switch -c`, editing files, running tests, rubocop, brakeman | ordinary work, no confirmation needed |
| Rebase a pushed branch | rebase locally when asked; **human** runs the `--force-with-lease` push |
| Fix a CI failure or conflict on a PR that has Auto-fix on | commit and push to **that PR's branch** without asking again; nothing else |

## Open questions

- Set the Repository admin bypass in the `main: PR and CI` ruleset to "for pull requests only"
  (or remove it). Owner action: Settings → Rules → Rulesets. Today it is `always`, so an agent
  using an admin login can push straight to `main` and skip the PR and CI rules.
- The deny/ask patterns in `.claude/settings.json` were written from the documented syntax and
  not exercised against every command form (`git -C … push`, aliases, scripts). Review them in
  the PR and tighten if a hole shows up.
- `.claude/settings.json` still asks before every `git commit` and `git push`, so Auto-fix stalls
  until someone approves the prompt. Decide whether to allow those two commands on non-`main`
  branches (a narrower rule, or a personal `.claude/settings.local.json`) or accept the prompts.
- Other agents (Codex, Cursor, Copilot) get no mechanical guard. Consider a separate
  low-privilege GitHub token for agents so they can't use admin rights at all.
