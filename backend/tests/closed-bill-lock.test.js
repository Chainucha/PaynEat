// Copyright 2026 Suruch Chakrapeesirisuk
// SPDX-License-Identifier: Apache-2.0

import test, { after, before } from 'node:test';
import assert from 'node:assert/strict';
import { api, login, authHeader, cleanup } from './helpers/testApp.js';

// บิลที่ปิดแล้วและรายการที่รับเงินไปแล้วยกเลิกไม่ได้ (T04 #95, docs/DECISIONS.md #85) — ยอดขาย VAT ใบกำกับภาษี และสต๊อก
// ของเงินที่รับไปแล้วต้องไม่เปลี่ยนเงียบๆ ส่วนครัวยังทำอาหารของบิลที่จ่ายก่อนทำ (takeaway) ได้ตามปกติ

const { getDb } = await import('../src/db/index.js');

after(cleanup);

const get = (url, token) => api().get(url).set(authHeader(token));
const send = (method, url, token, body) =>
  api()
    [method](url)
    .set(authHeader(token))
    .send(body ?? {});

let waiter;
let cashier;
let manager;
let kitchen;
let stockedMenuItem;
let plainMenuItem;

before(async () => {
  waiter = await login('waiter1', 'waiter123');
  cashier = await login('cashier', 'cashier123');
  manager = await login('manager', 'manager123');
  kitchen = await login('kitchen', 'kitchen123');
  const menu = await get('/api/v1/menu-items?availableOnly=true&limit=200', waiter.token);
  const simple = menu.body.data.filter(
    (item) => !item.soldByWeight && !item.optionGroups.some((group) => group.isRequired),
  );
  const linked = new Set(
    getDb()
      .prepare('SELECT DISTINCT menu_item_id AS id FROM menu_item_ingredients')
      .all()
      .map((row) => row.id),
  );
  stockedMenuItem = simple.find((item) => linked.has(item.id));
  plainMenuItem = simple.find((item) => item.id !== stockedMenuItem?.id);
  assert.ok(stockedMenuItem && plainMenuItem, 'ต้องมีเมนูที่ผูกวัตถุดิบและเมนูธรรมดา');
});

const openOrder = async (payload) => {
  const res = await send('post', '/api/v1/orders', waiter.token, payload);
  assert.equal(res.status, 201, JSON.stringify(res.body));
  return res.body.data;
};

const dineIn = async (menuItems) => {
  const tables = await get('/api/v1/tables?status=available', waiter.token);
  return openOrder({
    type: 'dine_in',
    tableId: tables.body.data[0].id,
    guestCount: 2,
    items: menuItems.map((item) => ({ menuItemId: item.id, quantity: 1, optionIds: [] })),
  });
};

const pay = async (order, extra = {}) => {
  const res = await send('post', '/api/v1/payments', cashier.token, {
    orderId: order.id,
    method: 'cash',
    ...(extra.itemIds ? {} : { amount: order.total, received: order.total }),
    ...extra,
  });
  assert.equal(res.status, 201, JSON.stringify(res.body));
  return res.body.data;
};

const setItemStatus = (order, itemId, status, token) =>
  send('patch', `/api/v1/orders/${order.id}/items/${itemId}/status`, token, { status });

const stockOf = () =>
  getDb().prepare('SELECT id, current_stock FROM ingredients ORDER BY id').all();

test('บิลจ่ายครบแล้ว: ยกเลิกรายการไม่ได้ทุกบทบาท (409) และยอด สต๊อก สถานะรายการไม่เปลี่ยน', async () => {
  const order = await dineIn([stockedMenuItem, plainMenuItem]);
  await send('post', `/api/v1/orders/${order.id}/send-to-kitchen`, waiter.token);
  const paid = await pay(order);
  assert.equal(paid.order.status, 'paid');

  const before = {
    stock: stockOf(),
    order: (await get(`/api/v1/orders/${order.id}`, manager.token)).body.data,
  };
  for (const token of [waiter.token, manager.token]) {
    const res = await setItemStatus(order, order.items[0].id, 'cancelled', token);
    assert.equal(res.status, 409, JSON.stringify(res.body));
    assert.match(res.body.error.message, /ปิดแล้ว/);
  }
  const english = await setItemStatus(order, order.items[0].id, 'cancelled', manager.token).set(
    'Accept-Language',
    'en',
  );
  assert.match(english.body.error.message, /closed/);

  const after = (await get(`/api/v1/orders/${order.id}`, manager.token)).body.data;
  assert.equal(after.total, before.order.total);
  assert.equal(after.subtotal, before.order.subtotal);
  assert.equal(after.vat, before.order.vat);
  assert.deepEqual(
    after.items.map((item) => item.status),
    before.order.items.map((item) => item.status),
  );
  assert.deepEqual(stockOf(), before.stock);
});

