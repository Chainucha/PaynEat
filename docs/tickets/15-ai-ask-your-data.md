# Ticket: AI ถามตอบข้อมูลร้าน (Ask-Your-Data / Natural Language Analytics)

**Priority:** นอกเหนือจาก gap analysis เดิม — ฟีเจอร์เชิงจุดขาย/นวัตกรรม (ผู้ใช้ร้องขอโดยตรง)
**สถานะ:** ✅ เสร็จแล้ว (ดู `docs/DECISIONS.md` #33 สำหรับรายละเอียดการตัดสินใจ)
— QA รอบ ก.ย. 2026 (#79) พบกฎที่ยังไม่ป้องกัน แก้ใน T24 [#88](https://github.com/SuruchBoss/PaynEat/issues/88)
**Ref:** ต่อยอดจาก `backend/src/modules/reports/`, ดีไซน์ dashboard ที่ทำไว้ก่อนหน้า
(Artifact "ยอดขายวันนี้"), และ `docs/tickets/14-financial-audit-trail.md` (เฟส 2 ของทิกเก็ตนี้)

## สรุปสิ่งที่ทำจริง

- **Backend** `backend/src/modules/ai-assistant/` — `POST /ai/ask` (admin/manager) ใช้ Claude API
  (`@anthropic-ai/sdk`, ค่าเริ่มต้น `claude-opus-5` ตั้งค่าได้ผ่าน `AI_ASSISTANT_MODEL`) ผ่าน manual
  tool loop ของตัวเอง (ไม่ใช้ beta Tool Runner) มี 6 tool: `get_sales_summary`, `get_top_selling_items`,
  `get_sales_by_day`, `list_recent_orders`, `get_top_customers` (ทุก role ที่เข้าถึงได้ใช้ได้),
  `list_audit_log_entries` (เฉพาะ admin) — ทุก tool ห่อ service/repository เดิมเท่านั้น ไม่แตะ DB ตรงๆ
  บังคับให้จบด้วยการเรียก tool `submit_answer` เสมอ (บังคับด้วย `tool_choice` ในรอบสุดท้ายถ้าโมเดิลไม่
  ยอมเรียกเอง) จำกัดโควตา `AI_ASSISTANT_DAILY_LIMIT` ต่อผู้ใช้ต่อวัน (ค่าเริ่มต้น 20) เก็บทุกคำถาม/
  คำตอบ/tool ที่เรียกไว้ที่ตาราง `ai_assistant_queries` ปิดอัตโนมัติ (503) ถ้าไม่ตั้ง `ANTHROPIC_API_KEY`
- **Flutter** `app/lib/features/ai_assistant/` — แท็บนำทางใหม่ "ผู้ช่วย AI" (admin/manager เท่านั้น)
  หน้าแชทถาม-ตอบพร้อมกราฟแท่งประกอบและชิป "แหล่งข้อมูล" ต่อคำตอบ, โหมดเดโมคืน error เดียวกับตอน
  backend ไม่ได้ตั้งค่า API key (ตั้งใจไม่ปลอมคำตอบ AI)
- **เทสต์** backend 10 เคสใหม่ (`ai-assistant.test.js`, `ai-assistant-rate-limit.test.js`) ผ่าน fake
  Anthropic client, Flutter 7 เคสใหม่ (`ai_assistant_controller_test.dart`)
- **ขอบเขตที่ตั้งใจยังไม่ทำ** (ตามที่ระบุไว้ในทิกเก็ตนี้ตั้งแต่ต้น): AI สรุป audit log อัตโนมัติ,
  chatbot ฝั่งลูกค้า, voice ordering

## ปัญหา

เจ้าของร้าน/ผู้จัดการต้องเปิดหลายหน้าจอ (dashboard, reports, top items, audit log) แล้วไล่หา
คำตอบเองว่า "เมนูไหนขายดีสุดอาทิตย์นี้เทียบกับอาทิตย์ก่อน" หรือ "ลูกค้าคนไหนซื้อบ่อยสุด" ทั้งที่
ข้อมูลทุกอย่างมีอยู่แล้วในระบบ (`/reports/*`, `/orders`, `/customers`, `/audit-logs`) แค่ต้อง
เปิดหลายหน้าแล้วคำนวณเปรียบเทียบเอง

## ทำไมสำคัญ

นี่คือฟีเจอร์ที่ตั้งใจให้เป็น **จุดขายทางการตลาด** ของโปรเจกต์ว่า "เอา LLM มาประยุกต์ใช้จริง" —
สำคัญที่ต้องแยกจาก "chatbot ประดับ" ทั่วไป: จุดต่างคือ LLM ต่อกับข้อมูลจริงในระบบผ่าน tool-calling
ไม่ใช่ตอบจากความรู้ทั่วไปของโมเดลเฉยๆ (ป้องกัน hallucinate ตัวเลขยอดขาย) ทำให้ demo ได้ชัดว่า
"ถามได้จริง ตอบจากข้อมูลร้านจริง" ไม่ใช่แค่ป้ายว่า "มี AI"

## ขอบเขตงาน (คร่าวๆ)

- **เลือก LLM provider ก่อนเริ่ม** — แนะนำ Claude API (Anthropic) เพราะรองรับ tool-calling ที่
  เหมาะกับงานนี้โดยตรง อ่าน skill `claude-api` ในเครื่องมือพัฒนาประกอบการตัดสินใจเรื่อง model/
  ราคา/caching ก่อนเริ่มเขียนโค้ดจริง
- **Backend**: module ใหม่ `backend/src/modules/ai-assistant/` — endpoint `POST /ai/ask` รับ
  คำถามภาษาธรรมชาติ (ไทย/อังกฤษ) แล้วให้ LLM เรียก tool ที่ wrap endpoint ที่มีอยู่แล้วเท่านั้น
  (`reportService.summary/topItems/salesByDay`, `orderService.list`, `customerRepository`,
  `auditLogService.list`) — ไม่ให้ LLM เข้าถึง DB ตรงๆ และไม่ให้แต่งตัวเลขเอง
- **เก็บ API key ผ่าน env var เท่านั้น** ไม่ commit เข้า repo (ตาม pattern เดิมของโปรเจกต์ที่ไม่มี
  secret hardcode อยู่แล้ว — ดู security review ที่ทำไปก่อนหน้า `docs/DECISIONS.md` #20)
- **Rate limit + cost monitoring** — จำกัดจำนวนคำถามต่อ user/วัน กันเรียก LLM บ่อยเกินจนเสีย
  ค่าใช้จ่ายเกินควบคุม (ทุกคำถาม = ค่าใช้จ่ายจริงต่อ token)
- **Frontend**: widget แชทถามตอบในหน้า dashboard/reports (เห็นเฉพาะ admin/manager) — พิมพ์คำถาม
  → เห็นคำตอบเป็นข้อความ + กราฟประกอบถ้าเกี่ยวกับตัวเลข (reuse component จากดีไซน์ dashboard ที่
  ทำไว้แล้ว)
- **Log คำถาม-คำตอบ** เพื่อ debug/monitor cost และตรวจสอบว่า AI ไม่ตอบมั่ว (อาจ reuse
  `audit_logs` infrastructure เดิม หรือตารางแยกก็ได้ ขึ้นกับ volume ที่คาดว่าจะเกิด)

## ขอบเขตที่ตั้งใจไม่ทำในเฟสแรก

- **AI สรุป audit log อัตโนมัติ** (เช่น "สัปดาห์นี้พนักงาน A ยกเลิกออเดอร์ผิดปกติ 3 ครั้ง") — ใช้
  infrastructure เดียวกัน แต่แยกเป็นทิกเก็ตถัดไปหลังฟีเจอร์นี้เสถียรแล้ว
- **Chatbot ฝั่งลูกค้า** (ถามเมนู/แพ้อาหารผ่าน LINE OA) — ต้องทำ channel ใหม่ทั้งหมด scope ใหญ่
  กว่านี้มาก แยกเป็นทิกเก็ตต่างหาก
- **Voice ordering** — ความเสี่ยงสั่งผิดสูง ต้องมี confirmation flow ที่ออกแบบแยกต่างหาก

## Acceptance Criteria

- [x] Admin/manager พิมพ์คำถามภาษาไทย/อังกฤษเกี่ยวกับยอดขาย/เมนูขายดี/ลูกค้า/ช่วงเวลาเปรียบเทียบ
  แล้วได้คำตอบที่ตรงกับข้อมูลจริงในระบบ (ตรวจสอบย้อนกลับได้ว่าตัวเลขมาจาก endpoint ไหน)
- [x] คำตอบระบุช่วงเวลา/ที่มาของข้อมูลที่ใช้ชัดเจนทุกครั้ง (เช่น "จากข้อมูล 1–15 ก.ย.")
- [x] คำถามที่อยู่นอกเหนือข้อมูลที่ระบบมี ต้องตอบตรงไปตรงมาว่าไม่มีข้อมูล ห้ามเดา/แต่งคำตอบ
- [x] มี rate limit ต่อ user/วัน และ log การใช้งานเพื่อ monitor ค่าใช้จ่าย
- [x] ตอบได้ทั้งแบบข้อความล้วนและแบบมีกราฟประกอบเมื่อคำถามเกี่ยวกับตัวเลขที่ plot ได้

## ไฟล์ที่เกี่ยวข้อง

- `backend/src/modules/ai-assistant/` (ใหม่)
- `backend/src/modules/reports/`, `orders/`, `customers/`, `audit-logs/` (endpoint ที่ให้ LLM
  เรียกผ่าน tool-calling)
- `app/lib/features/ai_assistant/` (ใหม่, Clean Architecture ตาม pattern เดิมของโปรเจกต์)
- `app/lib/features/report/` (จุดที่จะฝัง widget แชท)
