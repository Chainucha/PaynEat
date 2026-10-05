// Copyright 2026 Suruch Chakrapeesirisuk
// SPDX-License-Identifier: Apache-2.0

import test, { after } from 'node:test';
import assert from 'node:assert/strict';
import { api, login, authHeader, cleanup } from './helpers/testApp.js';

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

test('เส้นทางหลักของร้าน: รับออเดอร์ → ส่งครัว → ครัวทำ → เสิร์ฟ → ชำระเงิน → เข้ารายงาน', async (t) => {
  const waiter = await login('waiter1', 'waiter123');
  const kitchen = await login('kitchen', 'kitchen123');
  const cashier = await login('cashier', 'cashier123');

  let table;
  let menuItem;
  let orderId;

  await t.test('1) พนักงานเสิร์ฟเปิดผังโต๊ะและเลือกโต๊ะว่าง', async () => {
    const res = await get('/api/v1/tables', waiter.token);
    assert.equal(res.status, 200);
    table = res.body.data.find((row) => row.status === 'available');
    assert.ok(table, 'ต้องมีโต๊ะว่างอย่างน้อย 1 โต๊ะ');
    assert.equal(table.currentOrder, null);
  });

  await t.test('2) เปิดเมนูและเลือกอาหารพร้อมตัวเลือกเสริม', async () => {
    const res = await get('/api/v1/menu-items?availableOnly=true&limit=200', waiter.token);
    assert.equal(res.status, 200);
    assert.ok(res.body.meta.total > 0);

    menuItem = res.body.data.find((item) => item.name === 'ผัดกะเพราหมูสับ');
    assert.ok(menuItem, 'ข้อมูลตัวอย่างต้องมีเมนูผัดกะเพราหมูสับ');
    assert.equal(menuItem.price, 75);
    assert.ok(menuItem.optionGroups.length >= 2, 'เมนูนี้ต้องมีกลุ่มตัวเลือก');
  });

  await t.test('3) สร้างออเดอร์แล้วยอดต้องถูกคำนวณให้อัตโนมัติ', async () => {
    const spicy = menuItem.optionGroups.find((group) => group.name === 'ระดับความเผ็ด');
    const extra = menuItem.optionGroups.find((group) => group.name === 'เพิ่มพิเศษ');
    const friedEgg = extra.options.find((option) => option.name === 'ไข่ดาว');

    const res = await post('/api/v1/orders', waiter.token, {
      type: 'dine_in',
      tableId: table.id,
      guestCount: 2,
      items: [
        {
          menuItemId: menuItem.id,
          quantity: 2,
          optionIds: [spicy.options[2].id, friedEgg.id],
          note: 'ไม่ใส่ผัก',
        },
      ],
    });

    assert.equal(res.status, 201);
    const order = res.body.data;
    orderId = order.id;

    assert.match(order.code, /^ORD-\d{8}-\d{4}$/);
    assert.equal(order.status, 'open');
    assert.equal(order.items.length, 1);
    assert.equal(order.items[0].options.length, 2);
    // (75 + 15) x 2 = 180
    assert.equal(order.subtotal, 180);
    assert.equal(order.serviceCharge, 18);
    assert.equal(order.vat, 13.86);
    assert.equal(order.total, 211.86);
  });

  await t.test('4) โต๊ะเปลี่ยนเป็น "ไม่ว่าง" และผูกกับออเดอร์ที่เปิดอยู่', async () => {
    const res = await get('/api/v1/tables', waiter.token);
    const updated = res.body.data.find((row) => row.id === table.id);
    assert.equal(updated.status, 'occupied');
    assert.equal(updated.currentOrder.id, orderId);
    assert.equal(updated.currentOrder.total, 211.86);
  });

  await t.test('5) เปิดออเดอร์ซ้ำที่โต๊ะเดิมไม่ได้ (ต้องได้ 409)', async () => {
    const res = await post('/api/v1/orders', waiter.token, {
      type: 'dine_in',
      tableId: table.id,
      items: [],
    });
    assert.equal(res.status, 409);
  });

  await t.test('6) ก่อนส่งครัว รายการยังไม่ขึ้นคิวครัว', async () => {
    const res = await get('/api/v1/orders/kitchen/queue', kitchen.token);
    assert.equal(res.status, 200);
    assert.equal(res.body.data.filter((item) => item.orderId === orderId).length, 0);
  });

  await t.test('7) ส่งครัวแล้วรายการต้องเด้งเข้าคิวครัวพร้อมชื่อโต๊ะ', async () => {
    const res = await post(`/api/v1/orders/${orderId}/send-to-kitchen`, waiter.token);
    assert.equal(res.status, 200);
    assert.equal(res.body.data.status, 'in_kitchen');

    const queue = await get('/api/v1/orders/kitchen/queue', kitchen.token);
    const ticket = queue.body.data.find((item) => item.orderId === orderId);
    assert.ok(ticket);
    assert.equal(ticket.status, 'pending');
    assert.equal(ticket.tableName, table.name);
    assert.equal(ticket.note, 'ไม่ใส่ผัก');
    // สถานีครัวถูกประทับลงตั๋วตอนบันทึกรายการ (ticket 34) — ผัดกะเพราอยู่หมวดอาหารจานเดียว = ครัวร้อน
    assert.equal(ticket.stationCode, 'hot');
    assert.equal(ticket.stationName, 'ครัวร้อน');
    assert.ok(ticket.stationId > 0);
  });

  await t.test('8) ครัวกดรับงาน (pending → cooking → ready)', async () => {
    const order = await get(`/api/v1/orders/${orderId}`, kitchen.token);
    const itemId = order.body.data.items[0].id;

    const cooking = await patch(`/api/v1/orders/${orderId}/items/${itemId}/status`, kitchen.token, {
      status: 'cooking',
    });
    assert.equal(cooking.status, 200);
    assert.equal(cooking.body.data.items[0].status, 'cooking');

    // ข้ามขั้นจาก cooking ไป served ไม่ได้
    const invalid = await patch(`/api/v1/orders/${orderId}/items/${itemId}/status`, kitchen.token, {
      status: 'served',
    });
    assert.equal(invalid.status, 409);

    const ready = await patch(`/api/v1/orders/${orderId}/items/${itemId}/status`, kitchen.token, {
      status: 'ready',
    });
    assert.equal(ready.body.data.items[0].status, 'ready');
  });

  await t.test('9) แก้ไขรายการที่ครัวลงมือทำแล้วไม่ได้', async () => {
    const order = await get(`/api/v1/orders/${orderId}`, waiter.token);
    const itemId = order.body.data.items[0].id;

    const res = await patch(`/api/v1/orders/${orderId}/items/${itemId}`, waiter.token, {
      quantity: 5,
    });
    assert.equal(res.status, 409);
  });

  await t.test('10) เสิร์ฟครบทุกจาน ออเดอร์เปลี่ยนเป็น served อัตโนมัติ', async () => {
    const order = await get(`/api/v1/orders/${orderId}`, waiter.token);
    const itemId = order.body.data.items[0].id;

    const res = await patch(`/api/v1/orders/${orderId}/items/${itemId}/status`, waiter.token, {
      status: 'served',
    });
    assert.equal(res.status, 200);
    assert.equal(res.body.data.status, 'served');
  });

  await t.test('11) แคชเชียร์ให้ส่วนลด 10% แล้วยอดถูกคำนวณใหม่', async () => {
    const res = await post(`/api/v1/orders/${orderId}/discount`, cashier.token, {
      type: 'percent',
      value: 10,
    });
    assert.equal(res.status, 200);
    const order = res.body.data;
    assert.equal(order.discountAmount, 18); // 10% ของ 180
    assert.equal(order.serviceCharge, 16.2); // 10% ของ 162
    assert.equal(order.total, 190.67); // 162 + 16.20 + 12.47
  });

  await t.test('12) จ่ายไม่ครบยอด ออเดอร์ยังไม่ปิด (รองรับแยกจ่าย)', async () => {
    const res = await post('/api/v1/payments', cashier.token, {
      orderId,
      method: 'qr',
      amount: 100,
      reference: 'PROMPTPAY-0001',
    });
    assert.equal(res.status, 201);
    assert.equal(res.body.data.isFullyPaid, false);
    assert.equal(res.body.data.remaining, 90.67);
    assert.equal(res.body.data.order.status, 'served');
  });

  await t.test('13) จ่ายเงินสดส่วนที่เหลือ ปิดบิลและทอนเงินถูกต้อง', async () => {
    const res = await post('/api/v1/payments', cashier.token, {
      orderId,
      method: 'cash',
      amount: 90.67,
      received: 100,
    });
    assert.equal(res.status, 201);
    assert.equal(res.body.data.isFullyPaid, true);
    assert.equal(res.body.data.payment.change, 9.33);
    assert.equal(res.body.data.order.status, 'paid');
    assert.ok(res.body.data.order.closedAt);
  });

  await t.test('14) จ่ายซ้ำหลังปิดบิลไม่ได้', async () => {
    const res = await post('/api/v1/payments', cashier.token, {
      orderId,
      method: 'cash',
      amount: 10,
      received: 10,
    });
    assert.equal(res.status, 409);
  });

  await t.test('15) โต๊ะกลับมาว่างอัตโนมัติหลังปิดบิล', async () => {
    const res = await get('/api/v1/tables', waiter.token);
    const updated = res.body.data.find((row) => row.id === table.id);
    assert.equal(updated.status, 'available');
    assert.equal(updated.currentOrder, null);
  });

  await t.test('16) ใบเสร็จมีข้อมูลร้าน รายการอาหาร และการชำระเงินครบ', async () => {
    const res = await get(`/api/v1/payments/order/${orderId}/receipt`, cashier.token);
    assert.equal(res.status, 200);
    assert.ok(res.body.data.store.name);
    assert.equal(res.body.data.order.code.startsWith('ORD-'), true);
    assert.equal(res.body.data.payments.length, 2);
    assert.equal(res.body.data.changeTotal, 9.33);
  });

  await t.test('17) ยอดขายเข้ารายงานสรุปประจำวันแล้ว', async () => {
    const res = await get('/api/v1/reports/summary', cashier.token);
    assert.equal(res.status, 200);
    assert.ok(res.body.data.orderCount >= 1);
    assert.ok(res.body.data.netSales >= 190.67);
    assert.ok(res.body.data.paymentMethods.some((row) => row.method === 'qr'));

    const top = await get('/api/v1/reports/top-items', cashier.token);
    assert.equal(top.body.data[0].name, 'ผัดกะเพราหมูสับ');
    assert.equal(top.body.data[0].quantity, 2);
  });
});

