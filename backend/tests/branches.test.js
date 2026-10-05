// Copyright 2026 Suruch Chakrapeesirisuk
// SPDX-License-Identifier: Apache-2.0

import test, { after } from 'node:test';
import assert from 'node:assert/strict';
import { api, login, authHeader, cleanup } from './helpers/testApp.js';

after(cleanup);

const get = (url, token) => api().get(url).set(authHeader(token));
const post = (url, token, body) => api().post(url).set(authHeader(token)).send(body);
const patch = (url, token, body) => api().patch(url).set(authHeader(token)).send(body);

const rawLogin = (username, password) =>
  api().post('/api/v1/auth/login').send({ username, password });

test('POST /auth/login — waiter2 มีสิทธิ์ 2 สาขา ต้องได้ needsBranchSelection แทน token ทันที', async () => {
  const res = await rawLogin('waiter2', 'waiter123');

  assert.equal(res.status, 200);
  assert.equal(res.body.data.needsBranchSelection, true);
  assert.equal(res.body.data.token, undefined);
  assert.ok(res.body.data.pendingToken);
  assert.equal(res.body.data.branches.length, 2);
});

test('POST /auth/login — waiter1 มีสิทธิ์สาขาเดียว ล็อกอินได้ token ทันที พร้อม branchId/branchName', async () => {
  const res = await rawLogin('waiter1', 'waiter123');

  assert.equal(res.status, 200);
  assert.ok(res.body.data.token);
  assert.ok(res.body.data.user.branchId);
  assert.equal(res.body.data.user.branchName, 'สาขาสุขุมวิท');
});

test('POST /auth/login — admin ล็อกอินได้ token ทันทีแม้มีสิทธิ์ทุกสาขา (เข้าสาขาแรกอัตโนมัติ)', async () => {
  const res = await rawLogin('admin', 'admin123');

  assert.equal(res.status, 200);
  assert.ok(res.body.data.token);
  assert.equal(res.body.data.user.branchName, 'สาขาสุขุมวิท');
});

test('POST /auth/select-branch — waiter2 แลก pendingToken เป็น token ปกติของสาขาที่เลือกได้', async () => {
  const pending = await rawLogin('waiter2', 'waiter123');
  const { pendingToken, branches } = pending.body.data;
  const thonglor = branches.find((b) => b.code === 'THONGLOR');

  const res = await post('/api/v1/auth/select-branch', pendingToken, {
    branchId: thonglor.id,
  });

  assert.equal(res.status, 200);
  assert.ok(res.body.data.token);
  assert.equal(res.body.data.user.branchName, 'สาขาทองหล่อ');
});

test('POST /auth/select-branch — เลือกสาขาที่ไม่มีสิทธิ์เข้าต้องได้ 403', async () => {
  const pending = await rawLogin('waiter2', 'waiter123');
  const { pendingToken } = pending.body.data;

  // สร้างสาขาใหม่ที่ waiter2 ไม่มีสิทธิ์ ด้วย admin ก่อน
  const admin = await login('admin', 'admin123');
  const created = await post('/api/v1/branches', admin.token, { name: 'สาขาทดสอบ' });

  const res = await post('/api/v1/auth/select-branch', pendingToken, {
    branchId: created.body.data.id,
  });

  assert.equal(res.status, 403);
});

test('POST /auth/select-branch — เฉพาะ admin เท่านั้นที่เลือกโหมด "ทุกสาขา" (branchId: null) ได้', async () => {
  const { token } = await login('waiter1', 'waiter123');

  const res = await post('/api/v1/auth/select-branch', token, { branchId: null });

  assert.equal(res.status, 403);
});

test('POST /auth/select-branch — admin สลับไปโหมด "ทุกสาขา" แล้วสลับกลับสาขาเจาะจงได้', async () => {
  const { token } = await login('admin', 'admin123');

  const allBranches = await post('/api/v1/auth/select-branch', token, { branchId: null });
  assert.equal(allBranches.status, 200);
  assert.equal(allBranches.body.data.user.branchId, null);

  const me = await get('/api/v1/auth/me', allBranches.body.data.token);
  assert.equal(me.body.data.branchId, null);
});

