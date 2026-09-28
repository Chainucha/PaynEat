# สัญญาเชื่อมต่อ PaynEat ERP ↔ POS — สำเนาที่ปักเวอร์ชัน 1.0.0

ไฟล์ในโฟลเดอร์นี้ (ยกเว้นไฟล์นี้และ `checksums.json`) คัดลอกมาจาก
[`contracts/`](https://github.com/SuruchBoss/PaynEat-ERP/tree/fc489f2/contracts) ของ PaynEat ERP ที่ commit `fc489f2`
(สัญญา POS v1 **1.0.0**) โดย**ไม่แก้แม้แต่ไบต์เดียว** ต้นฉบับคือ repo ของ ERP ส่วนที่นี่เป็นสำเนาที่ POS ใช้ทดสอบและตรวจคำตอบของ
ERP (ticket 25, `docs/DECISIONS.md` #80)

| ไฟล์ที่นี่ | ต้นทางใน ERP | หมายเหตุ |
|---|---|---|
| `v1/` | `contracts/pos/v1/` | schema, OpenAPI และตัวอย่าง — ไม่เปลี่ยนตั้งแต่ 1.0.0 (PaynEat-ERP#9, `3661204`) |
| `README.md` | `contracts/README.md` | ข้อความของสัญญา รวมหัวข้อ "Transport" ที่เพิ่มใน PaynEat-ERP#61 (ticket 32, #82) |
| `CHANGELOG.md` | `contracts/CHANGELOG.md` | ประวัติของสัญญา |

ลิงก์ใน `README.md` ชี้ตามโครงสร้างของ repo ERP (`pos/v1/…`, `README.th.md`, `../docs/TELEMETRY.md`) จึงเปิดจากที่นี่ไม่ได้
ให้อ่านที่ [repo ของ ERP](https://github.com/SuruchBoss/PaynEat-ERP/tree/fc489f2/contracts) — ฉบับภาษาไทยอยู่ที่
[`README.th.md`](https://github.com/SuruchBoss/PaynEat-ERP/blob/fc489f2/contracts/README.th.md)

- `backend/src/modules/erp/erp.contract.js` โหลด JSON Schema จากที่นี่มาตรวจคำตอบของ ERP ทุกครั้งที่ POS เรียก
- `backend/tests/erp-contract.test.js` ตรวจว่าตัวอย่างในสัญญาผ่าน schema, ตัวแปลงคำตอบของ POS รับตัวอย่างได้ครบ, สัญญาเป็นเวอร์ชัน
  1.0.0 และไฟล์ตรงกับ `checksums.json` (sha256 ของไฟล์ตามที่คัดลอกมา) — ถ้ามีคนแก้ไฟล์ที่นี่ CI จะแดง

**อัปเดตสัญญา**: เมื่อสัญญาใน ERP เปลี่ยน ให้คัดลอกโฟลเดอร์ `contracts/pos/v1`, `contracts/README.md` และ `contracts/CHANGELOG.md`
จาก commit ที่ merge แล้วมาทับทั้งชุด แก้ commit ในไฟล์นี้ อัปเดต `checksums.json` และเวอร์ชันที่ปักไว้ในเทสต์ แล้วอ่าน CHANGELOG ว่ามี
อะไรที่ POS ต้องทำเพิ่ม เวอร์ชัน minor (1.x) เพิ่มได้อย่างเดียว POS รุ่นเดิมจึงยังใช้ได้ ส่วน major ใหม่ (2.0) อยู่ในโฟลเดอร์ `v2/` แยก

---

Apart from this file and `checksums.json`, these files are a byte-for-byte copy of PaynEat ERP's `contracts/` at commit
`fc489f2` (POS contract v1 **1.0.0**): `v1/` is the ERP's `contracts/pos/v1/`, and `README.md` and `CHANGELOG.md` are the
ERP's own. The links inside `README.md` follow the ERP repository's layout, so read it there. The ERP repository is the
source of truth; this copy is what the POS validates the ERP's answers against and tests with. Both projects are
Apache-2.0 by the same author.
