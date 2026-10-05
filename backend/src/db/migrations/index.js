// Copyright 2026 Suruch Chakrapeesirisuk
// SPDX-License-Identifier: Apache-2.0

import { createHash } from 'node:crypto';
import fs from 'node:fs';
import path from 'node:path';
import baseline from './0001_baseline.js';
import erpConnection from './0002_erp_connection.js';
import orderItemKitchenReached from './0003_order_item_kitchen_reached.js';
import orderItemPaidByPayment from './0004_order_item_paid_by_payment.js';
import repairCustomerPoints from './0005_repair_customer_points.js';
import kitchenStations from './0006_kitchen_stations.js';

/**
 * Migrations ทั้งหมดตามลำดับ (T01 #80, docs/DECISIONS.md #79) — ตัวรันอยู่ที่ ../migrate.js
 *
 * เปลี่ยน schema ครั้งต่อไป:
 * 1. สร้าง `NNNN_ชื่อ.js` (และ `.sql` ถ้าต้องการ) ด้วยเลขถัดไป export default
 *    `{ version, name, files, up(db) }` — ใส่ `foreignKeys: false` เฉพาะเมื่อต้องสร้างตารางใหม่แทนตารางเดิม
 * 2. เพิ่มในรายการด้านล่าง
 * 3. รันเทสต์ `tests/migrations.test.js` จะบอก checksum ให้ใส่ใน `checksums.json`
 *
 * ห้ามแก้ migration ที่อยู่ใน main แล้ว แม้แต่คอมเมนต์หรือการจัดรูปแบบ: checksum ถูกบันทึกในทุกฐานข้อมูลที่รัน
 * และเซิร์ฟเวอร์ของร้านจะไม่ยอมเปิดถ้าไฟล์ไม่ตรงกับที่รันไปแล้ว
 */
const DEFINITIONS = [
  baseline,
  erpConnection,
  orderItemKitchenReached,
  orderItemPaidByPayment,
  repairCustomerPoints,
  kitchenStations,
];

/** sha256 ของไฟล์ของ migration — ปรับบรรทัดเป็น \n ก่อน เพื่อให้ checkout บน Windows (CRLF) ได้ค่าเดียวกัน */
export const checksumOf = (files) => {
  const hash = createHash('sha256');
  for (const file of files) {
    hash.update(path.basename(file));
    hash.update('\0');
    hash.update(fs.readFileSync(file, 'utf8').replace(/\r\n/g, '\n'));
    hash.update('\0');
  }
  return hash.digest('hex');
};

export const MIGRATIONS = DEFINITIONS.map((migration) => ({
  ...migration,
  checksum: checksumOf(migration.files),
}));

export default MIGRATIONS;
