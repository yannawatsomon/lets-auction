# Product Onboarding Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use subagent-driven-development (recommended) or executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** A seller can list a product (1-5 images, 0-2 videos, details, minimum price, optional documents), an admin can approve / reject / request more evidence, and the seller is told the outcome.

**Architecture:** Rails models own the rules (media limits under a row lock, status transitions, append-only review history). Uploads use Active Storage direct upload behind our own `POST /uploads` so type and size are checked before a signed URL is issued. Seller and admin screens are Rails views (Hotwire) unless #47 decides on a separate JSON client. One PR per task.

**Tech Stack:** Ruby 4.0.5, Rails 8.1, Minitest, Active Storage + `image_processing` (already in `Gemfile`), Solid Queue (orphan cleanup), Stimulus (wizard).

**Spec:** [`docs/design/product-onboarding-flow.md`](../design/product-onboarding-flow.md) (draft), [`docs/design/milestone-1-api-and-database.md`](../design/milestone-1-api-and-database.md) (schema, state machine, endpoints), [`docs/decision/scope.md`](../decision/scope.md) (Open). GitHub milestone "product onboarding", issues #47-#54.

## Global Constraints

- Images: **1 to 5**, required. Videos: **0 to 2**, optional. Documents: no limit until #47 decides.
- Minimum price is set by the seller, must be greater than 0, and the admin cannot change it.
- Money is an integer number of satang in `bigint` columns named `*_cents` (proposed in `docs/decision/bidding.md`, Open) - so `items.min_price_cents`, not the design draft's `numeric`.
- Item statuses: `pending_review`, `info_requested`, `approved`, `rejected`, `in_auction`, `sold`, `withdrawn`. The seller can edit only in `pending_review` or `info_requested`. Withdraw is allowed in `pending_review`, `info_requested`, `approved`, not in `in_auction`.
- `item_reviews` is append-only history; every admin action is also written to `audit_logs`.
- A `reject` or `request_info` note is required (proposed in the flow doc).
- Buyers only ever see `approved` items.
- Repo rules (`AGENTS.md`): English files; branch `<handle>-<type>-<issue>-<detail>`; Decided/Open docs updated before code that contradicts them; ask before commit, push, PR or any `Gemfile` change; before a PR run `bin/rails db:test:prepare test`, `bin/rubocop`, `bin/brakeman`; no secrets or real personal data (public repo).

## Prerequisites (blockers found while planning)

None of these is in this milestone, so they need an owner before Task 2 can finish.

