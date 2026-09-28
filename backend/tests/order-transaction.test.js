// Copyright 2026 Suruch Chakrapeesirisuk
// SPDX-License-Identifier: Apache-2.0

import test, { after, before, describe } from 'node:test';
import assert from 'node:assert/strict';
import { api, login, authHeader, cleanup } from './helpers/testApp.js';

// การแก้ออเดอร์ทุกแบบอยู่ใน transaction เดียวกับการคำนวณยอดใหม่และ audit (T02 #81, docs/DECISIONS.md #84)
// จำลองให้การคำนวณยอดล้มกลางคัน: รายการ ยอดรวม สต๊อก สถานะโต๊ะ และ audit log ต้องอยู่ที่ค่าเดิมทั้งหมด ไม่ใช่เปลี่ยนไปครึ่งเดียว

const { settingsService } = await import('../src/modules/settings/settings.service.js');
const { getDb } = await import('../src/db/index.js');

after(cleanup);

const get = (url, token) => api().get(url).set(authHeader(token));
const send = (method, url, token, body) =>
  api()
    [method](url)
    .set(authHeader(token))
    .send(body ?? {});

/** ทุกอย่างที่การแก้ออเดอร์อาจแตะ — ใช้เทียบก่อน/หลังคำขอที่ล้ม */
const snapshot = (orderIds) => {
  const db = getDb();
  const placeholders = orderIds.map(() => '?').join(',');
  return {
    orders: db
      .prepare(
        `SELECT id, status, table_id, subtotal, discount_type, discount_value, discount_amount, promotion_id,
                promotion_code_snapshot, promotion_discount_amount, service_charge, vat, total, cancelled_reason
           FROM orders WHERE id IN (${placeholders}) ORDER BY id`,
      )
      .all(...orderIds),
    items: db
      .prepare(
        `SELECT id, order_id, quantity, status, line_total, stock_deducted
           FROM order_items WHERE order_id IN (${placeholders}) ORDER BY id`,
      )
      .all(...orderIds),
    orderCount: db.prepare('SELECT COUNT(*) AS c FROM orders').get().c,
    audit: db.prepare('SELECT COUNT(*) AS c FROM audit_logs').get().c,
    stock: db.prepare('SELECT id, current_stock FROM ingredients ORDER BY id').all(),
    tables: db.prepare('SELECT id, status FROM dining_tables ORDER BY id').all(),
  };
};

/** เรียก `call` ขณะที่การคำนวณยอดใหม่ล้ม (อ่านค่าตั้งค่าร้านไม่ได้) แล้วคืนการตั้งค่าเดิม */
const whileRecalculationFails = async (call) => {
  const original = settingsService.get;
  settingsService.get = () => {
    throw new Error('simulated recalculation failure');
  };
  try {
    return await call();
  } finally {
    settingsService.get = original;
  }
};

let waiter;
let manager;
let menuItems;
let stockedMenuItem;

before(async () => {
  waiter = await login('waiter1', 'waiter123');
  manager = await login('manager', 'manager123');
  const menu = await get('/api/v1/menu-items?availableOnly=true&limit=200', waiter.token);
  // เลี่ยงเมนูที่มีตัวเลือกบังคับ และเมนูขายตามน้ำหนัก เพื่อสั่งด้วยจำนวนอย่างเดียว
  menuItems = menu.body.data.filter(
    (item) => !item.soldByWeight && !item.optionGroups.some((group) => group.isRequired),
  );
  const linked = new Set(
    getDb()
      .prepare('SELECT DISTINCT menu_item_id AS id FROM menu_item_ingredients')
      .all()
      .map((row) => row.id),
  );
  stockedMenuItem = menuItems.find((item) => linked.has(item.id));
  assert.ok(menuItems.length >= 3 && stockedMenuItem, 'ต้องมีเมนูธรรมดาพอ และมีเมนูที่ผูกวัตถุดิบ');
});

const freeTable = async () => {
  const res = await get('/api/v1/tables?status=available', waiter.token);
  assert.ok(res.body.data.length > 0, 'ต้องมีโต๊ะว่าง');
  return res.body.data[0];
};

const openOrder = async (items = [menuItems[0], menuItems[1]]) => {
  const table = await freeTable();
  const res = await send('post', '/api/v1/orders', waiter.token, {
    type: 'dine_in',
    tableId: table.id,
    guestCount: 2,
    items: items.map((item) => ({ menuItemId: item.id, quantity: 1, optionIds: [] })),
  });
  assert.equal(res.status, 201, JSON.stringify(res.body));
  return res.body.data;
};

/** ทำคำขอที่แก้ออเดอร์ขณะการคำนวณยอดล้ม: ต้องได้ 500 และไม่มีอะไรเปลี่ยน */
const assertRolledBack = async (orderIds, request) => {
  const before = snapshot(orderIds);
  const res = await whileRecalculationFails(request);
  assert.equal(res.status, 500, JSON.stringify(res.body));
  assert.deepEqual(snapshot(orderIds), before);
};

