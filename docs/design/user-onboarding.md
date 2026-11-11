# Requirement: User Onboarding (4 step)

> **สถานะ: Draft (แผน)** · ยังไม่มีการตัดสินใจหรือเขียนโค้ด · ร่างเมื่อ 2026-11-11
> เอกสารนี้เขียนเป็นภาษาไทยตามที่ผู้เขียนขอ (ดูคำถามเรื่องภาษาใน `docs/decision/README.md`)

## เป้าหมาย

ผู้ใช้ต้องผ่าน onboarding 4 step ก่อนใช้งาน:

1. กรอกเลขบัตรประชาชนไทยและเบอร์โทรศัพท์
2. กรอกอาชีพ รายได้ และประสบการณ์ทำงาน
3. ระบบคำนวณ credit score
4. แสดงผลลัพธ์และให้ผู้ใช้ยืนยัน

## ⚠️ ประเด็นที่ต้องตัดสินใจก่อน

1. **ขัดกับ [`docs/decision/scope.md`](../decision/scope.md)**: ในนั้นเสนอไว้ว่า *"No deposit
   or KYC in Milestone 1"* แต่ onboarding นี้คือ KYC + credit check จึงต้องแก้ `scope.md` และเพิ่ม
   decision doc ใหม่ (`docs/decision/onboarding.md`, สถานะ Open) **ก่อน** เขียนโค้ด ตามกฎใน
   `AGENTS.md`
2. **เลขบัตรประชาชนเป็นข้อมูลส่วนบุคคล (PDPA) และ repo นี้เป็น public**: ต้องเข้ารหัสตอนเก็บ,
   ซ่อนเลขบน UI และใน log, เก็บ consent และห้ามใช้เลขบัตรจริงใน fixture/test
3. **Credit score ได้มาจากไหน**: ใช้ข้อมูลเครดิตบูโร (NCB) ไม่ได้ เพราะต้องเป็นสถาบันการเงินสมาชิก
   จึงเสนอให้ v1 **คำนวณเองแบบ rule-based** จากข้อมูลที่ผู้ใช้กรอก อธิบายที่มาของคะแนนได้
   และมีเลขเวอร์ชันของสูตร

## Requirement แต่ละ step

### Step 1: ยืนยันตัวตน

- เลขบัตรประชาชน 13 หลัก ตรวจ checksum (mod 11) ฝั่ง server
- 1 เลขบัตรผูกได้กับ 1 บัญชีเท่านั้น (unique)
- เบอร์มือถือไทย 10 หลัก ขึ้นต้น 06/08/09 เก็บเป็นรูป `+66...`
- Open: ต้องยืนยันเบอร์ด้วย OTP ไหม (ต้องใช้ SMS provider ซึ่งเป็น gem/บริการภายนอก
  จึงต้องถามก่อน) และต้องเก็บชื่อ-นามสกุล/วันเกิดด้วยไหม

### Step 2: อาชีพและรายได้

- อาชีพเลือกจาก list ที่กำหนด: พนักงานเอกชน, ข้าราชการ, เจ้าของกิจการ, ฟรีแลนซ์, นักศึกษา,
  เกษียณ, อื่นๆ
- รายได้ต่อเดือน (THB): กรอกตัวเลขจริงหรือเลือกเป็นช่วง (Open)
- ประสบการณ์ทำงาน: จำนวนปีในงานปัจจุบันและปีรวม มี validation ช่วงค่า

### Step 3: คำนวณ credit score

- คำนวณฝั่ง server เท่านั้น ใส่ input เดิมต้องได้คะแนนเดิมเสมอ (deterministic)
- เก็บ `score_version`, snapshot ของ input, คะแนน, เกรด (A–E) และเหตุผลที่ได้คะแนนนั้น
- ตัวอย่างน้ำหนัก (ต้องคอนเฟิร์ม): รายได้ 40, ความมั่นคงของอาชีพ 30, ประสบการณ์ 20,
  เบอร์ยืนยันแล้ว 10
- จำกัดจำนวนครั้งที่ส่งคำนวณใหม่ กันการลองแก้ข้อมูลเพื่อปั่นคะแนน

### Step 4: แสดงผลและยืนยัน

- แสดงคะแนน, เกรด, เหตุผล และสิ่งที่ปลดล็อก เช่น ประเภท auction หรือวงเงินประมูลสูงสุด
- ผู้ใช้ติ๊ก consent แล้วกดยืนยัน → สถานะ `completed` (บันทึกเวลา)
- ถ้าย้อนกลับไปแก้ step 1–2 ต้องคำนวณคะแนนใหม่
- Open: ถ้าคะแนนต่ำกว่าเกณฑ์จะเกิดอะไร (บล็อก, จำกัดสิทธิ์ หรือให้ admin review)

## Flow / Data / API (ร่าง)

- **State:** `not_started → identity_done → employment_done → scored → completed`
  บันทึกทีละ step ฝั่ง server ปิดแอปแล้วกลับมาทำต่อได้
- **ตาราง `user_onboardings`:** `user_id`, `national_id` (Active Record Encryption + digest
  สำหรับเช็ก unique), `phone`, `phone_verified_at`, `occupation`, `monthly_income`,
  `years_experience`, `status`, `consent_at`, `confirmed_at`
- **ตาราง `credit_assessments`:** append-only เก็บประวัติทุกครั้งที่คำนวณ ได้แก่ `score`,
  `grade`, `score_version`, `inputs` (jsonb), `reasons`
- **API** (ล้อตาม `/api/v1` ใน
  [design draft](milestone-1-api-and-database.md) แต่วิธี auth ยังเป็น Open ดู
  [`auth.md`](../decision/auth.md)):

  | Method | Path | ใช้ทำอะไร |
  |---|---|---|
  | GET | `/onboarding` | ดูสถานะและข้อมูลที่กรอกไว้ |
  | PATCH | `/onboarding/identity` | Step 1 |
  | PATCH | `/onboarding/employment` | Step 2 |
  | POST | `/onboarding/score` | Step 3 คำนวณคะแนน |
  | POST | `/onboarding/confirm` | Step 4 ยืนยัน |

- **Non-functional:**
  - ใส่ `national_id` ใน `filter_parameters` ไม่ให้หลุดลง log
  - บันทึก audit log ทุก step
  - มี rate limit
  - ทำ `security-review` ก่อน merge

## ขั้นตอนเมื่ออนุมัติแผน

1. แตก branch ใหม่ เช่น `eyetanamas-max-docs-user-onboarding-requirements`
2. ใช้ `record-decision`: แก้ `scope.md` และสร้าง `docs/decision/onboarding.md` (Open)
3. เพิ่มรายละเอียดในเอกสารนี้ตามคำตอบที่ได้ (ภาษาไทย)
4. ตรวจกับ `AGENTS.md` และ decision docs แล้วให้ผู้เขียนรีวิวก่อน commit/PR
5. เขียน implementation plan (TDD) แยกเป็นอีกงานหนึ่ง

## คำถามที่ต้องตอบก่อนเริ่ม

1. Onboarding นี้บังคับใช้กับใคร: buyer ทุกคน, เฉพาะคนที่จะเข้า English auction 20M หรือ
   seller ด้วย
2. Credit score ใช้ทำอะไร: เป็นเกณฑ์ผ่าน/ไม่ผ่าน หรือใช้กำหนดวงเงินประมูล
3. ใช้สูตร rule-based ของเราเองได้ไหม และอยากใช้สเกลแบบไหน (0–100 หรือ 300–850)
4. ต้องมี OTP ยืนยันเบอร์ใน Milestone 1 ไหม
