# Payment page and pricing Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use subagent-driven-development (recommended) or executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build a responsive Thai payment-page prototype for issue #45 using mock order data and server-recalculated pricing.

**Architecture:** Keep the page in Rails views and use a non-persistent mock order plus a plain pricing object. A small PaymentsController serves the page, a quote endpoint, and a no-payment preview submission; Stimulus handles page interactions without implementing a gateway.

**Tech Stack:** Rails 8.1, Ruby, Minitest, ERB, Stimulus, Turbo, CSS.

**Spec:** `docs/specs/2026-11-11-payment-page-pricing-design.md`

## Global Constraints

- Use Thai labels and the reference image's warm off-white surfaces, charcoal borders and buttons, rounded panels, and mobile-first layout.
- Use one clearly identified mock order; do not add persistent order, auction, or user records.
- Keep all prices as server-owned mock values.
- Calculate VAT at 7% on the winning bid, premium, and selected delivery fee; keep each component visible.
- Render the milestone's payment choices for the prototype, but make no claim that any method can charge or confirm a payment.
- Do not add authentication, real order data or persistence, payment gateway or settlement, QR generation, receipt, scheduled expiry/cancellation, or seller notification.
- Use integer satang for calculations and do not add dependencies.
- Existing auction/admin models and a development-only mock login do not authorize a payment
  order; this feature must use its own non-persistent mock order and must not imply real auth.

## Review Focus

- Unknown delivery or payment-method values must not produce a quote or bypass validation. Test invalid values in `PaymentQuote` and `PaymentSubmission`.
- A forged cash + shipping submission must be rejected server-side, even when the browser interaction is bypassed. Test the preview endpoint.
- Checked tax-invoice details must require a 13-digit tax ID, branch (≤100 characters), address (≤1,000 characters), and valid email (≤254 characters); unchecked details must remain optional. Test both cases.
- VAT rounding must stay deterministic in satang. Test a subtotal whose 7% VAT includes a fractional satang.
- Repeated clicks must not submit the form twice. Show the static 48-hour payment deadline without a live timer; verify submit interactions in a browser.

---

### Task 1: Mock pricing and order data

**Files:**
- Create: `app/models/payment_quote.rb`
- Create: `app/models/mock_payment_order.rb`
- Create: `test/models/payment_quote_test.rb`
- Create: `test/models/mock_payment_order_test.rb`

**Interfaces:**
- `PaymentQuote.new(winning_bid_satang:, buyer_premium_satang:, shipping_fee_satang:, delivery_method:)`
- `PaymentQuote#subtotal_satang`, `#vat_satang`, and `#total_satang` return integer satang.
- `MockPaymentOrder.demo` returns the fixed item, pickup, shipping, and price data for the prototype.
- `MockPaymentOrder#quote(delivery_method:)` returns a `PaymentQuote` using its server-owned amounts.

- [ ] **Step 1: Write failing pricing tests**

  Assert self-pickup for a ฿100,000 bid plus ฿5,000 premium yields ฿105,000 subtotal, ฿7,350 VAT, and ฿112,350 total. Assert shipping with a ฿500 fee yields ฿105,500 subtotal, ฿7,385 VAT, and ฿112,885 total. Assert an 8-satang subtotal rounds 0.56 satang VAT to 1 satang, and an unknown delivery method is rejected.

- [ ] **Step 2: Run the pricing tests and confirm they fail**

  Run: `bin/rails test test/models/payment_quote_test.rb`
  Expected: FAIL because `PaymentQuote` is not implemented.

- [ ] **Step 3: Implement `PaymentQuote`**

  Use integer satang and round 7% VAT to the nearest satang; reject delivery methods other than `self_pickup` and `shipping`.

- [ ] **Step 4: Add failing mock-order tests and implement `MockPaymentOrder.demo`**

  Assert the demo order supplies an item name and image placeholder, bid, premium, pickup location/hours/time slot, shipping address/carrier/fee, and delegates quote calculation to `PaymentQuote`.

- [ ] **Step 5: Run both model test files**

  Run: `bin/rails test test/models/payment_quote_test.rb test/models/mock_payment_order_test.rb`
  Expected: PASS.

### Task 2: Submission validation and server endpoints

**Files:**
- Create: `app/models/payment_submission.rb`
- Create: `app/controllers/payments_controller.rb`
- Modify: `config/routes.rb`
- Modify: `config/initializers/filter_parameter_logging.rb`
- Modify: `app/helpers/application_helper.rb`
- Modify: `app/helpers/auctions_helper.rb`
- Create: `test/models/payment_submission_test.rb`
- Create: `test/controllers/payments_controller_test.rb`

