# User onboarding

**Status:** Decided (2026-11-11) · **Effort:** M · **Deadline risk:** Medium — buyers can't join any auction until onboarding exists

## Context

Every auction in Milestone 1 needs some protection against a winner who never pays, most of
all the invite-only English lots of 20M THB or more. The requirement draft
[`docs/design/user-onboarding.md`](../design/user-onboarding.md) describes a 4-step onboarding:
national ID and phone → occupation, income and experience → credit score → result and confirm.
It replaces the "no KYC" part of [`scope.md`](scope.md) and of
[`bidding.md`](bidding.md) (no deposit still holds there).
Tracked by the User Onboarding milestone (#15–#21, #66).

## Decisions

- **Every buyer completes onboarding; sellers and admins skip it.** What: a buyer must reach
  `completed` before registering for a sealed event or being invited to an English lot.
  Browsing stays open. The rules in `bidding.md` still apply on top: register for sealed,
  invite + accept for English. Why: protects sellers on every auction type, not only the 20M THB lots.
  Trade-off: more friction before a buyer's first bid. Alternative rejected: English buyers
  only (sealed sellers stay unprotected); buyers and sellers (sellers don't need a credit
  check to list). Source: eyetanamas-max in chat, 2026-11-11.
- **The credit grade decides which auctions a buyer can join.** What: A → sealed and English;
  B, C, D → sealed only; E → no auctions yet. The grade decides who can be on the participant
  list: a buyer below the grade can't register (sealed) and the admin can't invite them
  (English, grade A only). It is checked at registration or invite, not on every bid. Why: ties the riskiest lots to the strongest profiles without a deposit.
  Trade-off: a fixed formula can exclude good buyers. Alternative rejected: a per-user bid limit
  (more rules in every bid check), pass/fail only (too coarse for 20M THB lots), admin-only
  information (no automatic protection). Source: eyetanamas-max in chat, 2026-11-11.
- **Score v1 is our own rule-based formula on a 0–100 scale.** What: computed on the server
  from the buyer's own answers, deterministic (same inputs → same score), stored with
  `score_version = 1`, a snapshot of the inputs and the reason for each part (table below).
  Shown to the user as a lets-auction score, never as a bank or bureau score. Why: the National
  Credit Bureau (NCB) only serves member financial institutions, so we can't get real credit
  data. Trade-off: self-declared data can be false. Alternative rejected: displaying on a
  300–900 scale like NCB (users could mistake it for a real NCB score). Source:
  eyetanamas-max in chat, 2026-11-11.
- **Income carries the most weight and tops out at 1M THB a month.** What: income 50,
  occupation 25, total experience 15, verified phone 10. Grade A (≥ 80) needs roughly 500,000
  THB a month or more. Why: English lots are rare items of 20M THB or more, so the top grade
  should mean a high income. Trade-off: steady low-income buyers top out at grade B–D. Source:
  eyetanamas-max in chat, 2026-11-11.
- **No phone OTP in Milestone 1.** What: the phone number is checked for format only;
  `phone_verified_at` stays empty, so the 10 OTP points are never awarded and the highest
  possible score is 90. Why: OTP needs an SMS provider (new gem, paid service, secrets).
  Trade-off: a fake number passes. Source: eyetanamas-max in chat, 2026-11-11.
- **A buyer can edit their answers and recalculate, at most 3 times in 30 days.** What: the
  same limit applies to every grade, including E. Editing step 1 or 2 after scoring requires a
  new score before confirming. Why: lets a buyer fix a mistake without letting them try
  answers until they reach grade A. Source: eyetanamas-max in chat, 2026-11-11.

- **Grade A needs proof of income.** What: a buyer whose score reaches grade A must attach
  proof of income before the admin can invite them to English lots. Why: income is
  self-declared and carries the most weight, and English lots are 20M THB or more. Trade-off:
  a file upload and an admin review step. Accepted: one of a salary slip, a 6-month bank
  statement or a salary certificate. Until the admin approves it the buyer is treated as grade
  B (sealed only, cannot be invited to English). Source: eyetanamas-max in chat, 2026-11-11.

- **National ID is handled as sensitive personal data (PDPA).** What: encrypt it with Active
  Record Encryption; keep a one-way digest to enforce one ID per account without decrypting;
  add it to `filter_parameters` so logs show `[FILTERED]`; show only the last 4 digits in the
  UI (buyer and admin); record when the buyer gave consent; tests use generated fake IDs with
  a valid checksum, never a real person's. Why: a leaked ID is costly to the owner, and this
  repo and its tests are public. Trade-off: no search by full ID except through the digest.
  Source: eyetanamas-max in chat, 2026-11-11.
- **Money in satang.** What: store monthly income as satang `bigint`, like bid amounts in
  [`bidding.md`](bidding.md). Why: no rounding errors and one money rule across the app.
  Source: eyetanamas-max in chat, 2026-11-11.
- **Build on mock data first; no database tables yet.** What: `UserOnboarding` (ActiveModel)
  and `CreditAssessment` (immutable `Data`) live in `OnboardingStore`, an in-memory store
  seeded from `db/mock/user_onboardings.yml` with one fake buyer per grade A–E and one who
  hasn't started. A restart resets it. Encryption and the national ID digest apply when the
  tables land; until then only fake IDs exist. Why: the user wants the flow working before
  touching the database, like bidding's mock users and items. Trade-off: data is lost on
  restart and each process has its own copy. Alternative rejected: storing answers in the
  browser session (the national ID would sit in a cookie). Source: eyetanamas-max in chat,
  2026-11-11 (#16).

## Rules / examples

Score v1 (`score_version = 1`):

| Part | Max | Bands → points |
|---|---|---|
| Monthly income (THB) | 50 | ≥ 1,000,000 → 50 · 500,000–999,999 → 42 · 200,000–499,999 → 34 · 100,000–199,999 → 26 · 50,000–99,999 → 18 · 15,000–49,999 → 10 · 1–14,999 → 4 · 0 → 0 |
| Occupation | 25 | government / state enterprise → 25 · private employee → 21 · business owner → 17 · retired → 13 · freelancer → 10 · student / other → 4 |
| Total work experience | 15 | ≥ 10 years → 15 · 5–9 → 11 · 2–4 → 7 · < 2 → 3 |
| Phone verified by OTP | 10 | 0 in Milestone 1 (no OTP) |

| Grade | Score | Can join |
|---|---|---|
| A | ≥ 80 | sealed + English (needs approved proof of income and an admin invite; before approval: sealed only) |
| B | 65–79 | sealed |
| C | 50–64 | sealed |
| D | 35–49 | sealed |
| E | < 35 | nothing yet; may edit and recalculate |

Examples: private employee, 1,000,000 THB, 10 years → 50 + 21 + 15 = 86 → A. Government
officer, 500,000 THB, 10 years → 42 + 25 + 15 = 82 → A. Private employee, 200,000 THB, 10 years
→ 70 → B. Private employee, 30,000 THB, 3 years → 10 + 21 + 7 = 38 → D.

## Open questions

- Proof of income: file types and size limit, and how long we keep the files.
- Does a score expire (e.g. redo onboarding every 12 months)?
- How long do we keep the national ID after an account is closed (PDPA retention)?
- Do we collect name and date of birth to match the ID card? There is no public DOPA API to
  verify the ID, so only the checksum is checked.
- Deposit for the 20M THB English lots is still open in [`scope.md`](scope.md).
