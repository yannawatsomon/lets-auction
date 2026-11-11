# Product Catalog Requirements

Status: Draft
Date: 2026-11-11

## Goal

Allow users to search and filter auction products, grouped into three sections by auction status.

## Search and filters

| Control | Behavior |
|---|---|
| Search | Search products by name. |
| Category | Filter by product category, with “All” as the default. |
| Auction status | Show all sections or only the selected status: ongoing, upcoming, or ended. |
| Auction date and time | Select a “From–To” range. Proposed behavior: let users choose whether the range applies to auction start time or closing time, defaulting to start time. |
| Clear filters | Reset the search and all filters. |

All filters work together and apply to every section.

## Auction sections

Display sections in the following order:

| Section | Status condition | Product ordering |
|---|---|---|
| 1. Ongoing auctions | The auction has started and has not ended: start time <= current time < closing time. | Closing time ascending: auctions closing soonest appear first. |
| 2. Upcoming auctions | Current time is before the auction start time. | Start time ascending: auctions starting soonest appear first. |
| 3. Ended auctions | Current time is at or after the auction closing time. | Closing time descending: auctions that ended most recently appear first. |

Use server time to determine status and display dates and times in the Asia/Bangkok time zone.

## Product cards

Display products in a responsive grid. Each card includes:

- Product image.
- Product name.
- Category.
- Auction status badge.

Proposed additions:

- Display auction start and closing dates and times to explain the ordering.
- Allow users to open the product detail page from the card.

## Proposed interaction and display behavior

- Show the matching product count in each section.
- Show an empty-state message when a section has no matching products.
- Keep pagination or “Load more” independent for each section so users can reach all three sections.
- Update the status and move products to the correct section when an auction starts or ends.
- Preserve active filters when updating auction statuses.
- Adapt the grid column count to mobile and larger screens.
- Display a fallback image when a product has no image.
- Provide a retry action when products cannot be loaded.

## Open decisions

- Confirm the proposed date/time filtering behavior: start time versus closing time, default selection, and inclusive range boundaries.
- Define how cancelled auctions and auctions closed early are represented.
- Choose pagination or “Load more” for each section.
- Define how frequently auction status changes are refreshed.
- Define a deterministic secondary sort for products with identical start or closing times.

## Suggested delivery order

1. Define product categories, auction statuses, and date/time filter semantics.
2. Build product cards and the three auction sections.
3. Implement ordering independently for each section.
4. Add search, category, status, and date/time filters that work together.
5. Add per-section pagination or “Load more” and status refresh behavior.
6. Verify combined filters, empty results, time boundaries, sorting, loading failures, and mobile layouts.

Implementation must follow the existing Ruby on Rails stack. Proposed behavior and open decisions require agreement before implementation.
