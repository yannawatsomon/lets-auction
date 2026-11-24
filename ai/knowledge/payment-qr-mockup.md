# Payment: QR and receipt mockup (#55)
Last verified: 2026-11-24

## Summary

A clickable mockup of #55 (PromptPay QR, countdown, webhook, receipt) so the team can review the
screens. It has no gateway, no table and no real QR, because Milestone 1 pays by uploaded slip
and has no gateway (`docs/decision/scope.md`), and the team adds no tables for now
(`docs/decision/bidding.md`).

## Details

- Picking "QR พร้อมเพย์" on `/payment` and submitting goes to `/payment/qr/:reference`. Other
  methods still show the demo notice.
- `MockQrPaymentStore` keeps each QR in memory: the exact amount from the server quote, a
  reference `QR` + 10 characters, a 10 minute lifetime, and a status of `pending`, `paid`,
  `failed` or `expired`. A restart forgets them. At most 500 are kept.
- The "จำลองผลจากธนาคาร" buttons POST `simulate`, which calls `apply_event!` the way a gateway
  webhook would: an expired or finished QR cannot be paid, a wrong amount fails, and an event id
  seen before changes nothing.
- `payment_qr_controller.js` counts down from the server's `seconds_left` and polls `status`
  every 4 seconds. When the QR is paid, it opens the receipt.
- Receipt numbers are sequential per process (`RC-2026-000001`). The receipt URL uses the QR
  reference, which is hard to guess, not the receipt number. "ดาวน์โหลด PDF" opens the browser's
  print dialog. Email to the buyer and the note to the seller are shown, not sent.
- The QR picture is drawn from the reference and is deliberately not scannable.

## Not done (needs a gateway decision first)

- Real PromptPay payload, a gateway, and webhook signature checks
- A server-made PDF with Thai fonts
- Sending email
- Storing payments and receipts in tables
- Linking to bidding's orders (`Bidding::OrderStore`)

## References

- `app/models/mock_qr_payment_store.rb`, `app/controllers/payment_qrs_controller.rb`,
  `app/views/payment_qrs/`, `test/integration/payment_qr_flow_test.rb`
