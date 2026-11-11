# Repo & collaboration

**Status:** Decided · **Effort:** S · **Deadline risk:** Low — foundation only

## Context

Several collaborators (humans and AI agents) work in one repo. They need a predictable flow so
work doesn't collide and nothing sensitive leaks. The project moved here from `we-auction`
(2026-11-11); this file carries over the decisions made there, updated.

## Decisions

- **GitHub repo is public, under the owner's personal account.** What:
  `yannawatsomon/lets-auction`, public. Why: user's choice. Trade-off: everything committed is
  world-readable forever — no secrets, personal data or private client info. Alternative
  rejected: private repo / organization (can migrate later). Source: user, 2026-11-10/11.
- **Collaborators are invited individually (Write role) by the owner.** What: Settings →
  Collaborators. Why: personal accounts have no teams. Trade-off: manual access management.
  Alternative rejected: organization with teams (overkill for now). Source: user, 2026-11-11
  (owner invites people themselves; the repo does not list them).
- **PR-based flow; `main` is protected and auto-deploys.** What: ~~branch `feat/*`, `fix/*`,
  `docs/*`, `chore/*`~~ **Superseded (2026-11-11):** branch naming, see *Branch naming* below;
  ~~PR with review; squash merge. Branch protection on `main`: PR required, 1 approval, stale
  approvals dismissed, status checks `scan_ruby`, `scan_js`, `lint`, `test` must pass, force
  pushes blocked.~~ **Superseded (2026-11-11):** classic branch protection was replaced by two
  rulesets and the required approval was dropped, see *`main` is protected by two rulesets*
  below; the flow is still PR + squash merge. Why: `main` deploys to production (`deployment.md`).
  Trade-off: slower than pushing directly; admin can still override in an emergency.
  Alternative rejected: trunk-based direct pushes. Source: user chose "yes, with required CI",
  2026-11-11.
- **`main` is protected by two rulesets; no approval required.** What: on 2026-11-11 the
  owner converted classic branch protection to two active rulesets and deleted the classic
  rule. `main: no delete or force-push` blocks deleting `main` and non-fast-forward pushes (no
  bypass). `main: PR and CI` requires a pull request, requires status checks `scan_ruby`,
  `scan_js`, `lint`, `test` to pass, sets **required approvals to 0**, and dismisses stale
  approvals on push; the Repository admin role can bypass it (mode `always`). Anyone with
  Write can therefore merge their own PR once CI is green. Why: the user wants every
  collaborator able to merge their own PR without waiting for a reviewer; a PR author can
  never approve their own PR, so the 1-approval rule left PRs waiting on someone else.
  Trade-off: no second reader before code reaches production (`main` auto-deploys), so
  AI-written code is checked only by its author, CI and `agent-boundaries.md`. Alternative
  rejected: keeping 1 required approval, with `CODEOWNERS` or rotating reviewers to avoid the
  bottleneck. Source: user, 2026-11-11 (applied in GitHub by the owner; state read back with
  `gh api` the same day).
- **Branch naming: `<github-handle>-<type>-[<issue>-]<detail>`.** What: lowercase,
  hyphen-separated. `<github-handle>` is the GitHub username of the person who owns the branch
  (an AI agent uses the handle of the human it works for); `<type>` is one of `feat`, `fix`,
  `docs`, `chore`, `refactor`, `test`, `ci`; `<issue>` is optional, the GitHub issue number
  (digits only) when the branch resolves an issue; `<detail>` is a short kebab-case
  description: only `a-z`, `0-9` and single hyphens, no dates, 2-5 words. Examples:
  `yannawatsomon-fix-add-db-schema`, `yannawatsomon-fix-12-add-db-schema`. Exempt: `main` and
  `dependabot/*`. Why: collaborators
  push branches straight to this one repo (Write role, no forks), so the handle shows who owns
  a branch and avoids name collisions, and the type shows what kind of change it is. Trade-off:
  long names; with hyphens as the only separator a handle that itself contains a hyphen
  (GitHub allows them) is ambiguous to parse, so tools should anchor on the `<type>` token.
  Alternative rejected: type-only prefixes (`feat/*`, `fix/*`) as before — no owner visible
  once several people have branches open. Source: user, 2026-11-11.
- **Branches are short-lived.** What: the head branch is deleted after the squash-merge, and
  before opening a PR you rebase your branch on the latest `main`. Rebase only your own branch;
  if it is already pushed, a human pushes it with `git push --force-with-lease`, never plain
  `--force`, and AI agents never force-push (`agent-boundaries.md`). Deleting on
  merge is done by the GitHub repo setting "Automatically delete head branches" (Settings →
  General → Pull Requests), which only the owner can turn on. Why: squash-merge leaves the
  original branch behind, so stale branches pile up (three merged ones exist already); and
  `main` deploys to production, so CI should test a branch that is current with `main`.
  Trade-off: rebasing rewrites the branch, so it needs a force-push and must not be done on a
  branch someone else has pulled. Alternative rejected: merging `main` into the branch —
  noisier history during review. Source: user, 2026-11-11 (the force-push wording was
  tightened the same day by the agent-boundaries decision).
- **Branch names are checked by CI.** What: `.github/workflows/branch-name.yml`, job
  `branch_name`, matches the PR's head branch against the naming rule on every pull request;
  `dependabot/*` is skipped. It is not a required status check yet — add `branch_name` to the
  `main` protection once it has run green on a real PR. Why: a rule nothing checks drifts.
  Trade-off: a wrongly named branch must be renamed and its PR reopened (GitHub cannot rename
  the head branch of an open PR). Alternative rejected: GitHub ruleset branch-name
  restrictions — availability depends on the plan (not verified) and the rule would live in
  settings instead of the repo. Source: user, 2026-11-11.
- **Commit email privacy.** Because the repo is public, each collaborator's commit email is
  visible; use the GitHub `noreply` address (Settings → Emails → "Keep my email private").

## Rules / examples

| Branch | Valid? |
|---|---|
| `yannawatsomon-fix-add-db-schema` | yes |
| `yannawatsomon-fix-12-add-db-schema` | yes — with issue number |
| `yannawatsomon-feat-bid-validation` | yes |
| `yannawatsomon-refactor-extract-bid-model` | yes |
| `yannawatsomon-docs-branch-naming-rule` | yes |
| `fix/add-db-schema` | no — old style, no owner |
| `yannawatsomon-add-db-schema` | no — missing `<type>` |
| `yannawatsomon-fix-add_db_schema` | no — underscores not allowed |
| `yannawatsomon-fix-2026-11-11-schema` | no — no dates in `<detail>` |
| `YannawatSomon-Fix-Add-DB-Schema` | no — must be lowercase |

## Open questions

- Make `branch_name` a required status check on `main`? (After one green run on a real PR.)
- Turn on "Automatically delete head branches"? (Repo setting; owner only.)
- The `main: PR and CI` ruleset has **"require branches to be up to date" off**
  (`strict_required_status_checks_policy: false`). That is how #5 and an earlier homepage change
  merged into a `main` with a duplicate `root` route and a red CI (fixed in #11). Turn it on?
- The ruleset allows **merge, squash and rebase** merges; the decided method is squash only.
  Restrict allowed merge methods to squash?
- The Repository admin bypass is `always` (a direct push to `main` skips the PR and CI rules).
  See `agent-boundaries.md`.

- Fork PRs vs branches in this repo: which do collaborators use? (Both exist today.)
- Who reviews? Add `CODEOWNERS` once reviewers are known.
- Dependabot PRs (workflow actions, gems) pile up: who merges them, and how often?
