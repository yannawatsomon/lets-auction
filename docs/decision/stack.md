# Stack

**Status:** Decided · **Effort:** M · **Deadline risk:** Medium — scope still open

## Context

The earlier `we-auction` repo kept the stack open (2026-11-10). On 2026-11-11 the project was
scaffolded as a Rails app in this repo (`lets-auction`).

## Decisions

- **Ruby on Rails.** What: Ruby 4.0.5 (`.ruby-version`), Rails 8.1 (`Gemfile.lock`), Minitest,
  importmap, RuboCop, Brakeman, SQLite in development/test. Why: user chose Rails and ran
  `rails new` (2026-11-11). Trade-off: Ruby/Rails knowledge needed by every collaborator;
  Windows contributors need WSL. Alternative rejected: staying stack-agnostic (blocked all
  implementation). Source: user action, 2026-11-11 — *a collaborator should confirm this
  entry, since Decided is a human call.*
- **CI is GitHub Actions** (`.github/workflows/ci.yml`): scan_ruby, scan_js, lint, test. The
  generated `system-test` job was removed because `test/system/` does not exist; re-add it
  with the first system test. Source: PR "Fix CI: add db/schema.rb, drop system-test job".

## Open questions

- Production database: SQLite files are lost on Railway redeploys without a volume. Postgres
  (add `pg`, change `config/database.yml`) or a volume? See `deployment.md`. The Milestone 1
  design draft (`docs/design/milestone-1-api-and-database.md`) uses Postgres-only features
  (enums, `citext`, `jsonb`, partial indexes).
- Scope and users (`scope.md`, `ai/context/project.md`); auth approach (`auth.md`); real-time
  bidding mechanism (`realtime.md`); frontend approach (Hotwire only, or a separate client
  calling a JSON API? Tailwind?).
