// Copyright 2026 Suruch Chakrapeesirisuk
// SPDX-License-Identifier: Apache-2.0

import test, { after } from 'node:test';
import assert from 'node:assert/strict';
import http from 'node:http';
import { api, login, authHeader, cleanup } from './helpers/testApp.js';
import { getDb } from '../src/db/index.js';
import { initSocket, getIo, closeSocket, EVENTS } from '../src/realtime/socket.js';

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

/** เปิดออเดอร์ที่โต๊ะใหม่ด้วยจานเดียว แล้วส่งครัวถ้า send=true */
const orderDish = async (token, menuItemId, send) => {
  const table = await post('/api/v1/tables', token, { name: unique('T') });
  assert.equal(table.status, 201, JSON.stringify(table.body));
  const order = await post('/api/v1/orders', token, {
    type: 'dine_in',
    tableId: table.body.data.id,
    guestCount: 1,
    items: [{ menuItemId, quantity: 1 }],
  });
  assert.equal(order.status, 201, JSON.stringify(order.body));
  if (send) {
    const sent = await post(`/api/v1/orders/${order.body.data.id}/send-to-kitchen`, token);
    assert.equal(sent.status, 200, JSON.stringify(sent.body));
  }
  return order.body.data;
};

test('pendingCount นับเฉพาะรายการที่ส่งครัวแล้ว และตั๋วไม่มีสถานีนับเป็นสถานีค่าเริ่มต้น', async () => {
  const { token } = await login('admin', 'admin123');
  const { station, dish } = await stationWithDish(token);

  await orderDish(token, dish.id, true);
  await orderDish(token, dish.id, false); // ยัง open ต้องไม่ถูกนับ
  assert.equal((await statusOf(token, station.id)).pendingCount, 1);

  // จานที่ไม่ผูกสถานี (เมนู/หมวดหมู่ไม่ระบุ) ไปตกที่สถานีค่าเริ่มต้น
  const stations = (await get('/api/v1/kitchen-stations/status', token)).body.data;
  const defaults = (await get('/api/v1/kitchen-stations', token)).body.data;
  const defaultId = defaults.find((row) => row.isDefault).id;
  const before = stations.find((row) => row.stationId === defaultId).pendingCount;
  const category = await post('/api/v1/categories', token, { name: unique('หมวด-') });
  assert.equal(category.status, 201, JSON.stringify(category.body));
  const plain = await post('/api/v1/menu-items', token, {
    categoryId: category.body.data.id,
    name: unique('จาน-'),
    price: 40,
    branchId: 1,
  });
  assert.equal(plain.status, 201, JSON.stringify(plain.body));
  await orderDish(token, plain.body.data.id, true);
  assert.equal((await statusOf(token, defaultId)).pendingCount, before + 1);

  // ปิดสถานีแล้ว audit เก็บจำนวนที่ค้างจริง
  await post(`/api/v1/kitchen-stations/${station.id}/close`, token);
  const [log] = await auditFor(token, 'kitchen_station.close', station.id);
  assert.deepEqual(log.metadata.summaryArgs, { station: station.name, pending: 1 });
});

test('ส่ง station:status เมื่อสถานะเปลี่ยนจริงเท่านั้น ไม่ส่งตอนปิดซ้ำ/เปิดซ้ำ', async () => {
  const { token } = await login('admin', 'admin123');
  const { station } = await stationWithDish(token);
  initSocket(http.createServer());
  try {
    const captured = [];
    getIo().to = (rooms) => ({
      emit: (event, payload) => captured.push({ rooms, event, payload }),
    });
    const url = (action) => `/api/v1/kitchen-stations/${station.id}/${action}`;

    await post(url('close'), token);
    assert.equal(captured.length, 1);
    const [first] = captured;
    assert.equal(first.event, EVENTS.STATION_STATUS);
    assert.equal(first.payload.branchId, 1);
    assert.equal(first.payload.stationId, station.id);
    assert.equal(first.payload.isClosed, true);
    for (const room of ['room:kitchen', 'room:service', 'room:management']) {
      assert.ok(first.rooms.includes(room), `ต้องส่งเข้า ${room}`);
    }

    await post(url('close'), token);
    assert.equal(captured.length, 1);
    await post(url('open'), token);
    assert.equal(captured.length, 2);
    assert.equal(captured[1].payload.isClosed, false);
    await post(url('open'), token);
    assert.equal(captured.length, 2);
  } finally {
    closeSocket();
  }
});

const createTable = async (token) => {
  const res = await post('/api/v1/tables', token, { name: unique('T').slice(0, 20) });
  assert.equal(res.status, 201, JSON.stringify(res.body));
  return res.body.data;
};

const openOrder = (token, tableId, menuItemId) =>
  post('/api/v1/orders', token, {
    type: 'dine_in',
    tableId,
    guestCount: 1,
    items: [{ menuItemId, quantity: 1 }],
  });