test('GET /auth/me — token เก่าที่สาขาถูกปิดใช้งานไปแล้วใช้ต่อไม่ได้ทันที', async () => {
  const admin = await login('admin', 'admin123');
  const created = await post('/api/v1/branches', admin.token, { name: 'สาขาชั่วคราว' });
  const branchId = created.body.data.id;

  const switched = await post('/api/v1/auth/select-branch', admin.token, { branchId });
  assert.equal(switched.status, 200);

  await patch(`/api/v1/branches/${branchId}`, admin.token, { isActive: false });

  const res = await get('/api/v1/auth/me', switched.body.data.token);
  assert.equal(res.status, 401);
});

test('GET /branches — เฉพาะ admin เท่านั้นที่ดูรายชื่อสาขาทั้งหมดได้ (RBAC 403)', async () => {
  const { token } = await login('waiter1', 'waiter123');

  const res = await get('/api/v1/branches', token);

  assert.equal(res.status, 403);
});

test('GET /branches/mine — คืนเฉพาะสาขาที่ตัวเองมีสิทธิ์ (ไม่จำกัด role)', async () => {
  const { token } = await login('waiter1', 'waiter123');

  const res = await get('/api/v1/branches/mine', token);

  assert.equal(res.status, 200);
  assert.equal(res.body.data.length, 1);
  assert.equal(res.body.data[0].name, 'สาขาสุขุมวิท');
});

test('GET /menu-items — เห็นเฉพาะเมนูของสาขาตัวเอง ไม่ปนกับสาขาอื่น', async () => {
  const waiter1 = await login('waiter1', 'waiter123'); // สาขาสุขุมวิท

  const pending = await rawLogin('waiter2', 'waiter123');
  const thonglor = pending.body.data.branches.find((b) => b.code === 'THONGLOR');
  const waiter2Thonglor = await post('/api/v1/auth/select-branch', pending.body.data.pendingToken, {
    branchId: thonglor.id,
  });

  const sukhumvitMenu = await get('/api/v1/menu-items?limit=200', waiter1.token);
  const thonglorMenu = await get('/api/v1/menu-items?limit=200', waiter2Thonglor.body.data.token);

  // 24 เมนูร้านอาหาร + 5 เมนูเคาน์เตอร์เนื้อสด/ของกลับบ้าน (ticket 18/19)
  assert.equal(sukhumvitMenu.body.meta.total, 29);
  assert.equal(thonglorMenu.body.meta.total, 7);
  const thonglorNames = thonglorMenu.body.data.map((item) => item.name);
  assert.ok(thonglorNames.includes('กุ้งเผา'));
  assert.ok(
    !thonglorNames.includes('กุ้งเผา') ||
      !sukhumvitMenu.body.data.some((item) => item.name === 'กุ้งเผา'),
  );
});

test('GET /menu-items — admin โหมด "ทุกสาขา" เห็นเมนูรวมทุกสาขา', async () => {
  const { token } = await login('admin', 'admin123');
  const allBranches = await post('/api/v1/auth/select-branch', token, { branchId: null });

  const res = await get('/api/v1/menu-items?limit=200', allBranches.body.data.token);

  assert.equal(res.body.meta.total, 36);
});

test('GET /tables — เห็นเฉพาะโต๊ะของสาขาตัวเอง', async () => {
  const { token } = await login('waiter1', 'waiter123');

  const res = await get('/api/v1/tables', token);

  assert.equal(res.body.data.length, 20);
});

test('GET /ingredients — เห็นเฉพาะวัตถุดิบของสาขาตัวเอง', async () => {
  const { token } = await login('waiter1', 'waiter123');

  const res = await get('/api/v1/ingredients', token);

  // 6 วัตถุดิบเดิม + หมูสามชั้น/เนื้อริบอาย (หน่วยกิโลกรัม ของเมนูขายตามน้ำหนัก)
  assert.equal(res.body.data.length, 8);
});