describe('ถ้าการคำนวณยอดใหม่ล้ม การแก้ออเดอร์ครั้งนั้นถูกยกเลิกทั้งหมด', () => {
  test('เปิดออเดอร์ใหม่: ไม่มีออเดอร์ค้าง และโต๊ะยังว่าง', async () => {
    const table = await freeTable();
    await assertRolledBack([], () =>
      send('post', '/api/v1/orders', waiter.token, {
        type: 'dine_in',
        tableId: table.id,
        items: [{ menuItemId: menuItems[0].id, quantity: 1, optionIds: [] }],
      }),
    );
    const again = await get('/api/v1/tables?status=available', waiter.token);
    assert.ok(again.body.data.some((row) => row.id === table.id));
  });

  test('เพิ่มรายการ แก้จำนวน ลบรายการ และยกเลิกรายการ', async () => {
    const order = await openOrder();
    const [first, second] = order.items;
    const base = `/api/v1/orders/${order.id}/items`;

    await assertRolledBack([order.id], () =>
      send('post', base, waiter.token, {
        items: [{ menuItemId: menuItems[2].id, quantity: 2, optionIds: [] }],
      }),
    );
    await assertRolledBack([order.id], () =>
      send('patch', `${base}/${first.id}`, waiter.token, { quantity: 3 }),
    );
    await assertRolledBack([order.id], () => send('delete', `${base}/${second.id}`, waiter.token));
    await assertRolledBack([order.id], () =>
      send('patch', `${base}/${first.id}/status`, waiter.token, { status: 'cancelled' }),
    );

    // เมื่อคำนวณยอดได้ การแก้เดิมสำเร็จและยอดรวมตามรายการทันที
    const ok = await send('patch', `${base}/${first.id}`, waiter.token, { quantity: 3 });
    assert.equal(ok.status, 200);
    assert.equal(ok.body.data.subtotal, first.lineTotal * 3 + second.lineTotal);
  });

  test('ส่วนลดมือ ใส่โค้ดส่วนลด และถอดโปรโมชัน', async () => {
    const promo = await send('post', '/api/v1/promotions', manager.token, {
      name: 'ลด 10 บาท (T02)',
      type: 'amount',
      value: 10,
      code: 'T02ROLLBACK',
    });
    assert.equal(promo.status, 201, JSON.stringify(promo.body));
    const order = await openOrder();
    const base = `/api/v1/orders/${order.id}`;

    await assertRolledBack([order.id], () =>
      send('post', `${base}/discount`, manager.token, { type: 'percent', value: 10 }),
    );
    await assertRolledBack([order.id], () =>
      send('post', `${base}/promotion/redeem`, waiter.token, { code: 'T02ROLLBACK' }),
    );

    const redeemed = await send('post', `${base}/promotion/redeem`, waiter.token, {
      code: 'T02ROLLBACK',
    });
    assert.equal(redeemed.status, 200);
    assert.equal(redeemed.body.data.promotionDiscountAmount, 10);
    await assertRolledBack([order.id], () => send('delete', `${base}/promotion`, waiter.token));
  });

  test('รวมบิล: รายการไม่ย้าย บิลต้นทางไม่ถูกยกเลิก และโต๊ะต้นทางยังไม่ว่าง', async () => {
    const target = await openOrder([menuItems[0]]);
    const source = await openOrder([menuItems[1]]);
    await assertRolledBack([target.id, source.id], () =>
      send('post', `/api/v1/orders/${target.id}/merge`, waiter.token, {
        sourceOrderId: source.id,
      }),
    );
  });

  test('ยกเลิกออเดอร์ที่ส่งครัวแล้ว: สต๊อกไม่ถูกคืน สถานะและโต๊ะเหมือนเดิม', async () => {
    const order = await openOrder([stockedMenuItem]);
    const stockBefore = snapshot([order.id]).stock;
    const sent = await send('post', `/api/v1/orders/${order.id}/send-to-kitchen`, waiter.token);
    assert.equal(sent.status, 200);
    assert.notDeepEqual(snapshot([order.id]).stock, stockBefore, 'ส่งครัวต้องตัดสต๊อก');

    await assertRolledBack([order.id], () =>
      send('post', `/api/v1/orders/${order.id}/cancel`, manager.token, { reason: 'ทดสอบ' }),
    );
  });
});

test('การแก้ที่ไม่กระทบบิลไม่คำนวณยอดใหม่ — ย้ายโต๊ะและส่งครัวทำได้แม้การคำนวณยอดใช้ไม่ได้', async () => {
  const order = await openOrder([menuItems[0]]);
  const target = (await get('/api/v1/tables?status=available', waiter.token)).body.data[0];

  const moved = await whileRecalculationFails(() =>
    send('patch', `/api/v1/orders/${order.id}/move-table`, waiter.token, { tableId: target.id }),
  );
  assert.equal(moved.status, 200, JSON.stringify(moved.body));
  assert.equal(moved.body.data.tableId, target.id);
  assert.equal(moved.body.data.total, order.total);

  const sent = await whileRecalculationFails(() =>
    send('post', `/api/v1/orders/${order.id}/send-to-kitchen`, waiter.token),
  );
  assert.equal(sent.status, 200, JSON.stringify(sent.body));
  assert.equal(sent.body.data.status, 'in_kitchen');
  assert.equal(sent.body.data.total, order.total);
});
