// Copyright 2026 Suruch Chakrapeesirisuk
// SPDX-License-Identifier: Apache-2.0

import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
import { randomUUID } from 'node:crypto';

/**
 * Migration 0001 — ทุกอย่างที่ migrate.js เคยรันทุกครั้งที่ boot ก่อน T01 (#80, docs/DECISIONS.md #79):
 * `0001_baseline.sql` (schema.sql เดิม) ตามด้วย patch ที่เพิ่มคอลัมน์/ย้ายข้อมูลให้ฐานข้อมูลรุ่นก่อน ๆ
 *
 * ทุกขั้นเช็คก่อนทำ จึงใช้ได้ทั้งกับฐานข้อมูลใหม่ล้วน และกับฐานข้อมูลของร้านที่สร้างก่อน T01 ซึ่งยังไม่มี
 * ตาราง schema_migrations — migration นี้จะรันกับฐานข้อมูลนั้นครั้งเดียว พาขึ้นมาถึงจุดเดียวกัน แล้วถูกบันทึกว่า
 * รันแล้ว จากนี้ไปการเปลี่ยน schema ทุกครั้งเป็น migration เลขถัดไป ไฟล์นี้กับ .sql ของมันถูกแช่แข็ง (checksum)
 *
 * `foreignKeys: false` เพราะการสร้างตาราง payments ใหม่ (ticket 20) ต้องลบตารางเดิมที่ refunds/ar_allocations
 * อ้างถึง ตัวรันจึงปิด foreign_keys ก่อนเปิด transaction และตรวจ `foreign_key_check` ก่อน commit
 */

const here = path.dirname(fileURLToPath(import.meta.url));
export const BASELINE_SQL = path.join(here, '0001_baseline.sql');

/**
 * เพิ่มคอลัมน์ให้ตารางที่มีอยู่แล้ว (CREATE TABLE IF NOT EXISTS ไม่แก้ตารางเดิมที่มีอยู่แล้วให้อัตโนมัติ)
 * บางคอลัมน์ (เช่น auto_disabled_by_stock) ไม่ได้อยู่ใน CREATE TABLE ของ .sql เลย ตั้งใจพึ่งขั้นนี้อย่างเดียว
 */
const addColumnIfMissing = (db, table, column, definition) => {
  const columns = db.prepare(`PRAGMA table_info(${table})`).all();
  if (columns.some((row) => row.name === column)) return;
  db.exec(`ALTER TABLE ${table} ADD COLUMN ${column} ${definition}`);
};

const BRANCH_SCOPED_TABLES = ['dining_tables', 'menu_items', 'orders', 'ingredients'];

/**
 * ฐานข้อมูลสาขาเดียวเดิม (ก่อน ticket 11) — ทุกแถวเดิมได้ branch_id = NULL จึงสร้างสาขา fallback ("สาขาหลัก")
 * ให้เฉพาะตอนพบข้อมูลเก่าที่ยังไม่มีสาขาจริงเท่านั้น (docs/DECISIONS.md #36) ฐานข้อมูลใหม่ล้วนไม่ได้สาขานี้
 * ปล่อยให้ seed.js สร้างสาขาจริงเอง
 */
const backfillDefaultBranch = (db) => {
  const hasUnscopedRows = BRANCH_SCOPED_TABLES.some((table) =>
    db.prepare(`SELECT 1 FROM ${table} WHERE branch_id IS NULL LIMIT 1`).get(),
  );
  if (!hasUnscopedRows) return;

  let defaultBranch = db.prepare('SELECT id FROM branches ORDER BY id LIMIT 1').get();
  if (!defaultBranch) {
    const info = db
      .prepare('INSERT INTO branches (name, code) VALUES (?, ?)')
      .run('สาขาหลัก', 'MAIN');
    defaultBranch = { id: info.lastInsertRowid };
  }

  for (const table of BRANCH_SCOPED_TABLES) {
    db.prepare(`UPDATE ${table} SET branch_id = ? WHERE branch_id IS NULL`).run(defaultBranch.id);
  }

  // ให้ผู้ใช้เดิมทุกคนเข้าสาขา fallback ได้ทันที ไม่งั้นจะล็อกอินไม่ได้หลังอัปเกรด
  const insertMembership = db.prepare(
    'INSERT OR IGNORE INTO user_branches (user_id, branch_id) VALUES (?, ?)',
  );
  for (const user of db.prepare('SELECT id FROM users').all()) {
    insertMembership.run(user.id, defaultBranch.id);
  }
};

