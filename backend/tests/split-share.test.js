// Copyright 2026 Suruch Chakrapeesirisuk
// SPDX-License-Identifier: Apache-2.0

import test, { after, before, describe } from 'node:test';
import assert from 'node:assert/strict';
import { calculateBill, calculateItemsShare } from '../src/modules/orders/order.calculator.js';
import { api, login, authHeader, cleanup } from './helpers/testApp.js';

// แยกจ่ายตามรายการ: ส่วนลดมือ ส่วนลดโปรโมชัน Service Charge และ VAT ปันตามสัดส่วนราคา ตามโหมด VAT ของร้าน และผลรวมของ
// ทุกคนเท่ายอดบิลพอดี (T10 #83, docs/DECISIONS.md #88)

after(cleanup);

const line = (id, lineTotal, extra = {}) => ({
  id,
  line_total: lineTotal,
  status: 'pending',
  ...extra,
});

/** จ่ายทีละกลุ่มตามลำดับเหมือนหน้าจอแยกบิล คืนยอดที่แต่ละกลุ่มจ่าย (สตางค์) */
const payInGroups = (items, groups, settings) => {
  const full = calculateBill({ items, ...settings });
  let paid = 0;
  const rows = items.map((item) => ({ ...item }));
  return groups.map((group) => {
    const share = calculateItemsShare({ items: rows, selectedIds: group, ...settings });
    const remaining = full.total - paid;
    const amount = share.isLastBatch ? remaining : Math.min(share.total, remaining);
    paid += amount;
    for (const row of rows) if (group.includes(row.id)) row.is_paid = 1;
    return { share, amount, full };
  });
};

describe('calculateItemsShare', () => {
  test('บิล 160 + 320 มีโปรลด 50% (282.48): รายการ 160 จ่าย 94.16 และ 320 จ่าย 188.32 ไม่ว่าใครจ่ายก่อน', () => {
    const items = [line(1, 16000), line(2, 32000)];
    const settings = { promotionDiscountAmount: 24000, vatRate: 0.07, serviceChargeRate: 0.1 };
    assert.equal(calculateBill({ items, ...settings }).total, 28248);

    for (const order of [
      [[1], [2]],
      [[2], [1]],
    ]) {
      const paid = Object.fromEntries(
        payInGroups(items, order, settings).map(({ amount }, index) => [order[index][0], amount]),
      );
      assert.deepEqual(paid, { 1: 9416, 2: 18832 });
    }

    const first = calculateItemsShare({ items, selectedIds: [1], ...settings });
    assert.deepEqual(
      {
        subtotal: first.subtotal,
        discountAmount: first.discountAmount,
        serviceCharge: first.serviceCharge,
        vat: first.vat,
        total: first.total,
      },
      { subtotal: 16000, discountAmount: 8000, serviceCharge: 800, vat: 616, total: 9416 },
    );
  });

  test('โหมด VAT รวมในราคา บิล 160 + 80 (264): จ่าย 176.00 และ 88.00 โดยไม่บวก VAT ซ้ำ', () => {
    const items = [line(1, 16000), line(2, 8000)];
    const settings = { vatRate: 0.07, serviceChargeRate: 0.1, vatIncluded: true };
    assert.equal(calculateBill({ items, ...settings }).total, 26400);

    const [first, second] = payInGroups(items, [[1], [2]], settings);
    assert.equal(first.amount, 17600);
    assert.equal(second.amount, 8800);
    assert.equal(first.share.vatIncluded, true);
    assert.ok(first.share.vat > 0, 'แสดง VAT ที่อยู่ในยอด');
    assert.equal(
      first.share.total,
      first.share.subtotal - first.share.discountAmount + first.share.serviceCharge,
    );
  });

  test('property: ทุกชุดค่าผสมของโปร/ส่วนลด/โหมด VAT/การแบ่งกลุ่ม ผลรวมทุกคน = ยอดบิล และแต่ละคนจ่ายตามสัดส่วน', () => {
    // สุ่มแบบกำหนด seed ได้ ให้ล้มแล้วทำซ้ำได้เหมือนเดิม
    let seed = 20260928;
    const random = () => {
      seed = (seed * 1103515245 + 12345) % 2147483648;
      return seed / 2147483648;
    };
    const pick = (values) => values[Math.floor(random() * values.length)];

    for (let run = 0; run < 2000; run += 1) {
      const count = 1 + Math.floor(random() * 6);
      const items = Array.from({ length: count }, (_, index) =>
        line(index + 1, 100 + Math.floor(random() * 99900)),
      );
      const subtotal = items.reduce((acc, item) => acc + item.line_total, 0);
      const discountType = pick(['none', 'amount', 'percent']);
      const settings = {
        discountType,
        discountValue:
          discountType === 'amount'
            ? Math.floor(random() * subtotal * 0.6)
            : discountType === 'percent'
              ? Math.floor(random() * 5000)
              : 0,
        promotionDiscountAmount: pick([0, 0, Math.floor(random() * subtotal * 0.5)]),
        vatRate: pick([0, 0.07]),
        serviceChargeRate: pick([0, 0.1]),
        vatIncluded: pick([false, true]),
      };

      // แบ่งรายการเป็นกลุ่มแบบสุ่ม แล้วสลับลำดับการจ่าย
      const groups = [];
      for (const item of items) {
        const target = Math.floor(random() * (groups.length + 1));
        if (target === groups.length) groups.push([]);
        groups[target].push(item.id);
      }
      groups.sort(() => random() - 0.5);

      const results = payInGroups(items, groups, settings);
      const { full } = results[0];
      const context = JSON.stringify({ items, settings, groups });
      assert.equal(
        results.reduce((acc, { amount }) => acc + amount, 0),
        full.total,
        `ผลรวมต้องเท่ายอดบิล ${context}`,
      );
      for (const [index, { share, amount }] of results.entries()) {
        assert.equal(
          share.total,
          share.subtotal -
            share.discountAmount +
            share.serviceCharge +
            (settings.vatIncluded ? 0 : share.vat),
          `ตัวเลขในส่วนแบ่งต้องรวมกันได้ยอดของคนนั้น ${context}`,
        );
        assert.equal(
          amount,
          share.total,
          `แบ่งตามรายการล้วน ยอดที่เก็บ = ส่วนแบ่งทุกรอบ ${context}`,
        );
        const fair = (full.total * share.subtotal) / full.subtotal;
        assert.ok(
          Math.abs(amount - fair) <= 3,
          `รอบที่ ${index + 1} จ่าย ${amount} ห่างจากสัดส่วน ${fair.toFixed(2)} เกิน 3 สตางค์ ${context}`,
        );
      }
    }
  });
});

