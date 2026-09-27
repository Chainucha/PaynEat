# Ticket: ลูกค้า/สมาชิก/แต้มสะสม (Customer & Loyalty)

**Priority:** 🟡 Medium
**สถานะ (2026-09-27):** ✅ เสร็จแล้ว (`docs/DECISIONS.md` #59) — QA รอบ ก.ย. 2026 (#79) พบกฎที่ยังไม่ป้องกัน แก้ใน T11 [#101](https://github.com/SuruchBoss/PaynEat/issues/101), T15 [#84](https://github.com/SuruchBoss/PaynEat/issues/84)
**Ref:** `docs/FEATURE-GAP-ANALYSIS.md` #9

## ปัญหา
ไม่มี table customer ใน schema เลย ระบบไม่สามารถผูกประวัติการซื้อกับลูกค้ารายบุคคล หรือทำ
ระบบสมาชิก/แต้มสะสมได้

## ทำไมสำคัญ
ระบบสมาชิกและแต้มสะสมเป็นเครื่องมือการตลาดที่ช่วยรักษาฐานลูกค้าเดิม (retention) และเป็น
ฟีเจอร์ที่ POS ระดับกลาง-สูงส่วนใหญ่มี

## ขอบเขตงาน (คร่าวๆ)
- Schema: table `customers` (id, name, phone, email nullable, points_balance,
  created_at), ผูก `orders.customer_id` (nullable — ลูกค้าทั่วไปไม่ต้องผูกก็ได้)
- Backend: endpoint ค้นหา/สร้างลูกค้า (เช่นจากเบอร์โทร), logic สะสม/ใช้แต้ม (อัตราแลกที่
  ตั้งค่าได้ใน settings)
- Frontend: ค้นหา/เพิ่มลูกค้าตอนเปิดออเดอร์หรือตอนชำระเงิน, แสดง/ใช้แต้มสะสมตอนเช็คบิล,
  หน้าประวัติการซื้อของลูกค้ารายคน (admin)

## Acceptance Criteria
- [x] ผูกออเดอร์กับลูกค้า (ค้นหาจากเบอร์โทรหรือสร้างใหม่) ได้แบบ optional — `CustomerPickerDialog`
  ในตะกร้าตอนรับออเดอร์ใหม่
- [x] สะสมแต้มอัตโนมัติตามยอดซื้อ ตามอัตราที่ตั้งค่าได้ — `settings.pointsEarnRateBaht`
  (ค่าเริ่มต้น 25 บาท/แต้ม) คำนวณครั้งเดียวตอนออเดอร์จ่ายครบ
- [x] ใช้แต้มสะสมแลกส่วนลดตอนชำระเงินได้ — ส่วน "แต้มสะสม" ในหน้าเก็บเงิน ใช้
  `settings.pointsRedeemValueBaht` (ค่าเริ่มต้น 1 บาท/แต้ม)
- [x] Admin ดูประวัติการซื้อ/แต้มสะสมของลูกค้ารายคนได้ — แท็บ "ลูกค้า/แต้มสะสม" (admin/manager)
  → รายชื่อลูกค้า → หน้าประวัติรายคน (reuse `GET /orders?customerId=`)

## ไฟล์ที่เกี่ยวข้อง
- `backend/src/db/schema.sql`
- `backend/src/modules/orders/`, `backend/src/modules/payments/`
- `app/lib/features/order/`, `app/lib/features/payment/`
