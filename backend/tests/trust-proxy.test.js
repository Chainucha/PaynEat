// Copyright 2026 Suruch Chakrapeesirisuk
// SPDX-License-Identifier: Apache-2.0

import test, { after } from 'node:test';
import assert from 'node:assert/strict';

// ไม่ตั้ง TRUST_PROXY (ค่าเริ่มต้น) — ลดเพดานใส่รหัสผ่านผิดเหลือ 3 ให้เห็นผลของ req.ip ในไม่กี่คำขอ
delete process.env.TRUST_PROXY;
process.env.AUTH_MAX_FAILED_ATTEMPTS = '3';

const { app, api, cleanup } = await import('./helpers/testApp.js');
const { parseTrustProxy } = await import('../src/config/env.js');

after(cleanup);

test('parseTrustProxy — ไม่ตั้ง/false ปิด, ตัวเลขเป็นจำนวน hop, ข้อความอื่นส่งต่อให้ Express', () => {
  assert.equal(parseTrustProxy(undefined), false);
  assert.equal(parseTrustProxy(''), false);
  assert.equal(parseTrustProxy('false'), false);
  assert.equal(parseTrustProxy('true'), true);
  assert.equal(parseTrustProxy('0'), 0);
  assert.equal(parseTrustProxy(' 2 '), 2);
  assert.equal(parseTrustProxy('loopback'), 'loopback');
  assert.equal(parseTrustProxy('10.0.0.0/8, 192.168.1.10'), '10.0.0.0/8, 192.168.1.10');
});

test('ค่าเริ่มต้นไม่เชื่อ X-Forwarded-For — เปลี่ยน header ก็ยังนับเป็นเครื่องเดียวกัน', async () => {
  assert.equal(app.get('trust proxy'), false);

  for (const [i, username] of ['ghost-a', 'ghost-b', 'ghost-c'].entries()) {
    const res = await api()
      .post('/api/v1/auth/login')
      .set('X-Forwarded-For', `203.0.113.${i + 1}`)
      .send({ username, password: 'wrong' });
    assert.equal(res.status, 401);
  }

  const res = await api()
    .post('/api/v1/auth/login')
    .set('X-Forwarded-For', '203.0.113.99')
    .send({ username: 'admin', password: 'admin123' });
  assert.equal(res.status, 429, JSON.stringify(res.body));
  assert.ok(res.headers['retry-after']);
});
