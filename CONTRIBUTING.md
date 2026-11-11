# Contributing

This repo is **public** — never commit secrets, tokens, `.env` files or personal data.

## Flow

1. Pick or open an issue.
2. Branch from latest `main`, named `<github-handle>-<type>-[<issue>-]<detail>`:
   - lowercase; type is `feat`, `fix`, `docs`, `chore`, `refactor`, `test` or `ci`;
   - `<issue>` is the optional issue number, `<detail>` is 2-5 words of `a-z`, `0-9`, `-`
     (no underscores, no dates);
   - e.g. `yannawatsomon-fix-add-db-schema` or `yannawatsomon-fix-12-add-db-schema`.

   CI (`branch_name`) checks the name. See `docs/decision/repo-and-collaboration.md`.
3. Make small, focused commits (imperative subject, e.g. `Add bid validation`).
4. Optional: rebase your own branch on the latest `main` (if already pushed, you run
   `git push --force-with-lease` yourself, never `--force`; agents never force-push), and run
   `bin/rails db:test:prepare test`, `bin/rubocop`, `bin/brakeman` locally. CI runs the same.
5. Open a PR using the template. CI must pass; no approval is required (see
   `docs/decision/repo-and-collaboration.md`);
   squash-merge, then delete the branch. **Merging to `main` auto-deploys to Railway.**

## Local setup

Ruby version is in `.ruby-version`. On Windows use WSL and keep the checkout in the WSL
filesystem (`~/`), not `/mnt/c` — see `ai/knowledge/rails-wsl-gotchas.md`.

```bash
bin/setup
bin/dev
```

## Working with AI agents

- Agents start at [`AGENTS.md`](AGENTS.md). Do not create per-tool rule files with duplicate
  content — add shared rules to `AGENTS.md`.
- Use your own agent setup, skills and habits. The only shared rules are the **Hard rules** in
  `AGENTS.md`: agents never force-push, delete remote branches or push to `main`, and change
  Railway/GitHub settings or merge PRs only when you ask
  (`docs/decision/agent-boundaries.md`). `.claude/settings.json` enforces them in Claude Code.
- Review agent-written changes as carefully as human ones. You are the author of record:
  read the diff before you push, and never paste tokens, keys or `.env` contents into a
  prompt.
- Put new shared knowledge in `ai/` (see `ai/README.md`), not only in chat or a PR comment.

## Commit email

Use your GitHub `noreply` address (GitHub → Settings → Emails → Keep my email private), since
history is public.
