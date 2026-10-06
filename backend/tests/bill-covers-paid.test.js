// Copyright 2026 Suruch Chakrapeesirisuk
// SPDX-License-Identifier: Apache-2.0

import test, { after, before } from 'node:test';
import assert from 'node:assert/strict';
import { api, login, authHeader, cleanup } from './helpers/testApp.js';
import { getDb } from '../src/db/index.js';

// ยอดบิลที่ยังเปิดต้องไม่ต่ำกว่าเงินที่ร้านถือไว้สุทธิ (T07 #105, docs/DECISIONS.md #95) — การแก้บิลที่ทำให้ยอดต่ำกว่าถูกปฏิเสธพร้อม
// บอกยอดที่ต้องคืนก่อน ยอดใหม่ที่เท่ากับเงินที่รับไว้พอดีปิดบิลทันที และบิลที่ถือเงินเกินยอดอยู่แล้ว (ข้อมูลเก่า) รับเงินเพิ่มไม่ได้แต่ไม่ 500

after(cleanup);

const get = (url, token) => api().get(url).set(authHeader(token));
const post = (url, token, body) =>
  api()
    .post(url)
    .set(authHeader(token))
    .send(body ?? {});
const patch = (url, token, body) => api().patch(url).set(authHeader(token)).send(body);
const del = (url, token) => api().delete(url).set(authHeader(token));

let waiter;
let cashier;
let manager;
let simpleMenu;
let menuAt85;
let menuAt160;
let menuAt20;

before(async () => {
  waiter = await login('waiter1', 'waiter123');
  cashier = await login('cashier', 'cashier123');
  manager = await login('manager', 'manager123');
  const menu = await get('/api/v1/menu-items?availableOnly=true&limit=200', waiter.token);
  simpleMenu = menu.body.data.filter(
    (item) => !item.soldByWeight && !item.optionGroups.some((group) => group.isRequired),
  );
  menuAt85 = simpleMenu.find((item) => item.price === 85);
  menuAt160 = simpleMenu.find((item) => item.price === 160);
  menuAt20 = simpleMenu.find((item) => item.price === 20);
  assert.ok(menuAt85 && menuAt160 && menuAt20, 'seed ต้องมีเมนูราคา 85, 160 และ 20 บาท');
});

const openOrder = async (lines, { tableId } = {}) => {
  const table =
    tableId ?? (await get('/api/v1/tables?status=available', waiter.token)).body.data[0].id;
  const res = await post('/api/v1/orders', waiter.token, {
    type: 'dine_in',
    tableId: table,
    guestCount: 2,
    items: lines.map(([item, quantity = 1]) => ({ menuItemId: item.id, quantity, optionIds: [] })),
  });
  assert.equal(res.status, 201, JSON.stringify(res.body));
  return res.body.data;
};

const orderOf = async (order) => (await get(`/api/v1/orders/${order.id}`, cashier.token)).body.data;
const summaryOf = async (order) =>
  (await get(`/api/v1/payments/order/${order.id}`, cashier.token)).body.data;

const payCash = async (order, amount) => {
  const res = await post('/api/v1/payments', cashier.token, {
    orderId: order.id,
    method: 'cash',
    amount,
    received: amount,
  });
  assert.equal(res.status, 201, JSON.stringify(res.body));
  return res.body.data;
};

const refund = async (payment, amount) => {
  const res = await post(`/api/v1/payments/${payment.id}/refund`, manager.token, {
    amount,
    reason: 'ลดราคาให้ลูกค้า',
  });
  assert.equal(res.status, 201, JSON.stringify(res.body));
  return res.body.data;
};

