// Copyright 2026 Suruch Chakrapeesirisuk
// SPDX-License-Identifier: Apache-2.0

import test, { after } from 'node:test';
import assert from 'node:assert/strict';
import { api, login, authHeader, cleanup } from './helpers/testApp.js';

// รูปเมนูไม่ส่งเป็น base64 ทั้งก้อนในรายการเมนูอีกแล้ว — ส่ง path ให้โหลดรูปแยกพร้อม cache (DECISIONS #101)

after(cleanup);

const get = (url, token) => api().get(url).set(authHeader(token));
const post = (url, token, body) => api().post(url).set(authHeader(token)).send(body);
const patch = (url, token, body) => api().patch(url).set(authHeader(token)).send(body);

const JPEG_BYTES = Buffer.from([0xff, 0xd8, 0xff, 0xe0, 1, 2, 3, 4, 0xff, 0xd9]);
const JPEG_DATA_URL = `data:image/jpeg;base64,${JPEG_BYTES.toString('base64')}`;
const SERVED = /^\/api\/v1\/public\/menu-images\/(\d+)\?v=[\w-]+$/;

const createItem = async (token, imageUrl) => {
  const category = await post('/api/v1/categories', token, { name: `รูป-${Math.random()}` });
  const res = await post('/api/v1/menu-items', token, {
    categoryId: category.body.data.id,
    name: `เมนูมีรูป-${Math.random()}`,
    price: 50,
    imageUrl,
  });
  assert.equal(res.status, 201, JSON.stringify(res.body));
  return res.body.data;
};

test('รายการเมนูส่ง path ของรูปแทน data URL และ path นั้นได้ไบต์ของรูปพร้อม cache ยาว', async () => {
  const { token } = await login('admin', 'admin123');
  const item = await createItem(token, JPEG_DATA_URL);

  assert.match(item.imageUrl, SERVED);
  assert.equal(item.imageUrl.match(SERVED)[1], String(item.id));

  const list = await get('/api/v1/menu-items?limit=100', token);
  const listed = list.body.data.find((row) => row.id === item.id);
  assert.equal(listed.imageUrl, item.imageUrl);
  assert.ok(list.body.data.every((row) => !String(row.imageUrl ?? '').startsWith('data:')));

  // ไม่ต้อง login — <img> และหน้า QR ส่ง Authorization header ไม่ได้
  const image = await api().get(item.imageUrl).buffer(true);
  assert.equal(image.status, 200);
  assert.equal(image.headers['content-type'], 'image/jpeg');
  assert.equal(image.headers['cache-control'], 'public, max-age=31536000, immutable');
  assert.equal(image.headers['cross-origin-resource-policy'], 'cross-origin');
  assert.deepEqual(Buffer.from(image.body), JPEG_BYTES);
});

test('เวอร์ชันเก่าหรือไม่มีเวอร์ชัน ได้รูปปัจจุบันแต่ต้องถามเซิร์ฟเวอร์ใหม่ทุกครั้ง', async () => {
  const { token } = await login('admin', 'admin123');
  const item = await createItem(token, JPEG_DATA_URL);

  const stale = await api().get(`/api/v1/public/menu-images/${item.id}?v=old`);
  assert.equal(stale.status, 200);
  assert.equal(stale.headers['cache-control'], 'no-cache');
});

test('ส่ง path รูปเดิมกลับมาตอนแก้เมนู = ไม่เปลี่ยนรูป, ส่ง "" = ลบรูป', async () => {
  const { token } = await login('admin', 'admin123');
  const item = await createItem(token, JPEG_DATA_URL);

  const echoed = await patch(`/api/v1/menu-items/${item.id}`, token, {
    price: 60,
    imageUrl: item.imageUrl,
  });
  assert.equal(echoed.status, 200, JSON.stringify(echoed.body));
  assert.match(echoed.body.data.imageUrl, SERVED);
  assert.equal((await api().get(echoed.body.data.imageUrl)).status, 200);

  const removed = await patch(`/api/v1/menu-items/${item.id}`, token, { imageUrl: '' });
  assert.equal(removed.body.data.imageUrl, null);
  assert.equal((await api().get(`/api/v1/public/menu-images/${item.id}`)).status, 404);
});

test('รูปใหม่ได้ URL ใหม่ — cache ของรูปเก่าไม่ค้าง', async () => {
  const { token } = await login('admin', 'admin123');
  const item = await createItem(token, JPEG_DATA_URL);
  const png = `data:image/png;base64,${Buffer.from('another picture').toString('base64')}`;

  const updated = await patch(`/api/v1/menu-items/${item.id}`, token, { imageUrl: png });
  assert.notEqual(updated.body.data.imageUrl, item.imageUrl);
  const image = await api().get(updated.body.data.imageUrl);
  assert.equal(image.headers['content-type'], 'image/png');
});

test('URL รูปภายนอกส่งต่อตามเดิม และ data URL ที่ไม่ใช่รูปไม่ถูกเสิร์ฟจาก origin ของเรา', async () => {
  const { token } = await login('admin', 'admin123');
  const external = await createItem(token, 'https://images.example.com/pad-thai.jpg');
  assert.equal(external.imageUrl, 'https://images.example.com/pad-thai.jpg');
  assert.equal((await api().get(`/api/v1/public/menu-images/${external.id}`)).status, 404);

  const html = `data:text/html;base64,${Buffer.from('<script>alert(1)</script>').toString('base64')}`;
  const unsafe = await createItem(token, html);
  assert.equal((await api().get(unsafe.imageUrl)).status, 404);

  const svg = `data:image/svg+xml;base64,${Buffer.from('<svg/>').toString('base64')}`;
  const vector = await createItem(token, svg);
  assert.equal((await api().get(vector.imageUrl)).status, 404);
});

test('เมนูหน้า QR ก็ได้ path รูปเหมือนกัน', async () => {
  const { token } = await login('admin', 'admin123');
  const item = await createItem(token, JPEG_DATA_URL);
  const table = await post('/api/v1/tables', token, {
    name: `IMG${Date.now().toString().slice(-8)}`,
  });

  const menu = await api().get(`/api/v1/public/tables/${table.body.data.qrToken}/menu`);
  assert.equal(menu.status, 200);
  const listed = menu.body.data.items.find((row) => row.id === item.id);
  assert.equal(listed?.imageUrl, item.imageUrl);
});