test('สั่งจานของสถานีที่ปิด → 409 ทั้งเปิดบิล สั่งเพิ่ม และ QR โดยไม่มีอะไรถูกบันทึก', async () => {
  const { token } = await login('admin', 'admin123');
  const { station, dish } = await stationWithDish(token);
  const other = (await get('/api/v1/menu-items?availableOnly=true&limit=1', token)).body.data[0];

  // สั่งเพิ่มเข้าออเดอร์ที่ส่งครัวแล้ว — เปิดออเดอร์ก่อนปิดสถานี
  const tableA = await createTable(token);
  const running = (await openOrder(token, tableA.id, other.id)).body.data;
  await post(`/api/v1/orders/${running.id}/send-to-kitchen`, token);

  await post(`/api/v1/kitchen-stations/${station.id}/close`, token);

  const tableB = await createTable(token);
  const created = await openOrder(token, tableB.id, dish.id);
  assert.equal(created.status, 409);
  assert.match(created.body.error.message, new RegExp(`${station.name}.*${dish.name}`));

  const added = await post(`/api/v1/orders/${running.id}/items`, token, {
    items: [{ menuItemId: dish.id, quantity: 1 }],
  });
  assert.equal(added.status, 409);
  const after = (await get(`/api/v1/orders/${running.id}`, token)).body.data;
  assert.equal(after.items.length, 1, 'ไม่มีรายการใหม่ถูกเพิ่ม');

  const tableC = await createTable(token);
  const qr = await api()
    .post(`/api/v1/public/tables/${tableC.qrToken}/items`)
    .send({ items: [{ menuItemId: dish.id, quantity: 1 }] });
  assert.equal(qr.status, 409);
});

test('ออเดอร์ที่บันทึกไว้ยังไม่ส่งครัว แล้วสถานีปิด → ส่งครัวไม่ได้ (409)', async () => {
  const { token } = await login('admin', 'admin123');
  const { station, dish } = await stationWithDish(token);
  const table = await createTable(token);
  const saved = (await openOrder(token, table.id, dish.id)).body.data;
  assert.equal(saved.status, 'open');

  await post(`/api/v1/kitchen-stations/${station.id}/close`, token);

  const sent = await post(`/api/v1/orders/${saved.id}/send-to-kitchen`, token);
  assert.equal(sent.status, 409);
  assert.equal((await get(`/api/v1/orders/${saved.id}`, token)).body.data.status, 'open');
});

test('บิลเก่าที่ station_id เป็น NULL ถูกนับเป็นสถานีค่าเริ่มต้น → ปิดสถานีค่าเริ่มต้นแล้วส่งครัวไม่ได้ (409)', async () => {
  const { token } = await login('admin', 'admin123');
  const { dish } = await stationWithDish(token);
  const table = await createTable(token);
  const saved = (await openOrder(token, table.id, dish.id)).body.data;
  assert.equal(saved.status, 'open');
  // จำลองบิลที่บันทึกไว้ก่อนมีสถานี (ticket 34) — รายการไม่มี station_id
  getDb()
    .prepare(
      'UPDATE order_items SET station_id = NULL, station_name_snapshot = NULL WHERE order_id = ?',
    )
    .run(saved.id);

  const defaultId = getDb()
    .prepare('SELECT id FROM kitchen_stations WHERE is_default = 1')
    .get().id;
  try {
    await post(`/api/v1/kitchen-stations/${defaultId}/close`, token);
    const sent = await post(`/api/v1/orders/${saved.id}/send-to-kitchen`, token);
    assert.equal(sent.status, 409, JSON.stringify(sent.body));
    assert.equal((await get(`/api/v1/orders/${saved.id}`, token)).body.data.status, 'open');
  } finally {
    await post(`/api/v1/kitchen-stations/${defaultId}/open`, token);
  }
});

test('รายการที่อยู่ในคิวก่อนปิด ยังอยู่บนจอครัวและเดินสถานะได้ตามปกติ', async () => {
  const { token } = await login('admin', 'admin123');
  const { station, dish } = await stationWithDish(token);
  const table = await createTable(token);
  const order = (await openOrder(token, table.id, dish.id)).body.data;
  await post(`/api/v1/orders/${order.id}/send-to-kitchen`, token);

  const closed = await post(`/api/v1/kitchen-stations/${station.id}/close`, token);
  assert.equal(closed.body.data.pendingCount, 1);

  const queue = (await get(`/api/v1/orders/kitchen/queue?station=${station.code}`, token)).body
    .data;
  const ticket = queue.find((item) => item.orderId === order.id);
  assert.ok(ticket, 'ตั๋วยังอยู่บนจอ');
  const cooking = await patch(`/api/v1/orders/${order.id}/items/${ticket.id}/status`, token, {
    status: 'cooking',
  });
  assert.equal(cooking.status, 200, JSON.stringify(cooking.body));
});