test('ออเดอร์ที่ถูกยกเลิกแล้ว: ยกเลิกรายการที่เสิร์ฟไปแล้วซ้ำไม่ได้ด้วยเหตุผลว่าบิลปิดแล้ว', async () => {
  const order = await dineIn([plainMenuItem]);
  await send('post', `/api/v1/orders/${order.id}/send-to-kitchen`, waiter.token);
  const itemId = order.items[0].id;
  for (const status of ['cooking', 'ready', 'served']) {
    assert.equal((await setItemStatus(order, itemId, status, kitchen.token)).status, 200);
  }
  const cancelled = await send('post', `/api/v1/orders/${order.id}/cancel`, manager.token, {
    reason: 'ลูกค้าเปลี่ยนใจ',
  });
  assert.equal(cancelled.status, 200);

  const res = await setItemStatus(order, itemId, 'cancelled', manager.token);
  assert.equal(res.status, 409);
  assert.match(res.body.error.message, /ปิดแล้ว/);
});

test('รายการที่ชำระแบบแยกจ่ายแล้วยกเลิกไม่ได้ (ต้องคืนเงินก่อน) ส่วนรายการที่ยังไม่จ่ายยกเลิกได้', async () => {
  const order = await dineIn([stockedMenuItem, plainMenuItem]);
  const [paidItem, unpaidItem] = order.items;
  const split = await pay(order, { itemIds: [paidItem.id] });
  assert.equal(split.isFullyPaid, false);

  const before = stockOf();
  const refused = await setItemStatus(order, paidItem.id, 'cancelled', manager.token);
  assert.equal(refused.status, 409);
  assert.match(refused.body.error.message, /ชำระเงินแล้ว/);
  const english = await setItemStatus(order, paidItem.id, 'cancelled', manager.token).set(
    'Accept-Language',
    'en',
  );
  assert.match(english.body.error.message, /refund it before cancelling/);
  assert.deepEqual(stockOf(), before);

  const ok = await setItemStatus(order, unpaidItem.id, 'cancelled', waiter.token);
  assert.equal(ok.status, 200, JSON.stringify(ok.body));
  const statusOf = (id) => ok.body.data.items.find((item) => item.id === id).status;
  assert.equal(statusOf(paidItem.id), 'pending');
  assert.equal(statusOf(unpaidItem.id), 'cancelled');
});

test('ครัวยังเดินสถานะอาหารของบิล takeaway ที่จ่ายก่อนทำได้ครบ และเลิกทำย้อนได้หนึ่งขั้น', async () => {
  const order = await openOrder({
    type: 'takeaway',
    items: [{ menuItemId: plainMenuItem.id, quantity: 1, optionIds: [] }],
  });
  await send('post', `/api/v1/orders/${order.id}/send-to-kitchen`, waiter.token);
  const paid = await pay(order);
  assert.equal(paid.order.status, 'paid');

  const itemId = order.items[0].id;
  for (const status of ['cooking', 'pending', 'cooking', 'ready', 'served']) {
    const res = await setItemStatus(order, itemId, status, kitchen.token);
    assert.equal(res.status, 200, `${status}: ${JSON.stringify(res.body)}`);
  }
  const final = (await get(`/api/v1/orders/${order.id}`, kitchen.token)).body.data;
  assert.equal(final.status, 'paid');
  assert.equal(final.items[0].status, 'served');
  assert.equal(final.total, order.total);
});
