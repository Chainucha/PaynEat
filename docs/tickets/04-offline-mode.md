# Ticket: Offline Mode (Local Queue + Sync)

**Priority:** 🔴 Critical
**สถานะ (2026-09-27):** ✅ เสร็จแล้ว
**Ref:** `docs/FEATURE-GAP-ANALYSIS.md` #4

## ปัญหา
ทุก action (สั่งอาหาร, ส่งครัว, ชำระเงิน) พึ่ง backend ผ่าน network ตลอดเวลา
(`app/lib/core/network/`) ไม่มี local queue หรือ sync กลับเมื่อเน็ตหลุด — ระบุไว้แล้วใน
README ว่าเป็นสิ่งที่ยังไม่ได้ทำ ("สิ่งที่จะทำต่อ")

## ทำไมสำคัญ
ร้านอาหารจำนวนมาก WiFi หลุดบ่อยโดยเฉพาะช่วงพีค ถ้าแอปพึ่ง network ตลอดเวลา ระบบจะรับ
ออเดอร์ไม่ได้ทันทีที่เน็ตหลุด กระทบ business continuity โดยตรง

## ขอบเขตงาน (คร่าวๆ)
- กำหนดขอบเขต action ไหนต้อง offline-first ก่อน (แนะนำเริ่มจาก: สั่งอาหาร/เพิ่มรายการ
  เข้าบิลที่เปิดอยู่แล้ว — ความเสี่ยง conflict ต่ำกว่าการชำระเงิน)
- Local persistence ของ order queue (ใช้ `get_storage` ที่มีอยู่แล้ว หรือ local DB
  เช่น sqflite/drift ถ้าข้อมูลซับซ้อนขึ้น)
- Sync strategy เมื่อกลับมาออนไลน์: retry queue ตามลำดับ, จัดการ conflict (เช่น โต๊ะถูกย้าย/
  merge ระหว่าง offline)
- UI indicator ว่ากำลัง offline / มีรายการรอ sync กี่รายการ (ต่อยอดจาก realtime
  connectivity indicator ที่มีอยู่แล้ว)
- ตัดสินใจ scope ที่ "ตั้งใจไม่รองรับ offline" ให้ชัด (เช่น การชำระเงิน/ปิดกะ อาจยังต้อง
  online เพื่อความถูกต้องของเงิน)

## Acceptance Criteria
- [ ] Waiter สั่งอาหารได้ต่อเนื่องแม้เน็ตหลุดชั่วคราว รายการถูก queue ไว้ในเครื่อง
- [ ] เมื่อเน็ตกลับมา รายการที่ queue ไว้ sync ขึ้น backend อัตโนมัติตามลำดับ
- [ ] มี UI แจ้งสถานะ offline และจำนวนรายการรอ sync
- [ ] มีเอกสารระบุชัดว่า action ใดรองรับ offline และ action ใดไม่รองรับ (เช่น payment)

## ไฟล์ที่เกี่ยวข้อง
- `app/lib/core/network/`
- `app/lib/features/order/`
- `app/lib/core/services/` (realtime connectivity indicator ที่มีอยู่)