describe('API: split-preview และการรับชำระตามรายการ', () => {
  let waiter;
  let cashier;
  let manager;
  let admin;
  const menuByPrice = {};

  before(async () => {
    waiter = await login('waiter1', 'waiter123');
    cashier = await login('cashier', 'cashier123');
    manager = await login('manager', 'manager123');
    admin = await login('admin', 'admin123');
    const menu = await api()
      .get('/api/v1/menu-items?availableOnly=true&limit=200')
      .set(authHeader(waiter.token));
    for (const item of menu.body.data) {
      const simple = !item.soldByWeight && !item.optionGroups.some((group) => group.isRequired);
      if (simple && !menuByPrice[item.price]) menuByPrice[item.price] = item;
    }
    assert.ok(menuByPrice[80] && menuByPrice[160] && menuByPrice[320], 'ต้องมีเมนูราคา 80/160/320');
  });

  const openOrder = async (prices) => {
    const table = (await api().get('/api/v1/tables?status=available').set(authHeader(waiter.token)))
      .body.data[0];
    const res = await api()
      .post('/api/v1/orders')
      .set(authHeader(waiter.token))
      .send({
        type: 'dine_in',
        tableId: table.id,
        guestCount: prices.length,
        items: prices.map((price) => ({
          menuItemId: menuByPrice[price].id,
          quantity: 1,
          optionIds: [],
        })),
      });
    assert.equal(res.status, 201, JSON.stringify(res.body));
    return res.body.data;
  };

  const preview = async (order, itemIds) => {
    const res = await api()
      .post(`/api/v1/payments/order/${order.id}/split-preview`)
      .set(authHeader(cashier.token))
      .send({ itemIds });
    assert.equal(res.status, 200, JSON.stringify(res.body));
    return res.body.data;
  };

  const payItems = async (order, itemIds) => {
    const res = await api()
      .post('/api/v1/payments')
      .set(authHeader(cashier.token))
      .send({ orderId: order.id, method: 'card', itemIds });
    assert.equal(res.status, 201, JSON.stringify(res.body));
    return res.body.data;
  };

  const sumOf = (p) =>
    Math.round(
      (p.subtotal -
        p.discountAmount +
        p.serviceCharge +
        (p.vatIncluded ? 0 : p.vat) +
        p.adjustment) *
        100,
    ) / 100;

  test('โปรลด 50% บน 160 + 320 → preview ปันส่วนลดแล้ว ตัวเลขรวมเท่ายอดที่เก็บ และจ่าย 94.16 + 188.32', async () => {
    const promo = await api()
      .post('/api/v1/promotions')
      .set(authHeader(manager.token))
      .send({ name: 'ลดครึ่งราคา (T10)', type: 'percent', value: 50, code: 'T10HALF' });
    assert.equal(promo.status, 201, JSON.stringify(promo.body));
    const order = await openOrder([160, 320]);
    const redeemed = await api()
      .post(`/api/v1/orders/${order.id}/promotion/redeem`)
      .set(authHeader(waiter.token))
      .send({ code: 'T10HALF' });
    assert.equal(redeemed.status, 200, JSON.stringify(redeemed.body));
    assert.equal(redeemed.body.data.total, 282.48);
    const [cheap, dear] = order.items;

    const first = await preview(order, [cheap.id]);
    assert.equal(first.discountAmount, 80);
    assert.equal(first.serviceCharge, 8);
    assert.equal(first.vat, 6.16);
    assert.equal(first.adjustment, 0);
    assert.equal(first.total, 94.16);
    assert.equal(sumOf(first), first.total);
    assert.equal((await payItems(order, [cheap.id])).payment.amount, 94.16);

    const second = await preview(order, [dear.id]);
    assert.equal(second.isLastBatch, true);
    assert.equal(second.total, 188.32);
    assert.equal(sumOf(second), second.total);
    const last = await payItems(order, [dear.id]);
    assert.equal(last.payment.amount, 188.32);
    assert.equal(last.isFullyPaid, true);
  });

  test('โหมด VAT รวมในราคา 160 + 80 → จ่าย 176.00 และ 88.00 และ preview บอกว่า VAT อยู่ในยอดแล้ว', async () => {
    const setVatIncluded = (value) =>
      api().patch('/api/v1/settings').set(authHeader(admin.token)).send({ vatIncluded: value });
    assert.equal((await setVatIncluded(true)).status, 200);
    try {
      const order = await openOrder([160, 80]);
      assert.equal(order.total, 264);
      const [big, small] = order.items;

      const first = await preview(order, [big.id]);
      assert.equal(first.vatIncluded, true);
      assert.equal(first.total, 176);
      assert.equal(sumOf(first), first.total);
      assert.equal((await payItems(order, [big.id])).payment.amount, 176);
      const last = await payItems(order, [small.id]);
      assert.equal(last.payment.amount, 88);
      assert.equal(last.isFullyPaid, true);
    } finally {
      assert.equal((await setVatIncluded(false)).status, 200);
    }
  });

  test('รับเงินแบบระบุยอดไปก่อนแล้วเลือกรายการที่เหลือ → preview แสดงส่วนต่างเป็น adjustment และรวมเท่ายอดคงเหลือ', async () => {
    const order = await openOrder([160, 320]);
    const paid = await api()
      .post('/api/v1/payments')
      .set(authHeader(cashier.token))
      .send({ orderId: order.id, method: 'cash', amount: 100, received: 100 });
    assert.equal(paid.status, 201, JSON.stringify(paid.body));

    const all = await preview(
      order,
      order.items.map((item) => item.id),
    );
    assert.equal(all.isLastBatch, true);
    assert.equal(all.total, Math.round((order.total - 100) * 100) / 100);
    assert.equal(all.adjustment, -100);
    assert.equal(sumOf(all), all.total);
  });
});
