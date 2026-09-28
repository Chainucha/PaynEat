-- Copyright 2026 Suruch Chakrapeesirisuk
-- SPDX-License-Identifier: Apache-2.0

-- Migration 0003 — จำว่าครัวเคยทำรายการถึงขั้นไหน (T05 #104, docs/DECISIONS.md #86)
-- ปุ่ม "เลิกทำ" บนจอครัวถอยสถานะกลับไป pending ได้ แต่การยกเลิกรายการที่ครัวเคยลงมือทำแล้วต้องใช้ผู้จัดการเสมอ
-- NULL = ครัวยังไม่เคยเริ่มทำ ค่าไม่เคยถอยลง แม้สถานะถอยกลับ
ALTER TABLE order_items
  ADD COLUMN kitchen_reached TEXT CHECK (kitchen_reached IN ('cooking', 'ready', 'served'));

-- รายการที่ครัวทำอยู่หรือทำเสร็จแล้วในวันที่อัปเดต ถือว่าเคยถึงสถานะปัจจุบัน
-- รายการที่ยกเลิกไปแล้วไม่รู้ว่าเคยถึงขั้นไหน จึงคงเป็น NULL (ยกเลิกซ้ำไม่ได้อยู่แล้ว)
UPDATE order_items SET kitchen_reached = status WHERE status IN ('cooking', 'ready', 'served');
