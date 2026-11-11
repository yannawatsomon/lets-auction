# Shared AI hub

The central place for everything an AI agent (or a new human collaborator) needs to develop
lets-auction consistently. Entry point for agents is [`../AGENTS.md`](../AGENTS.md).

```
ai/
├── context/     # Background: what the project is, domain, glossary, constraints
├── knowledge/   # Reusable notes: how things work, gotchas, external references
└── playbooks/   # Step-by-step procedures agents/humans follow
docs/decision/   # Decisions + reasons (one file per topic, indexed in README.md)
.claude/skills/  # Two optional skills: security-review, record-decision
```

## What goes where

| You have... | Put it in |
|---|---|
| A choice that was made, with a reason | `docs/decision/<topic>.md` (use skill `record-decision`) |
| "What is this project / who is it for / what are the limits" | `ai/context/` |
| A term whose meaning is easy to get wrong (Thai/English) | `ai/context/glossary.md` |
| A gotcha, convention or "how X works here" | `ai/knowledge/<topic>.md` |
| A repeatable procedure | `ai/playbooks/<name>.md`, or a skill if an agent should auto-invoke it |

## Rules for keeping the hub healthy

- One topic per file; link instead of copying.
- Date anything time-sensitive (`YYYY-MM-DD`).
- Decisions are never deleted — mark them `Superseded` (see `docs/decision/README.md`).
- Review hub changes in PRs like code. Wrong context is worse than no context.
