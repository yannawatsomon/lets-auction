# Catalog reference redesign

User reference: `~/Downloads/auction-redesign.html`, supplied 2026-11-11.
Reuse its cream background, white/gold/ink panels, typography hierarchy, compact labels,
image placeholders, metadata divider, starting-price footer, and detail interaction.
Keep Rails rendering and existing validated filters, section ordering, pagination, and demo notice.

Homepage and development preview are overview pages: render the first three matching lots
per section, with CSS hiding the third at <=900px and the second at <=600px. Thus each
section has exactly one row (3/2/1 cards). Do not report a fixed visible count on overview.
Each nonempty section links via “ดูเพิ่มเติม” to `/catalog?status=...`, preserving other
filters and resetting page counters. Hidden overview cards must use display:none so they
are not keyboard-focusable. Full listings at `/catalog` use existing cumulative 12-item
Load more behavior and matching totals; filters/clear stay on that route.

Adapt content rather than importing reference JavaScript, prices, sorting options or datasets.
Add explicitly synthetic starting prices in integer satang to the existing demo lots.
Cards accept optional prices and show an accessible native dialog for preview details
when no real detail route exists. Reuse Baht.format; do not calculate money with floats.

No dependency/schema/auth changes, no production deploy in this implementation task.
Tests cover overview size, filter-preserving section links, listings/pagination, safe card
rendering, optional prices, and existing failure/retry. Browser QA must check 3/2/1 rows
and dialog keyboard behavior where browser access is available.
