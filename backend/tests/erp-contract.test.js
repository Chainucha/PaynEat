// Copyright 2026 Suruch Chakrapeesirisuk
// SPDX-License-Identifier: Apache-2.0

import test, { after, describe } from 'node:test';
import assert from 'node:assert/strict';
import { createHash } from 'node:crypto';
import fs from 'node:fs';
import http from 'node:http';
import path from 'node:path';
import YAML from 'yaml';

// สัญญาเชื่อมต่อ PaynEat ERP ↔ POS ที่ POS ปักไว้ที่ 1.0.0 (backend/contracts/erp-pos, ticket 25, DECISIONS #80)
// ERP ทดสอบฝั่งตัวเองกับไฟล์ชุดเดียวกัน — ถ้าสองฝั่งอ่านสัญญาไม่ตรงกัน เทสต์ของฝั่งใดฝั่งหนึ่งจะแดง

process.env.NODE_ENV = 'test';
process.env.JWT_SECRET = 'test-secret';

const { CONTRACT_DIR, contractErrors } = await import('../src/modules/erp/erp.contract.js');
const {
  erpClient,
  ErpCallError,
  failureSeverity,
  integrationReason,
  parseRetryAfter,
  stopsUntilActedOn,
} = await import('../src/modules/erp/erp.client.js');

const PINNED = '1.0.0';
const CREDENTIAL = `pnepos_${'C'.repeat(43)}`;
const root = path.dirname(CONTRACT_DIR);
const read = (name) => JSON.parse(fs.readFileSync(path.join(CONTRACT_DIR, name), 'utf8'));

/** ERP ปลอมที่ตอบด้วยคำตอบที่เทสต์กำหนดทีละคำขอ */
let reply = () => ({ status: 200, body: {} });
const server = http.createServer((req, res) => {
  const { status, body, headers } = reply(req);
  res.writeHead(status, { 'Content-Type': 'application/json', ...headers });
  res.end(typeof body === 'string' ? body : JSON.stringify(body));
});
await new Promise((resolve) => server.listen(0, '127.0.0.1', resolve));
const connection = { baseUrl: `http://127.0.0.1:${server.address().port}`, credential: CREDENTIAL };
after(() => new Promise((resolve) => server.close(resolve)));

const failure = async (call) => {
  try {
    await call();
  } catch (error) {
    assert.ok(error instanceof ErpCallError, `ต้องเป็น ErpCallError แต่ได้ ${error}`);
    return error;
  }
  throw new Error('ต้อง throw');
};

describe('the pinned contract files', () => {
  test(`are version ${PINNED}, byte for byte as copied from PaynEat ERP`, () => {
    const openapi = YAML.parse(fs.readFileSync(path.join(CONTRACT_DIR, 'openapi.yaml'), 'utf8'));
    assert.equal(openapi.info.version, PINNED);
    const changelog = fs.readFileSync(path.join(root, 'CHANGELOG.md'), 'utf8');
    assert.match(changelog, new RegExp(`^## ${PINNED.replace(/\./g, '\\.')} `, 'm'));

    const manifest = JSON.parse(fs.readFileSync(path.join(root, 'checksums.json'), 'utf8'));
    for (const [file, checksum] of Object.entries(manifest)) {
      // ปรับท้ายบรรทัดเป็น \n ก่อน: checkout บน Windows (CRLF) ต้องได้ค่าเดียวกัน
      const text = fs.readFileSync(path.join(root, file), 'utf8').replace(/\r\n/g, '\n');
      assert.equal(
        createHash('sha256').update(text).digest('hex'),
        checksum,
        `${file} ต่างจากสัญญาที่คัดลอกมา — แก้ที่ PaynEat ERP แล้วคัดลอกมาใหม่ทั้งชุด`,
      );
    }
    assert.ok(Object.keys(manifest).length >= 5);
  });

  test('every example the POS reads passes its schema', () => {
    assert.deepEqual(contractErrors('posInstance', read('examples/pos-instance.json')), []);
    assert.deepEqual(
      contractErrors('masterDataChanges', read('examples/master-data-changes.json')),
      [],
    );
    for (const name of ['error.credential-revoked.json', 'error.schema-invalid.json']) {
      assert.deepEqual(contractErrors('error', read(`examples/${name}`)), [], name);
    }
  });
});

