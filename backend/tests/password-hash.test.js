// Copyright 2026 Suruch Chakrapeesirisuk
// SPDX-License-Identifier: Apache-2.0

import test from 'node:test';
import assert from 'node:assert/strict';
import bcrypt from 'bcryptjs';
import { comparePassword, hashPassword } from '../src/core/passwordHash.js';

// bcrypt บน worker thread — ตรวจรหัสผ่านโดยไม่หยุดคำขออื่น (DECISIONS #101)

const HASH = bcrypt.hashSync('waiter123', 10);

test('ตรวจรหัสผ่านถูก/ผิดได้ผลเหมือน bcryptjs และ hash ที่สร้างใช้ตรวจได้', async () => {
  assert.equal(await comparePassword('waiter123', HASH), true);
  assert.equal(await comparePassword('wrong', HASH), false);

  const created = await hashPassword('new-password-1');
  assert.ok(bcrypt.compareSync('new-password-1', created));
  assert.equal(await comparePassword('new-password-1', created), true);
});

test('ตรวจรหัสผ่าน 5 ครั้งพร้อมกัน thread หลักยังว่าง (แบบ sync จะค้างราว 60 ms ต่อครั้ง)', async () => {
  await comparePassword('warm-up', HASH);

  let last = performance.now();
  let longestGap = 0;
  const timer = setInterval(() => {
    const now = performance.now();
    longestGap = Math.max(longestGap, now - last);
    last = now;
  }, 5);

  const results = await Promise.all(
    Array.from({ length: 5 }, () => comparePassword('wrong', HASH)),
  );
  clearInterval(timer);
  // ช่วงสุดท้ายนับด้วย — ถ้า thread หลักค้างตลอด timer จะไม่ได้ทำงานเลย
  longestGap = Math.max(longestGap, performance.now() - last);

  assert.deepEqual(results, [false, false, false, false, false]);
  assert.ok(longestGap < 40, `thread หลักค้างนานสุด ${longestGap.toFixed(1)} ms`);
});
