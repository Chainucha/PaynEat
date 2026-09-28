// Copyright 2026 Suruch Chakrapeesirisuk
// SPDX-License-Identifier: Apache-2.0

import test, { after, before } from 'node:test';
import assert from 'node:assert/strict';
import { api, login, authHeader, cleanup } from './helpers/testApp.js';

// ยอด "จ่ายแล้ว" = ยอดชำระ − ยอดคืนเงิน ทุกจุดที่คิดยอดคงเหลือหรือสถานะจ่ายครบ (T06 #82, docs/DECISIONS.md #77 D1, #87)
// คืนเงินบนบิลที่ยังเปิดได้ ยอดคงเหลือเพิ่มขึ้นตามยอดที่คืน และบิลปิดได้เมื่อเก็บครบตามยอดสุทธิเท่านั้น

after(cleanup);

const get = (url, token) => api().get(url).set(authHeader(token));
const post = (url, token, body) =>
  api()
    .post(url)
    .set(authHeader(token))
    .send(body ?? {});
const patch = (url, token, body) => api().patch(url).set(authHeader(token)).send(body);

/** ปัดเป็นสตางค์ — ยอดใน API เป็นบาททศนิยม 2 ตำแหน่ง */
const baht = (value) => Math.round(value * 100) / 100;

let waiter;
let cashier;
let manager;
let simpleMenu;

before(async () => {
  waiter = await login('waiter1', 'waiter123');
  cashier = await login('cashier', 'cashier123');
  manager = await login('manager', 'manager123');
  const menu = await get('/api/v1/menu-items?availableOnly=true&limit=200', waiter.token);
  simpleMenu = menu.body.data.filter(
    (item) => !item.soldByWeight && !item.optionGroups.some((group) => group.isRequired),
  );
  assert.ok(simpleMenu.length >= 2, 'ต้องมีเมนูธรรมดาอย่างน้อย 2 รายการ');
});

const openOrder = async (menuItems = [simpleMenu[0]]) => {
  const table = (await get('/api/v1/tables?status=available', waiter.token)).body.data[0];
  const res = await post('/api/v1/orders', waiter.token, {
    type: 'dine_in',
    tableId: table.id,
    guestCount: 2,
    items: menuItems.map((item) => ({ menuItemId: item.id, quantity: 1, optionIds: [] })),
  });
  assert.equal(res.status, 201, JSON.stringify(res.body));
  return res.body.data;
};

const pay = async (order, body) => {
  const res = await post('/api/v1/payments', cashier.token, {
    orderId: order.id,
    method: 'cash',
    ...body,
  });
  return res;
};

const payCash = async (order, amount) => {
  const res = await pay(order, { amount, received: amount });
  assert.equal(res.status, 201, JSON.stringify(res.body));
  return res.body.data;
};

const refund = async (payment, amount) => {
  const res = await post(`/api/v1/payments/${payment.id}/refund`, manager.token, {
    amount,
    reason: 'ลูกค้าเปลี่ยนใจ',
  });
  assert.equal(res.status, 201, JSON.stringify(res.body));
  return res.body.data;
};

const summaryOf = async (order) => {
  const res = await get(`/api/v1/payments/order/${order.id}`, cashier.token);
  assert.equal(res.status, 200, JSON.stringify(res.body));
  return res.body.data;
};

test('จ่าย 50 แล้วคืน 50 บนบิลที่ยังเปิด → ยอดคงเหลือกลับเป็นยอดเต็ม และจ่ายแค่ส่วนที่เหลือเดิมไม่ปิดบิล', async () => {
  const order = await openOrder();
  assert.ok(order.total > 50, `ยอดบิลต้องเกิน 50 บาท (ได้ ${order.total})`);
  const { payment } = await payCash(order, 50);
  await refund(payment, 50);

  const summary = await summaryOf(order);
  assert.equal(summary.paid, 0);
  assert.equal(summary.refunded, 50);
  assert.equal(summary.remaining, order.total);
  assert.equal(summary.refunds.length, 1);
  assert.equal(summary.refunds[0].paymentId, payment.id);

  // ทางเดิมที่ปิดบิลได้ด้วยเงินสุทธิไม่ครบ: จ่ายส่วนที่เหลือเดิม (ยอด − 50) ต้องยังไม่ปิดบิล
  const partial = await payCash(order, baht(order.total - 50));
  assert.equal(partial.isFullyPaid, false);
  assert.equal(partial.remaining, 50);
  assert.equal(partial.order.status, order.status);

  // จ่ายเกินยอดสุทธิที่เหลือไม่ได้ จ่ายครบพอดีแล้วบิลปิด
  const over = await pay(order, { amount: 50.01, received: 50.01 });
  assert.equal(over.status, 400, JSON.stringify(over.body));
  const last = await payCash(order, 50);
  assert.equal(last.isFullyPaid, true);
  assert.equal(last.order.status, 'paid');

  const closed = await summaryOf(order);
  assert.equal(closed.paid, order.total);
  assert.equal(closed.remaining, 0);
});

