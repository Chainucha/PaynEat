-- Copyright 2026 Suruch Chakrapeesirisuk
-- SPDX-License-Identifier: Apache-2.0

-- Migration 0006 — สถานีครัว: ครัวร้อน / ครัวเย็น / บาร์ (ticket 34, docs/DECISIONS.md #94)
-- แต่ละจานผูกกับสถานี ตั๋วจึงเข้าจอของสถานีนั้นเอง ไม่ต้องให้ครัวไล่อ่านตั๋วที่ไม่ใช่ของตัวเอง
--
-- เป็นตารางอ้างอิง ไม่ใช่ CHECK (... IN (...)) เพราะ SQLite แก้ CHECK ไม่ได้ — ตอนเพิ่มวิธีชำระเงิน
-- หนึ่งวิธีใน 0001_baseline.js ต้องสร้างตารางใหม่ทั้งตาราง การเพิ่มสถานีใหม่ต้องไม่แพงขนาดนั้น
-- ไม่มี branch_id เหมือน categories (docs/DECISIONS.md #36): "ครัวร้อน/ครัวเย็น/บาร์" เป็นบทบาท
-- เดียวกันทุกสาขา และหมวดหมู่ซึ่งเป็นคนถือค่าเริ่มต้นของสถานีก็เป็นข้อมูลระดับเครือร้านอยู่แล้ว
CREATE TABLE IF NOT EXISTS kitchen_stations (
  id         INTEGER PRIMARY KEY AUTOINCREMENT,
  code       TEXT    NOT NULL UNIQUE,
  name       TEXT    NOT NULL,
  name_en    TEXT,
  name_ko    TEXT,
  icon       TEXT,
  sort_order INTEGER NOT NULL DEFAULT 0,
  is_active  INTEGER NOT NULL DEFAULT 1,
  is_default INTEGER NOT NULL DEFAULT 0 CHECK (is_default IN (0, 1)),
  created_at TEXT    NOT NULL DEFAULT (datetime('now')),
  updated_at TEXT    NOT NULL DEFAULT (datetime('now'))
);

-- partial unique index = "ค่าเริ่มต้นมีได้ไม่เกินหนึ่งสถานี" บังคับที่ฐานข้อมูล ไม่ใช่แค่ใน service
CREATE UNIQUE INDEX IF NOT EXISTS idx_kitchen_stations_default
  ON kitchen_stations(is_default) WHERE is_default = 1;

-- สามสถานีตั้งต้นมาพร้อม migration ไม่ใช่ seed.js เพราะกฎการตัดสินสถานีถอยไปหา "สถานีค่าเริ่มต้น"
-- เสมอ แถวนี้จึงเป็นเงื่อนไขความถูกต้อง ไม่ใช่ข้อมูลตัวอย่าง (seed.js ข้ามได้ด้วย AUTO_SEED=false)
INSERT INTO kitchen_stations (code, name, name_en, name_ko, icon, sort_order, is_default) VALUES
  ('hot',  'ครัวร้อน', 'Hot Kitchen',  '온주방', '🔥', 1, 1),
  ('cold', 'ครัวเย็น', 'Cold Kitchen', '냉주방', '🥗', 2, 0),
  ('bar',  'บาร์',     'Bar',          '바',     '🥤', 3, 0);

-- NULL = "ตามหมวดหมู่" สำหรับเมนู และ "ตามค่าเริ่มต้น" สำหรับหมวดหมู่ — ดูกฎใน order.service.js buildItemRow
ALTER TABLE menu_items ADD COLUMN station_id INTEGER REFERENCES kitchen_stations(id);
ALTER TABLE categories ADD COLUMN station_id INTEGER REFERENCES kitchen_stations(id);

-- ประทับสถานีลงตั๋วตอนบันทึกรายการ (คู่กับ name_snapshot) ย้ายเมนูไปสถานีอื่นทีหลังจึงไม่ดึงตั๋ว
-- ที่ครัวกำลังทำอยู่ข้ามจอ และเปลี่ยนชื่อสถานีก็ไม่เปลี่ยนชื่อบนตั๋วที่ค้างอยู่
-- ไม่ใส่ ON DELETE SET NULL: NO ACTION ทำให้ SQLite ปฏิเสธการลบสถานีที่เคยมีตั๋วอ้างถึง
-- ประวัติบนบิลเก่าจึงหายไปเงียบ ๆ ไม่ได้ (service ปิดทางนี้ด้วย 409 ก่อนถึงฐานข้อมูลอยู่แล้ว)
ALTER TABLE order_items ADD COLUMN station_id INTEGER REFERENCES kitchen_stations(id);
ALTER TABLE order_items ADD COLUMN station_name_snapshot TEXT;

CREATE INDEX IF NOT EXISTS idx_menu_items_station ON menu_items(station_id);
CREATE INDEX IF NOT EXISTS idx_order_items_station ON order_items(station_id);

-- ตั๋วที่ค้างอยู่บนจอครัวตอนอัปเกรดต้องไม่หายไปจากชิปสถานีใด จึงประทับสถานีค่าเริ่มต้นให้
-- (หลักเดียวกับ 0003 ที่ backfill kitchen_reached จาก status) รายการของบิลที่ปิดแล้วคงเป็น NULL
-- เพราะตอนนั้นยังไม่มีสถานีอยู่จริง เดาให้ก็เท่ากับแต่งประวัติ
UPDATE order_items
   SET station_id            = (SELECT id FROM kitchen_stations WHERE is_default = 1),
       station_name_snapshot = (SELECT name FROM kitchen_stations WHERE is_default = 1)
 WHERE status IN ('pending', 'cooking', 'ready')
   AND order_id IN (SELECT id FROM orders WHERE status IN ('in_kitchen', 'served'));
