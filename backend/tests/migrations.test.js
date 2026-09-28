// Copyright 2026 Suruch Chakrapeesirisuk
// SPDX-License-Identifier: Apache-2.0

import test, { after, describe } from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';
import os from 'node:os';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
import Database from 'better-sqlite3';

// Migration แบบมีเวอร์ชัน (T01 #80, docs/DECISIONS.md #79): รันครั้งเดียว, ล้มแล้ว rollback ทั้งตัว,
// ฐานข้อมูลที่สร้างก่อน T01 อัปเกรดได้โดยข้อมูลไม่หาย และ migration ที่รันแล้วถูกแก้ไม่ได้

const here = path.dirname(fileURLToPath(import.meta.url));
const dir = fs.mkdtempSync(path.join(os.tmpdir(), 'payneat-migrations-'));
const dbFile = path.join(dir, 'shop.sqlite');

process.env.NODE_ENV = 'test';
process.env.JWT_SECRET = 'test-secret';
process.env.DATABASE_FILE = dbFile;

const { runMigrations, migrate } = await import('../src/db/migrate.js');
const { MIGRATIONS, checksumOf } = await import('../src/db/migrations/index.js');
const { seed } = await import('../src/db/seed.js');
const { getDb, closeDb } = await import('../src/db/index.js');

after(() => {
  closeDb();
  fs.rmSync(dir, { recursive: true, force: true });
});

const tableExists = (db, name) =>
  Boolean(db.prepare("SELECT 1 FROM sqlite_master WHERE type = 'table' AND name = ?").get(name));
const recorded = (db) =>
  db
    .prepare('SELECT version, name, checksum, applied_at FROM schema_migrations ORDER BY version')
    .all();

/** migration สำหรับเทสต์: นับว่าถูกรันกี่ครั้งในตาราง runs */
const counting = (version, extra = () => {}) => ({
  version,
  name: `step_${version}`,
  checksum: `checksum-${version}`,
  up(db) {
    db.exec('CREATE TABLE IF NOT EXISTS runs (version INTEGER NOT NULL)');
    db.prepare('INSERT INTO runs (version) VALUES (?)').run(version);
    extra(db);
  },
});

describe('the runner', () => {
  test('runs each migration once, in version order, however many times the server boots', () => {
    const db = new Database(':memory:');
    const list = [counting(2), counting(1)];
    assert.deepEqual(runMigrations(db, list), ['0001_step_1', '0002_step_2']);
    assert.deepEqual(runMigrations(db, list), []);
    assert.deepEqual(runMigrations(db, list), []);
    assert.deepEqual(
      db.prepare('SELECT version FROM runs ORDER BY rowid').all(),
      [{ version: 1 }, { version: 2 }],
      'ต้องรันตามลำดับเวอร์ชัน และรันครั้งเดียว',
    );
    // migration ใหม่ที่เพิ่มทีหลังรันต่อจากที่มีอยู่ ตัวเก่าไม่ถูกแตะ
    assert.deepEqual(runMigrations(db, [...list, counting(3)]), ['0003_step_3']);
    assert.equal(db.prepare('SELECT COUNT(*) AS c FROM runs').get().c, 3);
  });

  test('rolls a failing migration back whole, records nothing for it, and can run it again once fixed', () => {
    const db = new Database(':memory:');
    const broken = {
      version: 2,
      name: 'half_done',
      checksum: 'checksum-2',
      up(target) {
        target.exec('CREATE TABLE half (id INTEGER PRIMARY KEY)');
        target.exec('INSERT INTO half (id) VALUES (1)');
        target.exec('ALTER TABLE runs ADD COLUMN note TEXT');
        throw new Error('power cut');
      },
    };
    assert.throws(() => runMigrations(db, [counting(1), broken]), /power cut/);
    assert.equal(tableExists(db, 'half'), false, 'ตารางที่สร้างกลางทางต้องหายไปด้วย');
    assert.equal(
      db
        .prepare('PRAGMA table_info(runs)')
        .all()
        .some((column) => column.name === 'note'),
      false,
      'คอลัมน์ที่เพิ่มกลางทางต้องหายไปด้วย',
    );
    assert.deepEqual(
      recorded(db).map((row) => row.version),
      [1],
      'migration ที่ล้มต้องไม่ถูกบันทึกว่ารันแล้ว',
    );

    const fixed = { ...counting(2), name: 'half_done' };
    assert.deepEqual(runMigrations(db, [counting(1), fixed]), ['0002_half_done']);
  });

  test('checks foreign keys before committing a migration that runs without them', () => {
    const db = new Database(':memory:');
    db.pragma('foreign_keys = ON');
    const orphaning = {
      version: 1,
      name: 'orphaning',
      checksum: 'checksum-1',
      foreignKeys: false,
      up(target) {
        target.exec('CREATE TABLE parent (id INTEGER PRIMARY KEY)');
        target.exec('CREATE TABLE child (parent_id INTEGER REFERENCES parent(id))');
        target.exec('INSERT INTO child (parent_id) VALUES (99)');
      },
    };
    assert.throws(() => runMigrations(db, [orphaning]), /broke foreign keys/);
    assert.equal(tableExists(db, 'child'), false);
    assert.equal(db.pragma('foreign_keys', { simple: true }), 1, 'ต้องเปิด foreign_keys คืนเสมอ');
  });

  test('refuses to start when an applied migration changed, or the database is newer than the build', () => {
    const db = new Database(':memory:');
    runMigrations(db, [counting(1), counting(2)]);

    const edited = { ...counting(1), checksum: 'edited-later' };
    assert.throws(() => runMigrations(db, [edited, counting(2)]), /changed after it ran/);
    assert.throws(() => runMigrations(db, [counting(1)]), /newer PaynEat \(migration 2\)/);
  });
});