/**
 * ticket 17 (QR สั่งอาหารเอง) — โต๊ะที่สร้างก่อนทิกเก็ตนี้ยังไม่มี qr_token เติมให้ครบทุกแถวก่อนสร้าง
 * UNIQUE INDEX โต๊ะที่สร้างหลังจากนี้ได้ token ตั้งแต่ตอน insert (table.repository.js#create)
 */
const backfillTableQrTokens = (db) => {
  const rows = db.prepare('SELECT id FROM dining_tables WHERE qr_token IS NULL').all();
  const update = db.prepare('UPDATE dining_tables SET qr_token = ? WHERE id = ?');
  for (const row of rows) update.run(randomUUID(), row.id);
};

/**
 * ticket 20 (ขายเชื่อ) — payments.method ในฐานข้อมูลรุ่นก่อนมี CHECK ที่ไม่รู้จัก 'credit' และ SQLite แก้
 * CHECK ของตารางที่มีอยู่แล้วไม่ได้ จึงสร้างตารางใหม่แล้วย้ายข้อมูล (สร้าง → คัดลอก → ลบเก่า → เปลี่ยนชื่อ)
 * นิยามตารางใหม่อ่านจากบล็อก CREATE TABLE payments ใน .sql ตรง ๆ id เดิมคงไว้ทุกแถว refunds/ar_allocations
 * จึงยังชี้ถูกแถว ตารางที่มี 'credit' แล้วถูกข้ามทันที
 */
const rebuildPaymentsForCreditMethod = (db, schemaSql) => {
  const current = db
    .prepare("SELECT sql FROM sqlite_master WHERE type = 'table' AND name = 'payments'")
    .get();
  // ดูเฉพาะรายการใน CHECK (method IN (...)) ไม่ใช่ทั้งข้อความ — คอมเมนต์ที่เอ่ยถึง 'credit' ต้องไม่หลอกให้ข้าม
  const allowed = current?.sql.match(/CHECK\s*\(\s*method\s+IN\s*\(([^)]*)\)\s*\)/i)?.[1] ?? '';
  if (!current || allowed.includes("'credit'")) return;

  const block = schemaSql.match(/CREATE TABLE IF NOT EXISTS payments \(([\s\S]*?)\n\);/);
  if (!block) throw new Error('หานิยามตาราง payments ใน 0001_baseline.sql ไม่เจอ');

  const oldColumns = db
    .prepare('PRAGMA table_info(payments)')
    .all()
    .map((row) => row.name);
  db.exec(`CREATE TABLE payments_rebuild (${block[1]}\n)`);
  const newColumns = db
    .prepare('PRAGMA table_info(payments_rebuild)')
    .all()
    .map((row) => row.name);
  const shared = newColumns.filter((column) => oldColumns.includes(column)).join(', ');
  db.exec(`INSERT INTO payments_rebuild (${shared}) SELECT ${shared} FROM payments`);
  db.exec('DROP TABLE payments');
  db.exec('ALTER TABLE payments_rebuild RENAME TO payments');
  db.exec('CREATE INDEX IF NOT EXISTS idx_payments_order ON payments(order_id)');
  db.exec('CREATE INDEX IF NOT EXISTS idx_payments_shift ON payments(shift_id)');
  db.exec('CREATE INDEX IF NOT EXISTS idx_payments_created ON payments(created_at)');
};

