// Copyright 2026 Suruch Chakrapeesirisuk
// SPDX-License-Identifier: Apache-2.0

import test, { after } from 'node:test';
import assert from 'node:assert/strict';
import { api, login, authHeader, cleanup } from './helpers/testApp.js';

after(cleanup);

const get = (url, token) => api().get(url).set(authHeader(token));
const post = (url, token, body) => api().post(url).set(authHeader(token)).send(body);
const patch = (url, token, body) => api().patch(url).set(authHeader(token)).send(body);

// ชื่อโต๊ะจำกัดไว้ที่ 20 ตัวอักษร (ดู table.schema.js) — สร้างโต๊ะใหม่แยกทุกเทสต์เพื่อกัน
// rate limit ของ endpoint POST items (ผูกกับ qrToken ต่อโต๊ะ ดู core/rateLimit.js) ปนกันข้ามเทสต์
const uniqueName = (prefix) => `${prefix}${Date.now().toString().slice(-8)}`;

const createTableWithQrToken = async (token, prefix) => {
  const res = await post('/api/v1/tables', token, { name: uniqueName(prefix) });
  assert.equal(res.status, 201);
  return res.body.data;
};

const publicGetTable = (qrToken) => api().get(`/api/v1/public/tables/${qrToken}`);
const publicGetMenu = (qrToken) => api().get(`/api/v1/public/tables/${qrToken}/menu`);
const publicAddItems = (qrToken, items) =>
  api().post(`/api/v1/public/tables/${qrToken}/items`).send({ items });

const firstAvailableMenuItem = async (token) => {
  const res = await get('/api/v1/menu-items?availableOnly=true&limit=200', token);
  const item = res.body.data[0];
  assert.ok(item, 'ต้องมีเมนูที่ขายอยู่อย่างน้อย 1 รายการสำหรับเทสต์นี้');
  return item;
};

test('GET /tables — โต๊ะทุกใบมี qrToken ติดมาด้วยเสมอ (สุ่มไม่ซ้ำกัน)', async () => {
  const { token } = await login('admin', 'admin123');

  const res = await get('/api/v1/tables', token);

  assert.equal(res.status, 200);
  const tokens = res.body.data.map((row) => row.qrToken);
  assert.ok(tokens.every(Boolean), 'ทุกโต๊ะต้องมี qrToken');
  assert.equal(new Set(tokens).size, tokens.length, 'qrToken ต้องไม่ซ้ำกันเลย');
});

test('GET /public/tables/:qrToken — token ไม่มีจริงต้องได้ 404 โดยไม่ต้อง login', async () => {
  const res = await publicGetTable('00000000-0000-0000-0000-000000000000');

  assert.equal(res.status, 404);
});

test('GET /public/tables/:qrToken — โต๊ะที่ยังไม่มีออเดอร์เปิดอยู่ ได้ order: null', async () => {
  const { token } = await login('admin', 'admin123');
  const table = await createTableWithQrToken(token, 'EMPTY');

  const res = await publicGetTable(table.qrToken);

  assert.equal(res.status, 200);
  assert.equal(res.body.data.table.name, table.name);
  assert.equal(res.body.data.order, null);
  // ต้องไม่มีข้อมูลพนักงาน/ลูกค้าที่ผูกไว้หลุดออกมาในมุมมองสาธารณะ
  assert.equal(res.body.data.waiterName, undefined);
  assert.equal(res.body.data.customerPhone, undefined);
});

test('GET /public/tables/:qrToken/menu — เห็นเฉพาะเมนูที่เปิดขายอยู่ ไม่ต้อง login', async () => {
  const { token } = await login('admin', 'admin123');
  const table = await createTableWithQrToken(token, 'MENU');

  const res = await publicGetMenu(table.qrToken);

  assert.equal(res.status, 200);
  assert.ok(res.body.data.categories.length > 0);
  assert.ok(res.body.data.items.length > 0);
  assert.ok(res.body.data.items.every((item) => item.isAvailable));
});

