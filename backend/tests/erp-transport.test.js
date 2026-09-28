// Copyright 2026 Suruch Chakrapeesirisuk
// SPDX-License-Identifier: Apache-2.0

import test, { after, before, describe } from 'node:test';
import assert from 'node:assert/strict';
import { execFile, spawnSync } from 'node:child_process';
import fs from 'node:fs';
import https from 'node:https';
import os from 'node:os';
import path from 'node:path';
import { promisify } from 'node:util';
import { fileURLToPath } from 'node:url';
import { api, login, authHeader, cleanup } from './helpers/testApp.js';
import { CREDENTIAL, instanceBody, startErpStub } from './helpers/erpStub.js';

// credential ของเครื่องไปหา PaynEat ERP ทาง HTTPS เท่านั้น (ticket 32, docs/DECISIONS.md #82, สัญญา POS v1 หัวข้อ
// "Transport") — ยกเว้น loopback และ http ในเครือข่ายปิดที่ผู้ดูแลเซิร์ฟเวอร์อนุญาตเองด้วย ERP_ALLOW_INSECURE_HTTP

const { env } = await import('../src/config/env.js');
const { setLogSink } = await import('../src/core/telemetry/logger.js');
const { erpTransport } = await import('../src/modules/erp/erp.transport.js');
const { erpClient, ErpCallError, failureSeverity, integrationReason } =
  await import('../src/modules/erp/erp.client.js');
const { erpService, checkErpTransportOnStartup } =
  await import('../src/modules/erp/erp.service.js');
const { erpRepository } = await import('../src/modules/erp/erp.repository.js');

const backendDir = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..');
const stub = await startErpStub();
const logs = [];
const previousSink = setLogSink((line) => logs.push(JSON.parse(line)));

/**
 * ทุกคำขอที่ POS ส่งออกไปผ่าน fetch — ใช้ยืนยันว่า "ไม่มีคำขอไป ERP เลย" คำขอไป host `erp` (ชื่อใน Docker network
 * ของเดโม) ถูกส่งต่อให้ ERP ปลอมบนเครื่องนี้ตอบแทน
 */
const realFetch = globalThis.fetch;
const outgoing = [];
globalThis.fetch = (input, init) => {
  const url = new URL(input);
  outgoing.push({ url: url.href, authorization: init?.headers?.Authorization });
  if (url.hostname === 'erp') url.host = new URL(stub.url).host;
  return realFetch(url, init);
};

after(async () => {
  globalThis.fetch = realFetch;
  setLogSink(previousSink);
  await stub.close();
  cleanup();
});

const admin = await login('admin', 'admin123');
const put = (body) =>
  api()
    .put('/api/v1/erp/connection')
    .set(authHeader(admin.token))
    .send({ credential: CREDENTIAL, ...body });
const status = async () =>
  (await api().get('/api/v1/erp/connection').set(authHeader(admin.token))).body.data;
const disconnect = () => api().delete('/api/v1/erp/connection').set(authHeader(admin.token));
const pullFailures = (from) =>
  logs.slice(from).filter((line) => line.labels.event === 'master_data.pull.failed');

const failure = async (call) => {
  try {
    await call();
  } catch (error) {
    assert.ok(error instanceof ErpCallError, `ต้องเป็น ErpCallError แต่ได้ ${error}`);
    return error;
  }
  throw new Error('ต้อง throw');
};

describe('ที่อยู่ไหนส่ง credential ได้', () => {
  // [ที่อยู่, ค่าเริ่มต้น, เมื่อตั้ง ERP_ALLOW_INSECURE_HTTP=true]
  const cases = [
    ['https://erp.example.com', 'https', 'https'],
    ['https://erp.example.com/erp/', 'https', 'https'],
    ['http://localhost:3000', 'loopback', 'loopback'],
    ['http://127.0.0.1:3000', 'loopback', 'loopback'],
    ['http://127.10.20.30', 'loopback', 'loopback'],
    ['http://[::1]:3000', 'loopback', 'loopback'],
    ['http://erp.example.com', 'insecure_blocked', 'insecure_allowed'],
    ['http://erp:3000', 'insecure_blocked', 'insecure_allowed'],
    ['http://10.0.0.5:3000', 'insecure_blocked', 'insecure_allowed'],
    // ตัดสินจากตัวอักษรของ host เท่านั้น: ชื่อที่ขึ้นต้นเหมือน loopback หรือ resolve เป็น 127.0.0.1 ไม่นับ
    ['http://127.example.com', 'insecure_blocked', 'insecure_allowed'],
    ['http://127.0.0.1.nip.io', 'insecure_blocked', 'insecure_allowed'],
    ['http://localhost.example.com', 'insecure_blocked', 'insecure_allowed'],
    ['http://localtest.me', 'insecure_blocked', 'insecure_allowed'],
  ];

  for (const [url, strict, allowed] of cases) {
    test(`${url} → ${strict}${strict === allowed ? '' : ` (อนุญาต http: ${allowed})`}`, () => {
      assert.equal(erpTransport(url, { allowInsecureHttp: false }), strict);
      assert.equal(erpTransport(url, { allowInsecureHttp: true }), allowed);
    });
  }

  test('ERP_ALLOW_INSECURE_HTTP ต้องเป็น true ตรงตัวเท่านั้น — ค่าเริ่มต้นคือไม่อนุญาต', () => {
    const allowed = (value) => {
      const run = spawnSync(
        process.execPath,
        [
          '--input-type=module',
          '-e',
          "const { env } = await import('./src/config/env.js'); console.log(env.erp.allowInsecureHttp);",
        ],
        {
          cwd: backendDir,
          env: {
            PATH: process.env.PATH,
            JWT_SECRET: 'test-secret',
            ...(value === undefined ? {} : { ERP_ALLOW_INSECURE_HTTP: value }),
          },
          encoding: 'utf8',
        },
      );
      assert.equal(run.status, 0, run.stderr);
      return run.stdout.trim();
    };
    assert.equal(allowed(undefined), 'false');
    assert.equal(allowed('true'), 'true');
    for (const value of ['1', 'yes', 'TRUE', 'false']) assert.equal(allowed(value), 'false');
  });
});

