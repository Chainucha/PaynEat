-- Copyright 2026 Suruch Chakrapeesirisuk
-- SPDX-License-Identifier: Apache-2.0

-- =============================================================
-- PaynEat POS — Database schema (SQLite), migration 0001: baseline
-- Original project by SuruchBoss — https://github.com/SuruchBoss/PaynEat
-- Licensed under Apache License 2.0 — see LICENSE and NOTICE at repo root
-- หมายเหตุ: จำนวนเงินทุกคอลัมน์เก็บเป็น "สตางค์" (integer)
--          เช่น 120.50 บาท = 12050 เพื่อเลี่ยงปัญหา floating point
--
-- ไฟล์นี้คือ schema ทั้งหมดก่อน T01 (#80, docs/DECISIONS.md #79) ถูกแช่แข็งแล้ว: ห้ามแก้ แม้แต่คอมเมนต์
-- เพราะ checksum ของไฟล์ถูกบันทึกในทุกฐานข้อมูลที่รันไปแล้ว — เปลี่ยน schema ให้เพิ่ม migration เลขถัดไป
-- ในโฟลเดอร์นี้แทน (ดู migrations/index.js) คอลัมน์และ index ที่คอมเมนต์ด้านล่างบอกว่า "สร้างใน
-- migrate.js" ตอนนี้อยู่ใน 0001_baseline.js
-- =============================================================

PRAGMA foreign_keys = ON;

-- สาขา (ดู docs/tickets/11-multi-branch.md) — entity ระดับองค์กร ไม่ผูก branch_id กับตัวเอง
-- (ผูกแค่ dining_tables/menu_items/orders/ingredients เท่านั้น — promotions/customers/categories/
-- options/settings ตั้งใจให้เป็นของทั้งเชนเหมือนเดิม ดู docs/DECISIONS.md #36)
CREATE TABLE IF NOT EXISTS branches (
  id         INTEGER PRIMARY KEY AUTOINCREMENT,
  name       TEXT    NOT NULL,
  code       TEXT    UNIQUE,
  address    TEXT,
  is_active  INTEGER NOT NULL DEFAULT 1,
  created_at TEXT    NOT NULL DEFAULT (datetime('now')),
  updated_at TEXT    NOT NULL DEFAULT (datetime('now'))
);

-- สิทธิ์การเข้าถึงสาขาของผู้ใช้แต่ละคน (many-to-many) — admin ไม่ต้องมีแถวในนี้เลยก็เข้าได้ทุกสาขา
-- เสมอ (bypass ที่ branch.repository.js#listForUser และ middlewares/auth.js#attachBranch)
CREATE TABLE IF NOT EXISTS user_branches (
  user_id    INTEGER NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  branch_id  INTEGER NOT NULL REFERENCES branches(id) ON DELETE CASCADE,
  created_at TEXT    NOT NULL DEFAULT (datetime('now')),
  PRIMARY KEY (user_id, branch_id)
);
CREATE INDEX IF NOT EXISTS idx_user_branches_branch ON user_branches(branch_id);

CREATE TABLE IF NOT EXISTS users (
  id            INTEGER PRIMARY KEY AUTOINCREMENT,
  name          TEXT    NOT NULL,
  username      TEXT    NOT NULL UNIQUE,
  password_hash TEXT    NOT NULL,
  role          TEXT    NOT NULL CHECK (role IN ('admin', 'manager', 'waiter', 'cashier', 'kitchen')),
  is_active     INTEGER NOT NULL DEFAULT 1,
  created_at    TEXT    NOT NULL DEFAULT (datetime('now')),
  updated_at    TEXT    NOT NULL DEFAULT (datetime('now'))
);

CREATE TABLE IF NOT EXISTS categories (
  id         INTEGER PRIMARY KEY AUTOINCREMENT,
  name       TEXT    NOT NULL,
  name_en    TEXT,
  icon       TEXT,
  sort_order INTEGER NOT NULL DEFAULT 0,
  is_active  INTEGER NOT NULL DEFAULT 1,
  created_at TEXT    NOT NULL DEFAULT (datetime('now')),
  updated_at TEXT    NOT NULL DEFAULT (datetime('now'))
);

CREATE TABLE IF NOT EXISTS menu_items (
  id             INTEGER PRIMARY KEY AUTOINCREMENT,
  category_id    INTEGER NOT NULL REFERENCES categories(id) ON DELETE RESTRICT,
  name           TEXT    NOT NULL,
  name_en        TEXT,
  description    TEXT,
  price          INTEGER NOT NULL CHECK (price >= 0),
  image_url      TEXT,
  is_available   INTEGER NOT NULL DEFAULT 1,
  is_recommended INTEGER NOT NULL DEFAULT 0,
  prep_minutes   INTEGER NOT NULL DEFAULT 10,
  sort_order     INTEGER NOT NULL DEFAULT 0,
  -- ขายตามน้ำหนัก (ดู docs/tickets/18-sell-by-weight.md) — 1 = price คือราคาต่อกิโลกรัม และทุกบรรทัด
  -- ที่สั่งต้องระบุ order_items.weight_grams
  sold_by_weight INTEGER NOT NULL DEFAULT 0,
  -- บาร์โค้ดสินค้าสำเร็จรูป (สแกนแล้วใส่ตะกร้า 1 ชิ้น) และรหัสสินค้าบนฉลากตาชั่ง (PLU — ฉลาก EAN-13
  -- ขึ้นต้นด้วย 2 ที่ตาชั่งพิมพ์ออกมาพร้อมน้ำหนัก) ดู docs/tickets/19-barcode-scale.md — index สร้าง
  -- ใน migrate.js หลังเพิ่มคอลัมน์ให้ฐานข้อมูลเดิม
  barcode        TEXT,
  scale_plu      TEXT,
  created_at     TEXT    NOT NULL DEFAULT (datetime('now')),
  updated_at     TEXT    NOT NULL DEFAULT (datetime('now'))
);
CREATE INDEX IF NOT EXISTS idx_menu_items_category ON menu_items(category_id);

-- กลุ่มตัวเลือกของเมนู เช่น "ระดับความเผ็ด", "เพิ่มท็อปปิ้ง"
CREATE TABLE IF NOT EXISTS option_groups (
  id           INTEGER PRIMARY KEY AUTOINCREMENT,
  menu_item_id INTEGER NOT NULL REFERENCES menu_items(id) ON DELETE CASCADE,
  name         TEXT    NOT NULL,
  min_select   INTEGER NOT NULL DEFAULT 0,
  max_select   INTEGER NOT NULL DEFAULT 1,
  is_required  INTEGER NOT NULL DEFAULT 0,
  sort_order   INTEGER NOT NULL DEFAULT 0
);
CREATE INDEX IF NOT EXISTS idx_option_groups_item ON option_groups(menu_item_id);

CREATE TABLE IF NOT EXISTS options (
  id          INTEGER PRIMARY KEY AUTOINCREMENT,
  group_id    INTEGER NOT NULL REFERENCES option_groups(id) ON DELETE CASCADE,
  name        TEXT    NOT NULL,
  price_delta INTEGER NOT NULL DEFAULT 0,
  is_default  INTEGER NOT NULL DEFAULT 0,
  sort_order  INTEGER NOT NULL DEFAULT 0
);
CREATE INDEX IF NOT EXISTS idx_options_group ON options(group_id);

-- วัตถุดิบ/สต๊อก (ดู docs/tickets/06-inventory-stock.md) — หน่วย (unit) เป็น string อิสระที่ร้าน
-- ตั้งเอง เช่น "กก.", "ลิตร", "ชิ้น" ไม่มี unit conversion ข้ามหน่วย — ไม่ใช่เงินจึงเก็บเป็น REAL
-- ตรง ๆ ไม่ผ่าน toSatang/toBaht เหมือนคอลัมน์เงินอื่นในระบบ (ดู docs/DECISIONS.md)
CREATE TABLE IF NOT EXISTS ingredients (
  id                  INTEGER PRIMARY KEY AUTOINCREMENT,
  name                TEXT    NOT NULL,
  unit                TEXT    NOT NULL,
  current_stock       REAL    NOT NULL DEFAULT 0,
  low_stock_threshold REAL    NOT NULL DEFAULT 0,
  created_at          TEXT    NOT NULL DEFAULT (datetime('now')),
  updated_at          TEXT    NOT NULL DEFAULT (datetime('now'))
);

-- ผูกเมนูกับวัตถุดิบที่ใช้ + ปริมาณที่ใช้ต่อ 1 ที่ (qty_per_unit) — เมนูหนึ่งผูกได้หลายวัตถุดิบ
-- ON DELETE RESTRICT ที่ ingredient_id: ลบวัตถุดิบที่ยังผูกกับเมนูอยู่ไม่ได้ต้องเลิกผูกก่อน
CREATE TABLE IF NOT EXISTS menu_item_ingredients (
  id            INTEGER PRIMARY KEY AUTOINCREMENT,
  menu_item_id  INTEGER NOT NULL REFERENCES menu_items(id) ON DELETE CASCADE,
  ingredient_id INTEGER NOT NULL REFERENCES ingredients(id) ON DELETE RESTRICT,
  qty_per_unit  REAL    NOT NULL CHECK (qty_per_unit > 0),
  created_at    TEXT    NOT NULL DEFAULT (datetime('now')),
  updated_at    TEXT    NOT NULL DEFAULT (datetime('now'))
);
CREATE UNIQUE INDEX IF NOT EXISTS idx_menu_item_ingredients_unique
  ON menu_item_ingredients(menu_item_id, ingredient_id);
CREATE INDEX IF NOT EXISTS idx_menu_item_ingredients_menu_item ON menu_item_ingredients(menu_item_id);
CREATE INDEX IF NOT EXISTS idx_menu_item_ingredients_ingredient ON menu_item_ingredients(ingredient_id);

CREATE TABLE IF NOT EXISTS dining_tables (
  id         INTEGER PRIMARY KEY AUTOINCREMENT,
  name       TEXT    NOT NULL UNIQUE,
  zone       TEXT    NOT NULL DEFAULT 'main',
  seats      INTEGER NOT NULL DEFAULT 4,
  status     TEXT    NOT NULL DEFAULT 'available'
             CHECK (status IN ('available', 'occupied', 'reserved', 'billing')),
  is_active  INTEGER NOT NULL DEFAULT 1,
  created_at TEXT    NOT NULL DEFAULT (datetime('now')),
  updated_at TEXT    NOT NULL DEFAULT (datetime('now'))
);

-- โปรโมชัน/ส่วนลดแบบมีเงื่อนไข (ดู docs/tickets/05-promotion-engine.md)
-- conditions_json: {daysOfWeek:[0-6], startTime:"HH:mm", endTime:"HH:mm",
--                    categoryIds:[...], menuItemIds:[...], minSubtotal: สตางค์}
-- ไม่ระบุ categoryIds/menuItemIds เลย = ใช้ได้กับทั้งบิล
CREATE TABLE IF NOT EXISTS promotions (
  id              INTEGER PRIMARY KEY AUTOINCREMENT,
  name            TEXT    NOT NULL,
  type            TEXT    NOT NULL CHECK (type IN ('percent', 'amount', 'bogo')),
  value           INTEGER NOT NULL DEFAULT 0,
  code            TEXT    UNIQUE,
  conditions_json TEXT    NOT NULL DEFAULT '{}',
  is_active       INTEGER NOT NULL DEFAULT 1,
  valid_from      TEXT,
  valid_to        TEXT,
  created_at      TEXT    NOT NULL DEFAULT (datetime('now')),
  updated_at      TEXT    NOT NULL DEFAULT (datetime('now'))
);
CREATE INDEX IF NOT EXISTS idx_promotions_active ON promotions(is_active);

-- ลูกค้า/สมาชิก + แต้มสะสม (ดู docs/tickets/09-customer-loyalty.md) — ผูกกับออเดอร์แบบ optional
-- เท่านั้น ลูกค้าทั่วไปไม่ต้องผูกก็สั่งอาหารได้ปกติ ค้นหาด้วยเบอร์โทร (unique) เป็นหลัก
CREATE TABLE IF NOT EXISTS customers (
  id             INTEGER PRIMARY KEY AUTOINCREMENT,
  name           TEXT    NOT NULL,
  phone          TEXT    NOT NULL UNIQUE,
  email          TEXT,
  points_balance INTEGER NOT NULL DEFAULT 0 CHECK (points_balance >= 0),
  -- ลูกค้าเครดิต/ขายส่ง (ดู docs/tickets/20-b2b-credit.md) — credit_limit เป็นสตางค์ 0 = ไม่ให้เครดิต
  -- (ขายเชื่อไม่ได้) credit_term_days ใช้คำนวณวันครบกำหนดของบิลขายเชื่อ ณ ตอนขาย (snapshot ไว้ที่
  -- payments.due_date) tax_id/address ใช้ออกใบวางบิลและเติมใบกำกับภาษีเต็มรูปให้อัตโนมัติ
  credit_limit     INTEGER NOT NULL DEFAULT 0 CHECK (credit_limit >= 0),
  credit_term_days INTEGER NOT NULL DEFAULT 30 CHECK (credit_term_days >= 0),
  tax_id           TEXT,
  address          TEXT,
  created_at     TEXT    NOT NULL DEFAULT (datetime('now')),
  updated_at     TEXT    NOT NULL DEFAULT (datetime('now'))
);

CREATE TABLE IF NOT EXISTS orders (
  id                INTEGER PRIMARY KEY AUTOINCREMENT,
  code              TEXT    NOT NULL UNIQUE,
  type              TEXT    NOT NULL DEFAULT 'dine_in' CHECK (type IN ('dine_in', 'takeaway', 'delivery')),
  table_id          INTEGER REFERENCES dining_tables(id) ON DELETE SET NULL,
  -- เลขคิวรับอาหารสำหรับลูกค้าที่มารอรับเอง (ดู docs/tickets/10-takeaway-delivery-flow.md) — รันต่อวัน
  -- เฉพาะออเดอร์ type='takeaway' เท่านั้น (delivery ให้ไรเดอร์อ้างอิงจาก code แทน ไม่มีคนมายืนรอคิว)
  queue_number      INTEGER,
  waiter_id         INTEGER REFERENCES users(id) ON DELETE SET NULL,
  -- ผูกลูกค้าแบบ optional (ดู docs/tickets/09-customer-loyalty.md) — points_earned สะสมครั้งเดียว
  -- ตอนออเดอร์จ่ายครบ (ดู payment.service.js#pay) ไม่ผูกซ้ำ/ไม่หักคืนอัตโนมัติถ้ามี refund ภายหลัง
  customer_id       INTEGER REFERENCES customers(id) ON DELETE SET NULL,
  points_earned     INTEGER NOT NULL DEFAULT 0,
  guest_count       INTEGER NOT NULL DEFAULT 1,
  status            TEXT    NOT NULL DEFAULT 'open'
                    CHECK (status IN ('open', 'in_kitchen', 'served', 'paid', 'cancelled')),
  note              TEXT,
  subtotal          INTEGER NOT NULL DEFAULT 0,
  discount_type     TEXT    NOT NULL DEFAULT 'none' CHECK (discount_type IN ('none', 'amount', 'percent')),
  discount_value    INTEGER NOT NULL DEFAULT 0,
  discount_amount   INTEGER NOT NULL DEFAULT 0,
  -- ส่วนลดจากโปรโมชัน — แยกจากส่วนลดมือข้างบน คำนวณรวมกันแต่ไม่เกิน subtotal (ดู order.calculator.js)
  promotion_id              INTEGER REFERENCES promotions(id) ON DELETE SET NULL,
  promotion_name_snapshot   TEXT,
  promotion_code_snapshot   TEXT,
  promotion_discount_amount INTEGER NOT NULL DEFAULT 0,
  service_charge    INTEGER NOT NULL DEFAULT 0,
  vat               INTEGER NOT NULL DEFAULT 0,
  total             INTEGER NOT NULL DEFAULT 0,
  cancelled_reason  TEXT,
  created_at        TEXT    NOT NULL DEFAULT (datetime('now')),
  updated_at        TEXT    NOT NULL DEFAULT (datetime('now')),
  closed_at         TEXT
);
CREATE INDEX IF NOT EXISTS idx_orders_status ON orders(status);
CREATE INDEX IF NOT EXISTS idx_orders_table ON orders(table_id);
CREATE INDEX IF NOT EXISTS idx_orders_created ON orders(created_at);
CREATE INDEX IF NOT EXISTS idx_orders_customer ON orders(customer_id);

CREATE TABLE IF NOT EXISTS order_items (
  id            INTEGER PRIMARY KEY AUTOINCREMENT,
  order_id      INTEGER NOT NULL REFERENCES orders(id) ON DELETE CASCADE,
  menu_item_id  INTEGER REFERENCES menu_items(id) ON DELETE SET NULL,
  name_snapshot TEXT    NOT NULL,
  unit_price    INTEGER NOT NULL,
  quantity      INTEGER NOT NULL CHECK (quantity > 0),
  options_json  TEXT    NOT NULL DEFAULT '[]',
  options_price INTEGER NOT NULL DEFAULT 0,
  line_total    INTEGER NOT NULL DEFAULT 0,
  -- น้ำหนักที่ชั่งได้ของสินค้าขายตามน้ำหนัก (NULL = ขายเป็นชิ้น) — บรรทัดชั่งน้ำหนัก quantity = 1 เสมอ
  -- line_total = ปัด((unit_price + options_price) × weight_grams / 1000) เป็นสตางค์
  weight_grams  INTEGER CHECK (weight_grams IS NULL OR weight_grams > 0),
  note          TEXT,
  status        TEXT    NOT NULL DEFAULT 'pending'
                CHECK (status IN ('pending', 'cooking', 'ready', 'served', 'cancelled')),
  is_paid       INTEGER NOT NULL DEFAULT 0,
  created_at    TEXT    NOT NULL DEFAULT (datetime('now')),
  updated_at    TEXT    NOT NULL DEFAULT (datetime('now'))
);
CREATE INDEX IF NOT EXISTS idx_order_items_order ON order_items(order_id);
CREATE INDEX IF NOT EXISTS idx_order_items_status ON order_items(status);

-- กะทำงานของแคชเชียร์ — ใช้กระทบยอดเงินสดตอนปิดกะ (ดู docs/tickets/01-shift-cash-reconciliation.md)
CREATE TABLE IF NOT EXISTS shifts (
  id             INTEGER PRIMARY KEY AUTOINCREMENT,
  status         TEXT    NOT NULL DEFAULT 'open' CHECK (status IN ('open', 'closed')),
  opened_by      INTEGER NOT NULL REFERENCES users(id) ON DELETE RESTRICT,
  opened_at      TEXT    NOT NULL DEFAULT (datetime('now')),
  opening_cash   INTEGER NOT NULL CHECK (opening_cash >= 0),
  closed_by      INTEGER REFERENCES users(id) ON DELETE SET NULL,
  closed_at      TEXT,
  expected_cash  INTEGER,
  counted_cash   INTEGER,
  variance       INTEGER,
  note           TEXT
);
CREATE INDEX IF NOT EXISTS idx_shifts_status ON shifts(status);

CREATE TABLE IF NOT EXISTS payments (
  id                    INTEGER PRIMARY KEY AUTOINCREMENT,
  order_id              INTEGER NOT NULL REFERENCES orders(id) ON DELETE CASCADE,
  shift_id              INTEGER REFERENCES shifts(id) ON DELETE SET NULL,
  -- 'credit' = ขายเชื่อลงบัญชีลูกค้า (ดู docs/tickets/20-b2b-credit.md) ปิดบิลได้โดยยังไม่มีเงินเข้า
  -- กลายเป็นลูกหนี้ที่รับชำระภายหลังผ่าน ar_receipts — ฐานข้อมูลเดิมที่ CHECK ยังไม่มี 'credit'
  -- ถูกสร้างตารางใหม่ให้ใน migrate.js (SQLite แก้ CHECK ของตารางที่มีอยู่แล้วไม่ได้)
  method                TEXT    NOT NULL CHECK (method IN ('cash', 'qr', 'card', 'transfer', 'credit')),
  amount                INTEGER NOT NULL CHECK (amount >= 0),
  received              INTEGER NOT NULL DEFAULT 0,
  change_amount         INTEGER NOT NULL DEFAULT 0,
  reference             TEXT,
  cashier_id            INTEGER REFERENCES users(id) ON DELETE SET NULL,
  -- แต้มสะสมที่ใช้แลกส่วนลดตอนจ่ายเงินรอบนี้ (ดู docs/tickets/09-customer-loyalty.md) —
  -- points_redeemed_value คือมูลค่าส่วนลดเป็นสตางค์ที่คำนวณจาก settings ณ เวลานั้น (snapshot ไว้
  -- เพราะ settings เปลี่ยนอัตราได้ภายหลัง)
  points_redeemed       INTEGER NOT NULL DEFAULT 0,
  points_redeemed_value INTEGER NOT NULL DEFAULT 0,
  -- วันครบกำหนดชำระของบิลขายเชื่อ (YYYY-MM-DD) — เฉพาะ method = 'credit'
  due_date              TEXT,
  created_at            TEXT    NOT NULL DEFAULT (datetime('now'))
);
CREATE INDEX IF NOT EXISTS idx_payments_order ON payments(order_id);
CREATE INDEX IF NOT EXISTS idx_payments_shift ON payments(shift_id);

-- คืนเงินหลังชำระเงินแล้ว — แยกจาก payment เดิมเสมอเพื่อเก็บ audit trail
-- (ดู docs/tickets/02-refund-flow.md)
CREATE TABLE IF NOT EXISTS refunds (
  id          INTEGER PRIMARY KEY AUTOINCREMENT,
  payment_id  INTEGER NOT NULL REFERENCES payments(id) ON DELETE RESTRICT,
  order_id    INTEGER NOT NULL REFERENCES orders(id) ON DELETE RESTRICT,
  amount      INTEGER NOT NULL CHECK (amount > 0),
  reason      TEXT    NOT NULL,
  refunded_by INTEGER NOT NULL REFERENCES users(id) ON DELETE RESTRICT,
  -- กะที่เปิดอยู่ตอนคืนเงิน (ไม่ใช่กะที่รับเงินมา) — เงินสดที่คืนออกจากลิ้นชักของกะนี้ ต้องหักจากยอดที่
  -- คาดไว้ตอนปิดกะ (ดู docs/DECISIONS.md #44) index สร้างใน migrate.js หลังเพิ่มคอลัมน์ให้ฐานข้อมูลเดิม
  shift_id    INTEGER REFERENCES shifts(id) ON DELETE SET NULL,
  created_at  TEXT    NOT NULL DEFAULT (datetime('now'))
);
CREATE INDEX IF NOT EXISTS idx_refunds_payment ON refunds(payment_id);
CREATE INDEX IF NOT EXISTS idx_refunds_order ON refunds(order_id);
CREATE INDEX IF NOT EXISTS idx_payments_created ON payments(created_at);

CREATE TABLE IF NOT EXISTS settings (
  key        TEXT PRIMARY KEY,
  value      TEXT NOT NULL,
  updated_at TEXT NOT NULL DEFAULT (datetime('now'))
);

-- ใบกำกับภาษี (ดู docs/tickets/07-tax-invoice.md) — แยกจากใบเสร็จปกติ (payments/receipt) เพราะมี
-- ข้อกำหนดตามกฎหมาย (ประมวลรัษฎากร มาตรา 86/4 เต็มรูป, มาตรา 86/6 อย่างย่อ) ที่ running number
-- ต้องเรียงต่อเนื่องไม่ซ้ำ/ไม่ข้าม จึง snapshot ข้อมูลร้าน+ยอดเงิน ณ เวลาที่ออกไว้ตรงนี้เลย
-- (เหมือน promotion_name_snapshot ดู docs/DECISIONS.md #14) ไม่อ้างอิงไปที่ settings/orders
-- เพราะสองตารางนั้นแก้ไขได้ภายหลัง จะทำให้ใบกำกับภาษีเก่าแสดงข้อมูลผิดเพี้ยนไปจากตอนออกจริง
CREATE TABLE IF NOT EXISTS tax_invoices (
  id                INTEGER PRIMARY KEY AUTOINCREMENT,
  order_id          INTEGER NOT NULL REFERENCES orders(id) ON DELETE RESTRICT,
  running_number    TEXT    NOT NULL UNIQUE,
  invoice_type      TEXT    NOT NULL CHECK (invoice_type IN ('abbreviated', 'full')),
  customer_name     TEXT,
  customer_address  TEXT,
  customer_tax_id   TEXT,
  store_name        TEXT    NOT NULL,
  store_tax_id      TEXT    NOT NULL,
  store_address     TEXT    NOT NULL,
  store_branch      TEXT,
  subtotal          INTEGER NOT NULL,
  vat               INTEGER NOT NULL,
  total             INTEGER NOT NULL,
  issued_by         INTEGER NOT NULL REFERENCES users(id) ON DELETE RESTRICT,
  issued_at         TEXT    NOT NULL DEFAULT (datetime('now')),
  voided_at         TEXT,
  void_reason       TEXT,
  voided_by         INTEGER REFERENCES users(id) ON DELETE SET NULL
);
-- ออกได้แค่ 1 ใบ "active" (ยังไม่ถูกยกเลิก) ต่อออเดอร์ ณ ขณะใดขณะหนึ่ง — ยกเลิกใบเดิมก่อนแล้วออกใหม่ได้
-- แต่เลขที่รันไปแล้วจะไม่ถูกใช้ซ้ำแม้ใบนั้นจะถูกยกเลิก (ต้องรักษาลำดับเลขที่ให้ต่อเนื่องไม่มีช่องว่างที่อธิบายไม่ได้)
CREATE UNIQUE INDEX IF NOT EXISTS idx_tax_invoices_active_order
  ON tax_invoices(order_id) WHERE voided_at IS NULL;
CREATE INDEX IF NOT EXISTS idx_tax_invoices_order ON tax_invoices(order_id);

-- Audit log — บันทึกการกระทำที่เสี่ยงต่อการทุจริตหน้าร้าน (ดู docs/tickets/08-audit-log.md)
-- append-only เสมอ: ไม่มี endpoint แก้ไข/ลบเปิดให้ใช้เลยทั้งระบบ — snapshot ชื่อผู้ทำไว้ที่ actor_name
-- ตรงๆ (เหมือน promotion_name_snapshot/tax_invoices ด้านบน) เพื่อให้ log ยังอ่านได้ครบแม้ผู้ใช้คนนั้น
-- ถูกลบภายหลัง (actor_user_id เป็น ON DELETE SET NULL ไม่ใช่ RESTRICT เพราะไม่ควรบล็อกการลบ user
-- แค่เพราะเคยมี log อ้างถึง — ข้อมูลที่ต้องอ่านได้เสมอคือ actor_name ที่ snapshot ไว้แล้ว)
CREATE TABLE IF NOT EXISTS audit_logs (
  id            INTEGER PRIMARY KEY AUTOINCREMENT,
  actor_user_id INTEGER REFERENCES users(id) ON DELETE SET NULL,
  actor_name    TEXT    NOT NULL,
  action        TEXT    NOT NULL,
  entity_type   TEXT    NOT NULL,
  entity_id     INTEGER,
  summary       TEXT    NOT NULL,
  reason        TEXT,
  metadata_json TEXT,
  created_at    TEXT    NOT NULL DEFAULT (datetime('now'))
);
CREATE INDEX IF NOT EXISTS idx_audit_logs_created ON audit_logs(created_at);
CREATE INDEX IF NOT EXISTS idx_audit_logs_actor ON audit_logs(actor_user_id);
CREATE INDEX IF NOT EXISTS idx_audit_logs_action ON audit_logs(action);
CREATE INDEX IF NOT EXISTS idx_audit_logs_entity ON audit_logs(entity_type, entity_id);

-- ผู้ช่วย AI ถามตอบข้อมูลร้าน (ดู docs/tickets/15-ai-ask-your-data.md) — เก็บทุกคำถาม/คำตอบไว้เพื่อ
-- (1) จำกัดจำนวนคำถามต่อคนต่อวัน (นับจาก created_at ในตารางนี้เอง ไม่ต้องมีตารางตัวนับแยก) และ
-- (2) ตรวจสอบย้อนหลังได้ว่า AI ใช้ tool ไหนตอบ กันข้อครหาว่าตอบมั่ว — แยกจาก audit_logs เพราะ
-- คนละเรื่องกัน (audit_logs = ใครทำอะไรกับข้อมูลจริง, ตารางนี้ = ใครถาม AI อะไรและ AI ใช้ข้อมูลไหนตอบ)
CREATE TABLE IF NOT EXISTS ai_assistant_queries (
  id              INTEGER PRIMARY KEY AUTOINCREMENT,
  actor_user_id   INTEGER REFERENCES users(id) ON DELETE SET NULL,
  actor_name      TEXT    NOT NULL,
  question        TEXT    NOT NULL,
  answer          TEXT,
  tool_calls_json TEXT,
  input_tokens    INTEGER NOT NULL DEFAULT 0,
  output_tokens   INTEGER NOT NULL DEFAULT 0,
  is_error        INTEGER NOT NULL DEFAULT 0,
  error_message   TEXT,
  created_at      TEXT    NOT NULL DEFAULT (datetime('now'))
);
CREATE INDEX IF NOT EXISTS idx_ai_assistant_queries_actor_date
  ON ai_assistant_queries(actor_user_id, created_at);

-- ============================================================================================
-- ลูกหนี้การค้า / ขายเชื่อ (ดู docs/tickets/20-b2b-credit.md, docs/DECISIONS.md #50)
-- "ใบแจ้งหนี้" แต่ละใบคือ payments แถวที่ method = 'credit' — ยอดค้าง = amount − คืนเงิน (refunds)
-- − ยอดที่ตัดชำระแล้ว (ar_allocations จากใบเสร็จที่ยังไม่ถูกยกเลิก) ไม่มีคอลัมน์ "ยอดค้าง" เก็บแยก
-- เพื่อไม่ให้ตัวเลขสองแหล่งเพี้ยนจากกัน
-- ============================================================================================

-- ใบเสร็จรับชำระหนี้ — เงินสดเข้าลิ้นชักของกะที่เปิดอยู่ตอนรับ (shift_id) เหมือนรับชำระค่าอาหาร
CREATE TABLE IF NOT EXISTS ar_receipts (
  id           INTEGER PRIMARY KEY AUTOINCREMENT,
  receipt_no   TEXT    NOT NULL UNIQUE,
  customer_id  INTEGER NOT NULL REFERENCES customers(id) ON DELETE RESTRICT,
  amount       INTEGER NOT NULL CHECK (amount > 0),
  method       TEXT    NOT NULL CHECK (method IN ('cash', 'qr', 'card', 'transfer')),
  reference    TEXT,
  note         TEXT,
  shift_id     INTEGER REFERENCES shifts(id) ON DELETE SET NULL,
  received_by  INTEGER NOT NULL REFERENCES users(id) ON DELETE RESTRICT,
  received_at  TEXT    NOT NULL DEFAULT (datetime('now')),
  voided_at    TEXT,
  void_reason  TEXT,
  voided_by    INTEGER REFERENCES users(id) ON DELETE SET NULL
);
CREATE INDEX IF NOT EXISTS idx_ar_receipts_customer ON ar_receipts(customer_id);
CREATE INDEX IF NOT EXISTS idx_ar_receipts_shift ON ar_receipts(shift_id);

-- ใบเสร็จหนึ่งใบตัดชำระได้หลายบิลขายเชื่อ (เก่าสุดก่อน) — บันทึกไว้ตอนรับเงินเลย ไม่คำนวณใหม่ทุกครั้ง
-- บิลที่ถูกตัดไปแล้วจึงไม่ย้ายไปมาเมื่อมีบิลใหม่หรือมีการคืนเงินภายหลัง
CREATE TABLE IF NOT EXISTS ar_allocations (
  id          INTEGER PRIMARY KEY AUTOINCREMENT,
  receipt_id  INTEGER NOT NULL REFERENCES ar_receipts(id) ON DELETE CASCADE,
  payment_id  INTEGER NOT NULL REFERENCES payments(id) ON DELETE RESTRICT,
  amount      INTEGER NOT NULL CHECK (amount > 0)
);
CREATE INDEX IF NOT EXISTS idx_ar_allocations_receipt ON ar_allocations(receipt_id);
CREATE INDEX IF NOT EXISTS idx_ar_allocations_payment ON ar_allocations(payment_id);

-- ใบวางบิล — รวบบิลขายเชื่อที่ยังค้างของลูกค้าหนึ่งรายไว้ในเอกสารเดียวพร้อมวันนัดชำระ snapshot ยอด
-- ณ วันที่ออกไว้ที่ billing_note_items (เอกสารที่ส่งให้ลูกค้าไปแล้วต้องพิมพ์ซ้ำได้ตัวเลขเดิม) — บิลหนึ่ง
-- อยู่ในใบวางบิลที่ยังไม่ถูกยกเลิกได้ใบเดียว (เช็คใน service) ยกเลิกแล้ววางบิลใหม่ได้
CREATE TABLE IF NOT EXISTS billing_notes (
  id           INTEGER PRIMARY KEY AUTOINCREMENT,
  note_no      TEXT    NOT NULL UNIQUE,
  customer_id  INTEGER NOT NULL REFERENCES customers(id) ON DELETE RESTRICT,
  total        INTEGER NOT NULL CHECK (total > 0),
  due_date     TEXT    NOT NULL,
  note         TEXT,
  issued_by    INTEGER NOT NULL REFERENCES users(id) ON DELETE RESTRICT,
  issued_at    TEXT    NOT NULL DEFAULT (datetime('now')),
  voided_at    TEXT,
  void_reason  TEXT,
  voided_by    INTEGER REFERENCES users(id) ON DELETE SET NULL
);
CREATE INDEX IF NOT EXISTS idx_billing_notes_customer ON billing_notes(customer_id);

CREATE TABLE IF NOT EXISTS billing_note_items (
  id               INTEGER PRIMARY KEY AUTOINCREMENT,
  billing_note_id  INTEGER NOT NULL REFERENCES billing_notes(id) ON DELETE CASCADE,
  payment_id       INTEGER NOT NULL REFERENCES payments(id) ON DELETE RESTRICT,
  amount           INTEGER NOT NULL CHECK (amount > 0)
);
CREATE INDEX IF NOT EXISTS idx_billing_note_items_note ON billing_note_items(billing_note_id);
CREATE INDEX IF NOT EXISTS idx_billing_note_items_payment ON billing_note_items(payment_id);

-- ใบแจ้งดอกเบี้ยผิดนัดชำระ (ดู docs/tickets/21-late-fees-credit-notes.md, docs/DECISIONS.md #55)
-- ผู้จัดการเป็นคนกดคิด ไม่คิดเองเงียบ ๆ — ดอกเบี้ยแต่ละบรรทัดผูกกับบิลขายเชื่อที่เกินกำหนด (payment_id)
-- แล้วบวกเข้ายอดค้างของบิลนั้นเลย ใบเสร็จรับชำระ/ใบวางบิลจึงเก็บดอกเบี้ยไปพร้อมกันโดยไม่ต้องมีเส้นทางใหม่
-- period_to ของบรรทัดล่าสุดคือ "คิดถึงวันไหนแล้ว" รอบต่อไปเริ่มนับวันถัดไป จึงไม่คิดซ้ำวันเดิม
CREATE TABLE IF NOT EXISTS ar_charges (
  id           INTEGER PRIMARY KEY AUTOINCREMENT,
  charge_no    TEXT    NOT NULL UNIQUE,
  customer_id  INTEGER NOT NULL REFERENCES customers(id) ON DELETE RESTRICT,
  total        INTEGER NOT NULL CHECK (total > 0),
  annual_rate  REAL    NOT NULL CHECK (annual_rate > 0),
  as_of        TEXT    NOT NULL,
  note         TEXT,
  issued_by    INTEGER NOT NULL REFERENCES users(id) ON DELETE RESTRICT,
  issued_at    TEXT    NOT NULL DEFAULT (datetime('now')),
  voided_at    TEXT,
  void_reason  TEXT,
  voided_by    INTEGER REFERENCES users(id) ON DELETE SET NULL
);
CREATE INDEX IF NOT EXISTS idx_ar_charges_customer ON ar_charges(customer_id);

CREATE TABLE IF NOT EXISTS ar_charge_items (
  id           INTEGER PRIMARY KEY AUTOINCREMENT,
  charge_id    INTEGER NOT NULL REFERENCES ar_charges(id) ON DELETE CASCADE,
  payment_id   INTEGER NOT NULL REFERENCES payments(id) ON DELETE RESTRICT,
  principal    INTEGER NOT NULL CHECK (principal > 0),
  period_from  TEXT    NOT NULL,
  period_to    TEXT    NOT NULL,
  days         INTEGER NOT NULL CHECK (days > 0),
  amount       INTEGER NOT NULL CHECK (amount > 0)
);
CREATE INDEX IF NOT EXISTS idx_ar_charge_items_charge ON ar_charge_items(charge_id);
CREATE INDEX IF NOT EXISTS idx_ar_charge_items_payment ON ar_charge_items(payment_id);

-- ใบลดหนี้ (ดู docs/DECISIONS.md #56) — เอกสารของการลดหนี้บิลขายเชื่อ ตัวเลขทางบัญชีจริงยังอยู่ที่ refunds
-- (ยอดขายสุทธิ/ยอดค้างที่มีอยู่แล้วใช้ต่อได้หมด) ใบนี้เก็บเลขที่เอกสาร เหตุผล ยอดเดิม/ยอดที่ถูกต้อง/ผลต่าง
-- และ VAT ของผลต่าง ตามที่ใบลดหนี้ต้องแสดง — ไม่มีการยกเลิก ถ้าลดผิดให้คิดดอกเบี้ย/ขายเพิ่มเป็นรายการใหม่
CREATE TABLE IF NOT EXISTS credit_notes (
  id                 INTEGER PRIMARY KEY AUTOINCREMENT,
  note_no            TEXT    NOT NULL UNIQUE,
  customer_id        INTEGER NOT NULL REFERENCES customers(id) ON DELETE RESTRICT,
  payment_id         INTEGER NOT NULL REFERENCES payments(id) ON DELETE RESTRICT,
  refund_id          INTEGER NOT NULL UNIQUE REFERENCES refunds(id) ON DELETE RESTRICT,
  order_id           INTEGER NOT NULL REFERENCES orders(id) ON DELETE RESTRICT,
  original_amount    INTEGER NOT NULL,
  previous_credited  INTEGER NOT NULL DEFAULT 0,
  amount             INTEGER NOT NULL CHECK (amount > 0),
  vat_amount         INTEGER NOT NULL DEFAULT 0,
  tax_invoice_no     TEXT,
  reason             TEXT    NOT NULL,
  issued_by          INTEGER NOT NULL REFERENCES users(id) ON DELETE RESTRICT,
  issued_at          TEXT    NOT NULL DEFAULT (datetime('now'))
);
CREATE INDEX IF NOT EXISTS idx_credit_notes_customer ON credit_notes(customer_id);

-- ประวัติส่งเอกสารลูกหนี้ทางอีเมล (ดู docs/DECISIONS.md #57) — เก็บว่าส่งฉบับไหน ถึงใคร เมื่อไร โดยใคร
CREATE TABLE IF NOT EXISTS document_emails (
  id           INTEGER PRIMARY KEY AUTOINCREMENT,
  kind         TEXT    NOT NULL CHECK (kind IN ('billing_note', 'receipt', 'credit_note', 'late_fee')),
  document_id  INTEGER NOT NULL,
  to_address   TEXT    NOT NULL,
  subject      TEXT    NOT NULL,
  message_id   TEXT,
  sent_by      INTEGER NOT NULL REFERENCES users(id) ON DELETE RESTRICT,
  sent_at      TEXT    NOT NULL DEFAULT (datetime('now'))
);
CREATE INDEX IF NOT EXISTS idx_document_emails_document ON document_emails(kind, document_id);