test('GET /public/tables/:qrToken/menu — ส่งเฉพาะฟิลด์ที่หน้า QR ใช้ (ชุดคีย์ตายตัว)', async () => {
  const { token } = await login('admin', 'admin123');
  const table = await createTableWithQrToken(token, 'KEYS');

  const res = await publicGetMenu(table.qrToken);

  assert.equal(res.status, 200);
  assert.deepEqual(Object.keys(res.body.data).sort(), ['categories', 'items', 'staffOnlyCount']);
  // ล็อกชุดคีย์ไว้ทุกระดับ — เพิ่มฟิลด์ใน DTO เมนูของพนักงานแล้วต้องไม่ติดมาเมนูลูกค้าเอง
  // ต้องตั้งใจเพิ่มใน toPublicMenuItem (public-order.service.js) พร้อมแก้เทสต์นี้
  for (const category of res.body.data.categories) {
    assert.deepEqual(Object.keys(category).sort(), ['icon', 'id', 'name', 'nameEn']);
  }
  for (const item of res.body.data.items) {
    assert.deepEqual(Object.keys(item).sort(), [
      'categoryId',
      'description',
      'id',
      'imageUrl',
      'isAvailable',
      'isRecommended',
      'name',
      'nameEn',
      'optionGroups',
      'price',
    ]);
  }

  const groups = res.body.data.items.flatMap((item) => item.optionGroups);
  assert.ok(groups.length > 0, 'ข้อมูลตั้งต้นต้องมีเมนูที่มีกลุ่มตัวเลือกอย่างน้อย 1 กลุ่ม');
  for (const group of groups) {
    assert.deepEqual(Object.keys(group).sort(), [
      'id',
      'isRequired',
      'maxSelect',
      'minSelect',
      'name',
      'options',
    ]);
    for (const option of group.options) {
      assert.deepEqual(Object.keys(option).sort(), ['id', 'isDefault', 'name', 'priceDelta']);
    }
  }
});

test('POST /public/tables/:qrToken/items — ยังไม่มีออเดอร์เปิดอยู่ → เปิดออเดอร์ใหม่ให้อัตโนมัติ', async () => {
  const { token } = await login('admin', 'admin123');
  const table = await createTableWithQrToken(token, 'NEW');
  const item = await firstAvailableMenuItem(token);

  const res = await publicAddItems(table.qrToken, [
    { menuItemId: item.id, quantity: 2, optionIds: [], note: 'ไม่ใส่ผัก' },
  ]);

  assert.equal(res.status, 200);
  // ลูกค้ากด "ส่งเข้าครัว" → ต้องเข้าครัวจริง (DECISIONS #46) — เดิมค้างเป็นร่าง 'open' ซึ่งคิวครัว
  // ไม่ดึงมาแสดง ลูกค้าเห็นข้อความว่าส่งแล้วแต่ไม่มีใครทำอาหาร (เจอจากชุด E2E ใน app/test_e2e/)
  assert.equal(res.body.data.status, 'in_kitchen');
  assert.equal(res.body.data.items.length, 1);
  assert.equal(res.body.data.items[0].quantity, 2);
  assert.equal(res.body.data.items[0].note, 'ไม่ใส่ผัก');

  const kitchen = await login('kitchen', 'kitchen123');
  const queue = await get('/api/v1/orders/kitchen/queue', kitchen.token);
  assert.equal(queue.status, 200);
  assert.equal(queue.body.data.filter((row) => row.orderId === res.body.data.id).length, 1);

  // โต๊ะต้องเปลี่ยนเป็น "มีคนนั่ง" ให้พนักงานเห็นในผังโต๊ะทันที เหมือนพนักงานเปิดออเดอร์เอง
  const tableRes = await get('/api/v1/tables', token);
  const updated = tableRes.body.data.find((row) => row.id === table.id);
  assert.equal(updated.status, 'occupied');
});

test('POST /public/tables/:qrToken/items — มีออเดอร์เปิดอยู่แล้ว → เพิ่มรายการเข้าออเดอร์เดิม ไม่เปิดใบใหม่', async () => {
  const { token } = await login('admin', 'admin123');
  const table = await createTableWithQrToken(token, 'ADD');
  const item = await firstAvailableMenuItem(token);

  const first = await publicAddItems(table.qrToken, [
    { menuItemId: item.id, quantity: 1, optionIds: [] },
  ]);
  const second = await publicAddItems(table.qrToken, [
    { menuItemId: item.id, quantity: 3, optionIds: [] },
  ]);

  assert.equal(second.status, 200);
  assert.equal(second.body.data.id, first.body.data.id, 'ต้องเป็นออเดอร์เดียวกัน ไม่เปิดใบใหม่');
  assert.equal(second.body.data.items.length, 2);
});

