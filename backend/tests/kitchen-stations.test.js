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

const uniqueCode = () =>
  `st${Date.now().toString(36)}${Math.floor(Math.random() * 1e4)}`.slice(0, 20);

/** สร้างสถานีใหม่ไว้ใช้ในเทสต์ ไม่พึ่งสามสถานีที่มาจาก migration เพื่อไม่ให้เทสต์เปราะ */
const createStation = async (token, overrides = {}) => {
  const res = await post('/api/v1/kitchen-stations', token, {
    code: uniqueCode(),
    name: 'สถานีทดสอบ',
    ...overrides,
  });
  assert.equal(res.status, 201, JSON.stringify(res.body));
  return res.body.data;
};

test('GET /kitchen-stations — migration เตรียมครัวร้อน ครัวเย็น บาร์ และค่าเริ่มต้นหนึ่งเดียว', async () => {
  const { token } = await login('admin', 'admin123');

  const res = await get('/api/v1/kitchen-stations', token);
  assert.equal(res.status, 200);

  const byCode = new Map(res.body.data.map((station) => [station.code, station]));
  for (const code of ['hot', 'cold', 'bar']) {
    assert.ok(byCode.has(code), `ต้องมีสถานีรหัส ${code}`);
  }
  assert.equal(byCode.get('hot').name, 'ครัวร้อน');
  assert.equal(byCode.get('hot').nameEn, 'Hot Kitchen');
  assert.equal(byCode.get('hot').nameKo, '온주방');

  const defaults = res.body.data.filter((station) => station.isDefault);
  assert.equal(defaults.length, 1, 'ค่าเริ่มต้นต้องมีได้สถานีเดียว');
  assert.equal(defaults[0].code, 'hot');
});

test('GET /kitchen-stations?activeOnly=true — ซ่อนสถานีที่ปิดใช้งาน', async () => {
  const { token } = await login('admin', 'admin123');
  const station = await createStation(token, { name: 'สถานีปิดใช้งาน' });

  await patch(`/api/v1/kitchen-stations/${station.id}`, token, { isActive: false });

  const all = await get('/api/v1/kitchen-stations', token);
  const activeOnly = await get('/api/v1/kitchen-stations?activeOnly=true', token);
  assert.ok(all.body.data.some((row) => row.id === station.id));
  assert.ok(!activeOnly.body.data.some((row) => row.id === station.id));
});

test('POST /kitchen-stations — รหัสซ้ำได้ 409 และรหัสผิดรูปแบบได้ 422', async () => {
  const { token } = await login('admin', 'admin123');
  const station = await createStation(token);

  const duplicate = await post('/api/v1/kitchen-stations', token, {
    code: station.code,
    name: 'ชื่ออื่น',
  });
  assert.equal(duplicate.status, 409);

  const invalid = await post('/api/v1/kitchen-stations', token, { code: 'ครัว', name: 'ชื่อ' });
  assert.equal(invalid.status, 422);
});

test('PATCH /kitchen-stations/:id — แก้ชื่อได้ แต่แก้รหัสไม่ได้ (จอครัวจำรหัสไว้ต่อเครื่อง)', async () => {
  const { token } = await login('admin', 'admin123');
  const station = await createStation(token, { name: 'ชื่อเดิม' });

  const renamed = await patch(`/api/v1/kitchen-stations/${station.id}`, token, {
    name: 'ชื่อใหม่',
    nameEn: 'New name',
    nameKo: '새 이름',
  });
  assert.equal(renamed.status, 200);
  assert.equal(renamed.body.data.name, 'ชื่อใหม่');
  assert.equal(renamed.body.data.code, station.code, 'รหัสต้องไม่เปลี่ยน');

  // zod strip ค่าที่ไม่รู้จักทิ้ง — ส่งรหัสใหม่มาแล้วต้องไม่มีผล ไม่ใช่ error เงียบ ๆ ที่เปลี่ยนค่าให้
  const tried = await patch(`/api/v1/kitchen-stations/${station.id}`, token, { code: 'newcode' });
  assert.equal(tried.status, 200);
  assert.equal(tried.body.data.code, station.code);
});

test('PATCH /kitchen-stations/:id — ย้ายค่าเริ่มต้นได้ และยังเหลือค่าเริ่มต้นเดียวเสมอ', async () => {
  const { token } = await login('admin', 'admin123');
  const station = await createStation(token, { name: 'สถานีค่าเริ่มต้นใหม่' });

  const res = await patch(`/api/v1/kitchen-stations/${station.id}`, token, { isDefault: true });
  assert.equal(res.status, 200);
  assert.equal(res.body.data.isDefault, true);

  const list = await get('/api/v1/kitchen-stations', token);
  const defaults = list.body.data.filter((row) => row.isDefault);
  assert.equal(defaults.length, 1);
  assert.equal(defaults[0].id, station.id);

  // ปลด/ปิดค่าเริ่มต้นเฉย ๆ ไม่ได้ ไม่งั้นจานที่ไม่ได้กำหนดสถานีจะไม่มีปลายทาง
  const unset = await patch(`/api/v1/kitchen-stations/${station.id}`, token, { isDefault: false });
  assert.equal(unset.status, 409);
  const deactivate = await patch(`/api/v1/kitchen-stations/${station.id}`, token, {
    isActive: false,
  });
  assert.equal(deactivate.status, 409);

  // คืนค่าเริ่มต้นให้ครัวร้อน เพื่อไม่ให้เทสต์อื่นในไฟล์นี้สะดุด
  const hot = list.body.data.find((row) => row.code === 'hot');
  await patch(`/api/v1/kitchen-stations/${hot.id}`, token, { isDefault: true });
});