test('กฎทางธุรกิจอื่น ๆ', async (t) => {
  const waiter = await login('waiter1', 'waiter123');
  const manager = await login('manager', 'manager123');

  await t.test('เพิ่มเมนูที่ปิดขายอยู่ลงออเดอร์ไม่ได้', async () => {
    const menu = await get('/api/v1/menu-items?limit=1', waiter.token);
    const item = menu.body.data[0];
    await patch(`/api/v1/menu-items/${item.id}/availability`, manager.token, {
      isAvailable: false,
    });

    const tables = await get('/api/v1/tables?status=available', waiter.token);
    const res = await post('/api/v1/orders', waiter.token, {
      tableId: tables.body.data[0].id,
      items: [{ menuItemId: item.id, quantity: 1 }],
    });
    assert.equal(res.status, 409);

    await patch(`/api/v1/menu-items/${item.id}/availability`, manager.token, { isAvailable: true });
  });

  await t.test('ส่งตัวเลือกที่ไม่ใช่ของเมนูนั้นต้องถูกปฏิเสธ', async () => {
    const menu = await get('/api/v1/menu-items?limit=200', waiter.token);
    const padThai = menu.body.data.find((row) => row.name === 'ผัดไทยกุ้งสด');
    const somtum = menu.body.data.find((row) => row.name === 'ส้มตำไทย');
    const foreignOptionId = somtum.optionGroups[0].options[0].id;

    const tables = await get('/api/v1/tables?status=available', waiter.token);
    const res = await post('/api/v1/orders', waiter.token, {
      tableId: tables.body.data[0].id,
      items: [{ menuItemId: padThai.id, quantity: 1, optionIds: [foreignOptionId] }],
    });
    assert.equal(res.status, 400);
  });

  await t.test('พนักงานเสิร์ฟยกเลิกออเดอร์ไม่ได้ แต่ผู้จัดการทำได้และโต๊ะต้องว่างคืน', async () => {
    const tables = await get('/api/v1/tables?status=available', waiter.token);
    const tableId = tables.body.data[0].id;
    const menu = await get('/api/v1/menu-items?availableOnly=true&limit=1', waiter.token);

    const createRes = await post('/api/v1/orders', waiter.token, {
      tableId,
      items: [{ menuItemId: menu.body.data[0].id, quantity: 1 }],
    });
    const orderId = createRes.body.data.id;

    const denied = await post(`/api/v1/orders/${orderId}/cancel`, waiter.token, {
      reason: 'ลูกค้าเปลี่ยนใจ',
    });
    assert.equal(denied.status, 403);

    const cancelled = await post(`/api/v1/orders/${orderId}/cancel`, manager.token, {
      reason: 'ลูกค้าเปลี่ยนใจ',
    });
    assert.equal(cancelled.status, 200);
    assert.equal(cancelled.body.data.status, 'cancelled');
    assert.equal(cancelled.body.data.total, 0);

    const table = await get(`/api/v1/tables/${tableId}`, waiter.token);
    assert.equal(table.body.data.status, 'available');
  });

  await t.test('ออเดอร์แบบทานที่ร้านต้องระบุโต๊ะ', async () => {
    const res = await post('/api/v1/orders', waiter.token, { type: 'dine_in', items: [] });
    assert.equal(res.status, 422);
  });

  await t.test('ออเดอร์กลับบ้านไม่ต้องระบุโต๊ะ พร้อมได้เลขคิว', async () => {
    const menu = await get('/api/v1/menu-items?availableOnly=true&limit=1', waiter.token);
    const res = await post('/api/v1/orders', waiter.token, {
      type: 'takeaway',
      items: [{ menuItemId: menu.body.data[0].id, quantity: 1 }],
    });
    assert.equal(res.status, 201);
    assert.equal(res.body.data.tableId, null);
    assert.equal(typeof res.body.data.queueNumber, 'number');
    assert.ok(res.body.data.queueNumber > 0);
  });
});
