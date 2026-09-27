# Ticket: QR สั่งอาหารเอง (QR Self-Order)

**Priority:** 🟠 High
**สถานะ (2026-09-27):** ✅ เสร็จแล้ว (`docs/DECISIONS.md` #37)
**Ref:** `docs/FEATURE-GAP-ANALYSIS.md` #17

## ปัญหา
ลูกค้าต้องเรียกพนักงานเสิร์ฟทุกครั้งที่จะสั่งอาหารเพิ่ม ไม่มีทางสั่งเองผ่านมือถือได้เลย ทั้งที่ POS
คู่แข่งในตลาดไทย (FoodStory, Loyverse, StoreHub ฯลฯ) ส่วนใหญ่มี "สแกน QR ที่โต๊ะ → สั่งเองผ่าน
เว็บ" เป็นมาตรฐานแล้ว ช่วยลดภาระพนักงานช่วงร้านแน่นและลดความผิดพลาดจากการจดออเดอร์ผิด

## ทำไมสำคัญ
ระบุเป็น 1 ใน 3 gap ที่เหลือเทียบกับตลาด (อีก 2 คือเชื่อมแพลตฟอร์มเดลิเวอรีและ payment gateway
อัตโนมัติ — ทั้งคู่ตั้งใจไม่ทำตาม `docs/DECISIONS.md` #23/#26) และเป็นตัวที่ทำได้เร็วที่สุดโดยไม่ต้อง
พึ่งบริการภายนอก/สัญญากับผู้ให้บริการรายที่สาม เพราะ reuse business logic เดิม (สต๊อก/โปรโมชัน/
realtime) ได้เกือบ 100%

## ขอบเขตงาน (คร่าวๆ)
- **Backend**: เพิ่มคอลัมน์ `dining_tables.qr_token` (opaque token กันเดา/enumerate เลข table id
  ตรงๆ) + endpoint สาธารณะไม่ต้อง login ใหม่ทั้งหมดที่ `/public/tables/:qrToken/*`
  (`backend/src/modules/public-order/`) ใช้ซ้ำ `orderService`/`menuService`/`categoryService` เดิม
  100% จึงได้ตัดสต๊อก/โปรโมชัน/realtime event ฟรีโดยไม่ต้องเขียน business logic ซ้ำ — จำกัดอัตรา
  ยิง `POST .../items` ด้วย in-memory rate limiter เขียนเอง (`core/rateLimit.js`, 30 ครั้ง/5 นาที
  ต่อ qrToken) กัน spam โต๊ะเดียวถล่มระบบ
- **Frontend**: หน้าใหม่ `/order/:qrToken` (`features/self_order/`) — โมดูลแยกต่างหาก ไม่มี login/
  AuthController เกี่ยวข้องเลย reuse widget เดิม (`MenuItemCard`, `CategoryFilterBar`,
  `OptionSelectionSheet`, `BillSummary`, `OrderItemTile`) ตรงๆ เพราะ response จาก public API เป็น
  subset/superset ของโครงสร้างเดิมที่ widget พวกนี้ parse อยู่แล้ว
- **ฝั่งพนักงาน**: ปุ่ม "ดู QR สั่งอาหารเอง" ที่ผังโต๊ะ (bottom sheet เดิมตอนกดค้างที่การ์ดโต๊ะ) แสดง
  ภาพ QR จริง (เข้ารหัสลิงก์ `/order/:qrToken` ด้วย `qr_flutter` เหมือน `promptpay_qr_view.dart`) +
  ปุ่ม "คัดลอกลิงก์" + ปุ่ม "เปลี่ยน QR" (เฉพาะ admin/manager) สำหรับกรณี QR ที่พิมพ์ไว้หลุด/ถูกถ่าย
  รูปแอบอ้างไป
- **Demo Mode**: `qrToken` แบบ deterministic (`demo-table-$id`) + `DemoSelfOrderDataSource` mirror
  endpoint สาธารณะทั้ง 3 เส้นทางในเครื่องล้วนๆ

## ขอบเขตที่ตั้งใจไม่ทำในทิกเก็ตนี้
- **พิมพ์ QR standee/table tent จริงจากในแอป** — ไม่เพิ่ม dependency ใหม่ (`printing`/`pdf`) แค่
  สำหรับงานนี้ ให้แสดงภาพ QR ขนาดใหญ่บนจอ + ปุ่มคัดลอกลิงก์แทน ร้านถ่ายภาพหน้าจอ/ใช้เครื่องมือ
  ออกแบบภายนอกไปทำป้ายเองได้ ตรงกับปรัชญาที่ตั้งใจไว้ (`docs/DECISIONS.md` #3) ว่าจะไม่เพิ่ม
  dependency ใหม่โดยไม่จำเป็น
- **ชำระเงินเองผ่าน QR (self-checkout)** — ทิกเก็ตนี้ให้ลูกค้าสั่งอาหารเองเท่านั้น การเก็บเงินยังต้อง
  ผ่านแคชเชียร์เหมือนเดิมทุกประการ (กันความเสี่ยงเงินหาย/ทุจริตที่มาพร้อม self-checkout ซึ่งต้องมี
  payment gateway จริงที่ตั้งใจแยกเป็นอีก gap หนึ่งอยู่แล้ว)
- **แจ้งเตือนพนักงานแบบ real-time เมื่อลูกค้าสั่งเอง** —ออเดอร์ที่ลูกค้าสั่งเองขึ้นที่ครัว/ผังโต๊ะทันที
  ผ่าน Socket.IO event เดิม (`ORDER_CREATED`/`KITCHEN_TICKET`) อยู่แล้วเพราะ reuse `orderService`
  ตรงๆ จึงไม่ต้องทำ notification แยกเพิ่ม

## Acceptance Criteria
- [x] ทุกโต๊ะมี `qrToken` ไม่ซ้ำกัน (สุ่มด้วย `crypto.randomUUID()` ฝั่ง backend, deterministic ฝั่ง
  Demo Mode) ตั้งแต่สร้างโต๊ะใหม่/migrate ฐานข้อมูลเดิม
- [x] ลูกค้าสแกน QR ที่โต๊ะแล้วเห็นเมนู + ตะกร้า + ออเดอร์ปัจจุบันของโต๊ะนั้นทันที โดยไม่ต้อง login
- [x] กด "ส่งเข้าครัว" แล้วออเดอร์ขึ้นที่ฝั่งพนักงาน (ผังโต๊ะ/ครัว) แบบ realtime เหมือนพนักงานสั่งเอง
  ทุกประการ (ตัดสต๊อก/คำนวณโปรโมชันอัตโนมัติเหมือนกัน)
- [x] เมนูหมด/โต๊ะถูกปิดใช้งาน/qrToken ผิด → แจ้งข้อความชัดเจน ไม่ใช่พังเงียบๆ
- [x] จำกัดอัตรายิง endpoint สั่งอาหารต่อโต๊ะ กันสแปม/DoS ระดับพื้นฐาน
- [x] พนักงาน (admin/manager) ดูภาพ QR + คัดลอกลิงก์ + เปลี่ยน QR ใหม่ได้จากหน้าผังโต๊ะ — เปลี่ยน
  แล้ว QR เดิมใช้ไม่ได้ทันที
- [x] Demo Mode ใช้งานได้ทันทีโดยไม่ต้องตั้งค่าเอง (ทุกโต๊ะ seed มี `qrToken` พร้อมใช้)
- [x] มีเทสต์ครบทั้งฝั่ง backend (public-order module) และ Flutter (controller + DemoStore
  extension methods)

## ไฟล์ที่เกี่ยวข้อง
- `backend/src/db/migrate.js`, `backend/src/db/seed.js` (`qr_token` column + backfill)
- `backend/src/modules/tables/` (`qrToken` field, `regenerateQrToken` endpoint)
- `backend/src/modules/public-order/` (`.service.js`/`.controller.js`/`.routes.js`/`.schema.js`)
- `backend/src/core/rateLimit.js`, `backend/tests/public-order.test.js`
- `app/lib/features/self_order/` (domain/data/presentation ทั้งโมดูล)
- `app/lib/features/table/presentation/widgets/table_qr_view.dart`,
  `app/lib/features/table/presentation/controllers/table_controller.dart` (`regenerateQrToken`)
- `app/lib/app/config/app_config.dart` (`selfOrderLink()`)
- `app/lib/core/demo/demo_self_order_data_source.dart`, `demo_store_tables.dart`
- `app/test/presentation/self_order_controller_test.dart`, `app/test/core/demo_store_test.dart`

## แก้ภายหลัง (2026-09-23 — พบจากชุด E2E `app/test_e2e/`)
เกณฑ์ข้อ "กดส่งเข้าครัวแล้วขึ้นที่ครัว" ติ๊กไว้แต่จริง ๆ ผ่านแค่กรณีพนักงานเปิดออเดอร์ไว้ก่อน — ถ้าลูกค้าเป็น
คนแรกของโต๊ะว่าง ออเดอร์ค้างเป็นร่าง (`open`) ครัวไม่เห็นเลย (เทสต์เดิมยืนยันพฤติกรรมผิดนี้ไว้ด้วย) ตอนนี้
ส่งเข้าครัวทันทีทุกกรณี และลิงก์ QR ที่ถูกตัดท้าย (token ผิดรูปแบบ → 400) แสดง "ลิงก์ใช้ไม่ได้" แทนหน้า
"ไม่มีอินเทอร์เน็ต" — กติกาอยู่ที่ `isBrokenSelfOrderLink` ที่เดียว ดู `docs/DECISIONS.md` #46
