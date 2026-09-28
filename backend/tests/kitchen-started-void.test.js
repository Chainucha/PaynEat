// Copyright 2026 Suruch Chakrapeesirisuk
// SPDX-License-Identifier: Apache-2.0

import test, { after, before } from 'node:test';
import assert from 'node:assert/strict';
import { api, login, authHeader, cleanup } from './helpers/testApp.js';

// ยกเลิกรายการที่ครัวเคยลงมือทำแล้วต้องใช้ผู้จัดการและถูกบันทึก audit เสมอ แม้สถานะถูกถอยกลับไป pending ด้วยปุ่ม
// "เลิกทำ" (T05 #104, docs/DECISIONS.md #86) — ปุ่มเลิกทำยังย้อนได้หนึ่งขั้นเหมือนเดิม (DECISIONS #64)

const { getDb } = await import('../src/db/index.js');

after(cleanup);

const get = (url, token) => api().get(url).set(authHeader(token));
const send = (method, url, token, body) =>
  api()
    [method](url)
    .set(authHeader(token))
    .send(body ?? {});

let waiter;
let kitchen;
let manager;
let admin;
let stockedMenuItem;

before(async () => {
  waiter = await login('waiter1', 'waiter123');
  kitchen = await login('kitchen', 'kitchen123');
  manager = await login('manager', 'manager123');
  admin = await login('admin', 'admin123');
  const menu = await get('/api/v1/menu-items?availableOnly=true&limit=200', waiter.token);
  const linked = new Set(
    getDb()
      .prepare('SELECT DISTINCT menu_item_id AS id FROM menu_item_ingredients')
      .all()
      .map((row) => row.id),
  );
  stockedMenuItem = menu.body.data.find(
    (item) =>
      !item.soldByWeight &&
      !item.optionGroups.some((group) => group.isRequired) &&
      linked.has(item.id),
  );
  assert.ok(stockedMenuItem, 'ต้องมีเมนูที่ผูกวัตถุดิบ');
});

/** ออเดอร์ 2 รายการที่ส่งครัวแล้ว (สต๊อกถูกตัด) — รายการแรกใช้ทดสอบ รายการที่สองให้ออเดอร์ยังไม่ว่าง */
const orderInKitchen = async () => {
  const table = (await get('/api/v1/tables?status=available', waiter.token)).body.data[0];
  const res = await send('post', '/api/v1/orders', waiter.token, {
    type: 'dine_in',
    tableId: table.id,
    guestCount: 2,
    items: [
      { menuItemId: stockedMenuItem.id, quantity: 1, optionIds: [] },
      { menuItemId: stockedMenuItem.id, quantity: 2, optionIds: [] },
    ],
  });
  assert.equal(res.status, 201, JSON.stringify(res.body));
  const sent = await send(
    'post',
    `/api/v1/orders/${res.body.data.id}/send-to-kitchen`,
    waiter.token,
  );
  assert.equal(sent.status, 200, JSON.stringify(sent.body));
  return sent.body.data;
};

const setStatus = (order, itemId, status, token) =>
  send('patch', `/api/v1/orders/${order.id}/items/${itemId}/status`, token, { status });

/** เดินสถานะตามลำดับ ทุกขั้นต้องผ่าน แล้วคืนรายการจากขั้นสุดท้าย */
const walk = async (order, itemId, steps) => {
  let item;
  for (const [status, token] of steps) {
    const res = await setStatus(order, itemId, status, token);
    assert.equal(res.status, 200, `${status}: ${JSON.stringify(res.body)}`);
    item = res.body.data.items.find((row) => row.id === itemId);
  }
  return item;
};

const stockOf = () =>
  getDb().prepare('SELECT id, current_stock FROM ingredients ORDER BY id').all();

const voidLogs = async (itemId) => {
  const res = await get(
    `/api/v1/audit-logs?action=order_item.void&entityId=${itemId}&limit=5`,
    admin.token,
  );
  assert.equal(res.status, 200, JSON.stringify(res.body));
  return res.body.data;
};

test('ยกเลิกรายการที่ครัวกำลังทำ: พนักงานเสิร์ฟและครัวได้ 403 เป็นภาษาของผู้ใช้', async () => {
  const order = await orderInKitchen();
  const itemId = order.items[0].id;
  await walk(order, itemId, [['cooking', kitchen.token]]);

  for (const token of [waiter.token, kitchen.token]) {
    const res = await setStatus(order, itemId, 'cancelled', token);
    assert.equal(res.status, 403, JSON.stringify(res.body));
    assert.match(res.body.error.message, /ผู้จัดการ/);
  }
  const english = await setStatus(order, itemId, 'cancelled', waiter.token).set(
    'Accept-Language',
    'en',
  );
  assert.equal(english.status, 403);
  assert.match(english.body.error.message, /needs a manager/);
  assert.deepEqual(await voidLogs(itemId), []);
});

test('ready → cooking → pending แล้วพนักงานเสิร์ฟยกเลิก → 403 และยอด สต๊อก สถานะไม่เปลี่ยน', async () => {
  const order = await orderInKitchen();
  const itemId = order.items[0].id;
  await walk(order, itemId, [
    ['cooking', kitchen.token],
    ['ready', kitchen.token],
  ]);
  // ถอยกลับทีละขั้นจนถึง pending — ระบบยังจำว่าครัวเคยทำเสร็จแล้ว
  const undone = await walk(order, itemId, [
    ['cooking', waiter.token],
    ['pending', waiter.token],
  ]);
  assert.equal(undone.status, 'pending');
  assert.equal(undone.kitchenReached, 'ready');

  const before = {
    stock: stockOf(),
    order: (await get(`/api/v1/orders/${order.id}`, manager.token)).body.data,
  };
  const res = await setStatus(order, itemId, 'cancelled', waiter.token);
  assert.equal(res.status, 403, JSON.stringify(res.body));
  assert.match(res.body.error.message, /ผู้จัดการ/);

  const after = (await get(`/api/v1/orders/${order.id}`, manager.token)).body.data;
  assert.equal(after.total, before.order.total);
  assert.equal(after.items[0].status, 'pending');
  assert.deepEqual(stockOf(), before.stock);
  assert.deepEqual(await voidLogs(itemId), []);
});

