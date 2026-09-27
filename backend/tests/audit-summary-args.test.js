// Copyright 2026 Suruch Chakrapeesirisuk
// SPDX-License-Identifier: Apache-2.0

// ค่าที่ใช้ประกอบประโยค audit log แบบไม่ผูกภาษา (metadata.summaryArgs, DECISIONS #74) — แอปใช้
// ค่าชุดนี้แสดงประโยคเป็นภาษาที่ผู้ดูเลือก ถ้าจุดไหนลืมส่งมา ผู้ใช้ภาษาเกาหลี/อังกฤษจะเห็นประโยคไทย
import test, { after } from 'node:test';
import assert from 'node:assert/strict';
import { readFileSync, readdirSync } from 'node:fs';
import { join } from 'node:path';
import { api, login, authHeader, cleanup } from './helpers/testApp.js';

after(cleanup);

const get = (url, token) => api().get(url).set(authHeader(token));
const post = (url, token, body) =>
  api()
    .post(url)
    .set(authHeader(token))
    .send(body ?? {});
const patch = (url, token, body) => api().patch(url).set(authHeader(token)).send(body);

const sourceFiles = (dir) =>
  readdirSync(dir, { withFileTypes: true }).flatMap((entry) =>
    entry.isDirectory()
      ? sourceFiles(join(dir, entry.name))
      : entry.name.endsWith('.js')
        ? [join(dir, entry.name)]
        : [],
  );

test('ทุกจุดที่เขียน audit log ส่ง summaryArgs มาคู่กับ summary', () => {
  const missing = [];
  let calls = 0;
  for (const file of sourceFiles(new URL('../src/modules', import.meta.url).pathname)) {
    const source = readFileSync(file, 'utf8');
    for (const match of source.matchAll(/auditLogService\.log\(\{([\s\S]*?)\n\s*\}\);/g)) {
      calls += 1;
      const action = match[1].match(/action: '([^']+)'/)?.[1] ?? '?';
      if (!/summaryArgs:/.test(match[1])) missing.push(`${action} (${file})`);
    }
  }
  assert.ok(calls >= 30, `เจอแค่ ${calls} จุด — regex ตามโค้ดไม่ทันแล้ว`);
  assert.deepEqual(missing, [], 'จุดเหล่านี้ลืมส่ง summaryArgs');
});

test('summaryArgs เก็บค่าเดียวกับที่อยู่ในประโยคไทย รวมถึงชื่อที่ metadata เดิมไม่มี', async () => {
  const admin = await login('admin', 'admin123');
  const waiter = await login('waiter1', 'waiter123');

  const tables = (await get('/api/v1/tables?status=available', waiter.token)).body.data;
  const menuItem = (await get('/api/v1/menu-items?availableOnly=true&limit=200', waiter.token)).body
    .data[0];
  const orderRes = await post('/api/v1/orders', waiter.token, {
    type: 'dine_in',
    tableId: tables[0].id,
    guestCount: 1,
    items: [{ menuItemId: menuItem.id, quantity: 2, optionIds: [] }],
  });
  assert.equal(orderRes.status, 201, JSON.stringify(orderRes.body));
  const order = orderRes.body.data;

  const moveRes = await patch(`/api/v1/orders/${order.id}/move-table`, waiter.token, {
    tableId: tables[1].id,
  });
  assert.equal(moveRes.status, 200, JSON.stringify(moveRes.body));

  const logs = (
    await get(`/api/v1/audit-logs?entityId=${order.id}&entityType=order&limit=10`, admin.token)
  ).body.data;
  const created = logs.find((log) => log.action === 'order.create');
  const moved = logs.find((log) => log.action === 'order.move_table');

  assert.deepEqual(created.metadata.summaryArgs, { code: order.code, count: 1 });
  assert.deepEqual(moved.metadata.summaryArgs, {
    code: order.code,
    fromTable: tables[0].name,
    toTable: tables[1].name,
  });
  // ประโยคไทยที่เป็นหลักฐานยังเหมือนเดิมทุกตัวอักษร
  assert.equal(
    moved.summary,
    `ย้ายออเดอร์ #${order.code} จากโต๊ะ "${tables[0].name}" ไปโต๊ะ "${tables[1].name}"`,
  );
});

test('แก้การตั้งค่า — summaryArgs บอกทีละช่องว่าเปลี่ยนอะไรจากเท่าไรเป็นเท่าไร', async () => {
  const admin = await login('admin', 'admin123');
  const before = (await get('/api/v1/settings', admin.token)).body.data;
  const next = before.serviceChargeRate === 0.1 ? 0.05 : 0.1;

  const res = await patch('/api/v1/settings', admin.token, { serviceChargeRate: next });
  assert.equal(res.status, 200, JSON.stringify(res.body));

  const [log] = (await get('/api/v1/audit-logs?action=settings.update&limit=1', admin.token)).body
    .data;
  assert.deepEqual(log.metadata.summaryArgs, {
    changes: [{ field: 'service', from: before.serviceChargeRate, to: next }],
  });
});