test('DELETE /kitchen-stations/:id — ลบสถานีที่ยังไม่เคยใช้ได้', async () => {
  const { token } = await login('admin', 'admin123');
  const station = await createStation(token, { name: 'สถานีที่จะลบ' });

  const res = await del(`/api/v1/kitchen-stations/${station.id}`, token);
  assert.equal(res.status, 204);
  assert.equal((await get(`/api/v1/kitchen-stations/${station.id}`, token)).status, 404);
});

test('DELETE /kitchen-stations/:id — ลบค่าเริ่มต้นไม่ได้', async () => {
  const { token } = await login('admin', 'admin123');
  const list = await get('/api/v1/kitchen-stations', token);
  const current = list.body.data.find((row) => row.isDefault);

  const res = await del(`/api/v1/kitchen-stations/${current.id}`, token);
  assert.equal(res.status, 409);
});

test('DELETE /kitchen-stations/:id — ลบไม่ได้เมื่อยังมีเมนูหรือหมวดหมู่ผูกอยู่', async () => {
  const { token } = await login('admin', 'admin123');
  const withCategory = await createStation(token, { name: 'สถานีของหมวดหมู่' });
  const withItem = await createStation(token, { name: 'สถานีของเมนู' });

  const category = await post('/api/v1/categories', token, {
    name: `หมวดสถานี-${Date.now()}`,
    stationId: withCategory.id,
  });
  assert.equal(category.status, 201);
  assert.equal((await del(`/api/v1/kitchen-stations/${withCategory.id}`, token)).status, 409);

  const item = await post('/api/v1/menu-items', token, {
    categoryId: category.body.data.id,
    name: 'เมนูผูกสถานี',
    price: 50,
    stationId: withItem.id,
    branchId: 1,
  });
  assert.equal(item.status, 201, JSON.stringify(item.body));
  assert.equal((await del(`/api/v1/kitchen-stations/${withItem.id}`, token)).status, 409);
});

test('kitchen-stations — itemCount นับจานที่ตกลงสถานีนี้จริงตามกฎการตัดสิน', async () => {
  const { token } = await login('admin', 'admin123');
  const viaCategory = await createStation(token, { name: 'สถานีนับผ่านหมวดหมู่' });
  const viaItem = await createStation(token, { name: 'สถานีนับผ่านเมนู' });

  const category = await post('/api/v1/categories', token, {
    name: `หมวดนับ-${Date.now()}`,
    stationId: viaCategory.id,
  });
  const categoryId = category.body.data.id;
  for (const name of ['จานหนึ่ง', 'จานสอง']) {
    const created = await post('/api/v1/menu-items', token, {
      categoryId,
      name,
      price: 60,
      branchId: 1,
    });
    assert.equal(created.status, 201, JSON.stringify(created.body));
  }

  const countOf = async (id) =>
    (await get('/api/v1/kitchen-stations', token)).body.data.find((row) => row.id === id).itemCount;
  assert.equal(await countOf(viaCategory.id), 2, 'ทั้งสองจานตกที่สถานีของหมวดหมู่');
  assert.equal(await countOf(viaItem.id), 0);

  // ย้ายจานเดียวไปสถานีอื่น — ตัวเลขต้องขยับทั้งสองฝั่ง
  const items = await get(`/api/v1/menu-items?categoryId=${categoryId}`, token);
  const moved = items.body.data[0];
  const patched = await patch(`/api/v1/menu-items/${moved.id}`, token, { stationId: viaItem.id });
  assert.equal(patched.status, 200);
  assert.equal(await countOf(viaCategory.id), 1);
  assert.equal(await countOf(viaItem.id), 1);
});

test('kitchen-stations — พนักงานอ่านได้ แต่แก้ไม่ได้ (403) และไม่ล็อกอินได้ 401', async () => {
  const { token: admin } = await login('admin', 'admin123');
  const station = await createStation(admin, { name: 'สถานีตรวจสิทธิ์' });

  for (const [username, password] of [
    ['waiter1', 'waiter123'],
    ['cashier', 'cashier123'],
    ['kitchen', 'kitchen123'],
  ]) {
    const { token } = await login(username, password);
    assert.equal((await get('/api/v1/kitchen-stations', token)).status, 200, `${username} อ่านได้`);
    assert.equal(
      (await post('/api/v1/kitchen-stations', token, { code: uniqueCode(), name: 'ห้าม' })).status,
      403,
      `${username} สร้างไม่ได้`,
    );
    assert.equal(
      (await patch(`/api/v1/kitchen-stations/${station.id}`, token, { name: 'ห้าม' })).status,
      403,
      `${username} แก้ไม่ได้`,
    );
    assert.equal(
      (await del(`/api/v1/kitchen-stations/${station.id}`, token)).status,
      403,
      `${username} ลบไม่ได้`,
    );
  }

  assert.equal((await api().get('/api/v1/kitchen-stations')).status, 401);
});
