# Payment page and pricing — design

## Intent

Build the P1 payment page from issue #45 as a working prototype using mock order data.
It should let a Thai auction buyer review the itemized amount, choose delivery and a
payment method, and enter optional tax-invoice details, while making clear that no real
payment is processed yet.

## Scope

- Show a mock item image, name, winning bid, buyer's premium, delivery fee, VAT (7%),
  payment methods, pickup or shipping details, tax-invoice option, and proceed button.
- Recalculate the total on the server when delivery changes. Reject cash with shipping.
- Validate the invoice fields when requested, show a static 48-hour payment-deadline notice,
  disable invalid submissions, and prevent repeated submits.
- Use Thai labels and the reference image's warm off-white surfaces, charcoal borders and
  buttons, rounded panels, and mobile-first layout. The page is one checkout step, not a
  recreation of all three screens in the image.
- Use Rails-rendered views and the existing Turbo/Stimulus setup. Supply one clearly
  identified mock order; do not add persistent order, auction, or user records.

## Not included

No sign-in or winner authorization, real order data or persistence, payment gateway or
settlement, QR generation, receipt, scheduled expiry/cancellation, or seller notification.
Those require the missing auth/order foundations or belong to later payment issues in
milestone 6 (#55–#58). The prototype must not report a payment as completed.

## Constraints and calls

- The repository now includes auction/admin models and a development-only mock login, but
  has no persisted payment orders or production authentication. The collaborator explicitly
  requested mock payment data because real authentication is not implemented yet.
- Keep all prices as server-owned mock values. Calculate VAT at 7% on the winning bid,
  premium, and selected delivery fee; keep each component visible. The mock fee values
  are examples, not product pricing policy.
- Render the milestone's payment choices for the prototype, but make no claim that any
  method can actually charge or confirm a payment.
- A live countdown is deferred; without persisted orders there is no durable deadline or
  expiry job. The static 48-hour notice reflects the payment rule, not a live order timer.

## Approaches considered

1. **Rails mock order with server-recalculated pricing — selected.** Preserves issue #45's
   important pricing and invalid-combination rules while making a usable prototype with
   the existing Rails/Stimulus stack. No authentication or payment processing is implied.
2. **Static/client-only mock.** Smaller, but pricing and cash/shipping rules would live only
   in the browser and would not demonstrate the server-side requirement.
3. **Full authenticated payment system.** Would add users, persisted auction orders,
   authorization, payment processing, and scheduled jobs. It conflicts with the explicit
   mock-data direction and the milestone's separate follow-up issues.

## Builder discretion

Choose the exact mock item and amounts, component boundaries, and desktop composition.
Keep the totals clearly marked as demo data; retain the reference's palette and compact
mobile checkout feel.
