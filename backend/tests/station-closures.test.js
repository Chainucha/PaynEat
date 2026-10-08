// Copyright 2026 Suruch Chakrapeesirisuk
// SPDX-License-Identifier: Apache-2.0

import test, { after } from 'node:test';
import assert from 'node:assert/strict';
import { api, login, authHeader, cleanup } from './helpers/testApp.js';

// ปิด/เปิดสถานีครัวรายสาขา (ticket 36) — สถานีปิด ≠ สถานีที่ปิดใช้งาน (CONTEXT.md)
// ทุกเทสต์สร้างสถานี/หมวด/เมนูของตัวเอง ไม่แตะสามสถานีตั้งต้น ปิดแล้วจึงไม่รั่วไปเทสต์อื่น

after(cleanup);

const get = (url, token) => api().get(url).set(authHeader(token));
const post = (url, token, body) =>
  api()
    .post(url)
    .set(authHeader(token))
    .send(body ?? {});
const patch = (url, token, body) => api().patch(url).set(authHeader(token)).send(body);

const unique = (prefix) =>
  `${prefix}${Date.now().toString(36)}${Math.floor(Math.random() * 1e4)}`.slice(0, 20);

/** สถานีใหม่ + หมวดหมู่ที่ผูกสถานีนั้น + เมนูหนึ่งจานในสาขาของ token */
const stationWithDish = async (token) => {
  const station = await post('/api/v1/kitchen-stations', token, {
    code: unique('st'),
    name: unique('สถานี-'),
  });
  assert.equal(station.status, 201, JSON.stringify(station.body));
  const category = await post('/api/v1/categories', token, {
    name: unique('หมวด-'),
    stationId: station.body.data.id,
  });
  assert.equal(category.status, 201, JSON.stringify(category.body));
  const dish = await post('/api/v1/menu-items', token, {
    categoryId: category.body.data.id,
    name: unique('จาน-'),
    price: 60,
    branchId: 1,
  });
  assert.equal(dish.status, 201, JSON.stringify(dish.body));
  return { station: station.body.data, category: category.body.data, dish: dish.body.data };
};

const statusOf = async (token, stationId) => {
  const res = await get('/api/v1/kitchen-stations/status', token);
  assert.equal(res.status, 200, JSON.stringify(res.body));
  return res.body.data.find((row) => row.stationId === stationId);
};

const auditFor = async (adminToken, action, entityId) => {
  const res = await get(
    `/api/v1/audit-logs?action=${action}&entityId=${entityId}&limit=100`,
    adminToken,
  );
  assert.equal(res.status, 200, JSON.stringify(res.body));
  return res.body.data;
};

test('ทุกสถานีเปิดอยู่ตั้งแต่แรก และสถานะคืนเฉพาะสถานีที่เปิดใช้งาน', async () => {
  const { token } = await login('admin', 'admin123');
  const { station } = await stationWithDish(token);

  const status = await statusOf(token, station.id);
  assert.equal(status.isClosed, false);
  assert.equal(status.closedAt, null);
  assert.equal(status.pendingCount, 0);
  assert.equal(status.code, station.code);

  await patch(`/api/v1/kitchen-stations/${station.id}`, token, { isActive: false });
  assert.equal(await statusOf(token, station.id), undefined);
});

