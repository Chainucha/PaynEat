# Ticket: Export รายงาน (CSV) + Z-report ปิดกะ

**Priority:** 🟠 High (ยกระดับจาก 🟡 Medium เดิม — ดู `docs/DECISIONS.md` #35)
**Ref:** `docs/FEATURE-GAP-ANALYSIS.md` #12, `docs/DECISIONS.md` #35
**สถานะ:** ✅ เสร็จแล้ว — implement ที่ commit `4e2684d` และ merge เข้า `main` แล้ว
— QA รอบ ก.ย. 2026 (#79) พบกฎที่ยังไม่ป้องกัน แก้ใน T12 [#106](https://github.com/SuruchBoss/PaynEat/issues/106), T16 [#107](https://github.com/SuruchBoss/PaynEat/issues/107), T25 [#89](https://github.com/SuruchBoss/PaynEat/issues/89)

> **ที่มาของเอกสารสองชั้นในไฟล์นี้** — ticket นี้ถูกทำจริงและเขียนสเปกขึ้นมาใหม่ *พร้อมกัน* โดยคนละ
> session ที่ไม่เห็นงานของกันและกัน (session หนึ่งทำโค้ดบน branch
> `claude/pos-restaurant-project-3djpp6` อีก session หนึ่งเขียน `/to-spec` เพราะเข้าใจว่ายังไม่มีใครทำ)
> ตอน merge จึงเก็บไว้ทั้งคู่แทนที่จะทิ้งอันใดอันหนึ่ง: **หัวข้อถัดจากนี้คือบันทึกของจริงว่าได้อะไรมา**
> ส่วน **ภาคผนวกท้ายไฟล์คือสเปกที่เขียนไว้** ซึ่งตรงกับของจริงเกือบทั้งหมด (โดยเฉพาะข้อที่ว่า Z-report
> ต้อง scope ด้วย `payments.shift_id` ไม่ใช่วันที่ปฏิทิน) มีประโยชน์ตรงที่บันทึก user stories และ
> เหตุผลเชิงออกแบบไว้ครบ — แต่ **ไม่ใช่งานที่ค้างให้ทำอีกแล้ว**

## ขอบเขตงาน (ที่ทำจริง)
- **Backend — export รายงานเป็น CSV**: `GET /reports/export/summary`, `/export/top-items`,
  `/export/sales-by-day` ทั้งสามตัว reuse query schema เดิมของรายงานนั้นๆ (`rangeQuerySchema`/
  `topItemQuerySchema`) เพราะตัวเลขในไฟล์ต้องตรงกับที่เห็นในแอปเป๊ะ ต่างกันแค่ format ที่ตอบกลับ
  ประกอบไฟล์ด้วย `backend/src/core/csv.js#toCsv` ตัวเดียวกับที่ audit log export (ticket 14) ใช้
- **Backend — Z-report**: `GET /reports/z-report/by-shift/:shiftId` และ `/z-report/by-date`
  พร้อม endpoint `/export` ของทั้งสองแบบ แยกกันชัดเจนไม่ใช่ endpoint เดียว — ต่อกะมีกระทบยอด
  เงินสด (เงินตั้งต้น/ที่คาดไว้/ที่นับได้จริง/ส่วนต่าง) ต่อวันรวมทุกกะและ**ไม่มี**กระทบยอดเงินสด
  เพราะวันเดียวอาจมีหลายกะ/หลายแคชเชียร์ปนกัน กระทบยอดระดับวันจึงไม่มีความหมาย
- **Backend — query ต่อกะคิดจาก `payments.shift_id` ไม่ใช่วันที่เปิดออเดอร์**: ออเดอร์เปิดค้าง
  ข้ามกะได้ (เปิดกะเช้า จ่ายจริงกะบ่าย) และกะดึกก็ข้ามเที่ยงคืน การ join ผ่าน `shift_id` ของแถว
  การชำระเงินจึงถูกต้องกว่าเทียบวันที่ — และรองรับ split-bill ถูกต้องด้วยเพราะนับจาก payment
  รายแถว ไม่ใช่ order ทั้งก้อน (คอลัมน์นี้มีมาตั้งแต่ ticket 01 ไม่ต้อง migrate เพิ่ม)
- **Frontend**: หน้ารายงานมีปุ่ม export ปุ่มเดียวเป็น `PopupMenuButton<ReportExportKind>`
  ให้เลือกสามรายงาน (สรุปยอดขาย/เมนูขายดี/ยอดขายรายวัน) แล้วเรียก `controller.exportCsv` ตัวเดียว
  ส่วน `z_report_dialog.dart` เปิดได้สองทาง: การ์ดสรุปกะที่เพิ่งปิด และรายการประวัติกะ — ทั้งคู่
  เปิดได้เฉพาะกะที่ปิดแล้ว (`onTap: isOpen ? null : ...`) เพราะยอดกระทบเงินสดยังเป็น `null`
  ตอนกะยังเปิด การโชว์ ฿0.00 จะดูเหมือนกะสมดุลแล้วทั้งที่ยังไม่ได้กระทบจริง
- **Demo Mode**: `demo_store_reports.dart` ประกอบ CSV ฝั่ง Dart ล้วน (`exportSummaryCsv`/
  `exportTopItemsCsv`/`exportSalesByDayCsv` และ `exportZReportCsv` พร้อม wrapper
  `exportZReportByShiftCsv`/`exportZReportByDateCsv`) ให้ทุกแถวตรงกับ `report.service.js`
  แล้วเรียก `toCsv()` ตัวเดียวกับ audit log — คนลองเดโมสาธารณะที่ไม่มี backend ยัง export ได้

## ขอบเขตที่ตั้งใจไม่ทำในทิกเก็ตนี้
- **Excel (`.xlsx`) และ PDF** — ทิกเก็ตยอมรับ "CSV/Excel อย่างน้อย 1 format" กับ "PDF หรือ
  เทียบเท่า" เลือก CSV เพราะ infra มีครบอยู่แล้วทั้งสองฝั่ง เปิดกับ Excel ได้ตรง (มี UTF-8 BOM
  กันอักษรไทยเพี้ยน) ไม่ต้องเพิ่ม dependency ใหม่ (`xlsx`/`pdfkit`) ดู `docs/DECISIONS.md` #35
- **พรีวิว Z-report ระหว่างกะที่ยังไม่ปิด** — ตัดสินใจตั้งใจ ไม่ใช่ของค้าง ถ้าอนาคตอยากได้ยอดขายสด
  ระหว่างกะโดยไม่กระทบเงินสด ให้แยก endpoint/UI ใหม่ อย่า reuse component Z-report เดิม
- **ดาวน์โหลดไฟล์บนแพลตฟอร์มที่ไม่ใช่เว็บ** — `csv_download_stub.dart` คืน
  `isCsvDownloadSupported = false` และ throw `UnsupportedError` เหมือน audit log export เดิม
  (ปุ่มซ่อนเองบนมือถือ/เดสก์ท็อป) เป็นฟีเจอร์ฝั่งเว็บผู้ดูแลระบบ

## Acceptance Criteria
- [x] Export รายงานยอดขาย (ตามช่วงวันที่ที่เลือก) เป็นไฟล์ CSV/Excel ได้ — ทำแล้ว: CSV ทั้งสาม
  รายงาน (สรุปยอดขาย/เมนูขายดี/ยอดขายรายวัน) เลือกจากเมนู export ที่หน้ารายงาน มี UTF-8 BOM
  เปิดกับ Excel ได้ตรง
- [x] มี Z-report สรุปยอดขาย/ภาษี/ส่วนลด/แยกตามช่องทางชำระเงินต่อวัน/ต่อกะ — ทำแล้ว: ต่อกะมีกระทบยอด
  เงินสดด้วย (คิดจาก `payments.shift_id`), ต่อวันรวมทุกกะ (ไม่มีกระทบยอดเงินสด)
- [x] Export/ดาวน์โหลด Z-report เป็นไฟล์ (PDF หรือเทียบเท่า) ได้ — ทำแล้ว: CSV (เทียบเท่าตามที่ระบุไว้
  — ดู `docs/DECISIONS.md` #35 สำหรับเหตุผลไม่ทำ Excel/PDF)
- [x] RBAC: admin/manager/cashier export ได้ (แคชเชียร์ต้องใช้ตอนปิดกะ) พนักงานเสิร์ฟ export ไม่ได้
  — บังคับที่ router ระดับ `authorize('admin', 'manager', 'cashier')` และมีเทสต์ยืนยัน 403
- [x] Demo Mode export ได้ครบทุกปุ่มโดยไม่ต้องมี backend จริง

## เทสต์
- `backend/tests/report-export.test.js` — 8 เคส ยิง HTTP จริงผ่าน supertest: CSV ทั้งสามรายงาน
  (เช็ค BOM + เนื้อแถว), Z-report ต่อกะ (สรุป+กระทบเงินสด), 404 เมื่อไม่พบกะ, Z-report ต่อวัน
  (ต้องเท่ากับ summary ของวันนั้น + ฟิลด์ `type`/`date`), export Z-report รายวัน, และ RBAC 403
- `app/test/presentation/report_controller_test.dart`,
  `app/test/presentation/shift_controller_test.dart` — ระดับ controller
- **ไม่ครอบคลุม** `exportCsv()`/`exportZReportCsv()` เส้นทางสำเร็จ เพราะเรียก `AppDialogs`/
  `downloadCsv` ตรงๆ ต้อง pump `GetMaterialApp` จริง — ตรงกับ `docs/CODING_STANDARDS.md` ข้อ 6.2
  และรูปแบบเดิมของ `audit_log_controller_test.dart`

## ไฟล์ที่เกี่ยวข้อง
- `backend/src/modules/reports/` (`report.routes.js`/`.controller.js`/`.service.js`/`.repository.js`)
- `backend/src/core/csv.js`, `backend/tests/report-export.test.js`, `backend/docs/openapi.yaml`
- `app/lib/features/report/` (domain/data/presentation — `reports_page.dart`,
  `report_controller.dart`, `report_usecases.dart`, `report_remote_data_source.dart`)
- `app/lib/features/shift/presentation/widgets/z_report_dialog.dart`,
  `app/lib/features/shift/presentation/{pages/shift_page.dart,controllers/shift_controller.dart}`
- `app/lib/core/utils/csv.dart`, `app/lib/core/utils/csv_download/` (web/stub)
- `app/lib/core/demo/demo_store_reports.dart`, `demo_report_data_source.dart` (Demo Mode mirror)
- เกี่ยวโยงกับ `01-shift-cash-reconciliation.md` (Z-report ต่อกะใช้ `payments.shift_id` จากทิกเก็ตนั้น)
  และ `14-financial-audit-trail.md` (reuse infra CSV export เดียวกัน)

---

# ภาคผนวก — สเปกฉบับ `/to-spec` (เขียนขนานกัน ไม่ใช่งานค้าง)

> เก็บไว้เป็น reference สำหรับ user stories และเหตุผลเชิงออกแบบ สถานะจริงของงานดูหัวข้อด้านบน
> เอกสารส่วนนี้เขียนด้วย spec template ของสกิล `/to-spec` (หัวข้อภาษาอังกฤษตามสกิล เนื้อหาภาษาไทย
> ตามธรรมเนียมโปรเจกต์) แทนการ publish เข้า issue tracker ภายนอก เพราะโปรเจกต์นี้ยังไม่ได้ตั้งค่า
> issue tracker/triage label vocabulary ของสกิล — ธรรมเนียมที่ใช้จริงในโปรเจกต์นี้ตลอดมาคือไฟล์
> ticket ใน `docs/tickets/` + index ที่ `docs/tickets/README.md`

## Problem Statement

เจ้าของร้าน/ผู้จัดการต้องส่งยอดขายให้นักบัญชี/สำนักงานบัญชีภายนอกเป็นประจำทุกเดือน และต้องปิดยอด
เงินสดเทียบกับยอดขายทุกกะ/ทุกวัน แต่ตอนนี้ระบบ (`reports` module + `shifts` module) ให้ดูข้อมูลได้
แค่ในแอปเท่านั้น — ไม่มีทาง export เป็นไฟล์เลยแม้แต่ทางเดียว (ยืนยันจากการอ่านโค้ดจริงซ้ำ 2026-09-19:
`report.controller.js` ทุก handler คืน JSON เฉยๆ ไม่มี route `/export`, ฝั่ง Flutter
`reports_page.dart` ไม่มี widget export/download เลย) ผลคือเจ้าของร้าน/นักบัญชีต้องเปิดแอปแล้ว
retype ตัวเลขเองด้วยมือทุกเดือน เสี่ยง transcription error และไม่มีทางตรวจสอบย้อนหลังได้ว่าตัวเลขที่
ส่งออกไปจริงตรงกับที่ระบบมีหรือไม่ — งานเดียวกันฝั่งบัญชี/ทุจริต (audit log) มี CSV export ให้แล้ว
(ticket 14) แต่ไม่เคยขยายมาถึงรายงานยอดขายหรือ Z-report เลย

## Solution

เพิ่มความสามารถ export ให้สองจุดที่เป็นแรงเสียดทานจริงที่สุด โดย reuse infrastructure ที่มีอยู่แล้ว
ทั้งหมด (ไม่สร้างกลไกใหม่ซ้ำซ้อน):

1. **Export รายงานยอดขาย/เมนูขายดี/ยอดขายรายวันเป็น CSV** — เพิ่ม endpoint export ให้ `reports`
   module ตาม pattern เดียวกับ `audit-logs/export` ที่มีอยู่แล้ว (ใช้ `core/csv.js#toCsv` helper
   ตัวเดิม) พร้อมปุ่ม export ในหน้ารายงานฝั่ง Flutter (reuse กลไก `csv_download` เดิมจากหน้า audit log)
2. **Z-report ปิดกะ** — เอกสารสรุปยอดขาย+เงินสด+ภาษี+ส่วนลด+ช่องทางชำระเงิน "ของกะนั้นโดยเฉพาะ" (ไม่ใช่
   แค่ตามวันที่ปฏิทิน — ดูเหตุผลใน Implementation Decisions) ผูกกับ endpoint ปิดกะที่มีอยู่แล้ว
   export เป็น CSV ได้จากหน้าปิดกะ

PDF อยู่นอกขอบเขตของรอบนี้ (ดู Out of Scope) — CSV เปิดได้ด้วย Excel อยู่แล้วและเป็นรูปแบบที่นักบัญชี
ไทยส่วนใหญ่รับได้ตรงๆ โดยไม่ต้องเพิ่ม dependency ใหม่

## User Stories

1. As an admin/manager, I want to export the sales summary report (by date range) as a CSV file, so that I can hand it to my accountant without retyping numbers by hand every month.
2. As an admin/manager, I want the exported CSV's totals (net sales, VAT, service charge, discounts, refunds) to exactly match the same `reportService.summary()` numbers already shown on screen, so that I can trust the file without re-checking it against the app.
3. As an admin/manager, I want to export the "sales by day" report as CSV for a selected date range, so that I can analyze daily trends in a spreadsheet.
4. As an admin/manager, I want to export the "top selling items" report as CSV, so that I can share menu performance data with a chef, supplier, or accountant outside the app.
5. As a cashier or manager closing a shift, I want to download a Z-report for that specific shift summarizing opening cash, expected cash, counted cash, and the variance, so that I have a standard end-of-shift reconciliation document instead of only an in-app screen.
6. As a cashier or manager closing a shift, I want the Z-report to also break sales down by payment method (cash/qr/card/transfer) and show subtotal/discount/service charge/VAT/net sales for that shift, so that the document is a complete end-of-shift summary, not just a cash count.
7. As a store owner reviewing a Z-report, I want a shift that runs past midnight to still report the correct sales figures for that shift only, so that a late-night shift's numbers aren't split incorrectly across two calendar days or mixed with the next shift's numbers.
8. As an admin, I want every report/Z-report export to be recorded in the existing audit log (same convention as other financial-impacting actions), so that I can verify who exported what data and when if a discrepancy is ever raised.
9. As a cashier (not admin/manager), I want to still be able to export the Z-report for the shift I personally closed, so that I have my own paper trail — while a waiter/kitchen role must not be able to reach either export endpoint at all, matching the existing view-permission boundary on `/reports/*`.
10. As an admin/manager, I want report exports (not the Z-report) restricted to admin/manager only, excluding cashier, so that raw multi-day sales data leaving the system as a file is treated as a more sensitive action than the read-only in-app dashboard cashiers already see.
11. As a non-technical restaurant owner, I want the exported CSV to open correctly in Excel with readable Thai text (not garbled/mojibake characters), so that I don't need any special software or settings to read it.
12. As a mobile-app user (not on the web build), I want a clear message if CSV export/download isn't supported on my platform, so that I'm not left confused by a button that silently does nothing — matching the existing audit-log export's web-only precedent and its `audit_log_export_unsupported_platform` message pattern.
13. As a developer maintaining this feature, I want the CSV serialization to reuse the existing `core/csv.js#toCsv` helper (columns + BOM + escaping already solved there), so formatting stays consistent with the audit-log export and isn't reimplemented.
14. As a PO, I want the Z-report to only be exportable for a shift that has actually been closed (status `closed`), so that nobody exports "final" numbers for a shift that's still open and could still change.
15. As an admin/manager, I want an empty date range or a range with zero orders to still export a valid CSV with a header row and zero data rows (not an error), so that "no sales this period" is a normal, unsurprising result rather than a broken export.
16. As a QA/dev reading the tests for this feature, I want the export endpoints tested the same way every other backend endpoint in this repo is tested (real HTTP request via `supertest` against an isolated test database), so the test suite stays consistent and I can find prior art easily.

## Implementation Decisions

**Backend — sales/menu report export**
- เพิ่ม `GET /reports/export` ใน `reports` module — query params: `report` (enum:
  `summary` | `top-items` | `sales-by-day`, required), `from`/`to` (วันที่, reuse
  `rangeQuerySchema`/`topItemQuerySchema` เดิมจาก `report.routes.js`), `limit` (เฉพาะ `top-items`)
- Role: `authorize('admin', 'manager')` — **แคบกว่า** endpoint view เดิม (`admin`/`manager`/`cashier`)
  โดยตั้งใจ เพราะการดึงข้อมูลออกจากระบบเป็นไฟล์ถือเป็น action ที่ sensitivity สูงกว่าการดูในแอปอย่างเดียว
  (ตรงกับหลักการเดียวกับที่ `refund`/`tax-invoice void` เป็น manager+ ทั้งที่ view เป็น role กว้างกว่า)
- Controller เรียก `reportService.summary()`/`topItems()`/`salesByDay()` ตัวเดิมทุกประการ (ไม่มี logic
  คำนวณใหม่) แล้วแปลงผลลัพธ์เป็น CSV ด้วย `core/csv.js#toCsv(rows, columns)` — คอลัมน์กำหนดต่อ
  report type หนึ่งชุด (เช่น `summary` เป็น 1 แถวสรุป, `sales-by-day`/`top-items` เป็นหลายแถวตาม array
  ที่ service คืนอยู่แล้ว) ส่ง response header แบบเดียวกับ `audit-logs/export`
  (`Content-Type: text/csv; charset=utf-8`, `Content-Disposition: attachment; filename=...`)
- Log audit event ใหม่ `report.export` (`entityType: 'report'`) เมื่อ export สำเร็จ — เก็บ `metadata`
  เป็น `{ report, from, to }` ตาม pattern เดียวกับ audit log อื่นๆ ในระบบ (บันทึกใน service เดียวกับ
  ที่จัดการ query ไม่ใช่ใน controller)

**Backend — Z-report ปิดกะ**
- เพิ่ม `GET /shifts/:id/z-report` (format CSV) ใน `shifts` module — role เดียวกับ shift อื่นๆ
  (`admin`/`manager`/`cashier` — cashier export ได้เฉพาะกะที่ตัวเองเกี่ยวข้อง ไม่ต้องจำกัดเพิ่มเติม
  เพราะระบบ role ปัจจุบันไม่ได้แยกสิทธิ์ cashier ต่อ shift เป็นรายบุคคลอยู่แล้ว — จุดนี้เป็นขอบเขตเดิม
  ของระบบ ไม่ใช่สิ่งที่ ticket นี้ต้องแก้)
- **จุดตัดสินใจสำคัญ**: Z-report ต้อง scope ข้อมูลตาม `shift_id` โดยตรง ไม่ใช่ตามช่วงวันที่ปฏิทิน —
  `payments` table มี `shift_id` FK อยู่แล้ว (`backend/src/db/schema.sql`) แต่ `report.repository.js`
  ปัจจุบันมีแต่ query แบบ `start`/`end` เป็นวันที่ (ไม่มี query แบบ scope ด้วย `shift_id`) ต้องเพิ่ม
  query ใหม่ในชั้น repository ที่ join จาก `payments.shift_id` (หรือ orders ที่ผูกกับ payments ของกะ
  นั้น) แทนการ reuse `reportService.summary()` ตรงๆ — เหตุผล: กะที่เปิดข้ามเที่ยงคืน (เช่น กะกลางคืน
  เปิด 22:00 ปิด 03:00 วันถัดไป) ถ้าคำนวณจากวันที่ปฏิทินของ `shift.opened_at` เพียงอย่างเดียวจะตัด
  ยอดขายหลังเที่ยงคืนออกไปผิด ต้อง query ด้วย `shift_id` ตรงๆ ถึงจะถูกเสมอไม่ว่ากะจะข้ามวันหรือไม่
- ปฏิเสธ (400/409) ถ้า shift ที่ระบุยังไม่ถูกปิด (`status !== 'closed'`) — ป้องกัน export ตัวเลขที่ยัง
  ไม่ final
- เนื้อหา Z-report: shift id, เวลาเปิด/ปิดกะ (`AppClock`, ไม่ใช้ `DateTime.now()` ตรงตาม
  `docs/CODING_STANDARDS.md` custom lint rule ที่มีอยู่แล้ว), เงินสดตั้งต้น/คาดไว้/นับได้/ส่วนต่าง
  (ค่าที่ persist ไว้แล้วจาก `shiftRepository.close()`), หมายเหตุปิดกะ, ยอดขายของกะนั้น (orderCount,
  guestCount, subtotal, discount, serviceCharge, vat, refundTotal, netSales) แยกตามช่องทางชำระเงิน
- Log audit event `shift.z_report_export` (`entityType: 'shift'`, `entityId: shift.id`) ตอน export
  สำเร็จ ตาม pattern เดียวกับ `report.export`

**Frontend (Flutter)**
- หน้ารายงาน (`reports_page.dart`) เพิ่มปุ่ม export ต่อ report type (summary/top-items/sales-by-day)
  reuse `core/utils/csv_download/csv_download.dart` ตัวเดิมที่ใช้อยู่แล้วในหน้า audit log (เว็บเท่านั้น
  — แสดง error message เดียวกับที่หน้า audit log ใช้ตอนไม่รองรับแพลตฟอร์ม)
  เพิ่ม use case ใหม่ใน `report` feature (Clean Architecture layer เดิม: data source → repository →
  use case → controller) ตาม pattern ที่ `ExportAuditLogsUseCase` วางไว้แล้ว
- หน้าปิดกะ (shift feature) เพิ่มปุ่ม "ดาวน์โหลด Z-report" หลังปิดกะสำเร็จ เรียก endpoint ใหม่ผ่าน use
  case ใหม่ในลักษณะเดียวกัน

**Out of Scope**
- Export เป็น Excel (.xlsx) หรือ PDF จริง — CSV พอสำหรับรอบนี้ (เปิดได้ด้วย Excel อยู่แล้ว), PDF ต้องมี
  library/layout เพิ่มซึ่งเป็นงานคนละขนาด แยกเป็น ticket ถัดไปถ้าจำเป็นจริง
  (**เว้นแต่**ทีมพัฒนาพบว่า PDF ทำได้เร็ว/ถูกด้วย library ที่มีอยู่แล้วในระบบ — ถ้าใช่ ให้คุยกับ PO
  ก่อนขยายขอบเขต)
- Export รวมทุกกะ/ทุกวันเป็น batch ครั้งเดียว (เช่น export รายเดือนทั้งเดือนรวดเดียว) — v1 นี้ export
  ทีละ report/ทีละกะเท่านั้น ตาม date range ที่เลือกในแต่ละ report type
- เชื่อมต่อส่งไฟล์ตรงไปโปรแกรมบัญชีภายนอก (เช่น QuickBooks/FlowAccount API) — เป็นคนละ scope ใหญ่กว่านี้
  มาก
- แก้ไข/ขยายสิทธิ์ cashier ต่อ shift ที่ตัวเองเกี่ยวข้องเท่านั้น (per-cashier shift access control) —
  เป็นขอบเขตเดิมของระบบ role ที่มีอยู่ ไม่ใช่สิ่งที่ ticket นี้ต้องแตะ

## Testing Decisions

เทสต์ที่ดีในโปรเจกต์นี้ = ยิง HTTP จริงผ่าน `supertest` เข้า route จริง บนฐานข้อมูลทดสอบแยกต่างหาก
(`backend/tests/helpers/testApp.js`) ตรวจ **พฤติกรรมภายนอก** (status code, body, response header) ไม่
mock/ตรวจ internal ของ service — นี่คือ pattern เดียวกันทุกไฟล์ใน `backend/tests/*.test.js` อยู่แล้ว
(ไม่ใช่ pattern ใหม่ที่ ticket นี้ต้องคิดเอง)

- **`backend/tests/reports-export.test.js` (ใหม่)** — prior art ตรงที่สุดคือ
  `backend/tests/audit-logs.test.js` เทสต์ `GET /audit-logs/export` (ดู test 3 เคสที่มีอยู่แล้ว:
  role ที่เข้าไม่ได้ต้องได้ 403, admin ดึงได้พร้อม header ที่ถูกต้อง, filter ทำงานถูก) — เทสต์ใหม่ควร
  คลุม: role ที่ไม่ใช่ admin/manager (waiter/kitchen/cashier) ต้อง 403, admin/manager ดึงแต่ละ
  `report` type ได้พร้อม header ที่ถูกต้อง, ตัวเลขในไฟล์ CSV ตรงกับที่ `reportService` คืนจริง (ยิง
  `/reports/summary` เทียบกับ `/reports/export?report=summary` ตัวเลขเดียวกัน), ช่วงว่าง/ไม่มีข้อมูล
  export ได้ CSV ที่มีแค่ header ไม่ error, มี audit log entry `report.export` ถูกสร้างหลัง export
  สำเร็จ (เทียบ pattern การเช็ค audit log entry ที่มีอยู่แล้วใน `backend/tests/audit-logs.test.js`
  และ `backend/tests/shifts.test.js`)
- **ขยาย `backend/tests/shifts.test.js` (มีอยู่แล้ว)** — เพิ่มเคส Z-report: export กะที่ยังไม่ปิดต้อง
  ถูกปฏิเสธ, export กะที่ปิดแล้วได้ CSV ที่มีตัวเลข expectedCash/countedCash/variance ตรงกับที่
  `shift.service.js#close()` persist ไว้, กะที่ข้ามเที่ยงคืนต้องรวมยอดขายฝั่งหลังเที่ยงคืนถูกต้อง (สร้าง
  order/payment ที่มี `shift_id` เดียวกันคร่อมสองวันปฏิทินในเทสต์ แล้วยืนยันว่า Z-report เห็นทั้งหมด)
- **Flutter — controller test ใหม่** (ไม่ใช่ full-page widget pump test ตาม
  `docs/CODING_STANDARDS.md` หัวข้อ 6.2) — prior art: `app/test/presentation/ai_assistant_controller_test.dart`
  และ controller test ของ audit log export ที่มีอยู่แล้ว (ถ้ามี — ตรวจสอบก่อนเริ่ม) ครอบคลุม: กด
  export แล้วเรียก use case ถูกต้อง, error message ตอนไม่รองรับแพลตฟอร์ม (`kIsWeb == false`), สถานะ
  loading (`isExporting`) ระหว่างรอ

## Further Notes

- ทุกจุดต้องผ่าน checklist เดิมของโปรเจกต์ก่อน commit: `dart format` / `flutter analyze` /
  `dart run custom_lint` / `flutter test` ฝั่งแอป, `npm run format:check` / `npm run lint` /
  `npm test` ฝั่ง backend (ดู `docs/CODING_STANDARDS.md` ข้อ 7) — ห้าม skip
- ตามกฎใน `CLAUDE.md`: ก่อน push ทุกครั้งต้องเช็ค/อัปเดต README.md และ README.en.md ให้ตรงกับโค้ดจริง
  โดยเฉพาะ badge จำนวนเทสต์, หัวข้อ "🧪 การทดสอบ", และถ้าฟีเจอร์นี้มีหน้าจอ/ปุ่มที่กดลองได้ ให้เพิ่มเข้า
  ทัวร์ 5 นาที ไม่ใช่แค่ bullet เดียวในหัวข้อฟีเจอร์ลึกๆ (บทเรียนจาก ticket 06 ที่เคยพลาดจุดนี้)
- ถ้าระหว่างพัฒนาเจอว่า scope ที่ตั้งใจไว้ (เช่น payments.shift_id ไม่ครอบคลุมกรณีที่คาดไว้) ไม่ตรงกับ
  ที่เขียนไว้ในสเปกนี้ ให้แก้ spec นี้ให้ตรงกับสิ่งที่ทำจริงก่อน แล้วค่อย push (เช่นเดียวกับที่ ticket
  อื่นในโปรเจกต์นี้ทำมาตลอด — ดู `docs/DECISIONS.md`)
- อัปเดต `docs/tickets/README.md` และ `docs/FEATURE-GAP-ANALYSIS.md` (#12) เป็น ✅ เสร็จแล้ว พร้อม
  เพิ่ม entry ใหม่ใน `docs/DECISIONS.md` เมื่อ ticket นี้เสร็จ ตามธรรมเนียมเดิมของโปรเจกต์

## แก้ภายหลัง (2026-09-23 — พบจากชุด E2E `app/test_e2e/`)
backend ใส่ BOM ถูกต้องตามสเปก แต่แอปที่ดาวน์โหลดไฟล์ผ่าน `ApiClient.getText` ถอด UTF-8 แบบปกติซึ่งตัด BOM
ทิ้ง ไฟล์ที่ร้านได้จริง (ตอนต่อ backend) จึงไม่มี BOM เปิดใน Excel แล้วภาษาไทยเพี้ยน — โหมดสาธิตไม่เจอเพราะ
สร้าง CSV ฝั่ง Dart เอง ตอนนี้ `getText` อ่านเป็นไบต์แล้วคง BOM ไว้ ดู `docs/DECISIONS.md` #45
