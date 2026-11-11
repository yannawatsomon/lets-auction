# lets-auction

> TODO: one-line description. See [`ai/context/project.md`](ai/context/project.md).

Ruby on Rails app, deployed to Railway from `main`. Continues the earlier `we-auction` repo.

## Status

Early. Scaffolded 2026-11-11; scope is not written down yet — see
[`docs/decision/`](docs/decision/README.md).

## Run it

Ruby version is in `.ruby-version`. On Windows use WSL, with the checkout in the WSL filesystem.

```bash
bin/setup      # installs gems, prepares the database, starts the server
bin/dev        # start the server later
bin/rails db:test:prepare test   # tests (what CI runs)
bin/rubocop && bin/brakeman      # lint and security scan
```

Open http://localhost:3000. **Merging to `main` deploys to production on Railway.**

## For collaborators

1. Read [`CONTRIBUTING.md`](CONTRIBUTING.md).
2. Read the decision log: [`docs/decision/README.md`](docs/decision/README.md).
3. Using an AI agent? It should start at [`AGENTS.md`](AGENTS.md) (a few hard rules only).
   Shared knowledge and context live in [`ai/`](ai/README.md).

## Repo map

```
AGENTS.md          entry point for all AI agents
CLAUDE.md          Claude Code (imports AGENTS.md)
ai/                shared context, knowledge, playbooks
docs/decision/     decision log (what + why)
.claude/           shared Claude Code permissions + 2 optional skills
.github/           CI, PR/issue templates, Dependabot, Copilot pointer
app/ config/ db/ test/   the Rails app
```
