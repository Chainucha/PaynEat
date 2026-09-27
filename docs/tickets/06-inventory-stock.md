# Ticket: สต๊อก/วัตถุดิบ (Inventory)

**Priority:** 🟠 High
**สถานะ (2026-09-27):** ✅ เสร็จแล้ว (`docs/DECISIONS.md` #38) — QA รอบ ก.ย. 2026 (#79) พบกฎที่ยังไม่ป้องกัน แก้ใน T27 [#110](https://github.com/SuruchBoss/PaynEat/issues/110)
**Ref:** `docs/FEATURE-GAP-ANALYSIS.md` #6

## ปัญหา
ไม่มี table สต๊อก/วัตถุดิบใน schema เลย ตอนนี้มีแค่ `menu_items.is_available` ที่ครัวกด
toggle มือ ("ของหมด") ไม่มีการตัดสต๊อกอัตโนมัติเมื่อขาย ไม่มีแจ้งเตือนของใกล้หมด

## ทำไมสำคัญ
ร้านอาหารต้องคุมต้นทุนวัตถุดิบและป้องกันการขายเกินสต๊อกที่มีจริง การพึ่งพนักงานกด
sold-out มือ ทำให้เกิดออเดอร์ที่ทำไม่ได้บ่อย และไม่มีข้อมูลสำหรับสั่งซื้อวัตถุดิบเพิ่ม

## ขอบเขตงาน (คร่าวๆ)
- Schema: table `ingredients` (id, name, unit, current_stock, low_stock_threshold),
  table `menu_item_ingredients` (menu_item_id, ingredient_id, qty_per_unit) เพื่อผูก
  เมนูกับวัตถุดิบที่ใช้
- Backend: ตัดสต๊อกอัตโนมัติเมื่อ order item ถูกยืนยัน/ส่งครัว, endpoint ปรับสต๊อกมือ (รับของเข้า)
- เมื่อสต๊อกวัตถุดิบใดหมด → auto mark เมนูที่เกี่ยวข้องเป็น unavailable (ต่อยอดจาก
  `is_available` เดิม)
- Frontend: หน้าจัดการสต๊อก (admin/manager), แจ้งเตือนของใกล้หมด (threshold), รายงาน
  การใช้วัตถุดิบ

## Acceptance Criteria
- [x] Admin ผูกเมนูกับวัตถุดิบและจำนวนที่ใช้ต่อ 1 ออเดอร์ได้
- [x] สต๊อกถูกตัดอัตโนมัติเมื่อขายเมนูที่ผูกวัตถุดิบไว้
- [x] เมนูที่วัตถุดิบหมด (ตามที่ผูกไว้) ถูก mark unavailable อัตโนมัติ
- [x] มีแจ้งเตือน/หน้าจอแสดงวัตถุดิบที่ใกล้หมด (ต่ำกว่า threshold)

## ไฟล์ที่เกี่ยวข้อง
- `backend/src/db/schema.sql`
- `backend/src/modules/menu/`
- `app/lib/features/menu/`, `app/lib/features/kitchen/`