test('ไม่ถอยไปสถานีอื่น: ปิดสถานีค่าเริ่มต้น → จานที่ไม่ได้กำหนดสถานีสั่งไม่ได้', async () => {
  const { token } = await login('admin', 'admin123');
  const stations = (await get('/api/v1/kitchen-stations', token)).body.data;
  const fallback = stations.find((row) => row.isDefault);
  const category = (await post('/api/v1/categories', token, { name: unique('หมวด-') })).body.data;
  const dish = (
    await post('/api/v1/menu-items', token, {
      categoryId: category.id,
      name: unique('จาน-'),
      price: 50,
      branchId: 1,
    })
  ).body.data;

  await post(`/api/v1/kitchen-stations/${fallback.id}/close`, token);
  try {
    const table = await createTable(token);
    assert.equal((await openOrder(token, table.id, dish.id)).status, 409);
  } finally {
    // สถานีค่าเริ่มต้นใช้ร่วมกับเทสต์อื่นในไฟล์ — เปิดคืนเสมอ
    await post(`/api/v1/kitchen-stations/${fallback.id}/open`, token);
  }
});

test('สถานีที่ปิดอยู่แล้วถูกปิดใช้งานภายหลัง → แถวปิดค้างไม่มีผล จานสั่งได้', async () => {
  const { token } = await login('admin', 'admin123');
  const { station, dish } = await stationWithDish(token);
  await post(`/api/v1/kitchen-stations/${station.id}/close`, token);
  await patch(`/api/v1/kitchen-stations/${station.id}`, token, { isActive: false });

  const table = await createTable(token);
  assert.equal((await openOrder(token, table.id, dish.id)).status, 201);
});

test('เมนูพนักงานบอก closedStation ส่วนเมนู QR ไม่มีจานนั้นเลย — is_available ไม่ถูกแตะ', async () => {
  const { token } = await login('admin', 'admin123');
  const { station, dish } = await stationWithDish(token);
  const table = await createTable(token);
  // ตั้งธงตัดอัตโนมัติจากสต๊อกไว้ก่อน เพื่อให้การเทียบก่อน/หลังมีความหมาย
  getDb().prepare('UPDATE menu_items SET auto_disabled_by_stock = 1 WHERE id = ?').run(dish.id);
  const findDish = async () =>
    (
      await get(`/api/v1/menu-items?search=${encodeURIComponent(dish.name)}&limit=200`, token)
    ).body.data.find((row) => row.id === dish.id);

  assert.equal((await findDish()).closedStation, null);

  await post(`/api/v1/kitchen-stations/${station.id}/close`, token);

  const closedRow = await findDish();
  assert.deepEqual(closedRow.closedStation, {
    id: station.id,
    name: station.name,
    nameEn: null,
    nameKo: null,
  });
  assert.equal(closedRow.isAvailable, true, 'ปิดสถานีไม่แตะ is_available');
  assert.equal(
    getDb().prepare('SELECT auto_disabled_by_stock AS v FROM menu_items WHERE id = ?').get(dish.id)
      .v,
    1,
    'ปิดสถานีไม่แตะ auto_disabled_by_stock',
  );

  const publicMenu = (await api().get(`/api/v1/public/tables/${table.qrToken}/menu`)).body.data;
  assert.ok(!publicMenu.items.some((row) => row.id === dish.id), 'QR ไม่เห็นจานของสถานีที่ปิด');

  await post(`/api/v1/kitchen-stations/${station.id}/open`, token);
  assert.equal((await findDish()).closedStation, null);
  assert.equal(
    getDb().prepare('SELECT auto_disabled_by_stock AS v FROM menu_items WHERE id = ?').get(dish.id)
      .v,
    1,
    'เปิดสถานีคืนก็ไม่แตะ auto_disabled_by_stock',
  );
});

test('เมนูที่ปิดขายไว้ก่อน → ปิดแล้วเปิดสถานีคืน เมนูนั้นยังปิดขายอยู่', async () => {
  const { token } = await login('admin', 'admin123');
  const { station, dish } = await stationWithDish(token);
  await patch(`/api/v1/menu-items/${dish.id}/availability`, token, { isAvailable: false });

  await post(`/api/v1/kitchen-stations/${station.id}/close`, token);
  await post(`/api/v1/kitchen-stations/${station.id}/open`, token);

  const row = (await get(`/api/v1/menu-items/${dish.id}`, token)).body.data;
  assert.equal(row.isAvailable, false);
});

test('admin โหมดทุกสาขาเห็น closedStation ตามสาขาของจานเอง', async () => {
  const admin = await login('admin', 'admin123');
  const { station, dish } = await stationWithDish(admin.token);
  await post(`/api/v1/kitchen-stations/${station.id}/close`, admin.token);

  const all = await post('/api/v1/auth/select-branch', admin.token, { branchId: null });
  const rows = (
    await get(
      `/api/v1/menu-items?search=${encodeURIComponent(dish.name)}&limit=200`,
      all.body.data.token,
    )
  ).body.data;
  assert.equal(rows.find((row) => row.id === dish.id).closedStation?.id, station.id);
});
