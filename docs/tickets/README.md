# PaynEat — Feature Gap Tickets

Ticket เหล่านี้สร้างจาก `docs/FEATURE-GAP-ANALYSIS.md` (PO gap analysis, 2026-09-09)
แต่ละไฟล์คือ 1 ticket อิสระ อ่านแล้วเริ่ม plan/implement ต่อได้เลย ไม่ต้องกลับไปอ่าน gap
analysis ซ้ำ (แต่ลิงก์ไว้เผื่ออยากดู context เพิ่ม)

จัดกลุ่มตามลำดับที่ควรทำ (ตัวเลขนำหน้าไฟล์ = ลำดับความสำคัญ ไม่ใช่ ticket id ตายตัว):

> **สถานะรวม ณ 2026-09-28** — ✅ เสร็จแล้ว 01–25, 29a และ 32 · ⏳ ยังไม่เริ่ม 26–28, 29b, 30, 31 (30, 31 **เริ่มได้** · 26–28 และ 29b **รอ QA รอบ 1** — `docs/DECISIONS.md` #77) · ผล QA รอบ ก.ย. 2026
> (#79) เป็น GitHub Issues T01–T32 (ดูหัวข้อท้ายไฟล์) ฟีเจอร์ที่ ✅ แล้วบางตัวมีกฎที่ QA พบว่ายังไม่ป้องกัน ระบุไว้ท้ายบรรทัดนั้น
> และในบรรทัด "สถานะ" ของไฟล์ ticket

## 🔴 Critical (Sprint แรก — ของที่ POS ทุกตัวต้องมี)
- `01-shift-cash-reconciliation.md` — ✅ เสร็จแล้ว — QA: T11 #101, T12 #106
- `02-refund-flow.md` — ✅ เสร็จแล้ว — QA: T06 #82, T08 #100, T13 #102
- `03-receipt-printer.md` — ✅ เสร็จแล้ว
- `04-offline-mode.md` — ✅ เสร็จแล้ว

## 🟠 High (เฟส 2 — แข่งขันกับ POS เจ้าอื่น)
- `05-promotion-engine.md` — ✅ เสร็จแล้ว — QA: T10 #83, T17 #108
- `06-inventory-stock.md` — ✅ เสร็จแล้ว — QA: T27 #110 (สต๊อกไม่พอห้ามส่งครัวเว้นผู้จัดการยืนยัน, DECISIONS #77 D6)
- `07-tax-invoice.md` — ✅ เสร็จแล้ว — QA: T13 #102
- `08-audit-log.md` — ✅ เสร็จแล้ว

## 🟡 Medium (เฟสขยายธุรกิจ)
- `09-customer-loyalty.md` — ✅ เสร็จแล้ว — QA: T11 #101, T15 #84 ✅
- `10-takeaway-delivery-flow.md` — ✅ เสร็จแล้ว — QA: T17 #108
- `11-multi-branch.md` — ✅ เสร็จแล้ว — backend scope 4 entity (โต๊ะ/เมนู/ออเดอร์/วัตถุดิบ) ตาม
  `branch_id` + หน้าเลือก/สลับสาขาใน Flutter (`branch_selection_page.dart`) โหมดสาธิตยังมีสาขาเดียว
  โดยตั้งใจ ดู `docs/DECISIONS.md` #36 — QA: T21 #109, T22 #86, T32 #117
- `12-report-export.md` — ✅ เสร็จแล้ว — export รายงานขาย (สรุป/เมนูขายดี/รายวัน) เป็น CSV และ
  Z-report ปิดกะ/ปิดวัน (ต่อกะมีกระทบยอดเงินสด คิดจาก `payments.shift_id` จึงถูกต้องแม้ออเดอร์
  หรือกะจะข้ามวัน) ดู `docs/DECISIONS.md` #35

## 🟠 ร้านเนื้อ + ขายส่ง B2B (ความต้องการของร้านเนื้อที่ขายส่ง 2026-09-23 — ไม่อยู่ใน gap analysis รอบแรก)
- `18-sell-by-weight.md` — ✅ เสร็จแล้ว — ราคาต่อกิโลกรัม น้ำหนักเก็บเป็นกรัม ราคาตรงกันทุกสตางค์ทั้ง
  ตะกร้า/backend/ใบเสร็จ ตัดสต๊อกเป็น กก. ดู `docs/DECISIONS.md` #48, #51
- `19-barcode-scale.md` — ✅ เสร็จแล้ว — สแกนบาร์โค้ดสินค้า + ฉลากตาชั่ง EAN-13 (น้ำหนักอยู่ในรหัส)
  ตั้งรูปแบบฉลากได้ อ่านรหัสในเครื่อง ดู `docs/DECISIONS.md` #49
- `20-b2b-credit.md` — ✅ เสร็จแล้ว — ขายเชื่อตามวงเงิน/เครดิตเทอม ใบวางบิล ใบเสร็จรับชำระหนี้ อายุหนี้
  เงินสดที่รับชำระนับเข้าลิ้นชักตอนปิดกะ ดู `docs/DECISIONS.md` #50
- `21-late-fees-credit-notes.md` — ✅ เสร็จแล้ว — ดอกเบี้ยผิดนัด (ใบแจ้ง LF, คิดจากเงินต้นที่ยังค้าง
  ยกเว้นได้) + ใบลดหนี้ออกอัตโนมัติทุกครั้งที่ลดหนี้บิลขายเชื่อ ดู `docs/DECISIONS.md` #55, #56
- `22-live-scale-camera-scan.md` — ✅ เสร็จแล้ว — เซิร์ฟเวอร์ร้านอ่านตาชั่ง (TCP/Serial) กระจายน้ำหนักสดให้
  ทุกเครื่องผ่าน socket.io + สแกนบาร์โค้ด/ฉลากด้วยกล้องมือถือ ดู `docs/DECISIONS.md` #54
- `23-document-pdf-email.md` — ✅ เสร็จแล้ว — เอกสารลูกหนี้ทุกชนิดเป็น PDF ภาษาไทย ส่งอีเมลผ่าน SMTP ของ
  ร้านเอง ดู `docs/DECISIONS.md` #57

## 🟢 Nice-to-have (backlog, ไม่ตัด ticket แยก)
- ระบบจองโต๊ะ (reservation) ผูกกับผังโต๊ะ
- แจ้งเตือนสต๊อกใกล้หมด/ยกเลิกออเดอร์ผิดปกติ ผ่าน push/LINE Notify
- ~~Flutter integration test กับ backend จริง~~ ✅ เสร็จแล้ว — ชุด E2E `app/test_e2e/` (42 เคส) เปิด
  backend ตัวจริงแล้วให้โค้ดชั้น data/domain ของแอปเดินหนึ่งวันทำงานของร้าน รอบแรกเจอบั๊กจริง 5 ตัวใน
  ticket 02/07/12/17 แก้แล้วทั้งหมด ดู `docs/DECISIONS.md` #43–#47
- เอา pagination ที่ backend รองรับอยู่แล้วมาใช้ฝั่ง app

## นอกเหนือจาก gap analysis เดิม (ผู้ใช้ร้องขอเพิ่มเติมภายหลัง — audit ทั้ง financial และ restaurant manager)
- `13-order-audit-trail.md` — ✅ เสร็จแล้ว — ขยาย audit log (ticket 08) ให้ครอบคลุม
  "ใครกดสั่ง/แก้ไขออเดอร์" สำหรับ**ผู้จัดการร้าน** ไม่ใช่แค่เหตุการณ์เสี่ยงต่อการทุจริต
- `14-financial-audit-trail.md` — ✅ เสร็จแล้ว — audit ระดับ**บัญชี/การเงิน**: แก้ราคาเมนู/
  โปรโมชัน/สต๊อกวัตถุดิบถูก log ครบแล้ว, export audit log เป็น CSV ได้ (เว็บเท่านั้น), มี
  date range picker บน UI (ของค้างจาก ticket 08)
- `15-ai-ask-your-data.md` — ✅ เสร็จแล้ว — **จุดขาย**: AI ถามตอบข้อมูลร้านด้วยภาษาพูด (ยอดขาย/
  เมนูขายดี/ลูกค้า) ผ่าน LLM tool-calling ที่เรียก endpoint จริงในระบบเท่านั้น (กัน hallucinate
  ตัวเลข) ต่อยอดจากดีไซน์ dashboard ที่ทำไว้ก่อนหน้า ดู `docs/DECISIONS.md` #33
- `12-report-export.md` — ✅ เสร็จแล้ว — export รายงานยอดขาย/เมนูขายดี/ยอดขายรายวันเป็น CSV +
  Z-report ต่อกะ/ต่อวัน (scope ด้วย `payments.shift_id` กันกะข้ามเที่ยงคืนนับผิด) — implement บน
  branch `claude/pos-restaurant-project-3djpp6` (commit `4e2684d`) **ขนานกัน** กับตอนที่เซสชันนี้
  เขียน full spec ให้ (`/to-spec`, ก่อนรู้ว่ามีอีก session ทำอยู่แล้ว) — ดู `docs/DECISIONS.md` #35

## พบระหว่างตรวจโค้ดจริงซ้ำ (2026-09-15) — ไม่เคยอยู่ใน gap analysis รอบแรก
- `16-promptpay-qr.md` — ✅ เสร็จแล้ว — 🔴 Critical gap เดียวที่เหลืออยู่หลังจากรายการ 1-4 เดิม
  ทำครบแล้ว: ช่องทางจ่าย "QR" เดิมเป็นแค่ label ไม่มี PromptPay QR จริงให้ลูกค้าสแกน
- ✅ เสร็จแล้ว — self code-review รอบใหม่ (clean code/tech debt/state management/architecture/
  spaghetti) พบว่า `14-financial-audit-trail.md` ยังเหลือรูอยู่ 3 จุด: เปิด/ปิดกะ, รับชำระเงิน,
  กรอก/ถอดโค้ดส่วนลด ไม่มี audit log (จุดหลังไม่มี transaction ห่อด้วย) — ปิดครบแล้ว
  ดู `docs/DECISIONS.md` #28 และหัวข้อ "ส่วนต่อขยาย" ใน `14-financial-audit-trail.md`

## เทียบกับตลาดรอบใหม่ (2026-09-19)
- `17-qr-self-order.md` — ✅ เสร็จแล้ว — 1 ใน 3 gap ที่เหลือเทียบกับ POS คู่แข่งในตลาดไทย (อีก 2 คือ
  เชื่อมแพลตฟอร์มเดลิเวอรีและ payment gateway อัตโนมัติ ซึ่งตั้งใจไม่ทำ ดู `docs/DECISIONS.md`
  #23/#26): ลูกค้าสแกน QR ที่โต๊ะแล้วสั่งอาหารเองจากมือถือตัวเองได้โดยไม่ต้อง login ผ่าน endpoint
  สาธารณะที่ reuse business logic เดิมทั้งหมด ดู `docs/DECISIONS.md` #37

## PO re-verify รอบใหม่ (2026-09-19) — ตอบคำถาม "พร้อมให้คนโหลดไปใช้จริงหรือยัง"

ผู้ใช้ถามตรงๆ ว่าฟีเจอร์ตอนนี้ดีพอให้คนโหลดไปใช้จริงหรือยัง (กังวลว่าจะมีคนคิดว่า "ฟรีแต่ฟีเจอร์ไม่พอ
ยอมเสียเงินดีกว่า") แทนที่จะเชื่อสถานะ ✅ เดิม แบ่งตรวจอิสระ 3 ทาง — รายละเอียดเต็มดู
`docs/DECISIONS.md` #38:

- ✅ สุ่มตรวจ 4 ticket ที่ติ๊ก ✅ ไว้ (01 shift, 02 refund, 06 inventory, 07 tax invoice) ยืนยันว่า
  ทำจริงครบ DB+backend+UI ไม่มีจุดที่เป็นของปลอมแบบ ticket 16 เดิม
- 🐛 **พบและแก้บั๊กจริงใน ticket 15 (AI assistant)**: โมเดิลตอบข้อความเฉยๆ โดยไม่เรียก
  `submit_answer` เคยหลุดผ่านเป็นคำตอบสุดท้ายได้ (ขัดกฎ "ห้ามเดา/แต่งคำตอบ" ของทิกเก็ตเอง) — แก้แล้ว
  พร้อมเทสต์ยืนยัน (`backend/src/modules/ai-assistant/ai-assistant.service.js`,
  `backend/tests/ai-assistant.test.js`)
- ⚠️ **บทเรียนเรื่อง session ทำงานขนานกัน**: รอบตรวจนั้นสรุปว่า ticket 11 ยัง out-of-scope และ
  ticket 12 ยังไม่ได้ทำ จึงเขียน full spec (`/to-spec`) ของ 12 ขึ้นมาใหม่ — ทั้งสองข้อไม่จริง ทั้งคู่
  ถูกทำเสร็จอยู่ก่อนแล้วบน branch `claude/pos-restaurant-project-3djpp6` (ticket 12 ที่ commit
  `4e2684d`, ticket 11 ครบทั้ง backend และ UI) และตอนนี้ merge เข้า `main` แล้ว — "ยืนยันด้วยโค้ดจริง"
  ครอบคลุมแค่โค้ดที่ session นั้นมองเห็น ไม่รวม branch อื่นที่ทำขนานกันอยู่ ครั้งหน้าต้องเช็ค branch
  ที่ยัง active ก่อนสรุปว่างานยังไม่ได้ทำ

## 🔗 ระบบนิเวศ PaynEat — เชื่อมกับ PaynEat ERP (2026-09-25)

POS กลายเป็นหนึ่งในสี่ระบบของระบบนิเวศ PaynEat (POS · [PaynEat ERP](https://github.com/SuruchBoss/PaynEat-ERP)
· [Cwork](https://github.com/SuruchBoss/Cwork) · SherWhyve ซึ่งเป็น private) ขอบเขตระหว่างกันอยู่ใน
[ERP ADR-0011](https://github.com/SuruchBoss/PaynEat-ERP/blob/main/docs/adr/0011-ecosystem-and-sherwhyve.md)
และ `docs/DECISIONS.md` #66 — **POS ยังใช้เดี่ยวได้เป็นค่าเริ่มต้นเสมอ** การเชื่อม ERP เป็นโหมดเลือกได้

งานฝั่ง ERP ติดตามใน [GitHub Issues ของ PaynEat-ERP](https://github.com/SuruchBoss/PaynEat-ERP/issues) ส่วนงาน
ฝั่ง POS อยู่ที่นี่ตามธรรมเนียมเดิมของ repo นี้

- `24-telemetry-contract.md` — ✅ เสร็จแล้ว — log แบบ JSON + `x-request-id` + `/metrics` (พอร์ตแยก 9464 ไม่เปิดออก
  นอกเครื่อง) ตาม[สัญญา telemetry v1.1](https://github.com/SuruchBoss/PaynEat-ERP/blob/main/docs/TELEMETRY.md)
  ไม่มีข้อมูลลูกค้า รหัสผ่าน หรือ QR token ใน log และแอปแสดงรหัสคำขอท้ายข้อความ error (`docs/DECISIONS.md` #68)
  — สัญญา v1.2 เพิ่มเฉพาะกฎของบรรทัดเชื่อมต่อ POS↔ERP ซึ่งอยู่ใน 25–26 ส่วนงานของ 24 ไม่ต้องแก้
- `25-erp-connected-mode.md` — ✅ เสร็จแล้ว (2026-09-27, `docs/DECISIONS.md` #80) — ลงทะเบียนกับ ERP, ดึง master data
  ตามเวอร์ชัน, หน้าจัดการวัตถุดิบ/สาขาเป็นอ่านอย่างเดียว, ปิดการปิดขายอัตโนมัติจากสต๊อกในเครื่องในโหมดเชื่อมต่อ,
  ปุ่ม "สร้างในเครื่อง" สำหรับสาขาที่ ERP ให้ดูแล และ log ของการดึงตามสัญญา telemetry v1.2 (แก้ตามรีวิว PR #121)
- `26-erp-sales-outbox.md` — ⏳ ยังไม่ได้ทำ — **รอ** QA รอบ 1 (รวม T02 #81) และ 27 — ส่งยอดขายเข้า ERP ผ่าน outbox ใน
  transaction เดียวกับการชำระเงิน ครั้งเดียวแน่นอนด้วย idempotency key แม้เน็ตหลุด
- `27-erp-menu-pull.md` — ⏳ ยังไม่ได้ทำ — **รอ** QA รอบ 1 และ PaynEat-ERP#16 (ฝั่ง ERP เริ่มได้แล้ว ยังไม่เริ่ม) — ดึงเมนู ราคา ตัวเลือก สูตรจาก ERP (สัญญา v1.1),
  ผูกเมนูเดิมกับรหัส ERP ตอนเชื่อมต่อครั้งแรก, ราคาแยกสาขาที่ขัดกันต้องแสดงชัด ไม่เลือกเงียบๆ
- `28-erp-connect-from-config.md` — ⏳ ยังไม่ได้ทำ — **รอ** QA รอบ 1, 26 และ 27 — เข้าโหมดเชื่อมต่อจาก `ERP_URL` +
  ไฟล์ credential ตอนเปิดเครื่อง (ตั้งผิดแล้วยังเปิดในโหมดเดี่ยวได้) และติด tag ให้ PaynEat-ERP#27 ใช้ทำเดโมคำสั่งเดียว
- `29-android-google-play.md` — 🟡 ทำไปครึ่งหนึ่ง — **29a เสร็จ** (2026-09-27: build `.aab` ลงนามใน CI จาก tag, build สาธิตสำหรับ
  ทดสอบแบบปิด, ไอคอนแอป, นโยบายความเป็นส่วนตัว, Data safety และหน้า store ใน `docs/store/` — `docs/DECISIONS.md` #75)
  เหลือ **29b** (ที่อยู่เซิร์ฟเวอร์/QR และโหมดสาธิตตอนใช้งาน — **รอ QA รอบ 1**, #77) ลำดับ: ERP #9 ✅ → 29a ✅ → 25 ✅ → 29b → 26/27/28
  (`docs/DECISIONS.md` #69) — applicationId `suruch.boss.payneat` (#78) · ก่อนอัปโหลด Play ครั้งแรกต้องทำ Flutter ขั้น 1–2 (#111)
- `30-korean-font-on-demand.md` — ⏳ ยังไม่ได้ทำ — **เริ่มได้** — วัดก่อนว่าเว็บโหลดฟอนต์เกาหลี 3.2MB ตั้งแต่เปิดหน้าไหม ถ้าใช่
  โหลดเฉพาะเมื่อต้องใช้ โดยข้อมูลเกาหลีต้องไม่เป็นกล่องสี่เหลี่ยมแม้ไม่มีอินเทอร์เน็ต (`docs/DECISIONS.md` #74)
- `31-og-image-and-pwa-icons.md` — ⏳ ยังไม่ได้ทำ — **เริ่มได้** — ภาพแชร์ลิงก์ยังเขียน "558 เทสต์" และไอคอนเว็บแอปยังเป็นโลโก้
  Flutter สร้างทั้งสองอย่างใหม่ด้วยสคริปต์จากแหล่งเดียว
- `32-erp-https-only.md` — ✅ เสร็จแล้ว — ส่ง credential ให้ ERP ผ่าน HTTPS เท่านั้น ยกเว้น loopback หรือเครือข่ายปิดที่ผู้ดูแลเซิร์ฟเวอร์
  ตั้ง `ERP_ALLOW_INSECURE_HTTP` เอง ตรวจใบรับรองเสมอ และสำเนาสัญญาจาก PaynEat-ERP#61 (`docs/DECISIONS.md` #82)
  — ไม่เกี่ยวกับ T32 (#117) ของ QA ซึ่งเป็น GitHub Issue

## 🧪 ผล QA รอบ ก.ย. 2026 (#79) — ticket อยู่ใน GitHub Issues ไม่ได้เป็นไฟล์ในโฟลเดอร์นี้

QA ตรวจ commit `b67874b` พบ bug 42 ใบ (#37–#78) แตกเป็น ticket T01–T32 (#80–#110, #117) และ issue dependency 6 ใบ (#111–#116)
PO ตอบ 12 ข้อที่มีทางเลือกครบแล้ว (`docs/DECISIONS.md` #77) — **สถานะ ณ 2026-09-28: เสร็จ 8 ใบ (T01, T02, T04, T05, T06, T10, T15, T19)**

- **รอบ 1 (ปิดทางที่เงินหาย)** — T01 #80 ✅ merge แล้ว (PR #119, `docs/DECISIONS.md` #79) · T19 #85 ✅ ค่าเริ่มต้นสำหรับ production (`docs/DECISIONS.md` #83) · T02 #81 ✅ แก้ออเดอร์ใน transaction เดียว (`docs/DECISIONS.md` #84) · T04 #95 ✅ ล็อกรายการในบิลที่ปิดแล้ว (`docs/DECISIONS.md` #85) · T05 #104 ✅ ยกเลิกรายการที่ครัวเคยทำต้องใช้ผู้จัดการแม้ถูกเลิกทำ (`docs/DECISIONS.md` #86) · T06 #82 ✅ ยอดจ่ายแล้วหักยอดคืนเงิน (`docs/DECISIONS.md` #87) · T10 #83 ✅ แยกจ่ายปันโปรและ VAT รวมในราคาถูกต้อง
  (`docs/DECISIONS.md` #88) · T15 #84 ✅ อัตราแต้มขั้นต่ำ 0.01 บาทและซ่อมยอดแต้มที่เสีย (`docs/DECISIONS.md` #89) · ที่เหลือ ⏳: T22 #86
- **รอบ 2 (ตัวเลขเงินและการแยกสาขา)** — ⏳ T07 #105, T08 #100, T09 #96, T11 #101, T03 #94, T20 #98, T21 #109, T23 #87
- **รอบ 3 (รายงานและสต๊อก)** — ⏳ T12 #106, T13 #102, T16 #107, T17 #108, T18 #97, T24 #88, T25 #89, T27 #110
- **หลัง T21** — ⏳ T32 #117 (ตรวจสาขาในทุก endpoint ที่รับ id — เปิดตาม D10)
- **Backlog** — ⏳ T14 #103, T26 #90, T28 #91, T29 #92, T30 #93, T31 #99
- **Dependency** — ⏳ #116 (PR ของ Dependabot ค้าง 5 ใบ: #10, #11, #12, #14, #21 — #14 ติดเพดาน `image_picker` รอ #111),
  #112 (เอกสาร Node 20), #111 → #114 (Flutter แล้วค่อย `custom_lint` — ขั้น 1–2 ก่อนอัปโหลด Play), #113 (`prom-client`),
  #115 (ที่เก็บ token ตาม D12)
- **ต่อกับงาน ERP** — ticket 25 เสร็จแล้ว (`docs/DECISIONS.md` #80) ส่วน ticket 26 รอ QA รอบ 1 ครบ (T02 ที่ 26 ต้องใช้เสร็จแล้ว)

