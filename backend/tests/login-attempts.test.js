// Copyright 2026 Suruch Chakrapeesirisuk
// SPDX-License-Identifier: Apache-2.0

import test, { after } from 'node:test';
import assert from 'node:assert/strict';

// ตั้งค่าก่อน import แอป (เหตุผลเดียวกับ ai-assistant-rate-limit.test.js) — ลดเพดานเหลือ 3 ครั้งให้เทสต์สั้น
// และเปิด TRUST_PROXY เพื่อกำหนด IP ของแต่ละคำขอผ่าน X-Forwarded-For ได้ (ไฟล์อื่นใช้ค่าเริ่มต้นตามเดิม)
process.env.AUTH_MAX_FAILED_ATTEMPTS = '3';
process.env.TRUST_PROXY = '1';

const { app, api, login, authHeader, cleanup } = await import('./helpers/testApp.js');

after(cleanup);

const WINDOW_SECONDS = 15 * 60;

const attempt = (ip, username, password, lang) => {
  const req = api().post('/api/v1/auth/login').set('X-Forwarded-For', ip);
  if (lang) req.set('Accept-Language', lang);
  return req.send({ username, password });
};

const assertPaused = (res) => {
  assert.equal(res.status, 429, JSON.stringify(res.body));
  assert.equal(res.body.error.code, 'TOO_MANY_REQUESTS');
  const retryAfter = Number(res.headers['retry-after']);
  assert.ok(
    Number.isInteger(retryAfter) && retryAfter >= 1 && retryAfter <= WINDOW_SECONDS,
    `Retry-After ต้องเป็นวินาทีภายใน window ได้ ${res.headers['retry-after']}`,
  );
};

test('TRUST_PROXY=1 ถูกส่งต่อเป็นค่า trust proxy ของ Express', () => {
  assert.equal(app.get('trust proxy'), 1);
});

test('POST /auth/login — ผิดครบเพดานแล้วพักไว้ แม้รอบถัดไปใส่รหัสถูกก็ได้ 429 + Retry-After', async () => {
  for (let i = 0; i < 3; i += 1) {
    assert.equal((await attempt('10.0.0.1', 'waiter1', 'wrong')).status, 401);
  }
  assertPaused(await attempt('10.0.0.1', 'waiter1', 'waiter123'));
});

test('POST /auth/login — นับต่อ username ข้าม IP และไม่กระทบบัญชีอื่น', async () => {
  // waiter1 ถูกพักจากเทสต์ก่อนหน้า — เปลี่ยนเครื่องก็ยังถูกพัก
  assertPaused(await attempt('10.0.0.2', 'waiter1', 'waiter123'));
  assert.equal((await attempt('10.0.0.3', 'kitchen', 'kitchen123')).status, 200);
});

test('POST /auth/login — username ตัวพิมพ์ต่างกัน/มีช่องว่างนับเป็นบัญชีเดียวกัน', async () => {
  const variants = ['WAITER2', 'Waiter2', ' waiter2 '];
  for (const [i, username] of variants.entries()) {
    assert.equal((await attempt(`10.0.1.${i + 1}`, username, 'wrong')).status, 401);
  }
  assertPaused(await attempt('10.0.1.9', 'waiter2', 'waiter123'));
});

test('POST /auth/login — นับต่อ IP แม้แต่ละครั้งใช้ username ต่างกัน', async () => {
  for (const username of ['ghost-a', 'ghost-b', 'ghost-c']) {
    assert.equal((await attempt('10.0.2.1', username, 'wrong')).status, 401);
  }
  assertPaused(await attempt('10.0.2.1', 'cashier', 'cashier123'));
  assert.equal((await attempt('10.0.2.2', 'cashier', 'cashier123')).status, 200);
});

test('POST /auth/login — เข้าสู่ระบบสำเร็จล้างตัวนับของทั้ง username และ IP', async () => {
  for (let round = 0; round < 2; round += 1) {
    for (let i = 0; i < 2; i += 1) {
      assert.equal((await attempt('10.0.3.1', 'manager', 'wrong')).status, 401);
    }
    assert.equal((await attempt('10.0.3.1', 'manager', 'manager123')).status, 200);
  }
});

test('POST /auth/login — ข้อความตอนถูกพักแปลตาม Accept-Language', async () => {
  for (const username of ['ghost-d', 'ghost-e', 'ghost-f']) {
    await attempt('10.0.4.1', username, 'wrong');
  }
  const th = await attempt('10.0.4.1', 'ghost-g', 'wrong');
  assertPaused(th);
  assert.match(th.body.error.message, /^ใส่รหัสผ่านผิดหลายครั้งเกินไป กรุณาลองใหม่ในอีก \d+ นาที$/);

  const en = await attempt('10.0.4.1', 'ghost-g', 'wrong', 'en');
  assert.match(
    en.body.error.message,
    /^Too many incorrect passwords — please try again in \d+ min$/,
  );
});

test('POST /auth/change-password — ใส่รหัสผ่านปัจจุบันผิดครบเพดานแล้วพักไว้', async () => {
  const { token } = await login('admin', 'admin123');
  const change = (currentPassword) =>
    api()
      .post('/api/v1/auth/change-password')
      .set(authHeader(token))
      .send({ currentPassword, newPassword: 'admin-new-123' });

  for (let i = 0; i < 3; i += 1) {
    assert.equal((await change('wrong')).status, 400);
  }
  assertPaused(await change('admin123'));
  // ยังเข้าสู่ระบบด้วยรหัสเดิมได้ — ตัวนับของเปลี่ยนรหัสผ่านแยกจาก login และรหัสไม่ได้ถูกเปลี่ยน
  assert.equal((await attempt('10.0.5.1', 'admin', 'admin123')).status, 200);
});
