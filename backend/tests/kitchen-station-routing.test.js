// Copyright 2026 Suruch Chakrapeesirisuk
// SPDX-License-Identifier: Apache-2.0

import test, { after } from 'node:test';
import assert from 'node:assert/strict';
import { api, login, authHeader, cleanup } from './helpers/testApp.js';

after(cleanup);

const get = (url, token) => api().get(url).set(authHeader(token));
const post = (url, token, body) => api().post(url).set(authHeader(token)).send(body);
const patch = (url, token, body) => api().patch(url).set(authHeader(token)).send(body);

const unique = (prefix) => `${prefix}${Date.now().toString(36)}${Math.floor(Math.random() * 1e4)}`;

const stationByCode = async (token, code) => {
  const res = await get('/api/v1/kitchen-stations', token);
  const station = res.body.data.find((row) => row.code === code);
  assert.ok(station, `ต้องมีสถานีรหัส ${code}`);
  return station;
};

const createCategory = async (token, stationId) => {
  const res = await post('/api/v1/categories', token, {
    name: unique('หมวดสถานี-'),
    ...(stationId === undefined ? {} : { stationId }),
  });
  assert.equal(res.status, 201, JSON.stringify(res.body));
  return res.body.data;
};

const createMenuItem = async (token, { categoryId, stationId, name = unique('จาน-') }) => {
  const res = await post('/api/v1/menu-items', token, {
    categoryId,
    name,
    price: 70,
    branchId: 1,
    ...(stationId === undefined ? {} : { stationId }),
  });
  assert.equal(res.status, 201, JSON.stringify(res.body));
  return res.body.data;
};

const createTable = async (token) => {
  const res = await post('/api/v1/tables', token, { name: unique('T').slice(0, 20) });
  assert.equal(res.status, 201, JSON.stringify(res.body));
  return res.body.data;
};

/** เปิดออเดอร์ที่โต๊ะใหม่พร้อมรายการที่ให้มา แล้วส่งเข้าครัว คืนออเดอร์ที่ส่งแล้ว */
const sendOrder = async (token, menuItemIds) => {
  const table = await createTable(token);
  const created = await post('/api/v1/orders', token, {
    type: 'dine_in',
    tableId: table.id,
    guestCount: 1,
    items: menuItemIds.map((menuItemId) => ({ menuItemId, quantity: 1 })),
  });
  assert.equal(created.status, 201, JSON.stringify(created.body));
  const sent = await post(`/api/v1/orders/${created.body.data.id}/send-to-kitchen`, token);
  assert.equal(sent.status, 200, JSON.stringify(sent.body));
  return sent.body.data;
};

const queueItemsOf = async (token, orderId, query = '') => {
  const res = await get(`/api/v1/orders/kitchen/queue${query}`, token);
  assert.equal(res.status, 200, JSON.stringify(res.body));
  return res.body.data.filter((item) => item.orderId === orderId);
};

test('สถานีของจานตัดสินจากเมนูก่อน แล้วค่อยหมวดหมู่ แล้วค่อยค่าเริ่มต้น', async () => {
  const { token } = await login('admin', 'admin123');
  const hot = await stationByCode(token, 'hot');
  const cold = await stationByCode(token, 'cold');
  const bar = await stationByCode(token, 'bar');

  const categoryOnBar = await createCategory(token, bar.id);
  const categoryWithout = await createCategory(token);

  const overridden = await createMenuItem(token, {
    categoryId: categoryOnBar.id,
    stationId: cold.id,
  });
  const inherited = await createMenuItem(token, { categoryId: categoryOnBar.id });
  const fallback = await createMenuItem(token, { categoryId: categoryWithout.id });

  const order = await sendOrder(token, [overridden.id, inherited.id, fallback.id]);
  const tickets = await queueItemsOf(token, order.id);
  const stationOf = (menuItemId) => tickets.find((item) => item.menuItemId === menuItemId);

  assert.equal(stationOf(overridden.id).stationCode, 'cold', 'เมนูทับค่าของหมวดหมู่');
  assert.equal(stationOf(overridden.id).stationName, cold.name);
  assert.equal(stationOf(inherited.id).stationCode, 'bar', 'ไม่กำหนดที่เมนู = ตามหมวดหมู่');
  assert.equal(stationOf(fallback.id).stationCode, 'hot', 'ไม่กำหนดเลย = สถานีค่าเริ่มต้น');
  assert.equal(stationOf(fallback.id).stationId, hot.id);
});

test('ย้ายเมนูไปสถานีอื่นภายหลัง ไม่ดึงตั๋วที่อยู่ในครัวแล้วข้ามจอ', async () => {
  const { token } = await login('admin', 'admin123');
  const bar = await stationByCode(token, 'bar');
  const cold = await stationByCode(token, 'cold');

  const category = await createCategory(token, bar.id);
  const item = await createMenuItem(token, { categoryId: category.id });
  const order = await sendOrder(token, [item.id]);

  const before = (await queueItemsOf(token, order.id))[0];
  assert.equal(before.stationCode, 'bar');

  const moved = await patch(`/api/v1/menu-items/${item.id}`, token, { stationId: cold.id });
  assert.equal(moved.status, 200);
  assert.equal(moved.body.data.stationId, cold.id);

  const after = (await queueItemsOf(token, order.id))[0];
  assert.equal(after.stationCode, 'bar', 'ตั๋วที่ครัวกำลังทำอยู่ต้องอยู่สถานีเดิม');

  // จานใบใหม่หลังย้าย ต้องไปสถานีใหม่
  const nextOrder = await sendOrder(token, [item.id]);
  assert.equal((await queueItemsOf(token, nextOrder.id))[0].stationCode, 'cold');
});