describe('the POS client against answers shaped by the contract', () => {
  test('reads the instance and a master-data page exactly as the examples give them', async () => {
    const seen = [];
    reply = (req) => {
      seen.push(req);
      return req.url.startsWith('/api/v1/pos/instance')
        ? { status: 200, body: read('examples/pos-instance.json') }
        : { status: 200, body: read('examples/master-data-changes.json') };
    };
    const instance = await erpClient.getInstance(connection);
    assert.deepEqual(instance.body, read('examples/pos-instance.json'));
    const page = await erpClient.getChanges(connection, 3, 500);
    assert.deepEqual(page.body, read('examples/master-data-changes.json'));

    assert.equal(seen[1].url, '/api/v1/master-data/changes?since=3&limit=500');
    for (const req of seen) {
      assert.equal(req.headers.authorization, `Bearer ${CREDENTIAL}`);
      assert.match(req.headers['x-request-id'], /^[\w-]{8,64}$/);
    }
  });

  test('ignores fields and entity types it does not know (1.x only adds them)', async () => {
    const page = read('examples/master-data-changes.json');
    page.newTopLevel = true;
    page.changes[0].data.fromMinor11 = 'x';
    page.changes.push({ ...page.changes[0], version: 13, entityType: 'menuItem', data: {} });
    reply = () => ({ status: 200, body: page });
    const result = await erpClient.getChanges(connection, 0, 500);
    assert.equal(result.body.changes.length, 3);
  });

  test('refuses an instance from another contract major before looking at its shape', async () => {
    reply = () => ({ status: 200, body: { contractVersion: '2.0.0', somethingElse: true } });
    const error = await failure(() => erpClient.getInstance(connection));
    assert.equal(error.kind, 'unsupported_contract');
    assert.equal(error.contractVersion, '2.0.0');
  });

  test('refuses an answer that breaks the contract, saying where but not what', async () => {
    const instance = read('examples/pos-instance.json');
    delete instance.branches;
    instance.code = 'lower case';
    reply = () => ({ status: 200, body: instance });
    const error = await failure(() => erpClient.getInstance(connection));
    assert.equal(error.kind, 'invalid_response');
    assert.deepEqual(error.problems.map((p) => p.path).sort(), ['/', '/code']);
    assert.ok(!JSON.stringify(error.problems).includes('lower case'));

    reply = () => ({ status: 200, body: '<html>proxy login</html>' });
    assert.equal(
      (await failure(() => erpClient.getChanges(connection, 0, 1))).kind,
      'invalid_response',
    );
  });

  test('turns each status into what the contract says the POS does', async () => {
    reply = () => ({ status: 401, body: read('examples/error.credential-revoked.json') });
    const revoked = await failure(() => erpClient.getInstance(connection));
    assert.deepEqual([revoked.kind, revoked.reason], ['credential_rejected', 'credential_revoked']);

    reply = () => ({ status: 429, body: '', headers: { 'Retry-After': '30' } });
    const limited = await failure(() => erpClient.getChanges(connection, 0, 1));
    assert.deepEqual([limited.kind, limited.retryAfterSeconds], ['rate_limited', 30]);

    reply = () => ({ status: 503, body: '', headers: { 'Retry-After': '5' } });
    const busy = await failure(() => erpClient.getChanges(connection, 0, 1));
    assert.deepEqual([busy.kind, busy.retryAfterSeconds], ['unavailable', 5]);

    reply = () => ({ status: 500, body: '' });
    assert.equal((await failure(() => erpClient.getChanges(connection, 0, 1))).kind, 'unavailable');

    reply = () => ({ status: 404, body: { message: 'Not found' } });
    const wrongAddress = await failure(() => erpClient.getInstance(connection));
    assert.deepEqual([wrongAddress.kind, wrongAddress.status], ['refused', 404]);

    // redirect ไม่ถูกตาม: credential ไปถึงที่อยู่ที่ผู้ดูแลตั้งเท่านั้น
    reply = () => ({ status: 302, body: '', headers: { Location: 'http://example.invalid/' } });
    const redirected = await failure(() => erpClient.getInstance(connection));
    assert.deepEqual([redirected.kind, redirected.status], ['refused', 302]);

    const unreachable = await failure(() =>
      erpClient.getInstance({ baseUrl: 'http://127.0.0.1:9', credential: CREDENTIAL }),
    );
    assert.equal(unreachable.kind, 'network');
    assert.ok(!unreachable.message.includes(CREDENTIAL));
  });

  test('reads Retry-After as seconds or as an HTTP date', () => {
    assert.equal(parseRetryAfter('120'), 120);
    const now = Date.parse('2026-09-27T05:00:00Z');
    assert.equal(parseRetryAfter('Sun, 27 Sep 2026 05:01:00 GMT', now), 60);
    assert.equal(parseRetryAfter(undefined), undefined);
    assert.equal(parseRetryAfter('soon'), undefined);
  });
});

