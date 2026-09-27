# สัญญาเชื่อมต่อ PaynEat ERP ↔ POS — สำเนาที่ปักเวอร์ชัน 1.0.0

ไฟล์ในโฟลเดอร์นี้คัดลอกมาจาก [`contracts/`](https://github.com/SuruchBoss/PaynEat-ERP/tree/3661204/contracts) ของ
PaynEat ERP ที่ commit `3661204` (สัญญา POS v1 **1.0.0**, PaynEat-ERP#9) โดย**ไม่แก้แม้แต่ไบต์เดียว**
ต้นฉบับคือ repo ของ ERP ส่วนที่นี่เป็นสำเนาที่ POS ใช้ทดสอบและตรวจคำตอบของ ERP (ticket 25, `docs/DECISIONS.md` #80)

- `backend/src/modules/erp/erp.contract.js` โหลด JSON Schema จากที่นี่มาตรวจคำตอบของ ERP ทุกครั้งที่ POS เรียก
- `backend/tests/erp-contract.test.js` ตรวจว่าตัวอย่างในสัญญาผ่าน schema, ตัวแปลงคำตอบของ POS รับตัวอย่างได้ครบ, สัญญาเป็นเวอร์ชัน
  1.0.0 และไฟล์ตรงกับ `checksums.json` (sha256 ของไฟล์ตามที่คัดลอกมา) — ถ้ามีคนแก้ไฟล์ที่นี่ CI จะแดง

**อัปเดตสัญญา**: เมื่อ ERP ออกเวอร์ชันใหม่ ให้คัดลอกโฟลเดอร์ `contracts/pos/v1` และ `contracts/CHANGELOG.md` จาก commit
ที่ merge แล้วมาทับทั้งชุด แก้ commit ในย่อหน้าแรก อัปเดต `checksums.json` และเวอร์ชันที่ปักไว้ในเทสต์ แล้วอ่าน CHANGELOG ว่ามีอะไรที่
POS ต้องทำเพิ่ม เวอร์ชัน minor (1.x) เพิ่มได้อย่างเดียว POS รุ่นเดิมจึงยังใช้ได้ ส่วน major ใหม่ (2.0) อยู่ในโฟลเดอร์ `v2/` แยก

---

These files are a byte-for-byte copy of PaynEat ERP's `contracts/` at commit `3661204` (POS contract v1 **1.0.0**). The
ERP repository is the source of truth; this copy is what the POS validates the ERP's answers against and tests with.
Both projects are Apache-2.0 by the same author.
