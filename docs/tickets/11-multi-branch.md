# Ticket: Multi-branch / Multi-store Support

**Priority:** 🟡 Medium
**สถานะ (2026-09-27):** ✅ เสร็จแล้ว — merge เข้า `main` ครบทั้ง backend และหน้าเลือกสาขาใน Flutter (`docs/DECISIONS.md` #36)
— QA รอบ ก.ย. 2026 (#79) พบการแยกสาขายังไม่ครบ แก้ใน T21 [#109](https://github.com/SuruchBoss/PaynEat/issues/109), T22 [#86](https://github.com/SuruchBoss/PaynEat/issues/86), T32 [#117](https://github.com/SuruchBoss/PaynEat/issues/117)

**Status เดิม (บันทึกไว้เป็นประวัติ):** 🚧 **กำลังทำอยู่ (บน branch อื่น)** — พบว่าอีก session เริ่มงานนี้จริงแล้วบน branch
`claude/pos-restaurant-project-3djpp6` (commit `68568c1`, ยังไม่ merge เข้า `main` ณ ตอนที่เขียน
บันทึกนี้) ขณะที่เซสชันนี้เพิ่งยืนยันไปเมื่อ 2026-09-19 ว่า "ยัง out-of-scope ไม่มี drift" (ดู
`docs/DECISIONS.md` #35/#36) — เป็นอีกตัวอย่างของ concurrent session ทำงานซ้อนกัน ของจริงที่ทำไปแล้ว:
เพิ่ม `branch_id` scoping ให้ tables/menu/ingredients/orders/reports ฝั่ง backend ครบ + RBAC + 16
เทสต์ใหม่ (`backend/tests/branches.test.js`) — **backend เท่านั้น ยังไม่มี branch-management UI /
เลือกสาขาตอน login ฝั่ง Flutter** (ตาม commit message ของ branch นั้นเอง) ดังนั้น Acceptance Criteria
ด้านล่างนี้ยังไม่ครบทั้งหมด — เมื่อ branch นั้น merge เข้า main แล้วควรอัปเดตบันทึกนี้ให้ตรงกับสถานะ
จริงอีกครั้ง (backend เสร็จบางส่วน / frontend ยังไม่เริ่ม)
**Ref:** `docs/FEATURE-GAP-ANALYSIS.md` #11

## ปัญหา
ระบบตั้งใจ scope ไว้แค่สาขาเดียวตั้งแต่ต้น (`docs/DECISIONS.md`) — ใช้ SQLite ไฟล์เดียว,
`settings` เป็น key-value เดียวไม่ผูกกับสาขา, ไม่มี table `branches`/`stores`

## ทำไมสำคัญ
ถ้าลูกค้าเป้าหมายของ PaynEat มีแผนขยายสาขา ระบบปัจจุบันรองรับไม่ได้เลย ต้องวางแผน
migration ทั้ง database (SQLite → PostgreSQL ตามที่ `docs/DECISIONS.md` เตรียม repository
layer ไว้รองรับ) และ data model (เพิ่มมิติ branch เข้าไปแทบทุก entity)

## ขอบเขตงาน (คร่าวๆ) — งานใหญ่ ควรแตกเป็นหลาย ticket ย่อยเมื่อจะเริ่มทำจริง
- ตัดสินใจ database migration path: SQLite → PostgreSQL (repository layer แยกไว้แล้วตาม
  design decision เดิม ควรกระทบ service/controller น้อย)
- Schema: เพิ่ม table `branches`, เพิ่ม `branch_id` FK ในแทบทุก entity (menu_items,
  dining_tables, orders, users-to-branch mapping, settings ต่อสาขา)
- Backend: ทุก query ต้อง scope ด้วย branch_id, auth/JWT ต้องพก branch context
- Frontend: เลือกสาขาตอน login (ถ้า user มีสิทธิ์หลายสาขา), แยกข้อมูล/รายงานตามสาขา,
  รายงานภาพรวมข้ามสาขาสำหรับ owner/admin ระดับองค์กร

## Acceptance Criteria
- [x] มี table branches และทุก entity หลักผูกกับ branch_id — ทำแล้ว: `branches` +
  `user_branches` (many-to-many) ใหม่, `branch_id` ผูกกับ 4 entity ที่เป็นข้อมูลระดับสาขาจริง
  (`dining_tables`/`menu_items`/`orders`/`ingredients`) — ตั้งใจไม่ผูก entity ระดับเชน/องค์กร
  (โปรโมชัน/ลูกค้า/หมวดหมู่/ตัวเลือกเสริม/ตั้งค่า/กะ/การชำระเงิน/คืนเงิน/ใบกำกับภาษี/audit log) ดู
  เหตุผลเต็มใน `docs/DECISIONS.md` #36
- [x] User ที่มีสิทธิ์หลายสาขาเลือกสาขาที่จะทำงานได้ตอน login — ทำแล้ว: login คืน `pendingToken`
  + รายชื่อสาขาถ้ามีสิทธิ์ ≥2 สาขา (ไม่ใช่ admin) หน้าเลือกสาขาใหม่ (`BranchSelectionPage`) ให้เลือก
  ก่อนเข้าใช้งาน — admin auto-select สาขาแรกเสมอเพื่อความเข้ากันได้ย้อนหลัง (เหตุผลดู DECISIONS #36)
- [x] ข้อมูล/รายงานแยกตามสาขาไม่ปนกัน — ทำแล้ว: โต๊ะ/เมนู/ออเดอร์/วัตถุดิบ + รายงานทุกตัว (ยอดขาย/
  เมนูขายดี/ยอดขายรายวัน-รายชั่วโมง/ตามหมวดหมู่/ตัวนับสด) กรองด้วย `branch_id` ของ token ปัจจุบัน
- [x] Owner/admin ระดับองค์กรดูรายงานสรุปรวมทุกสาขาได้ — ทำแล้ว: admin สลับเป็นโหมด "ทุกสาขา"
  (`branchId: null`) ผ่าน `POST /auth/select-branch` ได้ภายหลัง (หน้าโปรไฟล์ในแอปมีปุ่ม "สลับสาขา")
  ทุก query ที่ `branchId` เป็น `null` จะไม่ filter เลย = เห็นข้อมูลรวมทุกสาขาทันที

## สิ่งที่ตั้งใจเลื่อนไว้ก่อน (ดูรายละเอียดเหตุผลเต็มใน `docs/DECISIONS.md` #36)
- ไม่ migrate SQLite → PostgreSQL (repository layer แยกไว้แล้วรองรับได้ถ้าต้องขยายจริง)
- ไม่ทำ cross-branch guard เต็มรูปแบบสำหรับ update/delete/get-by-id (scope แค่ list/create)
- ชื่อโต๊ะยังต้องไม่ซ้ำกันทั้งเชน ไม่ใช่แค่ในสาขาเดียวกัน (ต้องแก้ schema constraint เพิ่ม)
- เลขที่ออเดอร์/เลขคิว takeaway ยังรันต่อเนื่องรวมทุกสาขา ไม่แยกตัวนับต่อสาขา
- ยังไม่มีหน้าจอ "จัดการสาขา" (สร้าง/แก้ไข/มอบสิทธิ์พนักงาน) ใน Flutter — backend มี endpoint ครบ
  (`GET/POST /branches`, `PATCH /branches/:id`) แต่ acceptance criteria ไม่ได้บังคับ
- โหมดสาธิต (Demo Mode) ในแอปยังมีสาขาเดียวเสมอโดยตั้งใจ ไม่ได้ทำ `branch_id` ให้ demo store ทุก
  โดเมน (เมนู/โต๊ะ/วัตถุดิบ/ออเดอร์/รายงาน) เพราะผู้ใช้เดโมสาธารณะสร้าง user คนที่ 2 ที่มีหลายสาขา
  เองไม่ได้อยู่แล้ว

## ไฟล์ที่เกี่ยวข้อง
- Backend: `backend/src/modules/branches/`, `backend/src/middlewares/auth.js`,
  `backend/src/core/branchScope.js`, `backend/src/db/schema.sql`, `backend/src/db/migrate.js`,
  `backend/src/db/seed.js`, `backend/tests/branches.test.js`
- Flutter: `app/lib/features/auth/` (entities/repositories/usecases/controllers/pages ที่เกี่ยวกับ
  branch), `app/lib/features/auth/presentation/pages/branch_selection_page.dart`,
  `app/lib/features/auth/presentation/pages/profile_page.dart` (การ์ดสลับสาขา)
