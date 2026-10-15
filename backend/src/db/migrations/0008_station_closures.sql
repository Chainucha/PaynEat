-- Copyright 2026 Suruch Chakrapeesirisuk
-- SPDX-License-Identifier: Apache-2.0

-- Migration 0008 — ปิด/เปิดสถานีครัวรายสาขา (ticket 36, docs/DECISIONS.md #102)
-- มีแถว = สถานีนี้ปิดอยู่ที่สาขานี้, เปิดคืน = ลบแถว, ไม่มีแถว = เปิด (สาขาใหม่/สถานีใหม่เปิดเสมอ)
--
-- เป็น "สถานะตอนนี้" ไม่ใช่ประวัติ (ประวัติอยู่ใน audit_logs) จึง CASCADE ตามสาขาและสถานีได้
-- คนละเรื่องกับ kitchen_stations.is_active ซึ่งเป็นค่าตั้งระดับเครือร้าน (ดู CONTEXT.md)
-- ประทับชื่อคนปิดไว้ด้วย แบนเนอร์ "บาร์ปิดตั้งแต่ ... โดย ..." จึงไม่หายถ้าบัญชีนั้นถูกลบภายหลัง
CREATE TABLE IF NOT EXISTS station_closures (
  branch_id      INTEGER NOT NULL REFERENCES branches(id) ON DELETE CASCADE,
  station_id     INTEGER NOT NULL REFERENCES kitchen_stations(id) ON DELETE CASCADE,
  closed_at      TEXT    NOT NULL DEFAULT (datetime('now')),
  closed_by      INTEGER REFERENCES users(id) ON DELETE SET NULL,
  closed_by_name TEXT,
  PRIMARY KEY (branch_id, station_id)
);

CREATE INDEX IF NOT EXISTS idx_station_closures_station ON station_closures(station_id);
