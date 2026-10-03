// Copyright 2026 Suruch Chakrapeesirisuk
// SPDX-License-Identifier: Apache-2.0

import test, { after, before } from 'node:test';
import assert from 'node:assert/strict';
import { api, login, authHeader, cleanup } from './helpers/testApp.js';
import { getDb } from '../src/db/index.js';

// ผู้จัดการจัดการได้เฉพาะพนักงานเสิร์ฟ ครัว และแคชเชียร์ในสาขาที่ตัวเองมีสิทธิ์ ส่วนบัญชีผู้จัดการและแอดมินเป็นของแอดมินเท่านั้น
// (T22 #86, docs/DECISIONS.md #77 D9, #92) — seed: manager มีสิทธิ์เฉพาะสุขุมวิท, waiter2 มีทั้งสุขุมวิทและทองหล่อ

after(cleanup);

const get = (url, token) => api().get(url).set(authHeader(token));
const post = (url, token, body) =>
  api()
    .post(url)
    .set(authHeader(token))
    .send(body ?? {});
const patch = (url, token, body) => api().patch(url).set(authHeader(token)).send(body);

const uniq = (prefix) =>
  `${prefix}${Date.now().toString().slice(-7)}${Math.round(Math.random() * 99)}`;

let manager;
let admin;
let adminAll;
let branch;
const accounts = {};

const createIn = async (branchId, role, prefix) => {
  const res = await post('/api/v1/users', adminAll, {
    name: `${prefix} ทดสอบขอบเขต`,
    username: uniq(prefix),
    password: 'test1234',
    role,
    branchId,
  });
  assert.equal(res.status, 201, JSON.stringify(res.body));
  return res.body.data;
};

const idOf = (username) =>
  getDb().prepare('SELECT id FROM users WHERE username = ?').get(username).id;

before(async () => {
  manager = await login('manager', 'manager123');
  admin = await login('admin', 'admin123');
  branch = Object.fromEntries(
    getDb()
      .prepare('SELECT id, code FROM branches')
      .all()
      .map((row) => [row.code, row.id]),
  );
  // โหมด "ทุกสาขา" ของแอดมิน ระบุสาขาของบัญชีใหม่เองได้
  const all = await post('/api/v1/auth/select-branch', admin.token, { branchId: null });
  assert.equal(all.status, 200, JSON.stringify(all.body));
  adminAll = all.body.data.token;

  accounts.otherBranchWaiter = await createIn(branch.THONGLOR, 'waiter', 'tlw');
  accounts.sameBranchManager = await createIn(branch.SUKHUMVIT, 'manager', 'skm');
  accounts.otherBranchManager = await createIn(branch.THONGLOR, 'manager', 'tlm');
});

test('รายการพนักงานของผู้จัดการ: เฉพาะเสิร์ฟ/ครัว/แคชเชียร์ที่มีสิทธิ์ในสาขาของเขา (รวมคนที่มีหลายสาขา)', async () => {
  const res = await get('/api/v1/users', manager.token);
  assert.equal(res.status, 200, JSON.stringify(res.body));
  const usernames = res.body.data.map((user) => user.username);

  for (const username of ['waiter1', 'waiter2', 'kitchen', 'cashier']) {
    assert.ok(usernames.includes(username), `ต้องเห็น ${username}`);
  }
  for (const hidden of [
    'admin',
    'manager',
    accounts.sameBranchManager.username,
    accounts.otherBranchManager.username,
    accounts.otherBranchWaiter.username,
  ]) {
    assert.ok(!usernames.includes(hidden), `ต้องไม่เห็น ${hidden}`);
  }
  assert.ok(res.body.data.every((user) => ['waiter', 'kitchen', 'cashier'].includes(user.role)));

  const managersOnly = await get('/api/v1/users?role=manager', manager.token);
  assert.deepEqual(managersOnly.body.data, []);
});

