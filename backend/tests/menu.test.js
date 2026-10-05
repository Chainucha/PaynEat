// Copyright 2026 Suruch Chakrapeesirisuk
// SPDX-License-Identifier: Apache-2.0

import test, { after } from 'node:test';
import assert from 'node:assert/strict';
import { api, login, authHeader, cleanup } from './helpers/testApp.js';

after(cleanup);

const get = (url, token) => api().get(url).set(authHeader(token));
const post = (url, token, body) => api().post(url).set(authHeader(token)).send(body);
const patch = (url, token, body) => api().patch(url).set(authHeader(token)).send(body);
const del = (url, token) => api().delete(url).set(authHeader(token));

/** สร้างหมวดหมู่ใหม่ไว้ผูกกับเมนูทดสอบ ไม่พึ่งข้อมูล seed เพื่อไม่ให้เทสต์เปราะ */
const createCategory = async (token, name = `ทดสอบ-${Date.now()}-${Math.random()}`) => {
  const res = await post('/api/v1/categories', token, { name });
  assert.equal(res.status, 201, JSON.stringify(res.body));
  return res.body.data;
};

test('POST /menu-items — สร้างเมนูพร้อมกลุ่มตัวเลือกได้ครบ', async () => {
  const { token } = await login('admin', 'admin123');
  const category = await createCategory(token);

  const res = await post('/api/v1/menu-items', token, {
    categoryId: category.id,
    name: 'เมนูทดสอบ',
    price: 99,
    optionGroups: [
      {
        name: 'ระดับความเผ็ด',
        minSelect: 1,
        maxSelect: 1,
        isRequired: true,
        options: [{ name: 'ปกติ' }, { name: 'เผ็ดมาก', priceDelta: 10 }],
      },
    ],
  });

  assert.equal(res.status, 201);
  assert.equal(res.body.data.name, 'เมนูทดสอบ');
  assert.equal(res.body.data.price, 99);
  assert.equal(res.body.data.optionGroups.length, 1);
  assert.equal(res.body.data.optionGroups[0].options.length, 2);
});

test('POST /menu-items — categoryId ที่ไม่มีอยู่จริงต้องได้ 400', async () => {
  const { token } = await login('admin', 'admin123');

  const res = await post('/api/v1/menu-items', token, {
    categoryId: 999999,
    name: 'เมนูไม่มีหมวดหมู่',
    price: 50,
  });

  assert.equal(res.status, 400);
});

test('POST /menu-items — ข้อมูลไม่ครบ (ไม่มีชื่อ) ต้องได้ 422', async () => {
  const { token } = await login('admin', 'admin123');
  const category = await createCategory(token);

  const res = await post('/api/v1/menu-items', token, {
    categoryId: category.id,
    price: 50,
  });

  assert.equal(res.status, 422);
  assert.equal(res.body.error.code, 'VALIDATION_ERROR');
});

test('POST /menu-items — พนักงานเสิร์ฟสร้างเมนูไม่ได้ (RBAC 403)', async () => {
  const { token } = await login('waiter1', 'waiter123');

  const res = await post('/api/v1/menu-items', token, {
    categoryId: 1,
    name: 'เมนูที่ไม่ควรสร้างได้',
    price: 50,
  });

  assert.equal(res.status, 403);
});

test('PATCH /menu-items/:id — แก้ไขราคาและชื่อได้', async () => {
  const { token } = await login('admin', 'admin123');
  const category = await createCategory(token);
  const created = await post('/api/v1/menu-items', token, {
    categoryId: category.id,
    name: 'ก่อนแก้',
    price: 50,
  });

  const res = await patch(`/api/v1/menu-items/${created.body.data.id}`, token, {
    name: 'หลังแก้',
    price: 65,
  });

  assert.equal(res.status, 200);
  assert.equal(res.body.data.name, 'หลังแก้');
  assert.equal(res.body.data.price, 65);
});

test(
  'PATCH /menu-items/:id/availability — ครัวและพนักงานเสิร์ฟปิด/เปิดขายเองได้ทันที ' +
    '(ไม่ต้องรอผู้จัดการ)',
  async () => {
    const admin = await login('admin', 'admin123');
    const category = await createCategory(admin.token);
    const created = await post('/api/v1/menu-items', admin.token, {
      categoryId: category.id,
      name: 'เมนูของหมดได้',
      price: 40,
    });

    const kitchen = await login('kitchen', 'kitchen123');
    const res = await patch(
      `/api/v1/menu-items/${created.body.data.id}/availability`,
      kitchen.token,
      { isAvailable: false },
    );

    assert.equal(res.status, 200);
    assert.equal(res.body.data.isAvailable, false);
  },
);