test('บิล 200.09 จ่าย 150 แล้วใส่ส่วนลด 50% → 409 ต้องคืนเงิน 49.95 ก่อน บิลไม่เปลี่ยน คืนแล้วใส่ได้และบิลปิดเอง', async () => {
  const order = await openOrder([[menuAt85, 2]]);
  assert.equal(order.total, 200.09);
  const { payment } = await payCash(order, 150);

  const refused = await post(`/api/v1/orders/${order.id}/discount`, cashier.token, {
    type: 'percent',
    value: 50,
  });
  assert.equal(refused.status, 409, JSON.stringify(refused.body));
  assert.match(refused.body.error.message, /ต้องคืนเงิน 49\.95 บาทก่อน/);
  assert.deepEqual(refused.body.error.details, { refundRequired: 49.95, total: 100.05, paid: 150 });

  const english = await post(`/api/v1/orders/${order.id}/discount`, cashier.token, {
    type: 'percent',
    value: 50,
  }).set('Accept-Language', 'en');
  assert.match(english.body.error.message, /refund 49\.95 THB first/);

  // rollback ทั้งก้อน: ยอดและส่วนลดเหมือนก่อนกด
  const unchanged = await orderOf(order);
  assert.equal(unchanged.total, 200.09);
  assert.equal(unchanged.discountType, 'none');
  const summary = await summaryOf(order);
  assert.equal(summary.remaining, 50.09);
  assert.equal(summary.refundDue, 0);

  // คืนส่วนต่างก่อน → ใส่ส่วนลดได้ ยอดใหม่เท่ากับเงินที่ถือไว้พอดี บิลปิดและโต๊ะว่างทันที ไม่ค้างเปิดที่คงเหลือ 0
  await refund(payment, 49.95);
  const discounted = await post(`/api/v1/orders/${order.id}/discount`, cashier.token, {
    type: 'percent',
    value: 50,
  });
  assert.equal(discounted.status, 200, JSON.stringify(discounted.body));
  assert.equal(discounted.body.data.total, 100.05);
  assert.equal(discounted.body.data.status, 'paid');
  assert.ok(discounted.body.data.closedAt);
  const table = (await get(`/api/v1/tables/${order.tableId}`, waiter.token)).body.data;
  assert.equal(table.status, 'available');
  const closed = await summaryOf(order);
  assert.equal(closed.paid, 100.05);
  assert.equal(closed.remaining, 0);
  assert.equal(closed.refundDue, 0);
});

test('บิล 211.86 แยกจ่ายรายการ 160 แล้ว → ยกเลิก/ลบ/ลดจำนวนรายการที่จ่ายแล้วไม่ได้ ยกเลิกรายการที่เหลือแล้วบิลปิดเอง', async () => {
  const order = await openOrder([
    [menuAt160, 2],
    [menuAt20, 1],
  ]);
  const paidItem = order.items.find((item) => item.menuItemId === menuAt160.id);
  const otherItem = order.items.find((item) => item.menuItemId === menuAt20.id);
  // จ่ายรายการ 160 x2 แบบแยกตามรายการ
  const paid = await post('/api/v1/payments', cashier.token, {
    orderId: order.id,
    method: 'card',
    itemIds: [paidItem.id],
  });
  assert.equal(paid.status, 201, JSON.stringify(paid.body));
  const held = paid.body.data.payment.amount;
  assert.equal(held, 376.64);

  // ยกเลิกรายการที่จ่ายแล้ว (T04)
  const voided = await patch(
    `/api/v1/orders/${order.id}/items/${paidItem.id}/status`,
    waiter.token,
    {
      status: 'cancelled',
    },
  );
  assert.equal(voided.status, 409, JSON.stringify(voided.body));

  // ลบรายการ pending ที่จ่ายแล้ว (DECISIONS #85 หมายเหตุข้อ 2)
  const removed = await del(`/api/v1/orders/${order.id}/items/${paidItem.id}`, waiter.token);
  assert.equal(removed.status, 409, JSON.stringify(removed.body));
  assert.match(removed.body.error.message, /ต้องคืนเงิน 353\.1 บาทก่อน/);

  // ลดจำนวนรายการ pending ที่จ่ายแล้วจาก 2 เหลือ 1
  const reduced = await patch(`/api/v1/orders/${order.id}/items/${paidItem.id}`, waiter.token, {
    quantity: 1,
  });
  assert.equal(reduced.status, 409, JSON.stringify(reduced.body));
  assert.match(reduced.body.error.message, /ต้องคืนเงิน 164\.78 บาทก่อน/);

  const still = await orderOf(order);
  assert.equal(still.items.find((item) => item.id === paidItem.id).quantity, 2);
  assert.equal(still.total, 400.18);

  // ยกเลิกรายการที่ยังไม่จ่าย → ยอดใหม่เท่ากับเงินที่จ่ายแยกไว้พอดี บิลปิด
  const cancelOther = await patch(
    `/api/v1/orders/${order.id}/items/${otherItem.id}/status`,
    waiter.token,
    {
      status: 'cancelled',
    },
  );
  assert.equal(cancelOther.status, 200, JSON.stringify(cancelOther.body));
  const closed = await orderOf(order);
  assert.equal(closed.total, held);
  assert.equal(closed.status, 'paid');
});

