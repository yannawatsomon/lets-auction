# Catalog homepage

User request (2026-11-11): replace the current homepage with the catalog page.

Reuse the existing catalog cards, filters, and section layout at `/`, with GET filters
and a query-free clear link pointing to `/`. Keep `/catalog-preview` development-only.
Extract shared page preparation and rendering rather than duplicating the controllers/views.

Synthetic lots remain restricted to development/test. Production serves the catalog
layout with empty sections until authorized real data is integrated; do not enable demo
users, inventory, or preview endpoints in production. No database or dependency changes.

Verify homepage rendering, filter submission, field errors, clear links, and the
production mock-data boundary. Keep changes uncommitted until requested.
