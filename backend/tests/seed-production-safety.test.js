// Copyright 2026 Suruch Chakrapeesirisuk
// SPDX-License-Identifier: Apache-2.0

import test, { after } from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
import bcrypt from 'bcryptjs';
import { randomBytes } from 'node:crypto';

// ไฟล์นี้ตั้งใจไม่ใช้ ./helpers/testApp.js เพราะต้อง toggle NODE_ENV=production เอง และต้องการ
// ตาราง users ว่างสนิทตอนเริ่ม (testApp.js seed บัญชีเดโมไว้แล้วตั้งแต่ import) — node:test รัน
// แต่ละไฟล์ทดสอบคนละ process กันอยู่แล้ว จึงมี env/DB เป็นของตัวเองโดยไม่ชนกับไฟล์อื่น
const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..');
const dbFile = path.join(root, `data/test-seed-prod-${process.pid}-${Date.now()}.sqlite`);

// production ต้องใช้ secret ที่ไม่ใช่ค่าตัวอย่างและยาวอย่างน้อย 32 ตัว (T19) — สุ่มใหม่ทุกครั้งที่รัน
process.env.JWT_SECRET = randomBytes(32).toString('hex');
process.env.DATABASE_FILE = dbFile;

after(() => {
  for (const suffix of ['', '-wal', '-shm']) {
    const file = `${dbFile}${suffix}`;
    if (fs.existsSync(file)) fs.rmSync(file);
  }
});

// ดูรายงาน security review + SECURITY.md: ห้าม seed บัญชีเดโม (admin123 ฯลฯ) แบบเงียบๆ ใน
// production ต้องตั้งรหัสผ่านเองผ่าน env ให้ครบทุกบัญชีก่อนเสมอ (fail-closed เหมือน JWT_SECRET)
test('seed() ปฏิเสธไม่ยอม seed บัญชีเดโมด้วยรหัสผ่านที่รู้อยู่แล้วเมื่อ NODE_ENV=production', async () => {
  process.env.NODE_ENV = 'production';
  const { seed } = await import('../src/db/seed.js');

  assert.throws(() => seed(), /SEED_ADMIN_PASSWORD/);
});

test('seed() สำเร็จใน production ถ้าตั้งรหัสผ่านเองผ่าน env ครบทุกบัญชี และไม่ใช้รหัสผ่านเดโม', async () => {
  process.env.NODE_ENV = 'production';
  process.env.SEED_ADMIN_PASSWORD = 'custom-admin-pw-1';
  process.env.SEED_MANAGER_PASSWORD = 'custom-manager-pw-1';
  process.env.SEED_WAITER1_PASSWORD = 'custom-waiter1-pw-1';
  process.env.SEED_WAITER2_PASSWORD = 'custom-waiter2-pw-1';
  process.env.SEED_KITCHEN_PASSWORD = 'custom-kitchen-pw-1';
  process.env.SEED_CASHIER_PASSWORD = 'custom-cashier-pw-1';

  const { seed } = await import('../src/db/seed.js');
  const db = seed();

  const admin = db.prepare('SELECT password_hash FROM users WHERE username = ?').get('admin');
  assert.ok(admin, 'ต้อง seed บัญชี admin สำเร็จ');
  assert.equal(bcrypt.compareSync('admin123', admin.password_hash), false);
  assert.equal(bcrypt.compareSync('custom-admin-pw-1', admin.password_hash), true);

  const cashier = db.prepare('SELECT password_hash FROM users WHERE username = ?').get('cashier');
  assert.equal(bcrypt.compareSync('cashier123', cashier.password_hash), false);
  assert.equal(bcrypt.compareSync('custom-cashier-pw-1', cashier.password_hash), true);
});