describe('the real migrations', () => {
  test('match checksums.json: an applied migration is never edited', () => {
    const manifest = JSON.parse(
      fs.readFileSync(path.join(here, '../src/db/migrations/checksums.json'), 'utf8'),
    );
    const current = Object.fromEntries(
      MIGRATIONS.map((m) => [`${String(m.version).padStart(4, '0')}_${m.name}`, m.checksum]),
    );
    assert.deepEqual(
      current,
      manifest,
      'migration ใหม่: ใส่ checksum ข้างบนลง src/db/migrations/checksums.json · migration ที่มีอยู่แล้ว: ห้ามแก้ ให้เพิ่ม migration ใหม่แทน',
    );
    for (const m of MIGRATIONS) {
      assert.equal(checksumOf(m.files), m.checksum);
      for (const file of m.files) assert.ok(fs.existsSync(file), `${file} ต้องมีอยู่จริง`);
    }
    assert.deepEqual(
      MIGRATIONS.map((m) => m.version),
      MIGRATIONS.map((_, i) => i + 1),
      'เลข migration ต้องเรียงต่อกันตั้งแต่ 1 ไม่ข้าม',
    );
  });

  test('a checkout with Windows line endings has the same checksum', () => {
    // ชื่อไฟล์เดียวกัน (checksum รวมชื่อไฟล์ด้วย) ต่างกันแค่ท้ายบรรทัด
    fs.mkdirSync(path.join(dir, 'lf'));
    fs.mkdirSync(path.join(dir, 'crlf'));
    const lf = path.join(dir, 'lf', '0002_example.sql');
    const crlf = path.join(dir, 'crlf', '0002_example.sql');
    fs.writeFileSync(lf, 'CREATE TABLE a (id INTEGER);\nSELECT 1;\n');
    fs.writeFileSync(crlf, 'CREATE TABLE a (id INTEGER);\r\nSELECT 1;\r\n');
    assert.equal(checksumOf([lf]), checksumOf([crlf]));
  });

  test('a database created before T01 upgrades once, with every seeded and sold row intact', () => {
    // ฐานข้อมูลของร้านก่อน T01 = ผลของ schema.sql + patch ทุกตัว (ตอนนี้คือ migration 0001) โดยไม่มี
    // schema_migrations — สร้างแบบนั้นขึ้นมา: seed บน schema ถึง 0001 มียอดขาย ชำระเงิน และคืนเงิน แล้วลบตารางติดตามทิ้ง
    seed({ migrations: MIGRATIONS.slice(0, 1) });
    const db = getDb();
    const cashier = db.prepare("SELECT id FROM users WHERE role = 'cashier' LIMIT 1").get();
    const branch = db.prepare('SELECT id FROM branches ORDER BY id LIMIT 1').get();
    const order = db
      .prepare(
        "INSERT INTO orders (code, status, total, branch_id) VALUES ('ORD-LEGACY-1', 'paid', 11770, ?)",
      )
      .run(branch.id);
    const payment = db
      .prepare(
        `INSERT INTO payments (order_id, method, amount, received, change_amount, cashier_id)
         VALUES (?, 'cash', 11770, 20000, 8230, ?)`,
      )
      .run(order.lastInsertRowid, cashier.id);
    db.prepare(
      "INSERT INTO refunds (payment_id, order_id, amount, reason, refunded_by) VALUES (?, ?, 1000, 'ของเสีย', ?)",
    ).run(payment.lastInsertRowid, order.lastInsertRowid, cashier.id);
    db.exec('DROP TABLE schema_migrations');

    const tables = db
      .prepare(
        "SELECT name FROM sqlite_master WHERE type = 'table' AND name NOT LIKE 'sqlite_%' ORDER BY name",
      )
      .all()
      .map((row) => row.name);
    const counts = () =>
      Object.fromEntries(
        tables.map((name) => [name, db.prepare(`SELECT COUNT(*) AS c FROM "${name}"`).get().c]),
      );
    const before = counts();
    assert.ok(
      before.users > 0 && before.menu_items > 0 && before.payments > 0,
      'ต้องมีข้อมูลจริงให้ตรวจ',
    );

    migrate();

    assert.deepEqual(counts(), before, 'ทุกตารางต้องมีจำนวนแถวเท่าเดิม');
    assert.deepEqual(
      recorded(db).map((row) => [row.version, row.name, row.checksum]),
      MIGRATIONS.map((m) => [m.version, m.name, m.checksum]),
    );
    const kept = db
      .prepare(
        `SELECT p.amount, p.received, p.change_amount, r.amount AS refunded
         FROM payments p JOIN refunds r ON r.payment_id = p.id WHERE p.id = ?`,
      )
      .get(payment.lastInsertRowid);
    assert.deepEqual(kept, { amount: 11770, received: 20000, change_amount: 8230, refunded: 1000 });
    assert.deepEqual(db.pragma('foreign_key_check'), []);
    // migration หลัง 0001 ก็รันต่อจนครบ เช่น 0002 เพิ่มรหัสสินค้าให้วัตถุดิบเดิม (ว่างไว้) และตารางของ ERP (ว่าง)
    assert.equal(
      db.prepare('SELECT COUNT(*) AS c FROM ingredients WHERE item_code IS NULL').get().c,
      before.ingredients,
    );
    assert.equal(db.prepare('SELECT COUNT(*) AS c FROM erp_connection').get().c, 0);

    // boot ครั้งถัดไป: ไม่มีอะไรให้รัน และเวลาที่บันทึกไว้ไม่เปลี่ยน
    const appliedAt = recorded(db).map((row) => row.applied_at);
    assert.deepEqual(runMigrations(db), []);
    migrate();
    assert.deepEqual(
      recorded(db).map((row) => row.applied_at),
      appliedAt,
    );
    assert.deepEqual(counts(), before);
  });
});

