# Ticket: ส่ง credential ให้ PaynEat ERP ผ่าน HTTPS เท่านั้น

**Priority:** 🟠 High — ต้องเสร็จก่อนร้านจริงร้านแรกใช้โหมดเชื่อมต่อ ERP
**สถานะ (2026-09-28):** ⏳ ยังไม่เริ่ม — เริ่มได้ (กติกาอยู่ในสัญญาแล้ว: PaynEat-ERP#61)
**Ref:** `docs/DECISIONS.md` #82, #80 (ticket 25), [PaynEat-ERP#60](https://github.com/SuruchBoss/PaynEat-ERP/issues/60) (HTTPS ฝั่ง ERP),
สัญญา POS v1 1.0 (`backend/contracts/erp-pos/`)
**Blocked by:** ไม่มี — งานเล็กที่ปิดช่องทางส่ง credential โดยไม่เข้ารหัส จึงไม่ต้องรอ QA รอบ 1 (#77) แต่ต้องเสร็จก่อน ticket 26 และ 28

## ปัญหา
ticket 25 (#121) รับที่อยู่ ERP แบบ `http://` ได้ POS ส่ง machine credential ใน header `Authorization` ทุกคำขอ ถ้าต่อผ่าน HTTP
ทุกคนที่อยู่ในเครือข่ายเดียวกัน (Wi-Fi ร้าน, เครือข่ายระหว่างสาขา) อ่าน credential ได้ ERP PO เพิ่ม HTTPS สำหรับการติดตั้งจริงใน
PaynEat-ERP#60 และเสนอกติกาในสัญญาว่า "POS ส่ง credential ผ่าน HTTPS เท่านั้น ยกเว้นไปที่ loopback" ซึ่ง POS PO รับแล้ว (#82)

## ขอบเขตงาน
- **ที่อยู่ ERP ต้องเป็น `https://`** ทั้งหน้าตั้งค่า (`PUT /erp/connection`) และ `ERP_URL` ของ ticket 28
  - ยกเว้น host ที่เป็น loopback คือ `localhost`, `127.0.0.0/8` และ `[::1]` ซึ่งรับ `http://` ได้ ตัดสินจากตัวอักษรของ host
    ห้าม resolve DNS แล้วถือว่าเป็น loopback
  - ถ้าไม่ผ่าน ตอบ 400 พร้อมเหตุผลที่แปลตามภาษา เช่น "ที่อยู่ของ PaynEat ERP ต้องขึ้นต้นด้วย https:// เพื่อไม่ให้ credential ถูกส่งแบบไม่เข้ารหัส"
- **ทางเลือกสำหรับเครือข่ายปิดที่ผู้ดูแลเซิร์ฟเวอร์ตั้งเอง:** ถ้าตั้ง `ERP_ALLOW_INSECURE_HTTP=true` ใน env ของ backend จะรับ `http://` ได้
  - มีไว้สำหรับเดโมคำสั่งเดียวของ PaynEat-ERP#27 ที่ POS กับ ERP อยู่ใน network ของ Docker เดียวกัน ซึ่งไม่ใช่ loopback
  - ตั้งจากหน้าจอไม่ได้ ต้องตั้งใน env เท่านั้น
  - เมื่อใช้ http โดยอาศัยค่านี้ หน้าตั้งค่าแสดงคำเตือนสีแดงถาวร และตอนเปิดเครื่องเขียน log ระดับ `WARNING` หนึ่งบรรทัด
- **การเชื่อมต่อที่บันทึกไว้แล้วด้วย `http://`** (จากช่วงก่อน ticket นี้) ต้องหยุดส่ง credential ทันทีหลังอัปเดต
  - ไม่ลบการเชื่อมต่อ
  - หน้าตั้งค่าบอกให้เปลี่ยนเป็น https
  - การดึงข้อมูลบันทึกเป็น `master_data.pull.failed` ระดับ `ERROR` (หยุดจนกว่าจะมีคนจัดการ) โดย `reason` เป็น `unexpected_response`
    เพราะแคตตาล็อก v1.2 ไม่มีค่าเฉพาะสำหรับกรณีนี้ ถ้า ERP PO เพิ่มค่าใหม่ให้ ค่อยเปลี่ยนตาม
- **HTTPS ต้องตรวจใบรับรองเสมอ** ห้ามมีค่าตั้งค่าที่ปิดการตรวจ (เช่น `NODE_TLS_REJECT_UNAUTHORIZED=0`)
  ถ้าเชนใช้ CA ภายในของตัวเอง ให้ใช้ `NODE_EXTRA_CA_CERTS` ชี้ไปที่ไฟล์ CA ของเชน
- **สำเนาสัญญาใน `backend/contracts/erp-pos/`**: ERP เพิ่มหัวข้อ "Transport" ใน `contracts/README.md` แล้ว
  (PaynEat-ERP#61, EN และ TH) เนื้อหาตรงกับ #82 รวมข้อยกเว้น `ERP_ALLOW_INSECURE_HTTP` และสัญญายังเป็น 1.0.0 ให้คัดลอก
  ไฟล์ที่เปลี่ยน (`README.md` และ `CHANGELOG.md` ถ้ามีการแก้) จาก `main` ของ ERP มาทั้งไฟล์โดยไม่แก้ และอัปเดต `checksums.json` สำหรับไฟล์ที่อยู่ในรายการ (ตอนนี้ `README.md` ไม่อยู่ในรายการ แต่ `CHANGELOG.md` อยู่) เพราะสำเนาต้องตรงกับต้นทางทุกไบต์ (#80)
- **เอกสาร:**
  - `backend/.env.example`: เพิ่ม `ERP_ALLOW_INSECURE_HTTP` และ `NODE_EXTRA_CA_CERTS` พร้อมคำอธิบาย
  - คู่มือติดตั้ง (`install*.html` ทั้ง 3 ภาษา): ถ้า ERP ของเชนใช้ใบรับรองจาก CA ภายใน เครื่อง POS ต้องเชื่อ CA นั้นผ่าน
    `NODE_EXTRA_CA_CERTS` และบอกวิธีตรวจว่าต่อได้
  - `SECURITY.md`: ข้อกำหนดก่อนใช้งานจริง ให้ใช้ HTTPS กับ ERP และห้ามตั้ง `ERP_ALLOW_INSECURE_HTTP` นอกเครือข่ายปิด
  - README ไทย/อังกฤษ และ `docs/DECISIONS.md` #82 (อัปเดตถ้าพฤติกรรมต่างจากที่เขียนไว้)

## Acceptance Criteria
- [ ] `http://erp.example.com` → 400 พร้อมเหตุผล; `http://localhost:3000`, `http://127.0.0.1:3000`, `http://[::1]:3000` → รับได้
- [ ] `http://127.example.com` หรือชื่อที่ resolve เป็น 127.0.0.1 → ไม่นับเป็น loopback
- [ ] `ERP_ALLOW_INSECURE_HTTP=true` → รับ `http://erp:3000` ได้ หน้าตั้งค่าแสดงคำเตือน และมี log `WARNING` ตอนเปิดเครื่อง
- [ ] การเชื่อมต่อ http เดิมหลังอัปเดต → ไม่มีคำขอไป ERP เลย หน้าตั้งค่าบอกให้เปลี่ยน และมี log ตามที่ระบุ
- [ ] https ที่ใบรับรองไม่ผ่าน → ปฏิเสธ พร้อมเหตุผลว่าใบรับรองไม่น่าเชื่อถือ; https ที่ใช้ CA ภายในผ่าน `NODE_EXTRA_CA_CERTS` → ต่อได้
- [ ] เทสต์เดิมที่ใช้ ERP ปลอมบน `http://127.0.0.1` ยังผ่านโดยไม่ต้องตั้งค่าเพิ่ม
- [ ] README ไทย/อังกฤษ, `docs/DECISIONS.md`, `docs/FEATURE-GAP-ANALYSIS.md`, `SECURITY.md` และคู่มือติดตั้งอัปเดตตาม `CLAUDE.md`

## เทสต์
- backend: ตารางของที่อยู่ที่รับหรือปฏิเสธ, ค่า env, การเชื่อมต่อ http เดิมหลัง migration
- ERP ปลอมแบบ HTTPS ที่ใช้ใบรับรองจาก CA ทดสอบ ทั้งกรณีเชื่อ CA และไม่เชื่อ
- แอป: คำเตือนบนหน้าตั้งค่าเมื่อใช้ http ด้วย `ERP_ALLOW_INSECURE_HTTP`
