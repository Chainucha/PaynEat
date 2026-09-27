// Copyright 2026 Suruch Chakrapeesirisuk
// SPDX-License-Identifier: Apache-2.0

import test, { after } from 'node:test';
import assert from 'node:assert/strict';
import { api, login, authHeader, cleanup } from './helpers/testApp.js';
import {
  CREDENTIAL,
  instanceBody,
  itemChange,
  locationChange,
  startErpStub,
} from './helpers/erpStub.js';

// โหมดเชื่อมต่อ PaynEat ERP (ticket 25, docs/DECISIONS.md #80) กับ ERP ปลอม (tests/helpers/erpStub.js)
// ตามลำดับที่ร้านจริงเจอ: ใช้งานเดี่ยว → แก้รหัสสาขา → เชื่อมต่อ → ดึงตามเวอร์ชัน → เน็ตหลุด/credential ถูกเพิกถอน
// → ออกจากโหมด

const { setLogSink } = await import('../src/core/telemetry/logger.js');
const { erpService } = await import('../src/modules/erp/erp.service.js');
const { getDb } = await import('../src/db/index.js');

const stub = await startErpStub();
const logs = [];
const previousSink = setLogSink((line) => logs.push(JSON.parse(line)));

after(async () => {
  setLogSink(previousSink);
  await stub.close();
  cleanup();
});

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
const put = (url, token, body) =>
  api()
    .put(url)
    .set(authHeader(token))
    .send(body ?? {});
const del = (url, token) => api().delete(url).set(authHeader(token));

const connect = (token, overrides = {}) =>
  put('/api/v1/erp/connection', token, { erpUrl: stub.url, credential: CREDENTIAL, ...overrides });

const count = (sql, ...params) =>
  getDb()
    .prepare(sql)
    .get(...params).c;

/** บรรทัด log ของโมดูล ERP (ไม่นับ http.request.completed ของ API POS เอง) */
const erpLines = (from = 0) => logs.slice(from).filter((line) => /PaynEat ERP/.test(line.message));

