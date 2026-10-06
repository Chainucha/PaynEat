// Copyright 2026 Suruch Chakrapeesirisuk
// SPDX-License-Identifier: Apache-2.0

import test, { after } from 'node:test';
import assert from 'node:assert/strict';

// ต้องตั้งค่า env ก่อน import โมดูลที่อ่าน config (เหตุผลเดียวกับ ai-assistant-rate-limit.test.js) — แยกไฟล์
// เพราะแต่ละไฟล์เทสต์รันคนละ process เทสต์อื่นจึงยังเห็นค่าเริ่มต้น 10/60 (DECISIONS #99)
process.env.SELF_ORDER_MAX_QTY_PER_LINE = '3';
process.env.SELF_ORDER_MAX_ORDER_QTY = '5';

const { api, login, authHeader, cleanup } = await import('./helpers/testApp.js');

after(cleanup);

const publicAddItems = (qrToken, items) =>
  api().post(`/api/v1/public/tables/${qrToken}/items`).send({ items });

test('ร้านตั้งเพดานของ QR เองผ่าน env ได้ — หน้า QR เห็นค่าใหม่ และ backend ใช้ค่าใหม่ตรวจ', async () => {
  const { token } = await login('admin', 'admin123');
  const created = await api()
    .post('/api/v1/tables')
    .set(authHeader(token))
    .send({ name: `ENV${Date.now().toString().slice(-8)}` });
  assert.equal(created.status, 201);
  const { qrToken } = created.body.data;
  const menu = await api().get(`/api/v1/public/tables/${qrToken}/menu`);
  const item = menu.body.data.items.find((row) =>
    (row.optionGroups ?? []).every((group) => !group.isRequired),
  );

  assert.deepEqual(menu.body.data.limits, { maxQuantityPerLine: 3, maxOrderQuantity: 5 });

  const perLine = await publicAddItems(qrToken, [
    { menuItemId: item.id, quantity: 4, optionIds: [] },
  ]);
  assert.equal(perLine.status, 409);
  assert.match(perLine.body.error.message, /ไม่เกิน 3 ที่ต่อรายการ/);

  const first = await publicAddItems(qrToken, [
    { menuItemId: item.id, quantity: 3, optionIds: [] },
  ]);
  assert.equal(first.status, 200);

  const overTotal = await publicAddItems(qrToken, [
    { menuItemId: item.id, quantity: 3, optionIds: [] },
  ]);
  assert.equal(overTotal.status, 409);
  assert.match(overTotal.body.error.message, /รวมไม่เกิน 5 ที่ต่อบิล \(สั่งไปแล้ว 3 ที่\)/);
});
