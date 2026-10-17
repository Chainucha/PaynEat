// Copyright 2026 Suruch Chakrapeesirisuk
// SPDX-License-Identifier: Apache-2.0

import test from 'node:test';
import assert from 'node:assert/strict';
import Database from 'better-sqlite3';

// สถิติของ query planner: ไม่มีหรือเก่าเกินไปก็รัน ANALYZE ใหม่ (DECISIONS #101)

process.env.NODE_ENV = 'test';
process.env.JWT_SECRET = 'test-secret';

const { refreshPlannerStats } = await import('../src/db/plannerStats.js');

const shop = () => {
  const db = new Database(':memory:');
  db.exec(`
    CREATE TABLE orders (id INTEGER PRIMARY KEY, table_id INTEGER, status TEXT);
    CREATE INDEX idx_orders_table ON orders(table_id);
  `);
  return db;
};

const addOrders = (db, count) => {
  const insert = db.prepare("INSERT INTO orders (table_id, status) VALUES (?, 'paid')");
  db.transaction(() => {
    for (let i = 0; i < count; i += 1) insert.run(i % 10);
  })();
};

const analyzedRows = (db) =>
  Number(db.prepare("SELECT stat FROM sqlite_stat1 WHERE tbl = 'orders'").get().stat.split(' ')[0]);

test('ยังไม่มีสถิติ → วิเคราะห์ / ข้อมูลเปลี่ยนไม่ถึง 2 เท่า → ไม่วิเคราะห์ซ้ำ', () => {
  const db = shop();
  addOrders(db, 100);

  assert.equal(refreshPlannerStats(db), true);
  assert.equal(analyzedRows(db), 100);

  addOrders(db, 50);
  assert.equal(refreshPlannerStats(db), false);
  assert.equal(analyzedRows(db), 100);
});

test('ออเดอร์โตขึ้นตั้งแต่ 2 เท่า → วิเคราะห์ใหม่', () => {
  const db = shop();
  addOrders(db, 100);
  refreshPlannerStats(db);

  addOrders(db, 100);
  assert.equal(refreshPlannerStats(db), true);
  assert.equal(analyzedRows(db), 200);
});

test('ฐานข้อมูลว่างไม่ทำให้พัง', () => {
  const db = shop();
  assert.doesNotThrow(() => refreshPlannerStats(db));
  assert.doesNotThrow(() => refreshPlannerStats(db));
});
