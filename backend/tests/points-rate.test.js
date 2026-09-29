// Copyright 2026 Suruch Chakrapeesirisuk
// SPDX-License-Identifier: Apache-2.0

import test, { after, before } from 'node:test';
import assert from 'node:assert/strict';
import { api, login, authHeader, cleanup } from './helpers/testApp.js';
import { getDb } from '../src/db/index.js';

// อัตราสะสมแต้มและมูลค่าแต้มต้องอย่างน้อย 0.01 บาท และค่าที่บันทึกไว้ก่อนมีกฎนี้ (เช่น 0) ต้องไม่ทำให้แต้มเป็น
// Infinity — ขายแล้วไม่ได้แต้ม และแลกแต้มไม่ได้ (T15 #84, docs/DECISIONS.md #89)

after(cleanup);

const get = (url, token) => api().get(url).set(authHeader(token));
const post = (url, token, body) =>
  api()
    .post(url)
    .set(authHeader(token))
    .send(body ?? {});
const patch = (url, token, body) =>
  api()
    .patch(url)
    .set(authHeader(token))
    .send(body ?? {});

let manager;
let cashier;
let water;

const uniq = () => `${Date.now()}${Math.round(Math.random() * 1e4)}`;

/** เขียนค่าตั้งลงฐานข้อมูลตรง ๆ แบบร้านที่ตั้งไว้ก่อนมีขั้นต่ำ — API ไม่ยอมให้ตั้งแล้ว */
const storeSetting = (key, value) =>
  getDb()
    .prepare(
      'INSERT INTO settings (key, value) VALUES (?, ?) ON CONFLICT(key) DO UPDATE SET value = excluded.value',
    )
    .run(key, value);

const withStoredSetting = async (key, value, run) => {
  const previous = getDb().prepare('SELECT value FROM settings WHERE key = ?').get(key)?.value;
  storeSetting(key, value);
  try {
    await run();
  } finally {
    if (previous === undefined) getDb().prepare('DELETE FROM settings WHERE key = ?').run(key);
    else storeSetting(key, previous);
  }
};

const newCustomer = async () => {
  const res = await post('/api/v1/customers', cashier.token, {
    name: `ลูกค้าแต้ม-${uniq()}`,
    phone: `08${uniq().slice(-8)}`,
  });
  assert.equal(res.status, 201, JSON.stringify(res.body));
  return res.body.data;
};

const openOrder = async (customerId, quantity = 20) => {
  const res = await post('/api/v1/orders', cashier.token, {
    type: 'takeaway',
    customerId,
    items: [{ menuItemId: water.id, quantity }],
  });
  assert.equal(res.status, 201, JSON.stringify(res.body));
  return res.body.data;
};

const payCash = (order, extra = {}) =>
  post('/api/v1/payments', cashier.token, {
    orderId: order.id,
    method: 'cash',
    amount: order.total,
    received: order.total,
    ...extra,
  });

const customerOf = async (id) => (await get(`/api/v1/customers/${id}`, cashier.token)).body.data;

before(async () => {
  manager = await login('manager', 'manager123');
  cashier = await login('cashier', 'cashier123');
  const menu = await get('/api/v1/menu-items?limit=200', manager.token);
  water = menu.body.data.find((item) => item.name === 'น้ำเปล่า');
  assert.ok(water);
  const shift = await get('/api/v1/shifts/current', cashier.token);
  if (!shift.body.data) await post('/api/v1/shifts', cashier.token, { openingCash: 1000 });
});

test('ตั้งอัตราสะสมแต้มต่ำกว่า 0.01 บาท → 400 บอกขั้นต่ำเป็นภาษาของผู้ใช้ และไม่บันทึกอะไรเลย', async () => {
  const before = (await get('/api/v1/settings', manager.token)).body.data;

  for (const rate of [0.004, 0.009, 0, -25]) {
    const res = await patch('/api/v1/settings', manager.token, {
      storeName: 'ไม่ควรถูกบันทึก',
      pointsEarnRateBaht: rate,
    });
    assert.equal(res.status, 400, `${rate}: ${JSON.stringify(res.body)}`);
    assert.equal(res.body.error.message, 'ยอดซื้อต่อ 1 แต้มต้องอย่างน้อย 0.01 บาท');
  }
  const english = await patch('/api/v1/settings', manager.token, {
    pointsEarnRateBaht: 0.004,
  }).set('Accept-Language', 'en');
  assert.equal(english.status, 400);
  assert.equal(english.body.error.message, 'Baht spent per point must be at least 0.01');
  const korean = await patch('/api/v1/settings', manager.token, {
    pointsEarnRateBaht: 0.004,
  }).set('Accept-Language', 'ko');
  assert.match(korean.body.error.message, /최소 0\.01바트/);

  const after = (await get('/api/v1/settings', manager.token)).body.data;
  assert.equal(after.storeName, before.storeName);
  assert.equal(after.pointsEarnRateBaht, before.pointsEarnRateBaht);
});

