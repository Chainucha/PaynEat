# Ticket: PromptPay QR จริง (Real PromptPay QR Code)

**Priority:** 🔴 Critical
**สถานะ (2026-09-27):** ✅ เสร็จแล้ว
**Ref:** `docs/FEATURE-GAP-ANALYSIS.md` #16

## ปัญหา
`backend/src/modules/payments/payment.schema.js` กำหนด `PAYMENT_METHODS = ['cash', 'qr',
'card', 'transfer']` เป็น enum เฉยๆ — `qr` ถูกจัดการเหมือน `card`/`transfer` ทุกประการ (มีแค่
ช่อง `reference` ให้กรอกข้อความอิสระ) ไม่มีการ generate QR code จริงตามมาตรฐาน PromptPay
(EMV QR) เลย ทั้งที่ POS คู่แข่งในตลาดไทยทุกเจ้า (FoodStory, Loyverse ฯลฯ) มี PromptPay QR
จริงเป็นมาตรฐานขั้นต่ำ

## ทำไมสำคัญ
ถ้าร้านเอาไปใช้จริงโดยเข้าใจว่า "QR" คือรับเงินผ่านระบบจริง ทั้งที่จริงเป็นแค่ปุ่มให้กดยืนยันเองว่า
"ลูกค้าโอนแล้ว" มีความเสี่ยงทั้งเรื่อง trust และเงินขาด/หายที่ตรวจสอบย้อนหลังไม่ได้ — เป็น gap
เดียวที่เหลืออยู่ใน 🔴 Critical หลังจากรายการ 1-4 เดิมทำครบแล้ว

## ขอบเขตงาน (คร่าวๆ)
- **Backend**: `backend/src/core/promptpay.js` — pure function สร้าง payload ตามมาตรฐาน EMV
  QRCPS Merchant Presented Mode (TLV + CRC-16/CCITT-FALSE) จากเลขพร้อมเพย์ของร้าน (ตั้งค่าใหม่
  `promptPayId` ใน settings) + ยอดเงิน endpoint ใหม่ `GET /payments/promptpay-qr?amount=`
- **Frontend**: เพิ่มช่อง "เลขพร้อมเพย์" ในหน้าตั้งค่า, เรนเดอร์ payload ที่ได้จาก backend เป็นภาพ
  QR จริงด้วย `qr_flutter` ในหน้าเก็บเงินตอนเลือกช่องทาง "QR" (แทนที่ placeholder เดิมที่ไม่ต่าง
  จาก card/transfer)
- **Demo Mode**: `app/lib/core/utils/promptpay.dart` — mirror อัลกอริทึมเดียวกันเป็น Dart pure
  function (มี golden-value test เทียบกับฝั่ง backend ตรงกันเป๊ะ) เพราะ Demo Mode ไม่มี backend
  จริงให้เรียก (ดู `docs/DECISIONS.md` #2 เรื่องโค้ดคำนวณที่ต้องซ้ำ Dart/JS)

## ขอบเขตที่ตั้งใจไม่ทำในทิกเก็ตนี้
- **Payment gateway / callback ตรวจสอบการจ่ายอัตโนมัติ** — เกินความจำเป็นสำหรับร้านอาหารสาขา
  เดียวขนาดนี้ (ต้องสมัคร merchant กับธนาคาร/ผู้ให้บริการ) ตามที่ gap analysis แนะนำไว้แล้วว่า
  "อย่างน้อยควร generate QR code ... แม้จะยังไม่ต้องมี payment gateway เต็มรูปก็ตาม" แคชเชียร์
  ยังต้องเช็คสลิป/แอปธนาคารเองก่อนกดยืนยันรับชำระ เหมือนช่องทางโอน/บัตรเดิม

## Acceptance Criteria
- [x] ตั้งค่าเลขพร้อมเพย์ของร้านได้ที่หน้าตั้งค่า (เบอร์โทร/เลขบัตรประชาชน/เลขผู้เสียภาษี)
- [x] เลือกช่องทางจ่าย "QR" ในหน้าเก็บเงิน แสดงภาพ QR พร้อมเพย์จริงที่สแกนได้ ผูกยอดเงินที่ต้อง
  จ่ายรอบนั้นอัตโนมัติ (อัปเดตใหม่ทุกครั้งที่ยอด/แต้มที่แลกเปลี่ยน)
- [x] ยังไม่ได้ตั้งค่าเลขพร้อมเพย์ → ขึ้นข้อความแจ้งเตือนชัดเจนแทนที่จะพังเงียบๆ (400 พร้อมข้อความ
  "ร้านยังไม่ได้ตั้งค่าเลขพร้อมเพย์")
- [x] อัลกอริทึมสร้าง payload มีเทสต์ครบทั้งฝั่ง backend (JS) และ Demo Mode (Dart) พร้อม golden
  value เทียบกันตรง — กัน bug จากการ implement ผิดสเปกโดยไม่รู้ตัว
- [x] Demo Mode ใช้งานได้ทันทีโดยไม่ต้องตั้งค่าเอง (seed เลขพร้อมเพย์ตัวอย่างไว้ให้)

## ไฟล์ที่เกี่ยวข้อง
- `backend/src/core/promptpay.js`, `backend/tests/promptpay.test.js`
- `backend/src/modules/payments/` (`payment.service.js`/`.controller.js`/`.routes.js`/`.schema.js`)
- `backend/src/modules/settings/` (`promptPayId` field)
- `app/lib/core/utils/promptpay.dart`, `app/test/core/utils/promptpay_test.dart`
- `app/lib/features/payment/` (entity/data/domain/presentation — `promptpay_qr_view.dart`)
- `app/lib/features/settings/` (`promptPayId` field ทั้ง entity/data/usecase/UI)
- `app/lib/core/demo/demo_data_sources.dart`, `demo_seed.dart` (Demo Mode mirror)
