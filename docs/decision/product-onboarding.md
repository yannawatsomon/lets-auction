# Product onboarding (seller lists a product, admin verifies it)

**Status:** Open · **Effort:** M · **Deadline risk:** High — issues #48 to #54 of the
`product onboarding` milestone all wait on these answers

## Context

A seller lists a product and an admin verifies it before it can go into an auction. The flow is
described in [`docs/design/product-onboarding-flow.md`](../design/product-onboarding-flow.md)
(draft) and builds on [`scope.md`](scope.md) and the Milestone 1 design draft
[`docs/design/milestone-1-api-and-database.md`](../design/milestone-1-api-and-database.md).
The flow doc leaves ten questions open; this file answers them as **proposals**. Each bullet
becomes Decided only when a collaborator confirms it in a PR (see `README.md`). Tracking issue:
#47. Implementation plan: [`docs/plans/2026-11-11-product-onboarding.md`](../plans/2026-11-11-product-onboarding.md).

Not decided here (owned elsewhere): money as integer satang → `bidding.md`; auth and roles →
`auth.md`; database (Postgres vs SQLite) → `stack.md`, `deployment.md`; Rails views vs a separate
client → `stack.md`.

## Proposals

- **Media limits.** What: 1 to 5 images (required), 0 to 2 videos (optional), counted per item
  and enforced by the server in a transaction that locks the item row. Why: buyers and the
  admin always have something to look at; the 5-image cap is from the Milestone 1 draft.
  Trade-off: a seller with only a video or a document cannot list. Alternative rejected: 1
  video, as in the team's UI sketch for adding a lot; 2 lets a seller show a product from two
  angles at no extra rule. Source: `scope.md` (2026-11-11), flow doc.
- **File formats and sizes.** What: images JPEG, PNG or WebP up to 10 MB; videos MP4 up to
  200 MB; documents PDF, JPEG or PNG up to 20 MB. The server checks the declared type and size
  before issuing an upload URL and checks the stored file again after upload. No video
  duration cap in Milestone 1. Why: covers phone photos and clips; 200 MB matches the team's
  UI sketch. Trade-off: a long clip can still be large; no duration check. Alternative
  rejected: allowing SVG or HTML-capable types (script risk). Source: flow doc suggestion,
  2026-11-11.
- **Documents: at most 10 per item, none required at listing.** What: the item can carry up to
  10 verification documents. Whether a 20M THB English item must have one is checked when the
  admin adds the item to an English event (#28), not when the seller lists it. Why: an item is
  not tied to an auction type until it is put in a lot, so listing cannot know. Trade-off: the
  seller finds out late that a document is needed; the admin can use "request more evidence".
  Alternative rejected: asking the seller to pick an auction type up front. Source: this
  proposal, 2026-11-11.
- **Details are free text.** What: title, category, description, minimum price and an optional
  contact channel; the form shows prompts (condition, size, age, defects, provenance) but
  stores them in the description. No new `items` columns. Why: structured fields are easy to
  add later and hard to remove. Trade-off: no filtering by brand, year or condition in the
  catalog. Alternative rejected: structured fields now (the team's UI sketch has brand,
  model, serial and year; revisit if the catalog needs filters). Source: flow doc, 2026-11-11.
- **No `draft` status.** What: submitting creates the item in `pending_review`; the wizard keeps
  its state in the browser until then. The state machine does not change. Why: fewer states
  for every query and screen. Trade-off: a seller who leaves loses unsent text, and uploaded
  files become orphans (next bullet). Alternative rejected: a `draft` status with autosave.
  Source: flow doc, 2026-11-11.
- **Orphaned uploads are purged after 48 hours.** What: a Solid Queue recurring job deletes
  unattached stored files older than 48 hours. Why: stops storage filling with abandoned
  uploads. Trade-off: a seller who comes back after two days re-uploads. Alternative
  rejected: a manual clean-up. Source: issue #49, 2026-11-11.
- **Files go through Rails' built-in Active Storage with direct upload.** What: `POST
  /uploads` validates kind, type and size, then returns a signed upload URL; the item stores an
  attachment, not a raw URL (`item_media` has a file attachment instead of a `url` column).
  Why: the framework already provides signed URLs and cleanup helpers, and the repo already has
  `image_processing`. Trade-off: differs from the design draft's `url` column. The production
  storage service (an S3-compatible bucket) is still undecided, and adding its gem needs
  approval. Alternative rejected: hand-rolled presigned URLs. Source: this proposal,
  2026-11-11.
- **Edits during review are caught, not blocked.** What: the admin's decision form carries the
  item's `lock_version`; if the seller changed the item since the admin opened it, the
  decision is refused and the admin sees the updated item. An item no longer in
  `pending_review` also refuses the decision. Why: no lock to release when an admin walks
  away. Trade-off: an admin occasionally reloads and re-reads. Alternative rejected: locking
  the item while the admin has it open. Source: this proposal, 2026-11-11.
- **A note is required for `reject` and `request_info`.** What: the review note cannot be
  blank for those two actions. Why: the seller must know why or what is missing. Trade-off:
  one more field for the admin. Source: flow doc proposal, 2026-11-11.
- **Every status change notifies the seller.** What: a notification row is created in the same
  transaction as the review; the seller reads it at `GET /me/notifications`. Source: flow doc
  proposal, issue #53.
- **Any admin may verify any item.** What: no per-item reviewer assignment in Milestone 1.
  Why: `item_reviews.admin_id` supports assignment later. Source: flow doc, 2026-11-11.
- **No "copy from a rejected item" in Milestone 1.** What: after `reject` the seller creates a
  new item from scratch. Trade-off: re-uploading. Alternative rejected: a copy feature (extra
  scope). Source: flow doc question 9, 2026-11-11.

## Rules / examples

| Kind | Min | Max | Types | Size limit |
| --- | --- | --- | --- | --- |
| image | 1 | 5 | JPEG, PNG, WebP | 10 MB |
| video | 0 | 2 | MP4 | 200 MB |
| document | 0 | 10 | PDF, JPEG, PNG | 20 MB |

## Open questions

- **Who confirms these proposals?** A collaborator, in the PR for #47. Until then, #48 to #54
  must not code past a proposal that is still Open.
- **Video count:** 2 here, 1 in the team's UI sketch. Which one?
- **Production file storage:** which S3-compatible service, and who approves the gem? Blocks
  the production half of #49.
- **Database:** the row-lock rule cannot be tested on SQLite → `stack.md`.
- **Users and auth** do not exist on `main` yet → `auth.md`, user-onboarding milestone (#16).
  Blocks #48 onward.
- **Language of the design docs** (Thai vs English) → `README.md` open questions.