test('บิลที่ถือเงินเกินยอดอยู่แล้ว (ข้อมูลก่อน T07) → แยกจ่ายชุดสุดท้าย/ระบุยอด/ดูยอดก่อนแยก ได้ 409 ไม่ใช่ 500 และสรุปยอดบอกยอดที่ต้องคืน', async () => {
  const order = await openOrder([
    [menuAt160, 1],
    [menuAt20, 1],
  ]);
  assert.equal(order.total, 211.86);
  const paidItem = order.items.find((item) => item.menuItemId === menuAt160.id);
  const otherItem = order.items.find((item) => item.menuItemId === menuAt20.id);
  const paid = await post('/api/v1/payments', cashier.token, {
    orderId: order.id,
    method: 'card',
    itemIds: [paidItem.id],
  });
  assert.equal(paid.status, 201, JSON.stringify(paid.body));

  // จำลองสภาพที่ #48 ทิ้งไว้ก่อนแก้: รายการที่จ่ายแล้วถูกยกเลิกไป ยอดบิลเหลือ 23.54 แต่ร้านถือเงิน 188.32
  getDb().prepare(`UPDATE order_items SET status = 'cancelled' WHERE id = ?`).run(paidItem.id);
  getDb().prepare(`UPDATE orders SET total = 2354 WHERE id = ?`).run(order.id);

  const summary = await summaryOf(order);
  assert.equal(summary.remaining, 0);
  assert.equal(summary.refundDue, 164.78);

  const lastSplit = await post('/api/v1/payments', cashier.token, {
    orderId: order.id,
    method: 'card',
    itemIds: [otherItem.id],
  });
  assert.equal(lastSplit.status, 409, JSON.stringify(lastSplit.body));
  assert.match(lastSplit.body.error.message, /เกินยอดบิล 164\.78 บาท ต้องคืนเงินส่วนเกินก่อน/);

  const byAmount = await post('/api/v1/payments', cashier.token, {
    orderId: order.id,
    method: 'cash',
    amount: 0.01,
    received: 1,
  });
  assert.equal(byAmount.status, 409, JSON.stringify(byAmount.body));

  const preview = await post(`/api/v1/payments/order/${order.id}/split-preview`, cashier.token, {
    itemIds: [otherItem.id],
  });
  assert.equal(preview.status, 409, JSON.stringify(preview.body));
});

// ---------------------------------------------------------------- property test

/** PRNG แบบมี seed (mulberry32) — รันซ้ำได้ผลเดิม ถ้าล้มให้ดู seed ในข้อความ */
const prng = (seed) => {
  let a = seed >>> 0;
  return () => {
    a = (a + 0x6d2b79f5) >>> 0;
    let t = a;
    t = Math.imul(t ^ (t >>> 15), t | 1);
    t ^= t + Math.imul(t ^ (t >>> 7), t | 61);
    return ((t ^ (t >>> 14)) >>> 0) / 4294967296;
  };
};

const toSatang = (baht) => Math.round(baht * 100);

