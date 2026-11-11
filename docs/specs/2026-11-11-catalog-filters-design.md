# Catalog filters — #41 and auction-type filtering from #63

Implement the search/filter flow authorized by the user in chat on 2026-11-11.
Use a Rails GET form and an ActiveModel form/service, reusing Catalog::Sections.
This fits the existing server-rendered app without adding client-side search or dependencies.

- Parameters: `q`, `category`, `status`, `auction_type`, `date_field`, `from`, `to`.
- Default category/status/type: all (empty string). Default date field: `starts_at`;
  alternative: `ends_at`. Date values are datetime-local inputs in Asia/Bangkok.
- Case-insensitive literal substring search on product name; trim query whitespace.
- All nonempty criteria intersect. Category is validated against the supplied category list.
- Status allows ongoing/upcoming/ended, type allows english/sealed_first_price.
- Date range includes both endpoints; either endpoint may be omitted. Accept local ISO
  timestamps to minute or second precision; reject invalid dates and reversed ranges.
- Reject nonscalar values and oversized text; show field errors and no products on invalid input.
- Keep form values on submit, show filtered counts and empty states; selected status hides other sections.
- Clear filters links to the query-free preview URL.
- Apply to authorized input lots only; no new production route or visibility policy.
- Preview keeps mock data. No Highlights, pagination, live refresh, or database adapter in this task.

Verification: service tests for intersections, literal search, exact boundaries, zones,
malformed inputs, empty results, and sorting; view tests for form controls/errors/clear link;
development HTTP checks for form submission and rendered results.