test('kitchen/manager/admin ปิดและเปิดได้ — waiter/cashier 403, ไม่ล็อกอิน 401', async () => {
  const admin = await login('admin', 'admin123');
  const { station } = await stationWithDish(admin.token);

  for (const username of ['waiter1', 'cashier']) {
    const password = username === 'cashier' ? 'cashier123' : 'waiter123';
    const { token } = await login(username, password);
    const res = await post(`/api/v1/kitchen-stations/${station.id}/close`, token);
    assert.equal(res.status, 403, `${username} ต้องปิดสถานีไม่ได้`);
  }
  const anonymous = await api().post(`/api/v1/kitchen-stations/${station.id}/close`);
  assert.equal(anonymous.status, 401);

  // อ่านสถานะได้ทุกบทบาท — แบนเนอร์บนหน้าสั่งอาหารของพนักงานเสิร์ฟต้องใช้
  const waiter = await login('waiter1', 'waiter123');
  assert.equal((await get('/api/v1/kitchen-stations/status', waiter.token)).status, 200);

  const kitchen = await login('kitchen', 'kitchen123');
  const closed = await post(`/api/v1/kitchen-stations/${station.id}/close`, kitchen.token);
  assert.equal(closed.status, 200, JSON.stringify(closed.body));
  assert.equal(closed.body.data.isClosed, true);
  assert.equal(closed.body.data.closedByName, kitchen.user.name);
  assert.ok(closed.body.data.closedAt);

  const manager = await login('manager', 'manager123');
  const opened = await post(`/api/v1/kitchen-stations/${station.id}/open`, manager.token);
  assert.equal(opened.status, 200);
  assert.equal(opened.body.data.isClosed, false);
  assert.equal(opened.body.data.closedByName, null);
});

test('ปิดซ้ำ/เปิดซ้ำได้ 200 และ audit log บันทึกเฉพาะตอนสถานะเปลี่ยนจริง', async () => {
  const { token } = await login('admin', 'admin123');
  const { station } = await stationWithDish(token);
  const countFor = async (action) =>
    (await auditFor(token, action, station.id)).filter((log) => log.entityId === station.id).length;

  assert.equal((await post(`/api/v1/kitchen-stations/${station.id}/open`, token)).status, 200);
  assert.equal((await post(`/api/v1/kitchen-stations/${station.id}/close`, token)).status, 200);
  assert.equal((await post(`/api/v1/kitchen-stations/${station.id}/close`, token)).status, 200);
  assert.equal((await post(`/api/v1/kitchen-stations/${station.id}/open`, token)).status, 200);

  assert.equal(await countFor('kitchen_station.close'), 1);
  assert.equal(await countFor('kitchen_station.open'), 1);
  const [log] = (await auditFor(token, 'kitchen_station.close', station.id)).filter(
    (row) => row.entityId === station.id,
  );
  assert.deepEqual(log.metadata.summaryArgs, { station: station.name, pending: 0 });
});

test('ปิดที่สาขาหนึ่ง สาขาอื่นยังเปิดอยู่', async () => {
  const admin = await login('admin', 'admin123');
  const { station } = await stationWithDish(admin.token);
  await post(`/api/v1/kitchen-stations/${station.id}/close`, admin.token);

  const branches = (await get('/api/v1/branches', admin.token)).body.data;
  const thonglor = branches.find((branch) => branch.code === 'THONGLOR');
  const switched = await post('/api/v1/auth/select-branch', admin.token, {
    branchId: thonglor.id,
  });
  assert.equal(switched.status, 200, JSON.stringify(switched.body));

  const elsewhere = await statusOf(switched.body.data.token, station.id);
  assert.equal(elsewhere.isClosed, false);
});

test('โหมด "ทุกสาขา" ดูหรือเปลี่ยนสถานะไม่ได้ (400) และสถานีไม่มีจริงได้ 404', async () => {
  const admin = await login('admin', 'admin123');
  const all = await post('/api/v1/auth/select-branch', admin.token, { branchId: null });
  const allToken = all.body.data.token;

  assert.equal((await get('/api/v1/kitchen-stations/status', allToken)).status, 400);
  assert.equal((await post('/api/v1/kitchen-stations/1/close', allToken)).status, 400);
  assert.equal((await post('/api/v1/kitchen-stations/999999/close', admin.token)).status, 404);
});

test('ลบสถานีที่ปิดอยู่ได้ แถวปิดหายตาม', async () => {
  const { token } = await login('admin', 'admin123');
  const station = (
    await post('/api/v1/kitchen-stations', token, { code: unique('st'), name: 'ลบได้' })
  ).body.data;
  await post(`/api/v1/kitchen-stations/${station.id}/close`, token);

  const removed = await api()
    .delete(`/api/v1/kitchen-stations/${station.id}`)
    .set(authHeader(token));
  assert.equal(removed.status, 204, JSON.stringify(removed.body));
});