// reason และ severity ของ master_data.pull.failed ตามสัญญา telemetry v1.2 ("Additions to v1.2", PaynEat-ERP#57)
// ใช้ฟังก์ชันเดียวกับ outbox.delivery.failed ของ ticket 26 — ทุกกรณีสร้างจากคำตอบจริงของ ERP ปลอม ไม่ประกอบ error เอง
describe('reason and severity of a failed call, as telemetry v1.2 names them', () => {
  const revoked = read('examples/error.credential-revoked.json');
  const cases = [
    {
      name: '401 credential_revoked',
      answer: { status: 401, body: revoked },
      reason: 'credential_revoked',
      severity: 'ERROR',
    },
    {
      name: '401 credential_unknown',
      answer: { status: 401, body: { ...revoked, details: { reason: 'credential_unknown' } } },
      reason: 'credential_unknown',
      severity: 'ERROR',
    },
    {
      // 401 ที่ไม่บอกเหตุผล (proxy ตอบแทน) — ก็ยังหยุด เพราะ credential ใช้ไม่ได้
      name: '401 without a reason',
      answer: { status: 401, body: '' },
      reason: 'unexpected_response',
      severity: 'ERROR',
    },
    {
      name: '500',
      answer: { status: 500, body: '' },
      reason: 'erp_unreachable',
      severity: 'WARNING',
    },
    {
      name: '503 without Retry-After',
      answer: { status: 503, body: '' },
      reason: 'erp_unreachable',
      severity: 'WARNING',
    },
    {
      name: '503 with Retry-After',
      answer: { status: 503, body: '', headers: { 'Retry-After': '5' } },
      reason: 'rate_limited',
      severity: 'WARNING',
    },
    {
      name: '429',
      answer: { status: 429, body: '', headers: { 'Retry-After': '30' } },
      reason: 'rate_limited',
      severity: 'WARNING',
    },
    {
      name: '429 without Retry-After',
      answer: { status: 429, body: '' },
      reason: 'rate_limited',
      severity: 'WARNING',
    },
    {
      name: '404 (address points elsewhere)',
      answer: { status: 404, body: { message: 'Not found' } },
      reason: 'unexpected_response',
      severity: 'ERROR',
    },
    {
      name: '302 (not followed)',
      answer: { status: 302, body: '', headers: { Location: 'http://example.invalid/' } },
      reason: 'unexpected_response',
      severity: 'ERROR',
    },
    {
      name: '200 that breaks the schema',
      answer: { status: 200, body: { contractVersion: '1.0.0' } },
      reason: 'unexpected_response',
      severity: 'ERROR',
    },
    {
      name: '200 that is not JSON',
      answer: { status: 200, body: '<html>proxy login</html>' },
      reason: 'unexpected_response',
      severity: 'ERROR',
    },
    {
      name: 'another contract major',
      answer: { status: 200, body: { contractVersion: '2.0.0' } },
      reason: 'contract_unsupported',
      severity: 'ERROR',
    },
    {
      // details.reason ที่ ERP ส่งมาเองใช้ตามนั้น ไม่แปลงเป็นค่าอื่น (สถานะอื่นที่ไม่ใช่ 401 = ไม่หยุดเอง)
      name: "403 with the ERP's own reason",
      answer: {
        status: 403,
        body: {
          statusCode: 403,
          code: 'X',
          message: 'x',
          details: { reason: 'branch_not_served' },
        },
      },
      reason: 'branch_not_served',
      severity: 'WARNING',
    },
  ];

  for (const { name, answer, reason, severity } of cases) {
    test(`${name} → ${reason}, ${severity}`, async () => {
      reply = () => answer;
      const error = await failure(() => erpClient.getInstance(connection));
      assert.equal(integrationReason(error), reason);
      assert.equal(failureSeverity(error), severity);
      assert.equal(stopsUntilActedOn(error), severity === 'ERROR');
    });
  }

  test('network failure → erp_unreachable, WARNING', async () => {
    const error = await failure(() =>
      erpClient.getInstance({ baseUrl: 'http://127.0.0.1:9', credential: CREDENTIAL }),
    );
    assert.equal(integrationReason(error), 'erp_unreachable');
    assert.equal(failureSeverity(error), 'WARNING');
  });

  test('a bug in the POS itself has no reason (never guessed) and is an ERROR', () => {
    const bug = new TypeError('x is undefined');
    assert.equal(integrationReason(bug), undefined);
    assert.equal(failureSeverity(bug), 'ERROR');
  });
});
