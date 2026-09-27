// Copyright 2026 Suruch Chakrapeesirisuk
// SPDX-License-Identifier: Apache-2.0

import test, { after } from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';
import os from 'node:os';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
import Database from 'better-sqlite3';

// ฐานข้อมูลของร้านที่ใช้งานอยู่แล้วก่อน ticket 20 — payments.method มี CHECK ที่ไม่รู้จัก 'credit'
// และ SQLite แก้ CHECK ของตารางเดิมไม่ได้ migrate.js จึงสร้างตาราง payments ใหม่แล้วย้ายข้อมูล
// เทสต์นี้สร้างฐานข้อมูล "รุ่นก่อน" จริง ๆ ขึ้นมาก่อน แล้วพิสูจน์ว่าย้ายแล้วข้อมูลเงินไม่หายสักแถว

const here = path.dirname(fileURLToPath(import.meta.url));
const dir = fs.mkdtempSync(path.join(os.tmpdir(), 'payneat-migrate-'));
const dbFile = path.join(dir, 'legacy.sqlite');

process.env.NODE_ENV = 'test';
process.env.JWT_SECRET = 'test-secret';
process.env.DATABASE_FILE = dbFile;

/** baseline (schema.sql เดิม) ถอยกลับเป็นรุ่นก่อน ticket 20 เฉพาะส่วน payments ที่เปลี่ยน */
const legacySchema = () => {
  const current = fs.readFileSync(
    path.join(here, '../src/db/migrations/0001_baseline.sql'),
    'utf8',
  );
  // คงคอมเมนต์ที่เอ่ยถึง 'credit' ไว้ในนิยามตารางโดยตั้งใจ — migrate.js ต้องดูที่ CHECK จริง ไม่ใช่
  // แค่ค้นข้อความ (รอบแรกค้นทั้งข้อความแล้วถูกคอมเมนต์หลอกว่าย้ายไปแล้ว)
  const legacy = current
    .replace("'cash', 'qr', 'card', 'transfer', 'credit'", "'cash', 'qr', 'card', 'transfer'")
    .replace(/\n\s*due_date\s+TEXT,/, '');
  assert.notEqual(legacy, current, 'ต้องถอย schema ได้จริง ไม่งั้นเทสต์นี้ไม่ได้ทดสอบอะไร');
  assert.ok(!legacy.includes("'transfer', 'credit'"));
  return legacy;
};

const { closeDb } = await import('../src/db/index.js');
after(() => {
  closeDb();
  fs.rmSync(dir, { recursive: true, force: true });
});

test('ย้ายตาราง payments ให้รับ credit ได้ โดยข้อมูลเดิม/ refund ที่อ้างถึง/ index อยู่ครบ', async () => {
  const legacy = new Database(dbFile);
  legacy.exec(legacySchema());
  legacy
    .prepare(
      "INSERT INTO users (id, name, username, password_hash, role) VALUES (7, 'แอน', 'ann', 'x', 'cashier')",
    )
    .run();
  legacy
    .prepare("INSERT INTO orders (id, code, status, total) VALUES (42, 'ORD-42', 'paid', 11770)")
    .run();
  legacy
    .prepare(
      `INSERT INTO payments (id, order_id, method, amount, received, change_amount, cashier_id)
       VALUES (901, 42, 'cash', 11770, 20000, 8230, 7)`,
    )
    .run();
  legacy
    .prepare(
      "INSERT INTO refunds (id, payment_id, order_id, amount, reason, refunded_by) VALUES (5, 901, 42, 1000, 'ของเสีย', 7)",
    )
    .run();
  assert.throws(
    () =>
      legacy
        .prepare("INSERT INTO payments (order_id, method, amount) VALUES (42, 'credit', 1)")
        .run(),
    /CHECK constraint failed/,
    'ฐานข้อมูลรุ่นก่อนต้องยังรับ credit ไม่ได้จริง',
  );
  legacy.close();

  const { migrate } = await import('../src/db/migrate.js');
  const db = migrate();

  const sql = db.prepare("SELECT sql FROM sqlite_master WHERE name = 'payments'").get().sql;
  assert.ok(sql.includes("'transfer', 'credit'"));

  const payment = db.prepare('SELECT * FROM payments WHERE id = 901').get();
  assert.equal(payment.order_id, 42);
  assert.equal(payment.amount, 11770);
  assert.equal(payment.received, 20000);
  assert.equal(payment.change_amount, 8230);
  assert.equal(payment.cashier_id, 7);
  assert.equal(payment.due_date, null);

  const refund = db
    .prepare('SELECT p.amount FROM refunds r JOIN payments p ON p.id = r.payment_id WHERE r.id = 5')
    .get();
  assert.equal(refund.amount, 11770, 'refund ต้องยังชี้ payment แถวเดิม');
  assert.deepEqual(db.pragma('foreign_key_check'), []);
  assert.equal(db.pragma('foreign_keys', { simple: true }), 1, 'ต้องเปิด foreign_keys คืน');

  const indexes = db
    .prepare("SELECT name FROM sqlite_master WHERE type = 'index' AND tbl_name = 'payments'")
    .all()
    .map((row) => row.name);
  for (const name of ['idx_payments_order', 'idx_payments_shift', 'idx_payments_created']) {
    assert.ok(indexes.includes(name), `ต้องสร้าง ${name} คืน`);
  }

  db.prepare(
    "INSERT INTO payments (order_id, method, amount, due_date) VALUES (42, 'credit', 500, '2099-01-01')",
  ).run();

  // รันซ้ำต้องไม่สร้างตารางใหม่ทับ (ข้อมูลที่เพิ่งเพิ่มต้องยังอยู่)
  migrate();
  assert.equal(db.prepare("SELECT COUNT(*) AS c FROM payments WHERE method = 'credit'").get().c, 1);
});
