---
name: record-decision
description: Optional helper for writing a decision into docs/decision/ with What/Why/Trade-off/Source and updating the index. Use only if the user asks to record or change a decision.
---

# Record a decision

Decisions live in `docs/decision/`, one file per topic, indexed in `docs/decision/README.md`.

## Steps

1. Read `docs/decision/README.md`. Does a topic file already cover this? Update it rather than
   creating a duplicate.
2. If the new choice contradicts a **Decided** bullet, do not edit it away. Prefix the old
   bullet: `~~**old decision**~~ **Superseded (YYYY-MM-DD):** <reason>, see <new bullet/file>.`
3. Create or edit `docs/decision/<topic>.md` using `docs/decision/_template.md`. Every
   decision needs: **What / Why / Trade-off / Alternative rejected / Source** (who confirmed,
   date).
4. Update the index row in `docs/decision/README.md` in the same change (status, one-line
   summary).
5. Status rules: `Open` → `Decided` → `Superseded`. Only a human collaborator moves a topic to
   `Decided` — an agent proposes, a person confirms in the PR or chat.
6. Mention the decision file in the PR description.

## Don'ts

- Don't delete old decisions. History is the evidence.
- Don't record guesses as Decided. Use `Open` and list the open question.
- Don't put secrets or personal data in decision docs (public repo).
