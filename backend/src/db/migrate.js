// Copyright 2026 Suruch Chakrapeesirisuk
// SPDX-License-Identifier: Apache-2.0

import { getDb } from './index.js';
import { MIGRATIONS } from './migrations/index.js';
import { env } from '../config/env.js';
import { logger } from '../core/telemetry/logger.js';

/**
 * Migration แบบมีเวอร์ชัน (T01 #80, docs/DECISIONS.md #79)
 *
 * - แต่ละ migration รันครั้งเดียว: เวอร์ชันที่รันแล้วถูกบันทึกในตาราง `schema_migrations` พร้อม checksum
 * - แต่ละ migration อยู่ใน transaction ของตัวเอง ถ้าล้มกลางทาง rollback ทั้งตัว ไม่เหลือ schema ครึ่ง ๆ กลาง ๆ
 *   และไม่ถูกบันทึกว่ารันแล้ว — การบันทึกอยู่ใน transaction เดียวกับตัว migration
 * - migration ที่รันแล้วแต่ไฟล์ไม่ตรงกับตอนรัน (ถูกแก้ภายหลัง) หรือฐานข้อมูลที่เคยรัน migration ที่ build นี้
 *   ไม่รู้จัก (ถอยเวอร์ชันแอป) ทำให้เซิร์ฟเวอร์ไม่ยอมเปิด พร้อมบอกเหตุผล ดีกว่าเปิดขึ้นมากับ schema ที่ไม่ตรงกับโค้ด
 */

const TRACKING_TABLE = `
  CREATE TABLE IF NOT EXISTS schema_migrations (
    version    INTEGER PRIMARY KEY,
    name       TEXT    NOT NULL,
    checksum   TEXT    NOT NULL,
    applied_at TEXT    NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%fZ', 'now'))
  )`;

const label = (migration) => `${String(migration.version).padStart(4, '0')}_${migration.name}`;

const apply = (db, migration) => {
  // PRAGMA foreign_keys ใช้ไม่ได้ภายใน transaction จึงต้องปิดก่อนเปิด transaction แล้วตรวจเองก่อน commit
  const withoutForeignKeys = migration.foreignKeys === false;
  if (withoutForeignKeys) db.pragma('foreign_keys = OFF');
  try {
    db.transaction(() => {
      migration.up(db);
      if (withoutForeignKeys) {
        const broken = db.pragma('foreign_key_check');
        if (broken.length) {
          throw new Error(
            `Migration ${label(migration)} broke foreign keys: ${JSON.stringify(broken)}`,
          );
        }
      }
      db.prepare('INSERT INTO schema_migrations (version, name, checksum) VALUES (?, ?, ?)').run(
        migration.version,
        migration.name,
        migration.checksum,
      );
    })();
  } finally {
    if (withoutForeignKeys) db.pragma('foreign_keys = ON');
  }
};

/**
 * รัน migration ที่ยังไม่เคยรันตามลำดับเวอร์ชัน คืนรายการที่รันในครั้งนี้ — แยกจาก migrate() ให้เทสต์ส่ง
 * รายการ migration ของตัวเองเข้ามาได้
 */
export const runMigrations = (db, migrations = MIGRATIONS) => {
  const ordered = [...migrations].sort((a, b) => a.version - b.version);
  db.exec(TRACKING_TABLE);
  const applied = new Map(
    db
      .prepare('SELECT version, name, checksum FROM schema_migrations')
      .all()
      .map((row) => [row.version, row]),
  );

  const known = new Set(ordered.map((migration) => migration.version));
  const unknown = [...applied.keys()].filter((version) => !known.has(version));
  if (unknown.length) {
    throw new Error(
      `This database was migrated by a newer PaynEat (migration ${unknown.join(', ')}). ` +
        'Run that version or newer against it.',
    );
  }

  const ran = [];
  for (const migration of ordered) {
    const done = applied.get(migration.version);
    if (done) {
      if (done.checksum !== migration.checksum) {
        throw new Error(
          `Migration ${label(migration)} was changed after it ran on this database. ` +
            'An applied migration must never change: add a new migration instead.',
        );
      }
      continue;
    }
    apply(db, migration);
    ran.push(label(migration));
    logger.info(`Applied database migration ${label(migration)}`);
  }
  return ran;
};

/** ค่าตั้งต้นของร้านจาก env — ไม่ใช่ schema จึงไม่อยู่ใน migration ใส่เฉพาะคีย์ที่ยังไม่มี ทุกครั้งที่ boot */
const ensureDefaultSettings = (db) => {
  const defaults = {
    store_name: env.store.name,
    currency: env.store.currency,
    vat_rate: String(env.store.vatRate),
    service_charge_rate: String(env.store.serviceChargeRate),
    vat_included: String(env.store.vatIncluded),
  };
  const upsert = db.prepare(
    'INSERT INTO settings (key, value) VALUES (?, ?) ON CONFLICT(key) DO NOTHING',
  );
  for (const [key, value] of Object.entries(defaults)) upsert.run(key, value);
};

export const migrate = () => {
  const db = getDb();
  runMigrations(db);
  ensureDefaultSettings(db);
  return db;
};

if (import.meta.url === `file://${process.argv[1]}`) {
  migrate();
  logger.info(`Migration finished: ${env.databaseFile}`);
}

export default migrate;
