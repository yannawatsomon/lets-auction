# UI design rules (shadcn look)
Last verified: 2026-11-20

## Summary

How pages should look, for people and agents restyling a module. Decision and token values:
[`docs/decision/ui-design.md`](../../docs/decision/ui-design.md) (Open). Bidding
(`app/assets/stylesheets/bidding.css`) is the first module on it; copy from there.

## Rules

- **Tokens, never raw colors.** Use `--background`, `--foreground`, `--card`, `--muted`,
  `--muted-foreground`, `--border`, `--input`, `--primary`, `--primary-foreground`, `--ring`,
  `--destructive`. Until every module moves, declare them on your layout's `<body>` class
  (bidding: `.bidding`), not on `:root`: `application.css` still uses `--muted` as a text color.
- **Spacing 4 / 8 / 16 / 24** (32+ only between page sections). Rows in one list or table have
  equal height: 52px table rows, 44px controls.
- **One accent.** `--primary` (amber `#A16207`) only for the main action, focus ring, progress
  and the live dot. Status badges use the success / warning / danger pairs in the decision doc.
  No gradient text, no glow, no colored shadows; cards get `0 1px 2px rgb(9 9 11 / .05)` at most.
- **Icons: Lucide only, inline SVG** (24 viewBox, `stroke="currentColor"`, stroke width 2,
  `aria-hidden="true"`). Never emoji as icons, no second icon set. Bidding's helper:
  `bidding_icon(:arrow_left)`; add a path from lucide.dev (ISC license) when you need a new one.
- **Components follow ui.shadcn.com**: button (default/primary, outline, ghost, destructive;
  radius 8, 44px tall), badge (full radius, 24px, 12px text), card (radius 12, 1px border,
  padding 24), input (radius 8, `--input` border, `--ring` on focus), table (header 12px muted,
  52px rows, hover `--muted`), alert (icon + text in a bordered box).
- **AI and waiting states follow beautifului.dev**: loading shows what is happening and the
  elapsed time; an approval card asks one question at a time; streamed text appears in place
  with a cursor; finished task rows show done / running / error with an icon, not only color.
- **Type:** Geist (Google Fonts) for text, Geist Mono with `tabular-nums` for money, times,
  countdowns and receipt numbers. Headings weight 600 with `letter-spacing: -0.02em`.
- **Copy is English** (Geist has no Thai). Write labels as the mockup does: sentence case,
  short, no trailing periods on buttons.
- **Accessible as drawn:** real `<button>`/`<a>`/`<label>`, `aria-label` on icon-only buttons,
  text contrast 4.5:1, visible focus (`outline: 2px solid var(--ring)`), honor
  `prefers-reduced-motion`.

## Gotchas

- Propshaft loads every stylesheet on every page: scope every selector under your module's
  body class, or you'll restyle a teammate's page.
- Security tests in `test/integration/bidding_security_test.rb` scan page text for leaked
  sealed-bid counts with English patterns; when you rename copy on bidding pages, keep those
  patterns in step.

## References

- Team mockup: Claude Design canvas "Lets Auction (English, shadcn)" (link in the PR that added
  this file).
- https://ui.shadcn.com, https://lucide.dev, https://beautifului.dev