export default {
  version: 1,
  name: 'baseline',
  files: [fileURLToPath(import.meta.url), BASELINE_SQL],
  foreignKeys: false,
  up(db) {
    const sql = fs.readFileSync(BASELINE_SQL, 'utf8');
    db.exec(sql);

    addColumnIfMissing(db, 'order_items', 'is_paid', 'INTEGER NOT NULL DEFAULT 0');
    addColumnIfMissing(
      db,
      'payments',
      'shift_id',
      'INTEGER REFERENCES shifts(id) ON DELETE SET NULL',
    );
    // เงินสดที่คืนออกจากลิ้นชักของกะที่เปิดอยู่ตอนคืน (docs/DECISIONS.md #44) — index อยู่ที่นี่ ไม่ใช่ใน .sql
    // เพราะฐานข้อมูลเดิมที่ยังไม่มีคอลัมน์นี้จะพังตั้งแต่ CREATE INDEX ก่อนได้เพิ่มคอลัมน์
    addColumnIfMissing(
      db,
      'refunds',
      'shift_id',
      'INTEGER REFERENCES shifts(id) ON DELETE SET NULL',
    );
    db.exec('CREATE INDEX IF NOT EXISTS idx_refunds_shift ON refunds(shift_id)');
    addColumnIfMissing(
      db,
      'orders',
      'promotion_id',
      'INTEGER REFERENCES promotions(id) ON DELETE SET NULL',
    );
    addColumnIfMissing(db, 'orders', 'promotion_name_snapshot', 'TEXT');
    addColumnIfMissing(db, 'orders', 'promotion_code_snapshot', 'TEXT');
    addColumnIfMissing(db, 'orders', 'promotion_discount_amount', 'INTEGER NOT NULL DEFAULT 0');
    addColumnIfMissing(db, 'order_items', 'stock_deducted', 'INTEGER NOT NULL DEFAULT 0');
    addColumnIfMissing(db, 'menu_items', 'auto_disabled_by_stock', 'INTEGER NOT NULL DEFAULT 0');
    // ticket 09 (ลูกค้า/แต้มสะสม)
    addColumnIfMissing(
      db,
      'orders',
      'customer_id',
      'INTEGER REFERENCES customers(id) ON DELETE SET NULL',
    );
    addColumnIfMissing(db, 'orders', 'points_earned', 'INTEGER NOT NULL DEFAULT 0');
    addColumnIfMissing(db, 'payments', 'points_redeemed', 'INTEGER NOT NULL DEFAULT 0');
    addColumnIfMissing(db, 'payments', 'points_redeemed_value', 'INTEGER NOT NULL DEFAULT 0');
    addColumnIfMissing(db, 'orders', 'queue_number', 'INTEGER');

    // ticket 11 (หลายสาขา) — branch_id ผูกแค่ 4 entity นี้ (docs/DECISIONS.md #36)
    for (const table of BRANCH_SCOPED_TABLES) {
      addColumnIfMissing(
        db,
        table,
        'branch_id',
        'INTEGER REFERENCES branches(id) ON DELETE SET NULL',
      );
    }
    backfillDefaultBranch(db);

    // ticket 17 (QR สั่งอาหารเอง) — token สุ่มไม่ซ้ำต่อโต๊ะ กันการเดา table id ใน URL สาธารณะ
    addColumnIfMissing(db, 'dining_tables', 'qr_token', 'TEXT');
    backfillTableQrTokens(db);
    db.exec(
      'CREATE UNIQUE INDEX IF NOT EXISTS idx_dining_tables_qr_token ON dining_tables(qr_token)',
    );

    // ticket 18 (ขายตามน้ำหนัก) + 19 (บาร์โค้ด/ฉลากตาชั่ง)
    addColumnIfMissing(db, 'menu_items', 'sold_by_weight', 'INTEGER NOT NULL DEFAULT 0');
    addColumnIfMissing(db, 'menu_items', 'barcode', 'TEXT');
    addColumnIfMissing(db, 'menu_items', 'scale_plu', 'TEXT');
    db.exec('CREATE INDEX IF NOT EXISTS idx_menu_items_barcode ON menu_items(barcode)');
    db.exec('CREATE INDEX IF NOT EXISTS idx_menu_items_scale_plu ON menu_items(scale_plu)');
    addColumnIfMissing(
      db,
      'order_items',
      'weight_grams',
      'INTEGER CHECK (weight_grams IS NULL OR weight_grams > 0)',
    );

    // ticket 20 (ขายเชื่อ/ลูกหนี้) — ลูกค้าเดิมไม่มีวงเงินเครดิตจนกว่าผู้จัดการจะตั้งให้
    addColumnIfMissing(
      db,
      'customers',
      'credit_limit',
      'INTEGER NOT NULL DEFAULT 0 CHECK (credit_limit >= 0)',
    );
    addColumnIfMissing(
      db,
      'customers',
      'credit_term_days',
      'INTEGER NOT NULL DEFAULT 30 CHECK (credit_term_days >= 0)',
    );
    addColumnIfMissing(db, 'customers', 'tax_id', 'TEXT');
    addColumnIfMissing(db, 'customers', 'address', 'TEXT');
    addColumnIfMissing(db, 'payments', 'due_date', 'TEXT');
    rebuildPaymentsForCreditMethod(db, sql);
  },
};