test('GET /public/tables/:qrToken — หลังสั่งแล้วเห็นรายการ+ยอดรวมที่สั่งไปเป็นพรีวิว', async () => {
  const { token } = await login('admin', 'admin123');
  const table = await createTableWithQrToken(token, 'PREV');
  const item = await firstAvailableMenuItem(token);

  await publicAddItems(table.qrToken, [{ menuItemId: item.id, quantity: 1, optionIds: [] }]);
  const res = await publicGetTable(table.qrToken);

  assert.equal(res.status, 200);
  assert.equal(res.body.data.order.items.length, 1);
  assert.ok(res.body.data.order.total > 0);
});

test('POST /public/tables/:qrToken/items — เมนูที่ปิดขายอยู่สั่งไม่ได้ (409)', async () => {
  const { token } = await login('admin', 'admin123');
  const table = await createTableWithQrToken(token, 'SOLD');
  const item = await firstAvailableMenuItem(token);
  await patch(`/api/v1/menu-items/${item.id}`, token, { isAvailable: false });

  const res = await publicAddItems(table.qrToken, [
    { menuItemId: item.id, quantity: 1, optionIds: [] },
  ]);

  assert.equal(res.status, 409);
});

test('POST /public/tables/:qrToken/items — ส่งรายการเกิน 20 ต้องโดนปฏิเสธ (422)', async () => {
  const { token } = await login('admin', 'admin123');
  const table = await createTableWithQrToken(token, 'MANY');
  const item = await firstAvailableMenuItem(token);

  const res = await publicAddItems(
    table.qrToken,
    Array.from({ length: 21 }, () => ({ menuItemId: item.id, quantity: 1, optionIds: [] })),
  );

  assert.equal(res.status, 422);
});

test('โต๊ะถูกปิดใช้งาน (isActive: false) → ลูกค้าสั่งเองต่อไม่ได้ทันที', async () => {
  const { token } = await login('admin', 'admin123');
  const table = await createTableWithQrToken(token, 'OFF');
  await patch(`/api/v1/tables/${table.id}`, token, { isActive: false });

  const res = await publicGetTable(table.qrToken);

  assert.equal(res.status, 404);
});

test('PATCH /tables/:id/qr-token/regenerate — token เก่าใช้ต่อไม่ได้ทันที ได้ token ใหม่ใช้แทน', async () => {
  const { token } = await login('admin', 'admin123');
  const table = await createTableWithQrToken(token, 'REGEN');

  const res = await patch(`/api/v1/tables/${table.id}/qr-token/regenerate`, token, {});

  assert.equal(res.status, 200);
  assert.notEqual(res.body.data.qrToken, table.qrToken);

  const oldToken = await publicGetTable(table.qrToken);
  assert.equal(oldToken.status, 404);

  const newToken = await publicGetTable(res.body.data.qrToken);
  assert.equal(newToken.status, 200);
});

test('PATCH /tables/:id/qr-token/regenerate — พนักงานเสิร์ฟทำไม่ได้ (RBAC 403)', async () => {
  const admin = await login('admin', 'admin123');
  const table = await createTableWithQrToken(admin.token, 'RBAC');
  const waiter = await login('waiter1', 'waiter123');

  const res = await patch(`/api/v1/tables/${table.id}/qr-token/regenerate`, waiter.token, {});

  assert.equal(res.status, 403);
});

test('POST /public/tables/:qrToken/items — ยิงถี่เกิน limit ต้องโดน 429', async () => {
  const { token } = await login('admin', 'admin123');
  const table = await createTableWithQrToken(token, 'RATE');
  const item = await firstAvailableMenuItem(token);

  let lastStatus = 200;
  for (let i = 0; i < 40; i += 1) {
    const res = await publicAddItems(table.qrToken, [
      { menuItemId: item.id, quantity: 1, optionIds: [] },
    ]);
    lastStatus = res.status;
    if (lastStatus === 429) break;
  }

  assert.equal(lastStatus, 429);
});