test('POST /orders — ออเดอร์ใหม่ผูก branch_id ตามสาขาที่กำลังทำงานอยู่ และ list กรองตามสาขา', async () => {
  const pending = await rawLogin('waiter2', 'waiter123');
  const thonglor = pending.body.data.branches.find((b) => b.code === 'THONGLOR');
  const waiter2Thonglor = await post('/api/v1/auth/select-branch', pending.body.data.pendingToken, {
    branchId: thonglor.id,
  });
  const token = waiter2Thonglor.body.data.token;

  const created = await post('/api/v1/orders', token, { type: 'takeaway', guestCount: 1 });
  assert.equal(created.status, 201);
  assert.equal(created.body.data.branchId, thonglor.id);

  const waiter1 = await login('waiter1', 'waiter123');
  const sukhumvitOrders = await get(`/api/v1/orders/code/${created.body.data.code}`, waiter1.token);
  // ยังหาเจอได้ตรงๆ ด้วยรหัส (getByCode ไม่ได้ scope ตามสาขา) แต่ list ต้องกรอง
  assert.equal(sukhumvitOrders.status, 200);

  const list = await get('/api/v1/orders?limit=100', waiter1.token);
  const codes = list.body.data.map((order) => order.code);
  assert.ok(!codes.includes(created.body.data.code));
});

test('POST /users — พนักงานใหม่ถูกกำหนดสาขาให้อัตโนมัติตามผู้สร้าง และล็อกอินได้ทันที', async () => {
  const { token } = await login('manager', 'manager123');
  const username = `branchstaff${Date.now().toString().slice(-8)}`;

  const created = await post('/api/v1/users', token, {
    name: 'พนักงานทดสอบสาขา',
    username,
    password: 'test1234',
    role: 'waiter',
  });
  assert.equal(created.status, 201);

  const loggedIn = await rawLogin(username, 'test1234');
  assert.equal(loggedIn.status, 200);
  assert.equal(loggedIn.body.data.user.branchName, 'สาขาสุขุมวิท');
});

test('GET /orders/kitchen/queue — จอครัวเห็นเฉพาะตั๋วของสาขาที่ล็อกอินอยู่ (ticket 34)', async () => {
  const { token: admin } = await login('admin', 'admin123');
  const branches = (await get('/api/v1/branches', admin)).body.data;

  // admin สลับไปทำงานในสาขาหนึ่ง เปิดโต๊ะ เปิดออเดอร์ แล้วส่งเข้าครัว — ทำทั้งสองสาขา
  const sendOrderAt = async (branchCode) => {
    const branch = branches.find((row) => row.code === branchCode);
    const selected = await post('/api/v1/auth/select-branch', admin, { branchId: branch.id });
    assert.equal(selected.status, 200, JSON.stringify(selected.body));
    const token = selected.body.data.token;

    const table = await post('/api/v1/tables', token, {
      name: `KQ${branchCode.slice(0, 3)}${Date.now().toString().slice(-6)}`,
    });
    assert.equal(table.status, 201, JSON.stringify(table.body));
    const menu = await get('/api/v1/menu-items?availableOnly=true&limit=1', token);
    const order = await post('/api/v1/orders', token, {
      type: 'dine_in',
      tableId: table.body.data.id,
      guestCount: 1,
      items: [{ menuItemId: menu.body.data[0].id, quantity: 1 }],
    });
    assert.equal(order.status, 201, JSON.stringify(order.body));
    const sent = await post(`/api/v1/orders/${order.body.data.id}/send-to-kitchen`, token);
    assert.equal(sent.status, 200, JSON.stringify(sent.body));
    return order.body.data.id;
  };

  const sukhumvitOrderId = await sendOrderAt('SUKHUMVIT');
  const thonglorOrderId = await sendOrderAt('THONGLOR');

  // บัญชีครัวมีสิทธิ์สาขาสุขุมวิทสาขาเดียว
  const { token: kitchen } = await login('kitchen', 'kitchen123');
  const queue = await get('/api/v1/orders/kitchen/queue', kitchen);
  assert.equal(queue.status, 200);
  const orderIds = new Set(queue.body.data.map((item) => item.orderId));
  assert.ok(orderIds.has(sukhumvitOrderId), 'ต้องเห็นตั๋วของสาขาตัวเอง');
  assert.ok(!orderIds.has(thonglorOrderId), 'ต้องไม่เห็นตั๋วของสาขาอื่น');

  // admin โหมด "ทุกสาขา" เห็นทั้งสองสาขาเหมือนเดิม (ดู docs/DECISIONS.md #36)
  const allBranches = await post('/api/v1/auth/select-branch', admin, { branchId: null });
  const adminQueue = await get('/api/v1/orders/kitchen/queue', allBranches.body.data.token);
  const adminOrderIds = new Set(adminQueue.body.data.map((item) => item.orderId));
  assert.ok(adminOrderIds.has(sukhumvitOrderId));
  assert.ok(adminOrderIds.has(thonglorOrderId));
});