test('โหมดเชื่อมต่อ PaynEat ERP ตั้งแต่ใช้งานเดี่ยวจนออกจากโหมด', async (t) => {
  const admin = await login('admin', 'admin123');
  const manager = await login('manager', 'manager123');
  let fish;
  let fishMenu;
  let table;

  await t.test(
    'ค่าเริ่มต้นคือใช้งานเดี่ยว — ทุกบทบาทอ่านโหมดได้ ส่วนหน้าตั้งค่าเป็นของ admin',
    async () => {
      const mode = await get('/api/v1/erp/mode', manager.token);
      assert.equal(mode.status, 200);
      assert.deepEqual(mode.body.data, { mode: 'standalone', instanceCode: null });

      assert.equal((await get('/api/v1/erp/connection', manager.token)).status, 403);
      const status = await get('/api/v1/erp/connection', admin.token);
      assert.equal(status.body.data.mode, 'standalone');
      assert.equal(status.body.data.connection, null);
      assert.deepEqual(
        status.body.data.branches.map((b) => [b.code, b.codeProblem, b.servedByErp]),
        [
          ['SUKHUMVIT', null, null],
          ['THONGLOR', null, null],
        ],
      );
      assert.equal(stub.state.requests.length, 0, 'ใช้งานเดี่ยวไม่เรียก ERP เลย');
    },
  );

  await t.test(
    'เตรียมในโหมดเดี่ยว: วัตถุดิบตั้งรหัสสินค้าได้ และเมนูถูกปิดขายอัตโนมัติเมื่อของหมด',
    async () => {
      const created = await post('/api/v1/ingredients', admin.token, {
        name: 'ปลากะพงทดสอบ',
        unit: 'ตัว',
        currentStock: 1,
        itemCode: 'SEABASS',
      });
      assert.equal(created.status, 201);
      fish = created.body.data;
      assert.equal(fish.itemCode, 'SEABASS');
      assert.equal(fish.erpItem, null);

      const duplicate = await post('/api/v1/ingredients', admin.token, {
        name: 'ปลาซ้ำ',
        unit: 'ตัว',
        itemCode: 'SEABASS',
      });
      assert.equal(duplicate.status, 409, 'รหัสสินค้าหนึ่งรหัสมีวัตถุดิบได้ตัวเดียวต่อสาขา');
      const badCode = await post('/api/v1/ingredients', admin.token, {
        name: 'ปลารหัสผิด',
        unit: 'ตัว',
        itemCode: 'sea bass',
      });
      assert.equal(badCode.status, 422);

      const category = await post('/api/v1/categories', admin.token, { name: 'หมวดทดสอบ ERP' });
      const menu = await post('/api/v1/menu-items', admin.token, {
        categoryId: category.body.data.id,
        name: 'ปลากะพงนึ่งมะนาว',
        price: 350,
        ingredients: [{ ingredientId: fish.id, qtyPerUnit: 1 }],
      });
      fishMenu = menu.body.data;
      const out = await post(`/api/v1/ingredients/${fish.id}/adjust-stock`, admin.token, {
        delta: -1,
      });
      assert.equal(out.status, 200);
      const closed = await get(`/api/v1/menu-items/${fishMenu.id}`, admin.token);
      assert.equal(
        closed.body.data.isAvailable,
        false,
        'โหมดเดี่ยว: ของหมด = ปิดขายอัตโนมัติเหมือนเดิม',
      );

      const tables = await get('/api/v1/tables', admin.token);
      table = tables.body.data.find((row) => row.status === 'available');
    },
  );

  await t.test('รหัสสาขาที่ไม่ตรงรูปแบบ: บอกว่าสาขาไหนต้องแก้อะไร และยังไม่เรียก ERP', async () => {
    const thonglor = (await get('/api/v1/branches', admin.token)).body.data.find(
      (b) => b.code === 'THONGLOR',
    );
    await patch(`/api/v1/branches/${thonglor.id}`, admin.token, { code: 'thonglor 2' });
    const noCode = await post('/api/v1/branches', admin.token, { name: 'สาขาใหม่ยังไม่มีรหัส' });
    assert.equal(noCode.status, 201);

    const refused = await connect(admin.token);
    assert.equal(refused.status, 409);
    assert.equal(refused.body.error.code, 'BRANCH_CODES_INVALID');
    assert.deepEqual(
      refused.body.error.details.map((d) => [d.name, d.code, d.problem]),
      [
        ['สาขาทองหล่อ', 'thonglor 2', 'invalid'],
        ['สาขาใหม่ยังไม่มีรหัส', null, 'missing'],
      ],
    );
    assert.ok(refused.body.error.details.every((d) => d.message));
    assert.equal(stub.state.requests.length, 0);

    // แอปภาษาอังกฤษได้เหตุผลเป็นภาษาอังกฤษ (DECISIONS #64)
    const english = await connect(admin.token).set('Accept-Language', 'en');
    assert.match(english.body.error.message, /Fix the branch codes/);
    assert.match(english.body.error.details[1].message, /no code/);

    await patch(`/api/v1/branches/${thonglor.id}`, admin.token, { code: 'THONGLOR' });
    await patch(`/api/v1/branches/${noCode.body.data.id}`, admin.token, { isActive: false });
  });

  await t.test(
    'ที่อยู่หรือ credential ผิดรูปแบบถูกปฏิเสธก่อนเรียก ERP และคำตอบไม่มี credential',
    async () => {
      const badUrl = await connect(admin.token, { erpUrl: 'ftp://erp.example' });
      assert.equal(badUrl.status, 422);
      const withUser = await connect(admin.token, { erpUrl: 'https://me:pw@erp.example' });
      assert.equal(withUser.status, 422);
      const badCredential = await connect(admin.token, { credential: 'secret-without-prefix' });
      assert.equal(badCredential.status, 422);
      assert.ok(!JSON.stringify(badCredential.body).includes('secret-without-prefix'));
      assert.equal(stub.state.requests.length, 0);
    },
  );

  await t.test(
    'ERP ไม่รู้จัก credential หรือใช้สัญญา major อื่น = ไม่เข้าโหมดเชื่อมต่อ พร้อมเหตุผล',
    async () => {
      const logFrom = logs.length;
      const unknown = await connect(admin.token, { credential: `pnepos_${'Z'.repeat(43)}` });
      assert.equal(unknown.status, 422);
      assert.equal(unknown.body.error.code, 'ERP_CREDENTIAL_REJECTED');

      stub.state.instance = instanceBody({ contractVersion: '2.0.0' });
      const major = await connect(admin.token);
      assert.equal(major.status, 422);
      assert.equal(major.body.error.code, 'ERP_CONTRACT_UNSUPPORTED');
      assert.match(major.body.error.message, /2\.0\.0/);
      stub.state.instance = instanceBody();

      const unreachable = await connect(admin.token, { erpUrl: 'http://127.0.0.1:9' });
      assert.equal(unreachable.status, 502);
      assert.equal(unreachable.body.error.code, 'ERP_UNREACHABLE');

      assert.equal((await get('/api/v1/erp/mode', admin.token)).body.data.mode, 'standalone');
      // ยังไม่รู้ว่าเป็น instance ไหน จึงไม่มี pos_instance (สัญญาห้ามเดา) แต่บอก reason ที่ ERP ส่งมา
      const failed = erpLines(logFrom);
      assert.equal(failed.length, 3);
      assert.ok(failed.every((line) => line.labels.pos_instance === undefined));
      assert.equal(failed[0].labels.reason, 'credential_unknown');
      assert.equal(failed[0].severity, 'WARNING');
    },
  );

  await t.test(
    'เชื่อมต่อสำเร็จ: ดึงรอบแรกทันที วัตถุดิบ/สาขาจาก ERP ถูก mirror และ credential ไม่ถูกส่งกลับ',
    async () => {
      stub.state.changes = [
        itemChange(1, 'WHOLE-CHICKEN', { nameTh: 'ไก่ทั้งตัว', nameEn: 'Whole chicken' }),
        itemChange(2, 'SEABASS', {
          nameTh: 'ปลากะพงขาว',
          nameEn: 'Sea bass',
          baseUnitCode: 'piece',
        }),
        locationChange(3, 'SUKHUMVIT', { nameTh: 'สาขาสุขุมวิท 24' }),
        locationChange(4, 'SILOM', { nameTh: 'สาขาสีลม' }),
      ];
      const requestsBefore = stub.state.requests.length;
      const res = await connect(admin.token);
      assert.equal(res.status, 200);
      const status = res.body.data;
      assert.ok(!JSON.stringify(res.body).includes(CREDENTIAL), 'credential ไม่อยู่ในคำตอบ');
      assert.equal(status.mode, 'connected');
      assert.equal(status.connection.instanceCode, 'POS-SUKHUMVIT-1');
      assert.equal(status.connection.contractVersion, '1.0.0');
      assert.equal(status.connection.credentialSaved, true);
      assert.equal(status.connection.appliedVersion, 4);
      assert.equal(status.connection.lastError, null);
      // ERP ให้ดูแลแค่สุขุมวิท: ทองหล่อบอกชัดว่าไม่อยู่ในรายการ
      assert.deepEqual(
        status.branches.filter((b) => b.isActive).map((b) => [b.code, b.servedByErp]),
        [
          ['SUKHUMVIT', true],
          ['THONGLOR', false],
        ],
      );
      assert.equal(status.servedBranches[0].localBranchId, status.branches[0].id);

      const sent = stub.state.requests.slice(requestsBefore);
      assert.ok(sent.every((r) => r.authorization === `Bearer ${CREDENTIAL}`));
      assert.ok(
        sent.every((r) => /^[\w-]{8,64}$/.test(r.requestId)),
        'ทุกคำขอมี x-request-id',
      );
      assert.deepEqual(stub.requestsTo('/api/v1/master-data/changes', requestsBefore)[0].query, {
        since: '0',
        limit: '500',
      });

      // รายการสินค้า → วัตถุดิบในทุกสาขา จับคู่ด้วยรหัสสินค้า: SEABASS เขียนทับวัตถุดิบเดิม (id เดิม สูตรเมนูไม่หลุด)
      const seabass = await get(`/api/v1/ingredients/${fish.id}`, admin.token);
      assert.equal(seabass.body.data.name, 'ปลากะพงขาว');
      assert.equal(seabass.body.data.unit, 'piece');
      assert.deepEqual(seabass.body.data.erpItem, { nameEn: 'Sea bass', active: true });
      const branches = count('SELECT COUNT(*) AS c FROM branches');
      assert.equal(
        count("SELECT COUNT(*) AS c FROM ingredients WHERE item_code = 'WHOLE-CHICKEN'"),
        branches,
      );
      // สาขาจับคู่ด้วยรหัสสถานที่: ชื่อตาม ERP; สาขาที่ยังไม่มีในเครื่อง (SILOM) ไม่ถูกสร้างเอง
      const sukhumvit = getDb().prepare("SELECT * FROM branches WHERE code = 'SUKHUMVIT'").get();
      assert.equal(sukhumvit.name, 'สาขาสุขุมวิท 24');
      assert.equal(count("SELECT COUNT(*) AS c FROM branches WHERE code = 'SILOM'"), 0);
    },
  );

  await t.test(
    'credential ไม่อยู่ใน log, audit log, CSV ที่ export หรือการตั้งค่าร้าน',
    async () => {
      const everything = JSON.stringify(logs);
      assert.ok(!everything.includes(CREDENTIAL));
      const audit = await get('/api/v1/audit-logs?action=erp.connect', admin.token);
      const entry = audit.body.data.find((row) => row.action === 'erp.connect');
      assert.ok(entry, 'การเชื่อมต่อถูกบันทึกใน audit log');
      assert.ok(!JSON.stringify(audit.body).includes(CREDENTIAL));
      const csv = await get('/api/v1/audit-logs/export', admin.token);
      assert.equal(csv.status, 200);
      assert.ok(!csv.text.includes(CREDENTIAL));
      const settings = await get('/api/v1/settings', admin.token);
      assert.ok(!JSON.stringify(settings.body).includes(CREDENTIAL));
      const status = await get('/api/v1/erp/connection', admin.token);
      assert.ok(!JSON.stringify(status.body).includes(CREDENTIAL));
    },
  );

  await t.test('โหมดเชื่อมต่อ: แก้วัตถุดิบ/สาขาไม่ได้ (409) แต่ยังอ่านได้', async () => {
    const attempts = [
      post('/api/v1/ingredients', admin.token, { name: 'ของใหม่', unit: 'kg' }),
      patch(`/api/v1/ingredients/${fish.id}`, admin.token, { name: 'แก้ชื่อ' }),
      post(`/api/v1/ingredients/${fish.id}/adjust-stock`, manager.token, { delta: 5 }),
      del(`/api/v1/ingredients/${fish.id}`, admin.token),
      post('/api/v1/branches', admin.token, { name: 'สาขาเพิ่ม', code: 'NEW-BR' }),
      patch(`/api/v1/branches/${fish.branchId}`, admin.token, { name: 'แก้ชื่อสาขา' }),
    ];
    for (const res of await Promise.all(attempts)) {
      assert.equal(res.status, 409);
      assert.equal(res.body.error.code, 'MANAGED_BY_ERP');
    }
    const english = await patch(`/api/v1/ingredients/${fish.id}`, admin.token, {
      name: 'x',
    }).set('Accept-Language', 'en');
    assert.match(english.body.error.message, /managed in PaynEat ERP/);
    assert.equal((await get('/api/v1/ingredients', manager.token)).status, 200);
    assert.equal((await get('/api/v1/erp/mode', manager.token)).body.data.mode, 'connected');
  });

  await t.test(
    'สต๊อกช่วงคั่น: เมนูที่ระบบสต๊อกปิดไว้เปิดคืน และของหมดในเครื่องไม่บล็อกการขาย',
    async () => {
      const reopened = await get(`/api/v1/menu-items/${fishMenu.id}`, admin.token);
      assert.equal(reopened.body.data.isAvailable, true);

      const order = await post('/api/v1/orders', admin.token, {
        type: 'dine_in',
        tableId: table.id,
        guestCount: 2,
        items: [{ menuItemId: fishMenu.id, quantity: 3 }],
      });
      assert.equal(order.status, 201, 'ยอดในเครื่องเป็น 0 แต่ต้องขายได้');
      const sent = await post(`/api/v1/orders/${order.body.data.id}/send-to-kitchen`, admin.token);
      assert.equal(sent.status, 200);
      const still = await get(`/api/v1/menu-items/${fishMenu.id}`, admin.token);
      assert.equal(still.body.data.isAvailable, true, 'ไม่ปิดขายอัตโนมัติจากยอดในเครื่อง');

      // ปิดขายด้วยมือยังใช้ได้
      const manual = await patch(`/api/v1/menu-items/${fishMenu.id}`, admin.token, {
        isAvailable: false,
      });
      assert.equal(manual.body.data.isAvailable, false);
      await patch(`/api/v1/menu-items/${fishMenu.id}`, admin.token, { isAvailable: true });
    },
  );

  await t.test(
    'ดึงตามเวอร์ชันทีละหน้า: ถามต่อจากเวอร์ชันล่าสุด ดึงซ้ำไม่ได้ข้อมูลซ้ำ',
    async () => {
      stub.state.pageLimit = 2;
      stub.state.changes.push(
        itemChange(5, 'RICE', { baseUnitCode: 'bag' }),
        itemChange(6, 'OIL', { baseUnitCode: 'l', extra: { fieldFromContract11: 'ignored' } }),
        { ...itemChange(7, 'MENU-X'), entityType: 'menuItem' },
        itemChange(8, 'WHOLE-CHICKEN', { nameTh: 'ไก่ทั้งตัว (ชำแหละ)', action: 'updated' }),
        itemChange(9, 'SALT', { baseUnitCode: 'tin' }),
      );
      const from = stub.state.requests.length;
      const res = await post('/api/v1/erp/pull', admin.token);
      assert.equal(res.status, 200);
      assert.deepEqual(res.body.data.result, { applied: 4, skipped: 1, appliedVersion: 9 });
      assert.deepEqual(
        stub.requestsTo('/api/v1/master-data/changes', from).map((r) => r.query.since),
        ['4', '6', '8'],
      );

      // data คือทั้งระเบียน: เขียนทับ ไม่ merge; entityType ที่ไม่รู้จักถูกข้ามแต่เวอร์ชันยังนับ
      assert.equal(
        getDb()
          .prepare("SELECT DISTINCT name FROM ingredients WHERE item_code = 'WHOLE-CHICKEN'")
          .all()
          .map((r) => r.name)
          .join(),
        'ไก่ทั้งตัว (ชำแหละ)',
      );
      assert.equal(count("SELECT COUNT(*) AS c FROM erp_items WHERE item_code = 'MENU-X'"), 0);

      const ingredients = count('SELECT COUNT(*) AS c FROM ingredients');
      const again = await post('/api/v1/erp/pull', admin.token);
      assert.deepEqual(again.body.data.result, { applied: 0, skipped: 0, appliedVersion: 9 });
      assert.equal(count('SELECT COUNT(*) AS c FROM ingredients'), ingredients, 'ไม่มีวัตถุดิบซ้ำ');
    },
  );

  await t.test(
    'เน็ตหลุดกลางทาง: หน้าที่นำไปใช้แล้วอยู่ครบ รอบถัดไปต่อจากตรงนั้นโดยไม่พลาด',
    async () => {
      stub.state.changes.push(
        itemChange(10, 'SUGAR'),
        itemChange(11, 'FLOUR'),
        itemChange(12, 'EGG', { baseUnitCode: 'tray' }),
        itemChange(13, 'MILK', { baseUnitCode: 'l' }),
      );
      // หน้าแรก (10–11) ผ่าน หน้าที่สองได้ 503
      stub.state.failures.push(
        { path: '/api/v1/pos/instance', status: 200, body: stub.state.instance },
        {
          path: '/api/v1/master-data/changes',
          status: 200,
          body: {
            latestVersion: 13,
            changes: stub.state.changes.slice(9, 11),
            hasMore: true,
          },
        },
        {
          path: '/api/v1/master-data/changes',
          status: 503,
          body: '',
          headers: { 'Retry-After': '1' },
        },
      );
      const logFrom = logs.length;
      const failed = await post('/api/v1/erp/pull', admin.token);
      assert.equal(failed.status, 502);
      assert.equal(failed.body.error.code, 'ERP_UNAVAILABLE');

      const status = (await get('/api/v1/erp/connection', admin.token)).body.data.connection;
      assert.equal(status.appliedVersion, 11);
      assert.equal(status.lastError.kind, 'unavailable');
      assert.equal(status.lastError.status, 503);
      assert.ok(status.retryAfter);
      assert.equal(
        count("SELECT COUNT(*) AS c FROM erp_items WHERE item_code IN ('SUGAR', 'FLOUR')"),
        2,
      );

      const line = erpLines(logFrom).find((l) => l.severity === 'WARNING');
      assert.equal(
        line.labels.pos_instance,
        'POS-SUKHUMVIT-1',
        'บรรทัดที่ล้มเหลวก็มี pos_instance',
      );
      assert.equal(line.error.type, 'unavailable');

      // ตามรอบเวลา: ยังไม่ถึงเวลาที่ ERP ขอให้รอ ไม่เรียก ERP เลย
      const quietFrom = stub.state.requests.length;
      assert.equal(await erpService.pull(), undefined);
      assert.equal(stub.state.requests.length, quietFrom);

      // กดดึงเอง: ต่อจาก 11 พอดี ได้ 12–13 ครบ
      const from = stub.state.requests.length;
      const resumed = await post('/api/v1/erp/pull', admin.token);
      assert.equal(resumed.status, 200);
      assert.deepEqual(resumed.body.data.result, { applied: 2, skipped: 0, appliedVersion: 13 });
      assert.equal(stub.requestsTo('/api/v1/master-data/changes', from)[0].query.since, '11');
      assert.equal(resumed.body.data.status.connection.lastError, null);
    },
  );

  await t.test(
    'ERP แทนสาขาด้วยรหัสใหม่: สาขาเดิมย้ายไปรหัสใหม่ ประวัติการขายตามไปด้วย',
    async () => {
      const before = getDb().prepare("SELECT * FROM branches WHERE code = 'SUKHUMVIT'").get();
      const orders = count('SELECT COUNT(*) AS c FROM orders WHERE branch_id = ?', before.id);
      assert.ok(orders > 0);
      stub.state.changes.push(
        locationChange(14, 'SUKHUMVIT-24', { action: 'created', nameTh: 'สาขาสุขุมวิท ซอย 24' }),
        locationChange(15, 'SUKHUMVIT', {
          active: false,
          supersededBy: {
            id: '00000000-0000-4000-8000-000000009999',
            locationCode: 'SUKHUMVIT-24',
          },
        }),
      );
      await post('/api/v1/erp/pull', admin.token);
      const moved = getDb().prepare('SELECT * FROM branches WHERE id = ?').get(before.id);
      assert.equal(moved.code, 'SUKHUMVIT-24');
      assert.equal(moved.name, 'สาขาสุขุมวิท ซอย 24');
      assert.equal(moved.is_active, 1, 'สาขาที่ย้ายรหัสยังเปิดอยู่ ไม่ใช่ปิดตามรหัสเดิม');
      assert.equal(
        count('SELECT COUNT(*) AS c FROM orders WHERE branch_id = ?', before.id),
        orders,
      );
    },
  );

  await t.test(
    'credential ถูกเพิกถอน: หยุดเรียก ERP จนกว่าจะบันทึก credential ใหม่ แล้วดึงต่อจากเดิม',
    async () => {
      stub.state.revoked = true;
      const logFrom = logs.length;
      const rejected = await post('/api/v1/erp/pull', admin.token);
      assert.equal(rejected.status, 422);
      assert.equal(rejected.body.error.code, 'ERP_CREDENTIAL_REJECTED');
      const line = erpLines(logFrom).find((l) => l.severity === 'WARNING');
      assert.equal(line.labels.pos_instance, 'POS-SUKHUMVIT-1');
      assert.equal(line.labels.reason, 'credential_revoked');

      const quietFrom = stub.state.requests.length;
      assert.equal(await erpService.pull(), undefined, 'ตามรอบเวลา: ไม่เรียก ERP');
      const manual = await post('/api/v1/erp/pull', admin.token);
      assert.equal(manual.status, 409);
      assert.equal(stub.state.requests.length, quietFrom, 'ไม่มีคำขอไปถึง ERP เลย');
      const status = (await get('/api/v1/erp/connection', admin.token)).body.data.connection;
      assert.equal(status.credentialRejected, true);

      // ผู้ดูแล ERP ออก credential ใหม่ → บันทึก → ดึงต่อจากเวอร์ชันเดิม ไม่เริ่มใหม่จาก 0
      const fresh = `pnepos_${'N'.repeat(43)}`;
      stub.state.credential = fresh;
      stub.state.revoked = false;
      const from = stub.state.requests.length;
      const saved = await connect(admin.token, { credential: fresh });
      assert.equal(saved.status, 200);
      assert.equal(saved.body.data.connection.credentialRejected, false);
      assert.equal(stub.requestsTo('/api/v1/master-data/changes', from)[0].query.since, '15');
    },
  );

  await t.test(
    'ทุกบรรทัด log เรื่องการดึงหลังเชื่อมต่อมี pos_instance และไม่มี credential',
    async () => {
      const pulled = logs.filter((line) => /master data/.test(line.message));
      assert.ok(pulled.length >= 5);
      assert.ok(pulled.every((line) => line.labels.pos_instance === 'POS-SUKHUMVIT-1'));
      assert.ok(pulled.some((line) => /now at version 13/.test(line.message)));
      assert.ok(pulled.every((line) => line.labels.event === 'app.log'));
      const everything = JSON.stringify(logs);
      assert.ok(!everything.includes(CREDENTIAL) && !everything.includes('N'.repeat(43)));
    },
  );

  await t.test(
    'ออกจากโหมดเชื่อมต่อ: credential ถูกลบ ข้อมูลที่ mirror ไว้ยังอยู่และกลับมาแก้ได้',
    async () => {
      const res = await del('/api/v1/erp/connection', admin.token);
      assert.equal(res.status, 200);
      assert.equal(res.body.data.mode, 'standalone');
      assert.equal(count('SELECT COUNT(*) AS c FROM erp_connection'), 0);
      assert.ok(count('SELECT COUNT(*) AS c FROM erp_items') > 0);

      const seabass = await get(`/api/v1/ingredients/${fish.id}`, admin.token);
      assert.equal(seabass.body.data.itemCode, 'SEABASS');
      const edit = await patch(`/api/v1/ingredients/${fish.id}`, admin.token, { name: 'ปลากะพง' });
      assert.equal(edit.status, 200);
      const branchEdit = await patch(`/api/v1/branches/${fish.branchId}`, admin.token, {
        address: '24 ถนนสุขุมวิท',
      });
      assert.equal(branchEdit.status, 200);

      const audit = await get('/api/v1/audit-logs?action=erp.disconnect', admin.token);
      assert.ok(audit.body.data.some((row) => row.action === 'erp.disconnect'));
      const from = stub.state.requests.length;
      assert.equal(await erpService.pull(), undefined);
      assert.equal(stub.state.requests.length, from, 'ใช้งานเดี่ยวไม่เรียก ERP');
    },
  );
});
