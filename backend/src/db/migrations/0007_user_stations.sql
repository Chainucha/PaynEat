-- Copyright 2026 Suruch Chakrapeesirisuk
-- SPDX-License-Identifier: Apache-2.0

-- Migration 0007 — พนักงานคนหนึ่งรับผิดชอบได้หลายสถานีครัว (ticket 35, docs/DECISIONS.md #98)
-- รูปเดียวกับ user_branches ทุกจุด เพราะเป็นคำถามเดียวกัน ("คนนี้ทำงานที่ไหนได้บ้าง") คนทำครัวร้อน
-- ที่ช่วยดูเตาย่างด้วยจึงไม่ต้องมีสองบัญชี
--
-- ไม่มีแถว = ไม่ผูกสถานี = เห็นทุกสถานีเหมือนก่อน ticket 35 (พฤติกรรมเดิมของทุกบัญชีที่มีอยู่แล้ว)
-- การผูกนี้ใช้ "เลือกสถานีให้ล่วงหน้า" บนจอครัวเท่านั้น ไม่ได้ซ่อนตั๋ว — จอยังสลับไปสถานีอื่นได้
CREATE TABLE IF NOT EXISTS user_stations (
  user_id    INTEGER NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  station_id INTEGER NOT NULL REFERENCES kitchen_stations(id) ON DELETE CASCADE,
  created_at TEXT    NOT NULL DEFAULT (datetime('now')),
  PRIMARY KEY (user_id, station_id)
);

CREATE INDEX IF NOT EXISTS idx_user_stations_station ON user_stations(station_id);