1. **No `users` table or auth on `main`.** Every task needs `User` with a `role` (buyer, seller, admin) and `Current.user`. The `user onboarding` milestone (#16) and `docs/decision/auth.md` (Open) own this. Do not stub it on this branch; wait for it or agree the interface with that owner first. Plan assumes `User#seller?`, `User#admin?`, `Current.user`, and fixtures `users(:seller)`, `users(:other_seller)`, `users(:admin)`.
2. **Database is SQLite; the design needs Postgres** (`stack.md`, `deployment.md`). SQLite ignores row locks, so the "two requests cannot exceed a limit" rule cannot be proven by a test until Postgres is chosen. Task 2 writes the concurrency test and skips it on SQLite with a message; Task 8 needs it running.
3. **`audit_logs` and `notifications` tables** are in the design draft but nobody owns them yet (bidding #28/#30 also need `audit_logs`). Tasks 6 and 7 create them only if absent on `main` at that time.
4. **File storage service** for production (Railway has no S3 of its own) is undecided (#49). Needs `aws-sdk-s3` or similar: a `Gemfile` change, so ask first.
5. **Frontend approach** (Hotwire vs separate client) is Open in `stack.md`. This plan assumes Rails views.

## Review Focus

Inputs and conditions the spec implies but does not spell out. Each has a test in the task named in brackets.

1. Two requests at once add images to the same item and push it past 5. Expected: one is rejected, count stays 5. [Task 2]
2. Seller B opens or changes seller A's item by id. Expected: 404, nothing changes. [Task 4, 6]
3. Upload whose declared type, size or extension lies (e.g. an HTML or SVG file declared as `image/png`, a 2 GB "video"). Expected: refused before a URL is issued, and re-checked after upload. [Task 3]
4. Minimum price `0`, negative, `abc`, `1e9`, `10,000.50` with satang rounding, or a value above the `bigint` range. Expected: validation error, never a silent change. [Task 2]
5. Admin approves while the seller is editing, or the admin double-clicks. Expected: the decision applies only to an item still in `pending_review`, one review row per click that succeeded, no duplicate notification. [Task 6]
6. Seller withdraws an `approved` item at the moment a lot is created from it. Expected: exactly one wins. [Task 2]

---

### Task 1: Record product onboarding decisions (#47)

**Files:**
- Create: `docs/decision/product-onboarding.md` (use the `record-decision` skill and `_template.md`)
- Modify: `docs/decision/scope.md` (move the media-limit bullet's open questions), `docs/decision/README.md` (index row), `docs/design/product-onboarding-flow.md` (state machine only if `draft` is added; `item_media.url` -> `has_one_attached :file`)

**Interfaces:**
- Produces: written answers every later task reads. Tasks 2-8 may not start coding past a point that a still-Open answer blocks.

- [ ] **Step 1: List each open question from the flow doc with a recommended answer.** Recommendations: images JPEG/PNG/WebP up to 10 MB; videos MP4 up to 200 MB; documents PDF or image up to 20 MB, max 10 per item, required for 20M THB English items (confirm); description is free text in Milestone 1; no `draft` status (wizard state kept client-side, submit creates the item); unattached blobs purged after 48 hours by a Solid Queue recurring job; seller sees a "changed since you opened" warning rather than a lock; Active Storage for files; Rails views + Hotwire for the UI.
- [ ] **Step 2: Write `product-onboarding.md` with every answer as a proposal** (What / Why / Trade-off / Source per `record-decision`). Status stays Open - only a human collaborator moves it to Decided.
- [ ] **Step 3: Update the README index row and `scope.md`; mark the matching open questions in the flow doc as answered.**
- [ ] **Step 4: Verify.** Run `grep -n "product-onboarding" docs/decision/README.md` -> one row; every relative link in the new file resolves (`ls` each target).
- [ ] **Step 5: Ask the human before committing; open the PR (docs only) and request the confirmations the team still owes.** Tasks 2+ wait for the Decided status of: media limits, file formats/sizes, `draft` status.

### Task 2: Item data model with media limits (#48)

**Files:**
- Create: `db/migrate/<ts>_create_categories.rb`, `..._create_items.rb`, `..._create_item_media.rb`, `..._create_item_reviews.rb`
- Create: `app/models/category.rb`, `app/models/item.rb`, `app/models/item_medium.rb`, `app/models/item_review.rb`
- Create: `test/models/item_test.rb`, `test/models/item_review_test.rb`, `test/models/item_media_concurrency_test.rb`, `test/fixtures/categories.yml`, `test/fixtures/items.yml`
- Modify: `config/initializers/inflections.rb` only if `"item_media".classify` is not `"ItemMedium"` (check in a console first)

**Interfaces:**
- Consumes: `User` with `role` (Prerequisite 1).
- Produces:
  - `Item::MEDIA_LIMITS = { "image" => 1..5, "video" => 0..2 }.freeze` (documents unlimited until Task 1 decides)
  - `Item::TRANSITIONS: Hash{String => Array<String>}` (pending_review -> approved, rejected, info_requested, withdrawn; info_requested -> pending_review, withdrawn; approved -> withdrawn, in_auction; in_auction -> sold, approved)
  - `Item#editable? -> Boolean`
  - `Item#sync_media!(entries) -> void`, `entries` = ordered array of `{ kind: "image"|"video"|"document", signed_id: String }`; replaces the item's media inside `with_lock`, raises `ActiveRecord::RecordInvalid` when a limit is broken
  - `Item#transition!(to, by:) -> Item`, raises `Item::InvalidTransition` (subclass of `StandardError`)
  - `ItemReview` columns `item_id`, `admin_id`, `action` (`approve|reject|request_info`), `note`, `created_at`; read-only once persisted
  - `items.min_price_cents` (`bigint`, `> 0`), `items.status` string enum, `items.contact_channel` nullable

- [ ] **Step 1: Write failing tests in `test/models/item_test.rb`.** Names and assertions: `"accepts 1 to 5 images"`; `"rejects a sixth image"` (`assert_raises(ActiveRecord::RecordInvalid)`); `"rejects zero images on submit"`; `"rejects a third video"`; `"allows zero videos"`; `"min price must be a positive integer"` for `0`, `-1`, `nil` (and non-integer input rejected, not truncated); `"seller can edit only in pending_review or info_requested"` (`editable?` per status); `"transition! follows TRANSITIONS and raises InvalidTransition otherwise"` (approved -> pending_review raises; rejected -> anything raises).
- [ ] **Step 2: Write failing tests in `test/models/item_review_test.rb`.** `"is read-only after create"` (`assert_raises(ActiveRecord::ReadOnlyRecord) { review.update!(note: "x") }`); `"reject and request_info require a note"`; `"approve allows a blank note"`.
- [ ] **Step 3: Write `test/models/item_media_concurrency_test.rb`.** `use_transactional_tests = false`; the item holds 4 images; two threads each call `sync_media!` to make it 5 images by adding a different new one. Assert `item.item_media.where(kind: "image").count == 5` and that exactly one thread raised `ActiveRecord::RecordInvalid`. First line: `skip "needs Postgres row locks" if ActiveRecord::Base.connection.adapter_name == "SQLite"`.
- [ ] **Step 4: Run** `bin/rails test test/models` **Expected:** FAIL, `NameError: uninitialized constant Item`.
- [ ] **Step 5: Write the four migrations** from the `CREATE TABLE` blocks in `milestone-1-api-and-database.md` (lines 351-388), changed to: `min_price_cents bigint NOT NULL CHECK (> 0)`, `lock_version integer NOT NULL DEFAULT 0` on `items`, `item_media` without `url` (Active Storage attachment instead), index `(item_id, kind, sort_order)`, `item_reviews.note` text. Use `uuid` primary keys only if the database decision says Postgres; otherwise bigint ids and say so in the PR.
- [ ] **Step 6: Implement the models** to the Interfaces block. `sync_media!` locks with `with_lock`, counts per kind after the change, and validates before commit. `ItemReview#readonly?` returns `persisted?`.
- [ ] **Step 7: Run** `bin/rails db:test:prepare test test/models` **Expected:** PASS (concurrency test SKIPPED on SQLite, reported as skipped, not passed).
- [ ] **Step 8: Run** `bin/rubocop` and `bin/brakeman`; fix findings. Ask the human before committing.

### Task 3: Uploads and file storage (#49)

**Files:**
- Create: `app/controllers/uploads_controller.rb`, `app/models/upload_policy.rb`, `app/jobs/purge_unattached_uploads_job.rb`
- Create: `test/controllers/uploads_controller_test.rb`, `test/models/upload_policy_test.rb`, `test/jobs/purge_unattached_uploads_job_test.rb`
- Modify: `config/routes.rb` (`post "/uploads"`), `config/recurring.yml` (daily purge), `config/storage.yml` + `config/environments/production.rb` (service chosen in Task 1; ask before adding a gem)

**Interfaces:**
- Consumes: `Current.user`, `User#seller?`.
- Produces:
  - `UploadPolicy.check!(kind:, content_type:, size:) -> void`, raises `UploadPolicy::Rejected` with a message; limits from Task 1 (`image` JPEG/PNG/WebP <= 10 MB, `video` MP4 <= 200 MB, `document` PDF/JPEG/PNG <= 20 MB)
  - `POST /uploads` body `{ kind, content_type, size, filename, checksum }` -> `200 { signed_id, direct_upload: { url, headers } }`; `403` for non-sellers, `422` for a rejected file
  - `PurgeUnattachedUploadsJob#perform -> void` purges `ActiveStorage::Blob.unattached` older than 48 hours

- [ ] **Step 1: Write failing `UploadPolicy` tests.** `"accepts image/jpeg of 10 MB"`; `"rejects image/jpeg of 10 MB + 1 byte"`; `"rejects image/svg+xml"`; `"rejects text/html declared as image"` (kind image, content_type `text/html`); `"rejects video/mp4 over 200 MB"`; `"rejects unknown kind"`; `"rejects size 0 and negative"`.
- [ ] **Step 2: Write failing controller tests.** `"seller gets a signed URL"`; `"buyer gets 403"`; `"anonymous gets 401/redirect to login"`; `"oversized file gets 422 and no blob is created"` (`assert_no_difference "ActiveStorage::Blob.count"`).
- [ ] **Step 3: Write the failing job test.** Blob unattached 49 hours old is purged; unattached 1 hour old stays; attached blob of any age stays.
- [ ] **Step 4: Run** `bin/rails test test/models/upload_policy_test.rb test/controllers/uploads_controller_test.rb test/jobs` **Expected:** FAIL, missing constants.
- [ ] **Step 5: Implement** `UploadPolicy`, `UploadsController#create` (policy check, then `ActiveStorage::Blob.create_before_direct_upload!`), and the job; schedule the job in `config/recurring.yml`.
- [ ] **Step 6: Add the post-upload check.** In `ItemMedium`, a validation that re-reads `blob.byte_size` and `blob.content_type` through `UploadPolicy` when media is attached (declared values are not trusted). Add test `"attach fails when the stored blob exceeds the limit"` in `test/models/item_test.rb`.
- [ ] **Step 7: Run** the same command plus `bin/rails test` **Expected:** PASS. Run the `security-review` skill on this task (file uploads) and record findings in the PR.
- [ ] **Step 8: Ask before committing.**

### Task 4: Seller dashboard (#51)

**Files:**
- Create: `app/controllers/seller/items_controller.rb` (index, show, update, destroy, `resubmit`), `app/views/seller/items/index.html.erb`, `show.html.erb`, `app/controllers/concerns/require_role.rb`
- Create: `test/controllers/seller/items_controller_test.rb`
- Modify: `config/routes.rb` (`namespace :seller { resources :items, only: %i[index show update destroy] { post :resubmit, on: :member } }`)

**Interfaces:**
- Consumes: `Item#editable?`, `Item#transition!`, `Item#sync_media!` (Task 2); `Current.user`.
- Produces: `RequireRole` concern with `require_role(:seller)` / `require_role(:admin)` (403 for the wrong role); `Seller::ItemsController` scoping every lookup through `Current.user.items` so another seller's id returns 404.

- [ ] **Step 1: Write failing tests.** `"index lists only my items and filters by status"`; `"show returns 404 for another seller's item"`; `"update is allowed in info_requested"`; `"update is refused (422) in approved"` and the item is unchanged; `"resubmit moves info_requested to pending_review"`; `"resubmit on pending_review is refused"`; `"destroy withdraws a pending_review item"`; `"destroy is refused for in_auction"`; `"show displays the admin note for rejected and info_requested"`; `"buyer gets 403 on every action"`.
- [ ] **Step 2: Run** `bin/rails test test/controllers/seller` **Expected:** FAIL, no route.
- [ ] **Step 3: Implement** the controller with strong params that permit `title, description, category_id, min_price, contact_channel` and a media list; convert `min_price` (THB string) to `min_price_cents` in one helper and reject malformed input.
- [ ] **Step 4: Build `index`/`show` views** with a status filter and the latest `item_reviews.note`; mobile-first layout.
- [ ] **Step 5: Run** `bin/rails test` **Expected:** PASS. Then `bin/rubocop`, `bin/brakeman`. Ask before committing.

### Task 5: Seller product wizard (#50)

**Files:**
- Create: `app/controllers/seller/items_controller.rb#new,#create` (extend Task 4's file), `app/views/seller/items/new.html.erb` + step partials `_images.html.erb`, `_videos.html.erb`, `_details.html.erb`, `_review.html.erb`, `app/javascript/controllers/media_picker_controller.js`, `app/javascript/controllers/wizard_controller.js`
- Create: `test/controllers/seller/items_create_test.rb`, `test/integration/seller_wizard_flow_test.rb`
- Modify: `config/importmap.rb` only if a new JS dependency is needed (prefer none)

**Interfaces:**
- Consumes: `POST /uploads` (Task 3), `Item#sync_media!` (Task 2), `Seller::ItemsController` (Task 4).
- Produces: `POST /seller/items` creates an item in `pending_review` with its media in one transaction.

- [ ] **Step 1: Write failing request tests.** `"create with 1 image succeeds and status is pending_review"`; `"create with 0 images returns 422 and creates no item"`; `"create with 6 images returns 422"`; `"create with 3 videos returns 422"`; `"create with min price 0 returns 422"`; `"a failed validation keeps the submitted text in the form"`.
- [ ] **Step 2: Write the integration flow test.** Sign in as seller -> GET new -> POST with signed ids -> follow redirect -> page shows "Waiting for verification".
- [ ] **Step 3: Run** `bin/rails test test/controllers/seller test/integration` **Expected:** FAIL.
- [ ] **Step 4: Implement** `new`/`create`; wrap `create` in a transaction (`item.save!` then `sync_media!`).
- [ ] **Step 5: Build the four steps.** `media_picker_controller` disables add at the cap (5 / 2) and shows the remaining count; first image is the cover; reorder writes `sort_order`; a failed direct upload shows retry and keeps the other files; step 1 blocks Next at 0 images; step 3 shows the "admin cannot change the minimum price" note; step 4 links back to each step.
- [ ] **Step 6: Manual check in the Browser pane** at mobile width (375 px) and desktop: add 5 images (add disabled), 2 videos, skip videos, submit. Record what you saw in the PR. (UI cannot be proven by the unit tests alone.)
- [ ] **Step 7: Run** `bin/rails test`, `bin/rubocop`, `bin/brakeman`. Ask before committing.

### Task 6: Admin verification and review service (#52)

**Files:**
- Create: `app/services/item_reviewer.rb`, `app/controllers/admin/items_controller.rb` (index, show), `app/controllers/admin/reviews_controller.rb` (create), `app/views/admin/items/index.html.erb`, `show.html.erb`
- Create: `app/models/audit_log.rb` + migration **only if absent on main**
- Create: `test/services/item_reviewer_test.rb`, `test/controllers/admin/items_controller_test.rb`, `test/controllers/admin/reviews_controller_test.rb`
- Modify: `config/routes.rb` (`namespace :admin { resources :items, only: %i[index show] { resources :reviews, only: :create } }`)

**Interfaces:**
- Consumes: `Item#transition!`, `ItemReview` (Task 2), `RequireRole` (Task 4).
- Produces:
  - `ItemReviewer.call(item:, admin:, action:, note: nil) -> ItemReview`, runs in `item.with_lock`; raises `ItemReviewer::NotReviewable` unless the item is `pending_review`; writes the review, the transition and `AuditLog.record!(actor:, action:, entity:, data:)` in one transaction
  - `ItemReviewer::NotReviewable < StandardError`
  - After this task, Task 7 hooks notifications into `ItemReviewer.call`

- [ ] **Step 1: Write failing service tests.** `"approve sets approved and writes one review and one audit log"`; `"reject without a note raises RecordInvalid and changes nothing"`; `"request_info sets info_requested"`; `"second call on an already-approved item raises NotReviewable and adds no review"`; `"never changes min_price_cents"` (call with extra attributes, assert unchanged); `"review history is kept across a resubmit cycle"` (two reviews after request_info -> resubmit -> approve).
- [ ] **Step 2: Write failing controller tests.** `"seller gets 403 on /admin/items"`; `"admin sees queue filtered by status"`; `"show lists media, description, min price and review history"`; `"POST reviews with action approve redirects and approves"`; `"params cannot carry min_price"` (unpermitted, price unchanged).
- [ ] **Step 3: Run** `bin/rails test test/services test/controllers/admin` **Expected:** FAIL.
- [ ] **Step 4: Implement** the service and controllers. `ItemReviewer` re-reads status after taking the lock (the stale-decision case from Review Focus 5); the review form posts the item's `lock_version` (proposed in `product-onboarding.md`, "Edits during review are caught"), and a changed `lock_version` also raises `NotReviewable`. Add test `"refuses a decision made on an outdated lock_version"`. Add `lock_version` (integer, default 0) to the `items` migration in Task 2. The controller turns `NotReviewable` into a flash message, not a 500.
- [ ] **Step 5: Run** `bin/rails test`, `bin/rubocop`, `bin/brakeman`. Approved items must be returned by whatever scope the lots work (#28) will use: add `Item.approved` scope and test it. Ask before committing.

### Task 7: Seller notifications (#53)

**Files:**
- Create: `app/models/notification.rb` + migration **only if absent on main**, `app/controllers/me/notifications_controller.rb`, `app/views/me/notifications/index.html.erb`
- Create: `test/models/notification_test.rb`, `test/controllers/me/notifications_controller_test.rb`
- Modify: `app/services/item_reviewer.rb` (create the notification), `config/routes.rb` (`namespace :me { resources :notifications, only: :index { patch :read, on: :member } }`)

**Interfaces:**
- Consumes: `ItemReviewer.call` (Task 6).
- Produces: `Notification.notify!(user:, type:, payload:) -> Notification`; type `"item_review"`, payload `{ item_id:, action:, note: }`; `GET /me/notifications`, `PATCH /me/notifications/:id/read`.

- [ ] **Step 1: Write failing tests.** `"approve creates one notification for the seller"`; `"reject notification carries the admin note"`; `"a failed review creates no notification"` (rollback with the review); `"index lists only my notifications"`; `"marking another user's notification as read returns 404"`; `"read sets read_at once and is idempotent"`.
- [ ] **Step 2: Run** `bin/rails test test/models/notification_test.rb test/controllers/me` **Expected:** FAIL.
- [ ] **Step 3: Implement** the model, controller and the one line in `ItemReviewer` inside its transaction.
- [ ] **Step 4: Run** `bin/rails test`, `bin/rubocop`, `bin/brakeman`. Ask before committing.

### Task 8: Cross-cutting tests and security review (#54)

**Files:**
- Create: `test/integration/product_onboarding_access_test.rb`, `test/integration/product_onboarding_lifecycle_test.rb`
- Modify: `test/models/item_media_concurrency_test.rb` (un-skip once Postgres is the test database)

**Interfaces:**
- Consumes: everything above. Produces: the merge gate for the milestone.

- [ ] **Step 1: Write the access matrix test.** For each of seller A, seller B, buyer, admin, anonymous x each seller and admin route: assert the expected status (200/302/403/404). One table-driven test, so a new route without a rule fails visibly.
- [ ] **Step 2: Write the lifecycle test.** Create -> request_info -> edit -> resubmit -> approve -> edit refused -> withdraw allowed; assert review count and notification count at each step.
- [ ] **Step 3: Confirm the concurrency test runs** (not skipped) against Postgres. If Postgres is still undecided, report this gap in the PR instead of claiming the rule is proven.
- [ ] **Step 4: Run the full suite** `bin/rails db:test:prepare test`, `bin/rubocop`, `bin/brakeman`. **Expected:** all green, no skipped tests other than documented ones.
- [ ] **Step 5: Run the `security-review` skill** (uploads, user input, access control) and paste the checklist result into the PR. Ask before committing.

## Order and PR slicing

Task 1 -> 2 -> 3 -> (4, 6 in either order) -> 5 -> 7 -> 8. One PR per task, each linking its issue (`Closes #N`). Tasks 4 and 6 both create `RequireRole` usage: Task 4 owns the concern. Start Task 2 only after Prerequisites 1 and 2 have answers; Task 1 can start now.

## Self-review notes

- Spec coverage: media limits (T2, T5), seller min price (T2, T6), verification and history (T2, T6), edit/resubmit/withdraw rules (T4), notifications (T7), uploads and cleanup (T3), tests and security review (T8). Open question 9 (re-listing copy) and 10 (who may verify) are left to Task 1 and are not planned as code.
- `ItemMedium` naming and `has_one_attached` are a change from the draft's `item_media.url`; Task 1 must record it.