**Interfaces:**
- `PaymentSubmission.new(payment_method:, delivery_method:, tax_invoice:, tax_id:, branch:, address:, email:)` exposes `#valid?` and `#errors`.
- `GET /payment` renders the prototype with the selected delivery method and server-calculated quote.
- `GET /payment/quote?delivery_method=...` returns JSON with `subtotal_satang`, `vat_satang`, `shipping_fee_satang`, and `total_satang`; invalid delivery methods return `422`.
- `POST /payment/preview` validates the submitted values and returns a clearly labeled demo-only response without creating or charging an order.

- [ ] **Step 1: Write failing `PaymentSubmission` tests**

  Assert the five milestone methods (`qr`, `online_banking`, `card`, `cheque`, `cash`) and two delivery methods are accepted; unknown values are rejected; cash + shipping is rejected; and invoice fields are required only when invoice details are requested. When requested, require a 13-digit tax ID, branch, address, and valid email.

- [ ] **Step 2: Run the submission tests and confirm they fail**

  Run: `bin/rails test test/models/payment_submission_test.rb`
  Expected: FAIL because `PaymentSubmission` is not implemented.

- [ ] **Step 3: Implement `PaymentSubmission`**

  Use Active Model validations; keep the tax ID rule to exactly 13 digits as specified by issue #45.

- [ ] **Step 4: Write failing controller tests**

  Assert `GET /payment` renders the mock item and quote; quote responses change with delivery method and return 422 for unknown values; `POST /payment/preview` rejects cash + shipping and invalid checked invoice details, and valid input responds with an explicit no-payment notice.

- [ ] **Step 5: Implement `PaymentsController` and routes**

  Add only the three payment routes listed in the interface. Rebuild the quote from `MockPaymentOrder.demo` on every request; do not accept price components from params or persist submitted details.

- [ ] **Step 6: Run submission and controller tests**

  Run: `bin/rails test test/models/payment_submission_test.rb test/controllers/payments_controller_test.rb`
  Expected: PASS.

### Task 3: Responsive checkout interface and interactions

**Files:**
- Create: `app/views/payments/show.html.erb`
- Create: `app/javascript/controllers/payment_controller.js`
- Modify: `app/assets/stylesheets/application.css`
- Modify: `app/views/home/index.html.erb`
- Create: `test/integration/payment_page_test.rb`

**Interfaces:**
- The view receives `@order`, `@quote`, `@delivery_method`, and `@payment_submission`.
- The Stimulus controller requests the quote endpoint on delivery changes, updates totals, toggles cash availability and invoice fields, and disables the proceed button on invalid or repeated submission.

- [ ] **Step 1: Write failing integration tests**

  Assert the page renders all seven issue elements; the itemized bid, premium, shipping, VAT, and total; pickup and shipping details; all five payment choices; invoice fields; the static 48-hour deadline notice; and proceed button. Assert the page clearly indicates demo-only behavior and never displays a payment-success state or live countdown.

- [ ] **Step 2: Run the integration test and confirm it fails**

  Run: `bin/rails test test/integration/payment_page_test.rb`
  Expected: FAIL because the payment page is not implemented.

- [ ] **Step 3: Implement the Rails-rendered view**

  Use the supplied mock order and quote; show the pickup location, hours and time slot or the shipping address, carrier and fee according to the selected method. Keep the submit form separate from the quote request so tax details do not enter a URL.

- [ ] **Step 4: Implement Stimulus interactions**

  Request server quotes using only the delivery-method value; update totals and accessible status text from the response. Apply HTML validation, cash/shipping disabling, invoice-required toggles, and one-submit button disabling.

- [ ] **Step 5: Style the responsive page**

  Match the image's palette, rounded dark header/cards/buttons, restrained accent colors, and compact mobile checkout layout. Keep desktop content readable without imitating the three separate process screens.

- [ ] **Step 6: Verify the interactive page in a browser**

  Open `/payment`; change pickup to shipping and confirm the displayed total matches the server quote, cash becomes unavailable, and shipping details appear. Toggle invoice details and confirm required-field validation. Confirm no live countdown is initialized and that a valid proceed click disables the button and shows only a demo notice, never a success state.

- [ ] **Step 7: Run the page tests and targeted checks**

  Run: `bin/rails test test/integration/payment_page_test.rb test/controllers/payments_controller_test.rb test/models/payment_quote_test.rb test/models/mock_payment_order_test.rb test/models/payment_submission_test.rb`
  Expected: PASS.
  Run: `bin/rubocop`
  Expected: PASS.

## Self-review

- Spec coverage: mock itemized pricing and 7% VAT (Task 1); delivery recalculation and method/invoice rules (Task 2); all seven page elements, deadline demo, no-double-submit behavior, and visual theme (Task 3); explicit demo-only constraints are covered by controller and integration tests.
- No persistent records, authentication, payment processing, expiry jobs, or notifications are planned, matching the approved spec.
- Implementation should run the full project checks before proposing a PR; no dependency or CI changes are planned.
