# Ticket: เปิด/ปิดกะ + กระทบยอดเงินสด (Shift & Cash Drawer Reconciliation)

**Priority:** 🔴 Critical
**สถานะ (2026-09-27):** ✅ เสร็จแล้ว (`docs/DECISIONS.md` #35 (Z-report), #38) — QA รอบ ก.ย. 2026 (#79) พบกฎที่ยังไม่ป้องกัน แก้ใน T11 [#101](https://github.com/SuruchBoss/PaynEat/issues/101), T12 [#106](https://github.com/SuruchBoss/PaynEat/issues/106)
**Ref:** `docs/FEATURE-GAP-ANALYSIS.md` #1

## ปัญหา
ปัจจุบันไม่มี table `shift`/`cash_session` ใน `backend/src/db/schema.sql` เลย cashier
เปิดหน้าจอรับเงินได้ทันทีโดยไม่ต้องเปิดกะ และไม่มีจุดปิดกะให้กระทบยอด ทำให้ตรวจสอบเงินสด
หายหรือขาด/เกินไม่ได้ — เป็นข้อกำหนดพื้นฐานของ POS ทุกตัวที่รับเงินสด

## ทำไมสำคัญ
ร้านอาหารจริงต้องมีการนับเงินตั้งต้นก่อนเปิดร้าน และนับ/กระทบยอดตอนปิดกะเทียบกับยอดที่
ระบบคำนวณจาก payment ที่บันทึกไว้ ถ้าไม่มีฟีเจอร์นี้ ร้านไม่มีทางรู้ว่าเงินสดหายระหว่างกะหรือไม่

## ขอบเขตงาน (คร่าวๆ)
- Schema: table `shifts` (id, opened_by user_id, opened_at, opening_cash, closed_by,
  closed_at, expected_cash, counted_cash, variance, note, status open/closed)
- Backend: endpoint เปิดกะ (`POST /shifts`), ปิดกะ (`PATCH /shifts/:id/close`), ดู
  รายการกะปัจจุบัน/ประวัติ
- ผูก payment ที่เกิดขึ้นระหว่างกะเข้ากับ shift (เพื่อคำนวณ expected cash ตอนปิด)
- Frontend: หน้าจอเปิดกะ (กรอกเงินตั้งต้น) ก่อนเข้าหน้า cashier, หน้าปิดกะ (กรอกยอดนับจริง
  เทียบกับยอดระบบ แสดงส่วนต่าง)
- Role: manager/cashier เปิด-ปิดกะได้ (ตาม RBAC ที่มีอยู่)

## Acceptance Criteria
- [ ] Cashier เปิดกะโดยกรอกเงินสดตั้งต้นได้ และระบบบันทึกเวลา/ผู้เปิด
- [ ] ระหว่างกะเปิดอยู่ payment ทั้งหมดผูกกับ shift นั้น
- [ ] ปิดกะโดยกรอกยอดเงินสดที่นับจริง ระบบคำนวณส่วนต่าง (variance) และบันทึกไว้
- [ ] มีรายงาน/หน้าจอดูประวัติการเปิด-ปิดกะย้อนหลัง

## ไฟล์ที่เกี่ยวข้อง
- `backend/src/db/schema.sql`
- `backend/src/modules/payments/`
- `app/lib/features/payment/`
- อาจต้องเพิ่ม feature ใหม่ `app/lib/features/shift/`