test('ผู้จัดการตั้งรหัสใหม่/ปิดบัญชี/เปลี่ยน role/แก้ชื่อของผู้จัดการคนอื่น → 403 ทั้งสาขาเดียวกันและข้ามสาขา', async () => {
  for (const target of [accounts.sameBranchManager, accounts.otherBranchManager]) {
    const url = `/api/v1/users/${target.id}`;
    const attempts = [
      await post(`${url}/reset-password`, manager.token, { password: 'takeover1' }),
      await patch(url, manager.token, { isActive: false }),
      await patch(url, manager.token, { role: 'waiter' }),
      await patch(url, manager.token, { name: 'แก้ชื่อผู้จัดการ' }),
      await get(url, manager.token),
    ];
    for (const res of attempts) {
      assert.equal(res.status, 403, `${target.username}: ${JSON.stringify(res.body)}`);
      assert.equal(
        res.body.error.message,
        'ผู้จัดการจัดการได้เฉพาะบัญชีพนักงานเสิร์ฟ ครัว และแคชเชียร์',
      );
    }
  }
  const english = await patch(`/api/v1/users/${accounts.sameBranchManager.id}`, manager.token, {
    isActive: false,
  }).set('Accept-Language', 'en');
  assert.equal(
    english.body.error.message,
    'Managers can only manage waiter, kitchen and cashier accounts',
  );

  // บัญชีตัวเองก็เป็นของแอดมิน
  const self = await patch(`/api/v1/users/${idOf('manager')}`, manager.token, {
    name: 'แก้ชื่อตัวเอง',
  });
  assert.equal(self.status, 403);

  const row = getDb()
    .prepare('SELECT is_active, role FROM users WHERE id = ?')
    .get(accounts.sameBranchManager.id);
  assert.deepEqual(row, { is_active: 1, role: 'manager' });
  assert.ok((await login(accounts.sameBranchManager.username, 'test1234')).token);
});

test('ผู้จัดการแตะพนักงานที่มีสิทธิ์เฉพาะสาขาอื่นไม่ได้ (404 เหมือนไม่อยู่ในรายการ)', async () => {
  const url = `/api/v1/users/${accounts.otherBranchWaiter.id}`;
  for (const res of [
    await get(url, manager.token),
    await patch(url, manager.token, { isActive: false }),
    await post(`${url}/reset-password`, manager.token, { password: 'takeover1' }),
  ]) {
    assert.equal(res.status, 404, JSON.stringify(res.body));
  }
  assert.ok((await login(accounts.otherBranchWaiter.username, 'test1234')).token);
});

test('ผู้จัดการยังจัดการพนักงานในสาขาได้ แต่เลื่อนหรือสร้างเป็นผู้จัดการ/แอดมินไม่ได้', async () => {
  const created = await post('/api/v1/users', manager.token, {
    name: 'พนักงานใหม่ของผู้จัดการ',
    username: uniq('mgrnew'),
    password: 'test1234',
    role: 'waiter',
  });
  assert.equal(created.status, 201, JSON.stringify(created.body));
  const url = `/api/v1/users/${created.body.data.id}`;

  assert.equal((await patch(url, manager.token, { role: 'kitchen' })).status, 200);
  assert.equal(
    (await post(`${url}/reset-password`, manager.token, { password: 'newpass1' })).status,
    200,
  );
  for (const role of ['manager', 'admin']) {
    const promote = await patch(url, manager.token, { role });
    assert.equal(promote.status, 403, role);
    const create = await post('/api/v1/users', manager.token, {
      name: `สร้าง ${role}`,
      username: uniq(`mk${role}`),
      password: 'test1234',
      role,
    });
    assert.equal(create.status, 403, role);
  }
  // พนักงานที่มีหลายสาขา (waiter2) อยู่ในสาขาของผู้จัดการด้วย จึงจัดการได้
  assert.equal((await get(`/api/v1/users/${idOf('waiter2')}`, manager.token)).status, 200);
});

test('แอดมินยังทำได้ทุกอย่างเหมือนเดิม ทุกบทบาทและทุกสาขา', async () => {
  const list = await get('/api/v1/users', admin.token);
  const usernames = list.body.data.map((user) => user.username);
  for (const account of Object.values(accounts)) assert.ok(usernames.includes(account.username));
  assert.ok(usernames.includes('manager') && usernames.includes('admin'));

  const reset = await post(
    `/api/v1/users/${accounts.sameBranchManager.id}/reset-password`,
    admin.token,
    {
      password: 'adminset1',
    },
  );
  assert.equal(reset.status, 200);
  const deactivate = await patch(`/api/v1/users/${accounts.otherBranchManager.id}`, admin.token, {
    isActive: false,
  });
  assert.equal(deactivate.status, 200);
  const role = await patch(`/api/v1/users/${accounts.otherBranchWaiter.id}`, admin.token, {
    role: 'manager',
  });
  assert.equal(role.status, 200);
  assert.equal(role.body.data.role, 'manager');
});
