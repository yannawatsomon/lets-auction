# UI design (look, tokens, components)

**Status:** Open · **Effort:** M · **Deadline risk:** Low — pages work either way; only the look and copy change

## Context

Each module styled its pages on its own (`application.css`, `bidding.css`, `catalog.css`,
`onboarding.css`) from an earlier cream/ink/gold mockup in Thai. A new team mockup (Claude
Design canvas "Lets Auction (English, shadcn)", 23 screens for buyer, seller, admin, mobile
and states, 2026-11-19) redraws every screen in English with shadcn/ui tokens. @guy127 asked
to adopt it with these rules (2026-11-20):

- shadcn/ui tokens: `--background`, `--foreground`, `--card`, `--muted`, `--border`, `--primary`, …
- Spacing on a 4 / 8 / 16 / 24 scale, equal row heights.
- One icon set (Lucide), never emoji as icons.
- No gradient text, no glow, one accent color.
- AI states (loading, approval, streaming) follow beautifului.dev; components follow ui.shadcn.com.

## Decisions

- **Adopt the shadcn look from the new mockup.** What: tokens and values below, font Geist
  (Geist Mono for numbers, times and receipt numbers), radius 8 for controls and 12 for cards,
  full radius for badges, 44px controls, 52px table rows, Lucide icons inline as SVG. Why: one
  look across modules, matching the team mockup. Trade-off: every module restyles its pages.
  Alternative rejected: keep the cream/ink/gold look (doesn't match the new mockup). Source:
  @guy127, 2026-11-20 (proposed; a collaborator confirms).
- **UI copy is English.** What: page text, labels, flash and error messages in English, as in
  the mockup. Geist has no Thai letters, and the mockup is English. Trade-off: Thai-speaking
  users read English; Thai can come back later through Rails i18n. Alternative rejected: keep
  Thai copy with a Thai fallback font. Source: @guy127, 2026-11-20 (proposed).
- **Roll out one module at a time.** What: bidding switches first (this PR, scoped to
  `.bidding` in `bidding.css`, so other pages don't change). Catalog, onboarding, product
  onboarding and payment switch in their owners' PRs using `ai/knowledge/ui-design.md`. Why:
  each page belongs to a different teammate, and shared `application.css` already uses
  `--muted` for a text color, so global shadcn names would clash today. Trade-off: two looks
  side by side until every module moves. Source: @guy127, 2026-11-20 (proposed).
- **Rules live in `ai/knowledge/ui-design.md`, not a new skill.** Why: `ai-agent-hub.md`
  (Decided) keeps only two own skills. Source: `ai-agent-hub.md`.

## Rules / examples

| Token | Value | Use |
|---|---|---|
| `--background` | `#FAFAFA` | page ground |
| `--foreground` | `#09090B` | text |
| `--card` | `#FFFFFF` | cards, header, inputs |
| `--muted` | `#F4F4F5` | subtle fills, hover, active nav |
| `--muted-foreground` | `#5F5F69` | secondary text (4.5:1 on white) |
| `--border` | `#E4E4E7` | borders, dividers |
| `--input` | `#D4D4D8` | input borders |
| `--primary` | `#A16207` | the one accent: primary buttons, focus ring, progress |
| `--primary-foreground` | `#FFFFFF` | text on primary |
| `--ring` | `#A16207` | focus outline |
| `--destructive` | `#B91C1C` | destructive actions, errors |

Status colors (badges and notices only): success `#F0FDF4`/`#15803D`, warning
`#FFFBEB`/`#92400E`, danger `#FEF2F2`/`#B91C1C`.

## Open questions

- Confirm English UI copy for all modules, or Thai via i18n later? (blocks other modules' copy)
- When every module has moved, put the tokens on `:root` in `application.css` and drop the
  old cream/ink/gold names.
