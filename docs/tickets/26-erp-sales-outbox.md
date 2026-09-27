# Ticket: ส่งยอดขายเข้า PaynEat ERP ผ่าน outbox — ครั้งเดียวแน่นอน แม้เน็ตหลุด

**Priority:** 🟠 High — สัปดาห์ที่ 4 ของแผน PaynEat ERP v1
**Ref:** [ERP ADR-0002](https://github.com/SuruchBoss/PaynEat-ERP/blob/main/docs/adr/0002-system-boundaries-and-pos-integration.md),
[สัญญา telemetry v1.2](https://github.com/SuruchBoss/PaynEat-ERP/blob/main/docs/TELEMETRY.md), `docs/DECISIONS.md` #66
**Blocked by:** `25-erp-connected-mode.md`, `27-erp-menu-pull.md`, [PaynEat-ERP#9](https://github.com/SuruchBoss/PaynEat-ERP/issues/9)

## ปัญหา
ERP ต้องรู้ว่าแต่ละสาขาขายอะไรไป เพื่อคำนวณการใช้วัตถุดิบตามสูตร ต้นทุน และการย้อนรอย lot แต่เน็ตหน้าร้านหลุดได้เป็นชั่วโมง
ถ้าส่งตรงตอนขาย ยอดจะหายตอนเน็ตหลุด ถ้า retry แบบไม่ระวัง ยอดจะนับซ้ำ

## ทำไมสำคัญ
เป็นครึ่งหนึ่งของเส้นทาง demo "จากจานย้อนกลับไปถึง lot ของซัพพลายเออร์" และเป็นจุดที่ SherWhyve จะถูกใช้สืบสวนบ่อยที่สุด
("ยอดขายสาขา 2 ไม่เข้า ERP")

## ขอบเขตงาน
- **ส่งเมื่อไร**: เมื่อ**บรรทัดขายถูกชำระ** ส่งหนึ่ง event ต่อบรรทัดที่ไม่ถูกยกเลิก คือตอนบิลถูกชำระครบ หรือตอนที่
  การชำระของบรรทัดนั้นเกิดขึ้น ถ้าแยกบิลตามรายการ (POS ทำเครื่องหมาย `order_items.is_paid` ทีละบรรทัดได้)
  - เวลาขาย (`saleTime`) = เวลาของการชำระที่ครอบคลุมบรรทัดนั้น
  - บรรทัดชั่งน้ำหนักส่งน้ำหนักจริง (kg)
  - ส่ง modifier ไปด้วย โดย `quantity` ของ modifier นับ**ต่อหนึ่งหน่วยที่ขายของบรรทัด** (ต่อชิ้นสำหรับ `quantity`,
    ต่อกิโลกรัมสำหรับ `weightKg`) ตรงกับที่ POS คิดราคาตัวเลือก (`options_price` × จำนวนหรือน้ำหนัก) ตัวเลือกใน POS
    เลือกได้ครั้งเดียวต่อบรรทัด จึงส่ง `"1"` เสมอในตอนนี้
  - เมนูและตัวเลือกระบุด้วย**รหัสของ ERP** ที่ได้จาก ticket 27 (เมนูที่ยังไม่ผูกขายไม่ได้ในโหมดเชื่อมต่อ จึงไม่มีบรรทัดที่ไม่มีรหัส)
  - ให้บันทึกความหมายนี้ในสัญญาฝั่ง ERP ด้วย ดูคอมเมนต์ใน PaynEat-ERP#9
- **outbox**: เขียนแถว event ลงตาราง outbox **ใน transaction เดียวกับการชำระเงิน** ถ้าการชำระเงินล้ม ต้องไม่มีแถว outbox
  - idempotency key คงที่ต่อบรรทัดขาย และไม่เปลี่ยนเมื่อ retry:
    **`<รหัส POS instance>-<รหัสฐานข้อมูล 6 ตัว>-<order_item id เติม 0 ข้างหน้าให้ครบ 8 หลัก>`**
    (ตัวอย่าง `SILOM-POS-K3F9Q2-00001234`) ต้องตรง `^[A-Za-z0-9_-]{8,64}$` ตามสัญญา 1.0.0 (ยาวสุด 32+1+6+1+8 = 48)
    — ห้ามใช้ `:` เพราะ ERP จะแทน `x-request-id` ด้วย id ของตัวเองแล้วการโยงหาย
  - **รหัสฐานข้อมูล** = `[A-Z0-9]` สุ่ม 6 ตัว สร้างครั้งเดียวตอนสร้างฐานข้อมูล เก็บใน settings ถ้าร้านติดตั้งใหม่หรือ
    reset ฐานข้อมูลแล้วเชื่อมด้วย instance เดิม `order_items.id` จะเริ่มนับใหม่ ถ้าไม่มีรหัสนี้ key จะชนกับยอดขายจริง
    ที่ ERP เก็บไว้แล้ว และยอดขายใหม่จะถูกปฏิเสธเป็น `idempotency_key_reused`
  - ทำเฉพาะโหมดเชื่อมต่อ ส่วนโหมดเดี่ยวไม่เขียนแถวใดๆ
- **ตัวส่ง** (background): `POST /api/v1/sales-events` ทีละ event ตามลำดับ ใส่ `x-request-id` = idempotency key
  ตามสัญญา POS v1 **1.0.0** ใน `contracts/` ของ PaynEat-ERP (PR PaynEat-ERP#55) — ทำตามตารางคำตอบของสัญญา:
  - `201` หรือ `200` ที่มี `duplicate: true` = สำเร็จ ทำเครื่องหมายว่าส่งแล้ว
  - `422 SALES_EVENT_REJECTED` = dead-letter พร้อม `details.reason` (`schema_invalid`, `pos_instance_mismatch`,
    `branch_not_served`, `idempotency_key_reused`)
  - `401 POS_CREDENTIAL_REJECTED` (`credential_revoked` / `credential_unknown`) = หยุดส่งทั้งคิวและแจ้งเตือน admin
    แถวที่รอส่งยังรออยู่ (ไม่ย้ายไป dead-letter) และส่งต่อเองเมื่อ admin บันทึก credential ใหม่
  - `429` = รอตาม `Retry-After` แล้วส่งตัวเดิมต่อ ไม่นับเป็นครั้งที่ล้ม
  - `5xx` / timeout / เน็ตหลุด = retry แบบ exponential backoff ด้วย key เดิม**ไม่มีกำหนดครั้ง** (เพดานรอ 5 นาที และทำตาม
    `Retry-After` ถ้า `503` ส่งมา) **ไม่ย้ายไป dead-letter เด็ดขาด** เพราะ ERP ล่มไม่กี่ชั่วโมงจะทำให้ยอดขายจริงกลายเป็น
    dead-letter ที่ต้องมีคนส่งใหม่ทีละรายการ ให้ `outbox_oldest_pending_age_seconds` เป็นตัวแจ้งเตือนแทน
  - คำตอบอื่นที่ไม่อยู่ในตาราง (เช่น `400`, `403`, `404`, `2xx` ที่ไม่ใช่ receipt ตาม schema) = ถือเป็นปัญหาการตั้งค่า
    (ที่อยู่ผิด, proxy, ERP คนละเวอร์ชัน) หยุดทั้งคิวและแจ้งเตือน admin เหมือน `401` ไม่ย้ายไป dead-letter
  - dead-letter มาจาก `422` เท่านั้น ปุ่มส่งใหม่ใช้ **key เดิม** (ERP ไม่เก็บ event ที่ปฏิเสธ จึงรับได้เมื่อแก้สาเหตุแล้ว
    เช่นเพิ่มสาขาให้ instance ใน ERP)
- **รูปแบบ event** ตาม sales event v1: `schemaVersion: 1`, `idempotencyKey`, `posInstance`, `branchCode`, `saleTime`
  (เวลาชำระพร้อม offset), `menuItemCode` และ**อย่างใดอย่างหนึ่ง**ระหว่าง `quantity` (จำนวนเต็มเป็นข้อความ) กับ `weightKg`
  (กิโลกรัมเป็นข้อความ ทศนิยมไม่เกิน 3 ตำแหน่ง — แปลงจาก `weight_grams` ตรงๆ ไม่ผ่าน float) และ `modifiers: [{code, quantity}]`
  ไม่มีฟิลด์ correlation id แยก เพราะ idempotency key คือ correlation id
- **หน้าจอสถานะ outbox** (admin/manager): จำนวนที่รอส่ง, อายุของรายการที่เก่าที่สุด, รายการ dead-letter พร้อมเหตุผล
  และปุ่มส่งใหม่
- **telemetry v1.2** (หัวข้อ "POS↔ERP integration lines"):
  - metric `outbox_pending_events{app,destination}` และ `outbox_oldest_pending_age_seconds{app,destination}`
  - log `outbox.delivery.failed` (`WARNING`, และ `ERROR` เมื่อ dead-letter) โดยมี idempotency key เป็น `correlation_id`
  - **ทุกบรรทัดเรื่องการส่ง รวมบรรทัดที่ล้มเหลว** มี `pos_instance` และ `location_code` ของสาขาใน event นั้น ห้ามเดาค่า
    ถ้าไม่รู้ให้เว้นไว้
- **contract test**: event ที่ POS สร้างต้องผ่าน JSON Schema ของ sales event v1 จาก ERP ใน CI โดยปักสัญญาเวอร์ชัน 1.0.0

## ขอบเขตที่ตั้งใจไม่ทำ (ช่องว่างที่รู้ตัว บันทึกใน DECISIONS #66)
- คืนเงินหรือ void หลังชำระแล้ว ยังไม่ส่งเข้า ERP ใน v1 (อาหารที่คืนเงินส่วนใหญ่ถูกทำไปแล้ว ส่วนต่างให้ ERP จับด้วยการตรวจนับ)
- อาหารที่ทำแล้วแต่ถูกยกเลิกก่อนชำระ (ของเสีย) ยังไม่ส่ง
- การสแกน lot ที่สาขา (ERP ADR-0006)

## Acceptance Criteria
- [ ] ชำระบิลในโหมดเชื่อมต่อ → หนึ่งแถว outbox ต่อบรรทัดที่ไม่ถูกยกเลิก ใน transaction เดียวกับการชำระ
- [ ] ERP ล่ม → รอส่งแล้วส่งครบเมื่อ ERP กลับมา ERP ไม่นับซ้ำ (idempotency key คงที่)
- [ ] ERP ตอบซ้ำ = สำเร็จ, 422 = dead-letter พร้อมเหตุผล, 401 และคำตอบนอกตาราง = หยุดคิวและแจ้งเตือนโดยแถวยังรอส่ง
- [ ] 5xx/เน็ตหลุดนานเท่าไรก็ไม่มีแถวไหนกลายเป็น dead-letter; dead-letter ส่งใหม่ด้วย key เดิมได้
- [ ] แยกบิลตามรายการ → event ของแต่ละบรรทัดมี `saleTime` เป็นเวลาที่บรรทัดนั้นถูกชำระ
- [ ] reset ฐานข้อมูลแล้วเชื่อม instance เดิม → key ใหม่ไม่ชนกับ key เก่า
- [ ] บรรทัดชั่งน้ำหนักส่งน้ำหนัก และส่ง modifier ครบ
- [ ] โหมดเดี่ยวไม่มีแถว outbox เลย
- [ ] metric และ log ตามสัญญา telemetry v1.2 (บรรทัดที่ล้มเหลวมี `pos_instance` และ `location_code`), contract test ผ่าน
- [ ] README (ไทย/อังกฤษ), `docs/DECISIONS.md`, `docs/FEATURE-GAP-ANALYSIS.md` อัปเดตตาม `CLAUDE.md`

## เทสต์
backend ใช้ stub server ของ ERP ครอบคลุม: ส่งสำเร็จ, ERP ล่มแล้วกลับมา, ตอบซ้ำ, 422, 401, 404, 503 พร้อม `Retry-After`,
การชำระล้มแล้วต้องไม่มีแถว outbox, แยกบิลตามรายการ, บรรทัดชั่งน้ำหนักพร้อมตัวเลือก และโหมดเดี่ยว
E2E ฝั่งแอป: ชำระบิลแล้วหน้าจอสถานะ outbox แสดงรายการรอส่ง
