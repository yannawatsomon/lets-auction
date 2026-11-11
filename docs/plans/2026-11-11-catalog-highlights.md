# Catalog highlights — issue #63

Implement the remaining Highlights requirement using existing cards, auction-type labels,
filters and refresh. Use public starting price for the mock catalog, select five products
total from matching ongoing auctions only, and apply every active catalog filter. Resolve ties by
lot ID and omit missing or invalid prices. These are implementation defaults for the demo;
real inventory integration must confirm the ranking contract with the product owner.

- [x] Add deterministic selection without inspecting bid data.
- [x] Add a homepage section above the existing status sections; preserve their ordering.
- [x] Add a responsive horizontal track with touch, keyboard and previous/next controls.
- [x] Reuse auction-type badges and filter behavior, including refresh and reset.
- [x] Verify selection edge cases and request-level filtering; run repository checks.
- [ ] Complete browser visual, mobile swipe and keyboard QA in #44.