test('property: แก้บิล/จ่าย/คืนเงินแบบสุ่มกี่ครั้งก็ได้ ยอดบิลที่ยังเปิด ≥ ยอดจ่ายสุทธิเสมอ และไม่มี 500', async () => {
  const SEED = 20261005;
  const ORDERS = 25;
  const STEPS = 14;
  const random = prng(SEED);
  const pick = (list) => list[Math.floor(random() * list.length)];
  const cheap = simpleMenu.filter((item) => item.price <= 200);
  // นับว่าการสุ่มไปชนกติกาจริง ไม่ใช่ผ่านเพราะไม่เคยลองทางที่ยอดจะต่ำกว่าเงินที่รับไว้
  let refusedForRefund = 0;

  for (let n = 0; n < ORDERS; n += 1) {
    const created = await post('/api/v1/orders', waiter.token, {
      type: 'takeaway',
      items: [1, 2, 3].map(() => ({
        menuItemId: pick(cheap).id,
        quantity: 1 + Math.floor(random() * 2),
      })),
    });
    assert.equal(created.status, 201, JSON.stringify(created.body));
    const orderId = created.body.data.id;
    const trail = [];

    for (let step = 0; step < STEPS; step += 1) {
      const order = (await get(`/api/v1/orders/${orderId}`, cashier.token)).body.data;
      if (order.status !== 'open') break;
      const summary = (await get(`/api/v1/payments/order/${orderId}`, cashier.token)).body.data;
      const live = order.items.filter((item) => item.status !== 'cancelled');
      const unpaid = live.filter((item) => !item.isPaid);
      const action = pick([
        'add',
        'qty',
        'remove',
        'void',
        'discountPercent',
        'discountAmount',
        'discountNone',
        'payAmount',
        'paySplit',
        'refund',
      ]);
      let res;
      switch (action) {
        case 'add':
          res = await post(`/api/v1/orders/${orderId}/items`, waiter.token, {
            items: [{ menuItemId: pick(cheap).id, quantity: 1 }],
          });
          break;
        case 'qty':
          if (!live.length) continue;
          res = await patch(`/api/v1/orders/${orderId}/items/${pick(live).id}`, waiter.token, {
            quantity: 1 + Math.floor(random() * 3),
          });
          break;
        case 'remove':
          if (!live.length) continue;
          res = await del(`/api/v1/orders/${orderId}/items/${pick(live).id}`, waiter.token);
          break;
        case 'void':
          if (!live.length) continue;
          res = await patch(
            `/api/v1/orders/${orderId}/items/${pick(live).id}/status`,
            manager.token,
            {
              status: 'cancelled',
            },
          );
          break;
        case 'discountPercent':
          res = await post(`/api/v1/orders/${orderId}/discount`, cashier.token, {
            type: 'percent',
            value: Math.floor(random() * 100),
          });
          break;
        case 'discountAmount':
          res = await post(`/api/v1/orders/${orderId}/discount`, cashier.token, {
            type: 'amount',
            value: Math.floor(random() * 300),
          });
          break;
        case 'discountNone':
          res = await post(`/api/v1/orders/${orderId}/discount`, cashier.token, {
            type: 'none',
            value: 0,
          });
          break;
        case 'payAmount': {
          if (summary.remaining <= 0) continue;
          const amount = Math.max(0.01, Math.round(summary.remaining * random() * 100) / 100);
          res = await post('/api/v1/payments', cashier.token, {
            orderId,
            method: 'cash',
            amount,
            received: amount,
          });
          break;
        }
        case 'paySplit':
          if (!unpaid.length) continue;
          res = await post('/api/v1/payments', cashier.token, {
            orderId,
            method: 'card',
            itemIds: [pick(unpaid).id],
          });
          break;
        case 'refund': {
          const refundable = summary.payments
            .map((payment) => ({
              payment,
              left:
                toSatang(payment.amount) -
                toSatang(
                  summary.refunds
                    .filter((refundRow) => refundRow.paymentId === payment.id)
                    .reduce((acc, refundRow) => acc + refundRow.amount, 0),
                ),
            }))
            .filter((row) => row.left > 0);
          if (!refundable.length) continue;
          const { payment, left } = pick(refundable);
          const amount = Math.max(1, Math.round(left * random())) / 100;
          res = await post(`/api/v1/payments/${payment.id}/refund`, manager.token, {
            amount,
            reason: 'property test',
          });
          break;
        }
        default:
          continue;
      }
      trail.push(`${action}→${res.status}`);
      const where = `seed ${SEED} order ${n} steps ${trail.join(' ')}`;
      assert.ok(res.status < 500, `${where}: ${JSON.stringify(res.body)}`);
      if (res.status === 409 && /ต้องคืนเงิน/.test(res.body.error.message)) refusedForRefund += 1;

      const after = (await get(`/api/v1/orders/${orderId}`, cashier.token)).body.data;
      const afterSummary = (await get(`/api/v1/payments/order/${orderId}`, cashier.token)).body
        .data;
      if (after.status === 'open') {
        assert.ok(
          toSatang(after.total) >= toSatang(afterSummary.paid),
          `${where}: total ${after.total} < paid ${afterSummary.paid}`,
        );
        // บิลเปิดที่ถือเงินอยู่ต้องยังมียอดให้เก็บ ไม่ค้างที่คงเหลือ 0
        if (afterSummary.paid > 0) {
          assert.ok(afterSummary.remaining > 0, `${where}: open with remaining 0`);
        }
        assert.equal(afterSummary.refundDue, 0, where);
      }
    }
  }
  assert.ok(refusedForRefund > 0, `seed ${SEED}: ไม่เคยชนกติกายอดบิลต่ำกว่าเงินที่รับไว้เลย`);
});