test('คืนบางส่วนบนบิลที่ยังเปิด → ยอดคงเหลือเพิ่มเท่ายอดที่คืน และ split-preview ใช้ยอดเดียวกัน', async () => {
  const order = await openOrder([simpleMenu[0], simpleMenu[1]]);
  const { payment } = await payCash(order, 60);
  await refund(payment, 20);

  const summary = await summaryOf(order);
  assert.equal(summary.paid, 40);
  assert.equal(summary.refunded, 20);
  assert.equal(summary.remaining, baht(order.total - 40));

  const preview = await post(`/api/v1/payments/order/${order.id}/split-preview`, cashier.token, {
    itemIds: order.items.map((item) => item.id),
  });
  assert.equal(preview.status, 200, JSON.stringify(preview.body));
  assert.equal(preview.body.data.remaining, summary.remaining);
  assert.equal(preview.body.data.total, summary.remaining);
});

test('แยกจ่ายตามรายการแล้วคืน payment นั้นครบ → รายการกลับเป็นยังไม่จ่าย ยกเลิกหรือเลือกจ่ายใหม่ได้', async () => {
  const order = await openOrder([simpleMenu[0], simpleMenu[1]]);
  const [first, second] = order.items;

  const split = await pay(order, { itemIds: [first.id] });
  assert.equal(split.status, 201, JSON.stringify(split.body));
  const { payment } = split.body.data;
  const isPaid = (data, id) => data.items.find((item) => item.id === id).isPaid;
  assert.equal(isPaid(split.body.data.order, first.id), true);

  // คืนบางส่วน: เงินของรายการนี้ยังอยู่กับร้านบางส่วน รายการยังนับว่าจ่ายแล้ว
  await refund(payment, 1);
  let now = (await get(`/api/v1/orders/${order.id}`, cashier.token)).body.data;
  assert.equal(isPaid(now, first.id), true);

  // คืนส่วนที่เหลือจนครบ: รายการกลับเป็นยังไม่จ่าย
  await refund(payment, baht(payment.amount - 1));
  now = (await get(`/api/v1/orders/${order.id}`, cashier.token)).body.data;
  assert.equal(isPaid(now, first.id), false);
  assert.equal((await summaryOf(order)).remaining, order.total);

  // T04 บอกให้ "คืนเงินก่อนจึงจะยกเลิกได้" — หลังคืนครบต้องยกเลิกได้จริง
  const cancel = await patch(`/api/v1/orders/${order.id}/items/${first.id}/status`, waiter.token, {
    status: 'cancelled',
  });
  assert.equal(cancel.status, 200, JSON.stringify(cancel.body));

  // รายการที่เหลือจ่ายเป็นรอบสุดท้ายแล้วบิลปิดด้วยยอดสุทธิที่ถูกต้อง
  const rest = await pay(order, { itemIds: [second.id] });
  assert.equal(rest.status, 201, JSON.stringify(rest.body));
  assert.equal(rest.body.data.isFullyPaid, true);
  const closed = await summaryOf(order);
  assert.equal(closed.paid, closed.total);
  assert.equal(closed.remaining, 0);
});

test('คืนเงินหลังปิดบิล → บิลยังปิดอยู่ ไม่มียอดค้างใหม่ และรายการที่แยกจ่ายไว้ยังนับว่าจ่ายแล้ว', async () => {
  const order = await openOrder([simpleMenu[0], simpleMenu[1]]);
  const [first, second] = order.items;
  const firstPay = await pay(order, { itemIds: [first.id] });
  assert.equal(firstPay.status, 201, JSON.stringify(firstPay.body));
  const secondPay = await pay(order, { itemIds: [second.id] });
  assert.equal(secondPay.body.data.isFullyPaid, true);

  const { payment } = firstPay.body.data;
  await refund(payment, payment.amount);

  const after = (await get(`/api/v1/orders/${order.id}`, cashier.token)).body.data;
  assert.equal(after.status, 'paid');
  assert.ok(after.items.every((item) => item.isPaid));
  const summary = await summaryOf(order);
  assert.equal(summary.remaining, 0);
  assert.equal(summary.refunded, payment.amount);
  assert.equal(summary.paid, baht(order.total - payment.amount));

  const again = await pay(order, { amount: 1, received: 1 });
  assert.equal(again.status, 409, 'บิลที่ปิดแล้วรับชำระเพิ่มไม่ได้');
});