test('ลำดับเดียวกันโดยผู้จัดการ → ยกเลิกได้ คืนสต๊อก และ audit order_item.void บอกขั้นที่ครัวเคยทำถึง', async () => {
  const order = await orderInKitchen();
  const [target, other] = order.items;
  await walk(order, target.id, [
    ['cooking', kitchen.token],
    ['ready', kitchen.token],
    ['cooking', waiter.token],
    ['pending', waiter.token],
  ]);

  const stockBefore = stockOf();
  const res = await setStatus(order, target.id, 'cancelled', manager.token);
  assert.equal(res.status, 200, JSON.stringify(res.body));
  const cancelled = res.body.data.items.find((row) => row.id === target.id);
  assert.equal(cancelled.status, 'cancelled');
  assert.equal(cancelled.kitchenReached, 'ready');
  assert.equal(res.body.data.subtotal, other.lineTotal);
  assert.notDeepEqual(stockOf(), stockBefore, 'ยกเลิกรายการที่ตัดสต๊อกแล้วต้องคืนสต๊อก');

  const [log] = await voidLogs(target.id);
  assert.ok(log, 'ต้องมี audit log order_item.void');
  assert.equal(log.actorName, 'สมชาย (ผู้จัดการ)');
  assert.equal(
    log.summary,
    `ยกเลิกรายการ "${target.name}" ในออเดอร์ #${order.code} (สถานะก่อนยกเลิก: pending, ครัวเคยทำถึง: ready)`,
  );
  assert.equal(log.metadata.previousStatus, 'pending');
  assert.equal(log.metadata.kitchenReached, 'ready');
  assert.deepEqual(log.metadata.summaryArgs, {
    code: order.code,
    name: target.name,
    status: 'pending',
    reached: 'ready',
  });
});

test('ผู้จัดการยกเลิกรายการที่ไม่ได้ถูกเลิกทำ: audit เหมือนเดิม ไม่มีขั้นที่เคยถึงซ้ำกับสถานะ', async () => {
  const order = await orderInKitchen();
  const itemId = order.items[0].id;
  await walk(order, itemId, [['cooking', kitchen.token]]);
  const res = await setStatus(order, itemId, 'cancelled', manager.token);
  assert.equal(res.status, 200, JSON.stringify(res.body));

  const [log] = await voidLogs(itemId);
  assert.match(log.summary, /\(สถานะก่อนยกเลิก: cooking\)$/);
  assert.equal(log.metadata.kitchenReached, 'cooking');
  assert.equal(log.metadata.summaryArgs.reached, undefined);
});

test('รายการที่ครัวเคยเริ่มทำแล้วถูกเลิกทำ: แก้จำนวนหรือลบไม่ได้ (409) ต้องใช้การยกเลิก', async () => {
  const order = await orderInKitchen();
  const itemId = order.items[0].id;
  await walk(order, itemId, [
    ['cooking', kitchen.token],
    ['pending', kitchen.token],
  ]);
  const base = `/api/v1/orders/${order.id}/items/${itemId}`;

  const edit = await send('patch', base, waiter.token, { quantity: 3 });
  assert.equal(edit.status, 409, JSON.stringify(edit.body));
  assert.match(edit.body.error.message, /ครัวเริ่มทำ/);
  const remove = await send('delete', base, waiter.token);
  assert.equal(remove.status, 409, JSON.stringify(remove.body));
  assert.match(remove.body.error.message, /ใช้การยกเลิกรายการแทน/);

  const now = (await get(`/api/v1/orders/${order.id}`, waiter.token)).body.data;
  assert.equal(now.items.length, 2);
  assert.equal(now.items[0].quantity, 1);
});

test('รายการที่ครัวยังไม่เคยแตะ: พนักงานเสิร์ฟยกเลิกเองได้ ไม่มี audit', async () => {
  const order = await orderInKitchen();
  const item = order.items[0];
  assert.equal(item.kitchenReached, null);

  const res = await setStatus(order, item.id, 'cancelled', waiter.token);
  assert.equal(res.status, 200, JSON.stringify(res.body));
  assert.equal(res.body.data.items[0].kitchenReached, null);
  assert.deepEqual(await voidLogs(item.id), []);
});

test('ครัวยังเลิกทำได้หนึ่งขั้นเหมือนเดิม และขั้นที่เคยถึงไม่ถอยลง', async () => {
  const order = await orderInKitchen();
  const itemId = order.items[0].id;
  const steps = [
    ['cooking', 'cooking'],
    ['ready', 'ready'],
    ['cooking', 'ready'],
    ['pending', 'ready'],
    ['cooking', 'ready'],
    ['ready', 'ready'],
    ['served', 'served'],
  ];
  for (const [status, reached] of steps) {
    const item = await walk(order, itemId, [[status, kitchen.token]]);
    assert.equal(item.status, status);
    assert.equal(item.kitchenReached, reached, `หลัง ${status}`);
  }
  // ช่องทางครัว (คิวครัว) เห็นค่าเดียวกัน
  const queue = (await get(`/api/v1/orders/${order.id}`, kitchen.token)).body.data;
  assert.equal(queue.items[0].kitchenReached, 'served');
});
