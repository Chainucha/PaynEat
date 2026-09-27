-- Copyright 2026 Suruch Chakrapeesirisuk
-- SPDX-License-Identifier: Apache-2.0

-- Migration 0002 — โหมดเชื่อมต่อ PaynEat ERP (ticket 25, docs/DECISIONS.md #80)
-- ไม่มีแถวใน erp_connection = โหมดใช้งานเดี่ยว (ค่าเริ่มต้น) ตารางอื่นในไฟล์นี้เป็นสำเนา (mirror) ของ master data
-- ที่ดึงจาก ERP ตามสัญญา POS v1 ซึ่งยังอยู่หลังออกจากโหมดเชื่อมต่อ

-- การเชื่อมต่อปัจจุบัน มีได้แถวเดียว ลบแถวนี้ = ออกจากโหมดเชื่อมต่อ
-- credential เก็บที่นี่ที่เดียว: ไม่อยู่ในตาราง settings (ซึ่งส่งกลับไปที่แอปทั้งตาราง) และไม่มี mapper ตัวไหนอ่านคอลัมน์นี้
CREATE TABLE erp_connection (
  id                   INTEGER PRIMARY KEY CHECK (id = 1),
  base_url             TEXT    NOT NULL,
  credential           TEXT    NOT NULL,
  instance_code        TEXT    NOT NULL,
  instance_name        TEXT    NOT NULL,
  contract_version     TEXT    NOT NULL,
  connected_at         TEXT    NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%fZ', 'now')),
  -- เวอร์ชัน master data ล่าสุดที่นำไปใช้แล้ว (0 = ยังไม่เคยดึง) ดึงรอบถัดไปใช้เป็น since
  applied_version      INTEGER NOT NULL DEFAULT 0 CHECK (applied_version >= 0),
  latest_version       INTEGER,
  last_pull_at         TEXT,
  -- ผลของการดึงครั้งล่าสุดที่ล้มเหลว (JSON: kind, status, reason, at) — NULL หลังดึงสำเร็จ
  last_error           TEXT,
  -- ERP ตอบ 401: หยุดเรียก ERP จนกว่าจะบันทึก credential ใหม่ (สัญญา POS v1)
  credential_rejected  INTEGER NOT NULL DEFAULT 0 CHECK (credential_rejected IN (0, 1)),
  -- หยุดดึงตามรอบเวลาจนกว่าคนจะจัดการ (credential ถูกปฏิเสธ, คำตอบผิดสัญญา, สัญญา major อื่น — telemetry v1.2)
  -- กด "ดึงทันที" ได้ (ยกเว้น credential ถูกปฏิเสธ) บันทึกการเชื่อมต่อใหม่หรือดึงสำเร็จแล้วกลับมาดึงตามรอบ
  pull_stopped         INTEGER NOT NULL DEFAULT 0 CHECK (pull_stopped IN (0, 1)),
  -- ERP ตอบ 429/503 พร้อม Retry-After: ไม่เรียกก่อนเวลานี้
  retry_after          TEXT
);

-- สาขาที่ ERP ให้ instance นี้ดูแล (จาก GET /api/v1/pos/instance) — อ่านใหม่ทุกครั้งที่เชื่อมต่อและทุกรอบที่ดึง
CREATE TABLE erp_instance_branches (
  location_code TEXT    PRIMARY KEY,
  name_th       TEXT    NOT NULL,
  name_en       TEXT    NOT NULL,
  is_active     INTEGER NOT NULL CHECK (is_active IN (0, 1))
);

-- รายการสินค้าของ ERP ทั้งระเบียนตามที่ดึงมาล่าสุด (data = JSON ทั้งก้อน เขียนทับ ไม่ merge)
CREATE TABLE erp_items (
  item_code      TEXT    PRIMARY KEY,
  erp_id         TEXT    NOT NULL,
  name_th        TEXT    NOT NULL,
  name_en        TEXT    NOT NULL,
  base_unit_code TEXT    NOT NULL,
  is_active      INTEGER NOT NULL CHECK (is_active IN (0, 1)),
  version        INTEGER NOT NULL,
  data           TEXT    NOT NULL,
  updated_at     TEXT    NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%fZ', 'now'))
);

-- สาขาของ ERP ทั้งระเบียนตามที่ดึงมาล่าสุด — superseded_by = รหัสสาขาที่มาแทน (ถ้ามี)
CREATE TABLE erp_locations (
  location_code  TEXT    PRIMARY KEY,
  erp_id         TEXT    NOT NULL,
  name_th        TEXT    NOT NULL,
  name_en        TEXT    NOT NULL,
  is_active      INTEGER NOT NULL CHECK (is_active IN (0, 1)),
  superseded_by  TEXT,
  version        INTEGER NOT NULL,
  data           TEXT    NOT NULL,
  updated_at     TEXT    NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%fZ', 'now'))
);

-- วัตถุดิบจับคู่กับรายการสินค้าของ ERP ด้วยรหัสสินค้า — ตั้งเองได้ในโหมดเดี่ยว (เตรียมก่อนเชื่อมต่อ ให้สูตรเมนูเดิมไม่หลุด)
-- และถูกตั้งให้เมื่อดึงรายการใหม่จาก ERP รหัสหนึ่งมีวัตถุดิบได้หนึ่งตัวต่อสาขา
ALTER TABLE ingredients ADD COLUMN item_code TEXT;
CREATE UNIQUE INDEX idx_ingredients_branch_item_code
  ON ingredients(branch_id, item_code) WHERE item_code IS NOT NULL;