test('DELETE /menu-items/:id — ลบไม่ได้ถ้ายังอยู่ในออเดอร์ที่ไม่ปิด', async () => {
  const admin = await login('admin', 'admin123');
  const category = await createCategory(admin.token);
  const menuItem = await post('/api/v1/menu-items', admin.token, {
    categoryId: category.id,
    name: 'เมนูที่ถูกสั่งแล้ว',
    price: 30,
  });

  const waiter = await login('waiter1', 'waiter123');
  const tablesRes = await get('/api/v1/tables?status=available', waiter.token);
  const table = tablesRes.body.data[0];
  assert.ok(table, 'ต้องมีโต๊ะว่างอย่างน้อย 1 โต๊ะสำหรับเทสต์นี้');

  await post('/api/v1/orders', waiter.token, {
    type: 'dine_in',
    tableId: table.id,
    guestCount: 1,
    items: [{ menuItemId: menuItem.body.data.id, quantity: 1, optionIds: [] }],
  });

  const res = await del(`/api/v1/menu-items/${menuItem.body.data.id}`, admin.token);
  assert.equal(res.status, 409);
});

test('DELETE /menu-items/:id — ลบได้ปกติถ้าไม่มีออเดอร์ค้าง', async () => {
  const { token } = await login('admin', 'admin123');
  const category = await createCategory(token);
  const created = await post('/api/v1/menu-items', token, {
    categoryId: category.id,
    name: 'เมนูที่ไม่มีใครสั่ง',
    price: 20,
  });

  const res = await del(`/api/v1/menu-items/${created.body.data.id}`, token);
  assert.equal(res.status, 204);

  const detail = await get(`/api/v1/menu-items/${created.body.data.id}`, token);
  assert.equal(detail.status, 404);
});

test('GET /menu-items — ค้นหาด้วยคำค้นและกรองตามหมวดหมู่ได้', async () => {
  const { token } = await login('admin', 'admin123');
  const category = await createCategory(token);
  await post('/api/v1/menu-items', token, {
    categoryId: category.id,
    name: 'ค้นหาเจอแน่นอน-เฉพาะกิจ',
    price: 55,
  });

  const res = await get(
    `/api/v1/menu-items?search=${encodeURIComponent('เฉพาะกิจ')}&categoryId=${category.id}&limit=200`,
    token,
  );

  assert.equal(res.status, 200);
  assert.equal(res.body.data.length, 1);
  assert.equal(res.body.data[0].name, 'ค้นหาเจอแน่นอน-เฉพาะกิจ');
});

test('POST/PATCH /menu-items — stationId ตั้งได้ ล้างกลับเป็น "ตามหมวดหมู่" ได้ และสถานีมั่วได้ 400', async () => {
  const { token } = await login('admin', 'admin123');
  const category = await createCategory(token);
  const stations = await get('/api/v1/kitchen-stations', token);
  const bar = stations.body.data.find((row) => row.code === 'bar');

  const created = await post('/api/v1/menu-items', token, {
    categoryId: category.id,
    name: 'เมนูมีสถานี',
    price: 80,
    stationId: bar.id,
  });
  assert.equal(created.status, 201, JSON.stringify(created.body));
  assert.equal(created.body.data.stationId, bar.id);

  // null = "ตามหมวดหมู่" ต้องเขียนลงฐานข้อมูลได้จริง ไม่ใช่ถูก COALESCE กลืนไปเฉย ๆ
  const cleared = await patch(`/api/v1/menu-items/${created.body.data.id}`, token, {
    stationId: null,
  });
  assert.equal(cleared.status, 200, JSON.stringify(cleared.body));
  assert.equal(cleared.body.data.stationId, null);

  const reassigned = await patch(`/api/v1/menu-items/${created.body.data.id}`, token, {
    stationId: bar.id,
  });
  assert.equal(reassigned.body.data.stationId, bar.id);

  // ไม่ส่งมาเลย = ไม่แตะช่องนี้
  const untouched = await patch(`/api/v1/menu-items/${created.body.data.id}`, token, {
    name: 'เมนูมีสถานี (แก้ชื่อ)',
  });
  assert.equal(untouched.body.data.stationId, bar.id);

  const bogus = await post('/api/v1/menu-items', token, {
    categoryId: category.id,
    name: 'เมนูสถานีมั่ว',
    price: 80,
    stationId: 999999,
  });
  assert.equal(bogus.status, 400);
});

test('POST/PATCH /categories — stationId เป็นค่าตั้งต้นของหมวดหมู่ ล้างได้ และสถานีมั่วได้ 400', async () => {
  const { token } = await login('admin', 'admin123');
  const stations = await get('/api/v1/kitchen-stations', token);
  const cold = stations.body.data.find((row) => row.code === 'cold');

  const created = await post('/api/v1/categories', token, {
    name: `หมวดมีสถานี-${Date.now()}`,
    stationId: cold.id,
  });
  assert.equal(created.status, 201, JSON.stringify(created.body));
  assert.equal(created.body.data.stationId, cold.id);

  const cleared = await patch(`/api/v1/categories/${created.body.data.id}`, token, {
    stationId: null,
  });
  assert.equal(cleared.status, 200);
  assert.equal(cleared.body.data.stationId, null);

  const bogus = await patch(`/api/v1/categories/${created.body.data.id}`, token, {
    stationId: 999999,
  });
  assert.equal(bogus.status, 400);
});