test('เปลี่ยนชื่อสถานี ไม่เปลี่ยนชื่อบนตั๋วที่ค้างอยู่ในครัว', async () => {
  const { token } = await login('admin', 'admin123');
  const station = await post('/api/v1/kitchen-stations', token, {
    code: unique('rn').slice(0, 20),
    name: 'ชื่อตอนสั่ง',
  });
  assert.equal(station.status, 201);

  const category = await createCategory(token, station.body.data.id);
  const item = await createMenuItem(token, { categoryId: category.id });
  const order = await sendOrder(token, [item.id]);
  assert.equal((await queueItemsOf(token, order.id))[0].stationName, 'ชื่อตอนสั่ง');

  await patch(`/api/v1/kitchen-stations/${station.body.data.id}`, token, { name: 'ชื่อใหม่' });
  assert.equal((await queueItemsOf(token, order.id))[0].stationName, 'ชื่อตอนสั่ง');
});

test('GET /orders/kitchen/queue?station= กรองเฉพาะตั๋วของสถานีนั้น', async () => {
  const { token } = await login('admin', 'admin123');
  const bar = await stationByCode(token, 'bar');
  const cold = await stationByCode(token, 'cold');

  const category = await createCategory(token, bar.id);
  const drink = await createMenuItem(token, { categoryId: category.id });
  const salad = await createMenuItem(token, { categoryId: category.id, stationId: cold.id });
  const order = await sendOrder(token, [drink.id, salad.id]);

  const onBar = await queueItemsOf(token, order.id, '?station=bar');
  assert.equal(onBar.length, 1);
  assert.equal(onBar[0].menuItemId, drink.id);

  const onCold = await queueItemsOf(token, order.id, '?station=cold');
  assert.equal(onCold.length, 1);
  assert.equal(onCold[0].menuItemId, salad.id);

  assert.equal((await queueItemsOf(token, order.id, '?station=hot')).length, 0);
  assert.equal((await queueItemsOf(token, order.id)).length, 2, 'ไม่ส่ง station = เห็นทุกสถานี');
});

test('GET /orders/kitchen/queue — ค่า query ที่ไม่รู้จักถูกปฏิเสธตั้งแต่ชั้นตรวจสอบ', async () => {
  const { token } = await login('kitchen', 'kitchen123');

  assert.equal((await get('/api/v1/orders/kitchen/queue?status=junk', token)).status, 422);
  assert.equal((await get('/api/v1/orders/kitchen/queue?status=', token)).status, 422);
  assert.equal((await get('/api/v1/orders/kitchen/queue?station=ครัว', token)).status, 422);
  assert.equal((await get('/api/v1/orders/kitchen/queue?station=nope', token)).status, 404);
  assert.equal((await get('/api/v1/orders/kitchen/queue?status=pending', token)).status, 200);
});

test('รายการที่สั่งเพิ่มเข้าออเดอร์ที่ส่งครัวแล้ว ได้สถานีประทับมาด้วย', async () => {
  const { token } = await login('admin', 'admin123');
  const cold = await stationByCode(token, 'cold');

  const category = await createCategory(token, cold.id);
  const first = await createMenuItem(token, { categoryId: category.id });
  const second = await createMenuItem(token, { categoryId: category.id });
  const order = await sendOrder(token, [first.id]);

  const added = await post(`/api/v1/orders/${order.id}/items`, token, {
    items: [{ menuItemId: second.id, quantity: 1 }],
  });
  assert.equal(added.status, 201, JSON.stringify(added.body));

  const tickets = await queueItemsOf(token, order.id, '?station=cold');
  assert.equal(tickets.length, 2);
  assert.ok(tickets.every((item) => item.stationName === cold.name));
});

test('ลูกค้าสั่งเองผ่าน QR ก็ได้สถานีประทับเหมือนพนักงานสั่ง', async () => {
  const { token } = await login('admin', 'admin123');
  const bar = await stationByCode(token, 'bar');

  const category = await createCategory(token, bar.id);
  const item = await createMenuItem(token, { categoryId: category.id });
  const table = await createTable(token);

  const res = await api()
    .post(`/api/v1/public/tables/${table.qrToken}/items`)
    .send({ items: [{ menuItemId: item.id, quantity: 1 }] });
  assert.equal(res.status, 200, JSON.stringify(res.body));

  const queue = await get('/api/v1/orders/kitchen/queue?station=bar', token);
  const ticket = queue.body.data.find((row) => row.menuItemId === item.id);
  assert.ok(ticket, 'ตั๋วของลูกค้าต้องขึ้นคิวบาร์');
  assert.equal(ticket.stationCode, 'bar');
  assert.equal(ticket.stationName, bar.name);
});
