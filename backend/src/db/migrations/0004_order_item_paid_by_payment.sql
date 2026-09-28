-- Copyright 2026 Suruch Chakrapeesirisuk
-- SPDX-License-Identifier: Apache-2.0

-- Migration 0004 — จำว่ารายการที่แยกจ่ายถูกจ่ายด้วย payment ไหน (T06 #82, docs/DECISIONS.md #87)
-- คืนเงินของ payment นั้นครบทั้งจำนวนบนบิลที่ยังเปิดอยู่ = เงินของรายการเหล่านั้นไม่ได้อยู่กับร้านแล้ว
-- รายการจึงกลับเป็น "ยังไม่จ่าย" ให้เลือกจ่ายใหม่หรือยกเลิกได้ (T04 บอกให้ "คืนเงินก่อน" ทางนี้ต้องเดินต่อได้)
-- รายการที่แยกจ่ายก่อน migration นี้ไม่รู้ว่าจ่ายด้วย payment ไหน จึงคงเป็น NULL
ALTER TABLE order_items ADD COLUMN paid_by_payment_id INTEGER REFERENCES payments(id);

CREATE INDEX IF NOT EXISTS idx_order_items_paid_by_payment ON order_items(paid_by_payment_id);