test('มูลค่าแต้มต่ำกว่า 0.01 บาท → 400 ส่วน 0.01 พอดีตั้งได้ทั้งสองค่า', async () => {
  for (const value of [0, 0.004]) {
    const res = await patch('/api/v1/settings', manager.token, { pointsRedeemValueBaht: value });
    assert.equal(res.status, 400, `${value}: ${JSON.stringify(res.body)}`);
    assert.equal(res.body.error.message, 'มูลค่า 1 แต้มต้องอย่างน้อย 0.01 บาท');
  }

  const before = (await get('/api/v1/settings', manager.token)).body.data;
  try {
    const res = await patch('/api/v1/settings', manager.token, {
      pointsEarnRateBaht: 0.01,
      pointsRedeemValueBaht: 0.01,
    });
    assert.equal(res.status, 200, JSON.stringify(res.body));
    assert.equal(res.body.data.pointsEarnRateBaht, 0.01);
    assert.equal(res.body.data.pointsRedeemValueBaht, 0.01);
  } finally {
    await patch('/api/v1/settings', manager.token, {
      pointsEarnRateBaht: before.pointsEarnRateBaht,
      pointsRedeemValueBaht: before.pointsRedeemValueBaht,
    });
  }
});

test('อัตราสะสมในฐานข้อมูลเป็น 0 หรือต่ำกว่า 0.01 อยู่แล้ว → ขายได้ตามปกติ แต่ได้ 0 แต้ม ไม่ใช่ Infinity', async () => {
  for (const stored of ['0', '0.004']) {
    await withStoredSetting('points_earn_rate_baht', stored, async () => {
      const customer = await newCustomer();
      const order = await openOrder(customer.id);
      const res = await payCash(order);
      assert.equal(res.status, 201, JSON.stringify(res.body));
      assert.equal(res.body.data.isFullyPaid, true);
      assert.equal(res.body.data.order.pointsEarned, 0, stored);
      assert.equal((await customerOf(customer.id)).pointsBalance, 0, stored);
    });
  }
  const broken = getDb()
    .prepare(
      "SELECT (SELECT COUNT(*) FROM customers WHERE typeof(points_balance) != 'integer') + (SELECT COUNT(*) FROM orders WHERE typeof(points_earned) != 'integer') AS c",
    )
    .get().c;
  assert.equal(broken, 0);
});

test('ขายเชื่อแล้วรับชำระหนี้ครบตอนอัตราในฐานข้อมูลเป็น 0 → รับชำระได้ ลูกค้าได้ 0 แต้ม', async () => {
  const customer = await newCustomer();
  const credit = await patch(`/api/v1/customers/${customer.id}/credit`, manager.token, {
    creditLimit: 50000,
    creditTermDays: 30,
  });
  assert.equal(credit.status, 200, JSON.stringify(credit.body));
  const order = await openOrder(customer.id);
  const sale = await post('/api/v1/payments', cashier.token, {
    orderId: order.id,
    method: 'credit',
    amount: order.total,
  });
  assert.equal(sale.status, 201, JSON.stringify(sale.body));

  await withStoredSetting('points_earn_rate_baht', '0', async () => {
    const receipt = await post('/api/v1/receivables/receipts', cashier.token, {
      customerId: customer.id,
      amount: order.total,
      method: 'transfer',
    });
    assert.equal(receipt.status, 201, JSON.stringify(receipt.body));
    assert.equal((await customerOf(customer.id)).pointsBalance, 0);
    const now = (await get(`/api/v1/orders/${order.id}`, cashier.token)).body.data;
    assert.equal(now.pointsEarned, 0);
  });
});

test('มูลค่าแต้มในฐานข้อมูลเป็น 0 อยู่แล้ว → แลกแต้มไม่ได้ (400) แต้มของลูกค้าไม่ถูกหัก', async () => {
  const customer = await newCustomer();
  const first = await openOrder(customer.id);
  assert.equal((await payCash(first)).status, 201);
  const points = (await customerOf(customer.id)).pointsBalance;
  assert.ok(points > 0, 'ต้องมีแต้มให้ลองแลก');

  await withStoredSetting('points_redeem_value_baht', '0', async () => {
    const order = await openOrder(customer.id);
    const res = await payCash(order, { pointsToRedeem: points });
    assert.equal(res.status, 400, JSON.stringify(res.body));
    assert.equal(res.body.error.message, 'ร้านยังไม่ได้ตั้งมูลค่าแต้ม จึงใช้แต้มแลกส่วนลดไม่ได้');
  });
  assert.equal((await customerOf(customer.id)).pointsBalance, points);
});

test('ยอดแต้มที่ไม่ใช่จำนวนเต็มถูกปฏิเสธก่อนถึงฐานข้อมูล', async () => {
  const { customerRepository } = await import('../src/modules/customers/customer.repository.js');
  const { orderRepository } = await import('../src/modules/orders/order.repository.js');
  const customer = await newCustomer();
  for (const delta of [Infinity, -Infinity, NaN, 1.5]) {
    assert.throws(() => customerRepository.adjustPoints(customer.id, delta), /integer/);
  }
  assert.throws(() => orderRepository.setPointsEarned(1, Infinity), /integer/);
  assert.equal((await customerOf(customer.id)).pointsBalance, 0);
});