describe('บันทึกที่อยู่ของ ERP', () => {
  test('http:// ที่ไม่ใช่ loopback → 400 พร้อมเหตุผลตามภาษา และไม่มีคำขอไป ERP', async () => {
    const before = outgoing.length;
    for (const erpUrl of ['http://erp.example.com', 'http://127.example.com']) {
      const res = await put({ erpUrl });
      assert.equal(res.status, 400);
      assert.equal(res.body.error.code, 'ERP_URL_NOT_HTTPS');
      assert.match(res.body.error.message, /https:\/\//);
    }
    const english = await put({ erpUrl: 'http://erp.example.com' }).set('Accept-Language', 'en');
    assert.match(english.body.error.message, /never sent unencrypted/);
    assert.equal(outgoing.length, before);
    assert.equal((await status()).mode, 'standalone');
  });

  test('http:// ไป loopback ใช้ได้โดยไม่ต้องตั้งค่าเพิ่ม (ERP ปลอมของเทสต์ทุกไฟล์)', async (t) => {
    t.after(disconnect);
    const res = await put({ erpUrl: stub.url });
    assert.equal(res.status, 200, JSON.stringify(res.body));
    assert.equal(res.body.data.connection.transport, 'loopback');
  });

  test('ERP_ALLOW_INSECURE_HTTP=true → รับ http://erp:3000 ได้ หน้าตั้งค่ารู้ว่าต้องเตือน และ log WARNING ตอนเปิดเครื่อง', async (t) => {
    env.erp.allowInsecureHttp = true;
    t.after(async () => {
      env.erp.allowInsecureHttp = false;
      await disconnect();
    });
    const before = outgoing.length;
    const res = await put({ erpUrl: 'http://erp:3000' });
    assert.equal(res.status, 200, JSON.stringify(res.body));
    assert.equal(res.body.data.connection.transport, 'insecure_allowed');
    assert.ok(
      outgoing.slice(before).some((call) => call.url === 'http://erp:3000/api/v1/pos/instance'),
    );

    const logFrom = logs.length;
    await checkErpTransportOnStartup();
    const lines = logs.slice(logFrom);
    assert.equal(lines.length, 1);
    assert.equal(lines[0].severity, 'WARNING');
    assert.match(lines[0].message, /ERP_ALLOW_INSECURE_HTTP=true/);
    assert.equal(lines[0].labels.pos_instance, 'POS-SUKHUMVIT-1');
    assert.ok(!JSON.stringify(lines).includes(CREDENTIAL));
  });

  test('ไม่ตั้ง ERP_ALLOW_INSECURE_HTTP และไม่มีการเชื่อมต่อ → ตอนเปิดเครื่องไม่มี log และไม่เรียก ERP', async () => {
    const logFrom = logs.length;
    const before = outgoing.length;
    await checkErpTransportOnStartup();
    assert.equal(logs.length, logFrom);
    assert.equal(outgoing.length, before);
  });
});

describe('การเชื่อมต่อที่บันทึกไว้ด้วย http:// ก่อนอัปเดต', () => {
  test('หยุดส่ง credential ทันที: ไม่มีคำขอไป ERP เลย หน้าตั้งค่าบอกให้เปลี่ยน และ log ERROR ตามสัญญา', async (t) => {
    t.after(disconnect);
    // สถานะในฐานข้อมูลของร้านที่เชื่อมต่อด้วย http:// ไว้ตั้งแต่ก่อน ticket นี้ (ticket 25 รับ http ได้)
    erpRepository.save({
      baseUrl: 'http://erp.lan:3000',
      credential: CREDENTIAL,
      instanceCode: 'POS-SUKHUMVIT-1',
      instanceName: 'Sukhumvit front counter',
      contractVersion: '1.0.0',
      appliedVersion: 7,
    });
    const before = outgoing.length;
    const logFrom = logs.length;

    // เปิดเซิร์ฟเวอร์หลังอัปเดต: ล้มก่อนส่งคำขอ บันทึกเหตุผล และหยุดดึงตามรอบ
    await checkErpTransportOnStartup();
    const failed = pullFailures(logFrom);
    assert.equal(failed.length, 1);
    assert.equal(failed[0].severity, 'ERROR');
    assert.equal(failed[0].labels.reason, 'unexpected_response');
    assert.equal(failed[0].labels.pos_instance, 'POS-SUKHUMVIT-1');

    const connection = (await status()).connection;
    assert.equal(connection.transport, 'insecure_blocked');
    assert.equal(connection.pullStopped, true);
    assert.equal(connection.lastError.kind, 'insecure_transport');
    assert.equal(connection.lastError.reason, 'unexpected_response');
    assert.equal(connection.appliedVersion, 7, 'ไม่ลบการเชื่อมต่อหรือเวอร์ชันที่ดึงไว้');

    // รอบเวลาข้ามไป ส่วนกดดึงเองได้เหตุผลว่าต้องเปลี่ยนเป็น https
    assert.equal(await erpService.pull(), undefined);
    const manual = await api().post('/api/v1/erp/pull').set(authHeader(admin.token));
    assert.equal(manual.status, 409);
    assert.equal(manual.body.error.code, 'ERP_URL_NOT_HTTPS');
    assert.equal(outgoing.length, before, 'ไม่มีคำขอไป ERP เลย');
    assert.ok(!JSON.stringify(logs.slice(logFrom)).includes(CREDENTIAL));

    // บันทึกที่อยู่ที่ส่งได้แล้วกลับมาดึงตามปกติ
    const fixed = await put({ erpUrl: stub.url });
    assert.equal(fixed.status, 200);
    assert.equal(fixed.body.data.connection.transport, 'loopback');
    assert.equal(fixed.body.data.connection.pullStopped, false);
    assert.equal(fixed.body.data.connection.lastError, null);
  });
});

// ------------------------------------------------------------------- HTTPS กับ CA สำหรับทดสอบ

const hasOpenssl = spawnSync('openssl', ['version']).status === 0;

describe('HTTPS ตรวจใบรับรองเสมอ', { skip: !hasOpenssl && 'ไม่มี openssl ในเครื่องนี้' }, () => {
  /**
   * CA ทดสอบที่สร้างใหม่ทุกครั้ง (ไม่เก็บ private key ไว้ใน repo) กับใบรับรองของ ERP สองใบที่ CA นี้ออกให้:
   * `erp` สำหรับ 127.0.0.1 และ `other` สำหรับชื่ออื่น (ชื่อไม่ตรงกับที่อยู่ที่เรียก)
   */
  let dir;
  const openssl = (...args) => {
    const run = spawnSync('openssl', args, { cwd: dir, encoding: 'utf8' });
    if (run.status !== 0) throw new Error(`openssl ${args[0]}: ${run.stderr}`);
  };
  const EC = ['-newkey', 'ec', '-pkeyopt', 'ec_paramgen_curve:prime256v1', '-nodes'];
  const issueCa = () =>
    openssl(
      'req',
      '-x509',
      ...EC,
      '-keyout',
      'ca.key',
      '-out',
      'ca.pem',
      '-days',
      '1',
      '-subj',
      '/CN=PaynEat test CA',
      '-addext',
      'basicConstraints=critical,CA:TRUE',
      '-addext',
      'keyUsage=critical,keyCertSign,cRLSign',
    );
  const issue = (name, subjectAltName) => {
    openssl('req', ...EC, '-keyout', `${name}.key`, '-out', `${name}.csr`, '-subj', `/CN=${name}`);
    fs.writeFileSync(
      path.join(dir, `${name}.ext`),
      `subjectAltName=${subjectAltName}\nbasicConstraints=CA:FALSE\nextendedKeyUsage=serverAuth\n`,
    );
    openssl(
      'x509',
      '-req',
      '-in',
      `${name}.csr`,
      '-CA',
      'ca.pem',
      '-CAkey',
      'ca.key',
      '-CAcreateserial',
      '-out',
      `${name}.pem`,
      '-days',
      '1',
      '-extfile',
      `${name}.ext`,
    );
  };

  /** ERP ปลอมแบบ HTTPS — บันทึกทุกคำขอที่ผ่าน TLS เข้ามาได้ */
  const startHttpsErp = (name) =>
    new Promise((resolve) => {
      const seen = [];
      const server = https.createServer(
        {
          key: fs.readFileSync(path.join(dir, `${name}.key`)),
          cert: fs.readFileSync(path.join(dir, `${name}.pem`)),
        },
        (req, res) => {
          seen.push({ path: req.url, authorization: req.headers.authorization });
          const body = req.url.startsWith('/api/v1/pos/instance')
            ? instanceBody()
            : { latestVersion: 0, changes: [], hasMore: false };
          res.writeHead(200, { 'Content-Type': 'application/json' });
          res.end(JSON.stringify(body));
        },
      );
      server.listen(0, '127.0.0.1', () =>
        resolve({
          url: `https://127.0.0.1:${server.address().port}`,
          seen,
          close: () =>
            new Promise((done) => {
              server.closeAllConnections();
              server.close(done);
            }),
        }),
      );
    });

  let erp;
  let other;
  before(async () => {
    dir = fs.mkdtempSync(path.join(os.tmpdir(), 'payneat-erp-tls-'));
    issueCa();
    issue('erp', 'IP:127.0.0.1');
    issue('other', 'DNS:erp.example.com');
    erp = await startHttpsErp('erp');
    other = await startHttpsErp('other');
  });
  after(async () => {
    await erp?.close();
    await other?.close();
    if (dir) fs.rmSync(dir, { recursive: true, force: true });
  });

  test('ใบรับรองจาก CA ที่เครื่องไม่เชื่อ → ปฏิเสธก่อนส่งคำขอ ด้วยเหตุผลของตัวเอง และหยุดรอคนแก้', async () => {
    const error = await failure(() =>
      erpClient.getInstance({ baseUrl: erp.url, credential: CREDENTIAL }),
    );
    assert.equal(error.kind, 'untrusted_certificate');
    assert.equal(integrationReason(error), 'unexpected_response');
    assert.equal(failureSeverity(error), 'ERROR');
    assert.equal(erp.seen.length, 0, 'TLS ล้มก่อนมีคำขอ HTTP — credential ไม่ได้ออกไป');
  });

  test('บันทึกที่อยู่ที่ใบรับรองไม่ผ่าน → 502 บอกให้ตั้ง NODE_EXTRA_CA_CERTS และไม่เข้าโหมดเชื่อมต่อ', async () => {
    const logFrom = logs.length;
    const res = await put({ erpUrl: erp.url }).set('Accept-Language', 'en');
    assert.equal(res.status, 502);
    assert.equal(res.body.error.code, 'ERP_CERTIFICATE_UNTRUSTED');
    assert.match(res.body.error.message, /NODE_EXTRA_CA_CERTS/);
    assert.equal((await status()).mode, 'standalone');
    assert.deepEqual(
      pullFailures(logFrom).map((line) => [line.labels.reason, line.severity]),
      [['unexpected_response', 'ERROR']],
    );
  });

  test('เครื่องเชื่อ CA ของเชนผ่าน NODE_EXTRA_CA_CERTS → ต่อได้ แต่ชื่อในใบรับรองต้องตรงกับที่อยู่', async () => {
    const script = `
      const { erpClient } = await import('./src/modules/erp/erp.client.js');
      const out = {};
      for (const [name, baseUrl] of Object.entries(JSON.parse(process.env.TEST_URLS))) {
        try {
          out[name] = (await erpClient.getInstance({ baseUrl, credential: process.env.TEST_CREDENTIAL })).body.code;
        } catch (error) {
          out[name] = error.kind ?? String(error);
        }
      }
      console.log(JSON.stringify(out));`;
    // execFile แบบ async: ERP ปลอมอยู่ใน process นี้ ต้องตอบได้ระหว่างรอ
    const { stdout } = await promisify(execFile)(
      process.execPath,
      ['--input-type=module', '-e', script],
      {
        cwd: backendDir,
        env: {
          PATH: process.env.PATH,
          NODE_ENV: 'test',
          JWT_SECRET: 'test-secret',
          NODE_EXTRA_CA_CERTS: path.join(dir, 'ca.pem'),
          TEST_URLS: JSON.stringify({ trusted: erp.url, wrongName: other.url }),
          TEST_CREDENTIAL: CREDENTIAL,
        },
      },
    );
    assert.deepEqual(JSON.parse(stdout), {
      trusted: 'POS-SUKHUMVIT-1',
      wrongName: 'untrusted_certificate',
    });
    assert.deepEqual(
      erp.seen.map((req) => [req.path, req.authorization]),
      [['/api/v1/pos/instance', `Bearer ${CREDENTIAL}`]],
    );
    assert.equal(other.seen.length, 0);
  });
});