describe('0003 order_item_kitchen_reached (T05 #104)', () => {
  test('marks items the kitchen is working on or finished as reached, and leaves the rest unknown', () => {
    const db = new Database(':memory:');
    db.pragma('foreign_keys = ON');
    runMigrations(db, MIGRATIONS.slice(0, 2));
    const order = db
      .prepare("INSERT INTO orders (code, status) VALUES ('ORD-T05-1', 'in_kitchen')")
      .run().lastInsertRowid;
    const insert = db.prepare(
      `INSERT INTO order_items (order_id, name_snapshot, unit_price, quantity, status)
       VALUES (?, ?, 5000, 1, ?)`,
    );
    for (const status of ['pending', 'cooking', 'ready', 'served', 'cancelled']) {
      insert.run(order, status, status);
    }

    assert.deepEqual(runMigrations(db, MIGRATIONS.slice(0, 3)), [
      '0003_order_item_kitchen_reached',
    ]);
    assert.deepEqual(
      db.prepare('SELECT status, kitchen_reached FROM order_items ORDER BY id').all(),
      [
        { status: 'pending', kitchen_reached: null },
        { status: 'cooking', kitchen_reached: 'cooking' },
        { status: 'ready', kitchen_reached: 'ready' },
        { status: 'served', kitchen_reached: 'served' },
        { status: 'cancelled', kitchen_reached: null },
      ],
    );
    assert.throws(
      () => db.prepare("UPDATE order_items SET kitchen_reached = 'pending' WHERE id = 1").run(),
      /CHECK constraint failed/,
    );
  });
});

describe('0004 order_item_paid_by_payment (T06 #82)', () => {
  test('keeps items already paid in a split as paid, with no payment to release them by', () => {
    const db = new Database(':memory:');
    db.pragma('foreign_keys = ON');
    runMigrations(db, MIGRATIONS.slice(0, 3));
    const order = db
      .prepare("INSERT INTO orders (code, status) VALUES ('ORD-T06-1', 'in_kitchen')")
      .run().lastInsertRowid;
    db.prepare(
      `INSERT INTO order_items (order_id, name_snapshot, unit_price, quantity, is_paid)
       VALUES (?, 'split', 5000, 1, 1), (?, 'open', 5000, 1, 0)`,
    ).run(order, order);

    assert.deepEqual(runMigrations(db), ['0004_order_item_paid_by_payment']);
    assert.deepEqual(
      db.prepare('SELECT is_paid, paid_by_payment_id FROM order_items ORDER BY id').all(),
      [
        { is_paid: 1, paid_by_payment_id: null },
        { is_paid: 0, paid_by_payment_id: null },
      ],
    );
    assert.throws(
      () => db.prepare('UPDATE order_items SET paid_by_payment_id = 999 WHERE id = 1').run(),
      /FOREIGN KEY constraint failed/,
    );
  });
});
