# Ticket: ส่วนลด/โปรโมชันแบบมีเงื่อนไข (Promotion Engine)

**Priority:** 🟠 High
**สถานะ (2026-09-27):** ✅ เสร็จแล้ว (`docs/DECISIONS.md` #14) — QA รอบ ก.ย. 2026 (#79) พบกฎที่ยังไม่ป้องกัน แก้ใน T10 [#83](https://github.com/SuruchBoss/PaynEat/issues/83), T17 [#108](https://github.com/SuruchBoss/PaynEat/issues/108)
**Ref:** `docs/FEATURE-GAP-ANALYSIS.md` #5

## ปัญหา
ปัจจุบันลดราคาได้แค่ manual ต่อบิลตอนชำระเงิน (`orders.discount_type/value/amount`) ไม่มี
กติกาส่วนลดแบบตั้งเงื่อนไขล่วงหน้า เช่น happy hour, โค้ดส่วนลด, buy-1-get-1, ลดตามเมนู/
ตามช่วงเวลา

## ทำไมสำคัญ
โปรโมชันเป็นเครื่องมือการตลาดพื้นฐานที่ร้านอาหารใช้ประจำ การไม่มี rule engine ทำให้ต้องพึ่ง
cashier กดลดมือทุกครั้ง เสี่ยง error/ทุจริต และวางแผนแคมเปญล่วงหน้าไม่ได้

## ขอบเขตงาน (คร่าวๆ)
- Schema: table `promotions` (id, name, type: percent/amount/bogo, conditions JSON —
  ช่วงเวลา, วันในสัปดาห์, เมนู/หมวดหมู่ที่เข้าร่วม, ยอดขั้นต่ำ, โค้ด (nullable), is_active,
  valid_from/valid_to)
- Backend: logic คำนวณโปรโมชันที่ apply ได้ ผสานเข้ากับ `order.calculator.js` เดิม (ต้อง
  คงลำดับการคำนวณ subtotal → discount → service charge → VAT ตามที่มีอยู่)
- Frontend: หน้าจัดการโปรโมชัน (admin/manager), แสดงโปรโมชันที่ใช้ได้ตอนสั่ง/เช็คบิล, ช่อง
  กรอกโค้ดส่วนลด
- ต้อง sync logic คำนวณระหว่าง backend กับ `bill_calculator.dart` เหมือนที่ discount เดิม
  ทำอยู่ (ดู `docs/DECISIONS.md` เรื่อง dual bill-calculator)

## Acceptance Criteria
- [x] Admin/manager สร้าง/แก้ไข/ปิดใช้งานโปรโมชันได้ (เงื่อนไขเวลา/เมนู/ยอดขั้นต่ำ)
- [x] ระบบ apply โปรโมชันที่เข้าเงื่อนไขให้อัตโนมัติตอนคำนวณบิล หรือรับโค้ดส่วนลดได้
- [x] ผลการคำนวณ (subtotal/discount/service charge/VAT/total) ตรงกันระหว่าง backend กับ
  frontend เหมือนเดิม มี test คุม
- [x] Order ที่ใช้โปรโมชันแสดงชัดเจนในใบเสร็จ/รายงาน

## ไฟล์ที่เกี่ยวข้อง
- `backend/src/modules/orders/order.calculator.js`
- `app/lib/features/order/domain/services/bill_calculator.dart`
- `backend/src/db/schema.sql`
