# Ticket: Audit Log

**Priority:** 🟠 High
**สถานะ (2026-09-27):** ✅ เสร็จแล้ว
**Ref:** `docs/FEATURE-GAP-ANALYSIS.md` #8

## ปัญหา
ไม่มี table audit log ในระบบ การกระทำที่มีความเสี่ยงต่อการทุจริต เช่น ยกเลิกออเดอร์/
รายการ (`orders.status = cancelled`, `order_items.status = cancelled`), ให้ส่วนลดพิเศษ,
แก้ไขราคาเมนู, ลบ/ปลด staff ไม่ถูกบันทึกว่าใครทำเมื่อไหร่และเหตุผลอะไร

## ทำไมสำคัญ
เป็นฟีเจอร์พื้นฐานของ POS เพื่อป้องกันการทุจริตหน้าร้าน (เช่น cashier ยกเลิกบิลหลังรับเงิน
สดแล้วเก็บเงินเอง) และช่วย manager/owner ตรวจสอบย้อนหลังได้เมื่อมีข้อสงสัย

## ขอบเขตงาน (คร่าวๆ)
- Schema: table `audit_logs` (id, actor_user_id, action type, entity_type, entity_id,
  before/after JSON หรือ diff, reason nullable, created_at)
- กำหนด action ที่ต้อง log เป็นอย่างน้อย: cancel order, void order item (หลัง cooking),
  แก้ไขราคา/ส่วนลด, ลบ/ปิดใช้งาน staff, แก้ settings (VAT/service charge), refund
  (ผูกกับ ticket #2)
- Backend: middleware/หรือ service-level logging ที่จุดที่ action เหล่านี้เกิดขึ้น (ไม่ใช่
  generic HTTP logging — ต้องมี context ทางธุรกิจ เช่น "ยกเลิกออเดอร์ #123 เหตุผล: ...")
- Frontend: หน้าจอดู audit log สำหรับ admin (filter ตามผู้ใช้/ช่วงเวลา/ประเภท action)

## Acceptance Criteria
- [x] ทุก action เสี่ยง (ตามรายการข้างบน) ถูกบันทึกพร้อมผู้ทำ/เวลา/รายละเอียด — ทำแล้ว: cancel
  order, void order item (หลัง cooking เท่านั้น — pending ยกเลิกเองยังไม่ถือว่าเสี่ยง), แก้ไข
  ส่วนลด, ปิดใช้งาน/ลบ staff, แก้ settings (VAT/service charge), refund พร้อมขยาย scope เพิ่ม
  `user.role_change`, `user.password_reset`, `tax_invoice.void` (ดู `docs/DECISIONS.md` #21)
- [x] Admin ดูประวัติ audit log ทั้งหมด filter ได้ตามผู้ใช้/ประเภท action (ผ่าน query parameter
  `actorUserId`/`action`/`entityType`/`entityId`/`dateFrom`/`dateTo` ที่ backend ครบ — หน้าจอ
  admin ต่อ UI filter เฉพาะ action type ด้วยชิปเลือก ส่วนช่วงเวลายังไม่มี date picker บน UI
  ดู "ข้อเสียที่ยอมรับ" ใน `docs/DECISIONS.md` #21)
- [x] Log ไม่สามารถแก้ไข/ลบได้จาก UI ปกติ (append-only) — ไม่มี endpoint/ปุ่มแก้ไข/ลบเลยทั้งระบบ
  ทั้ง backend (`GET /audit-logs` เท่านั้น) และ Flutter (หน้า **ประวัติการทำรายการ** อ่านอย่างเดียว)

## ไฟล์ที่เกี่ยวข้อง
- `backend/src/db/schema.sql`
- `backend/src/middlewares/`
- `backend/src/modules/orders/`, `backend/src/modules/users/`, `backend/src/modules/settings/`

## ดูเพิ่มเติม

`docs/tickets/13-order-audit-trail.md` ขยายขอบเขตของ ticket นี้ให้ครอบคลุม "ใครกดสั่ง/แก้ไข
ออเดอร์" (เปิดออเดอร์ใหม่, เพิ่ม/แก้ไข/ลบรายการ, ย้ายโต๊ะ, รวมบิล) สำหรับ financial audit และ
ผู้จัดการร้าน ไม่ใช่แค่เหตุการณ์เสี่ยงต่อการทุจริตเหมือนรายการข้างบน
