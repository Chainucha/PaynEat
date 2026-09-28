// Copyright 2026 Suruch Chakrapeesirisuk
// SPDX-License-Identifier: Apache-2.0

import test, { after, describe } from 'node:test';
import assert from 'node:assert/strict';
import { spawnSync } from 'node:child_process';
import { randomBytes } from 'node:crypto';
import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
import YAML from 'yaml';
import { api, login, authHeader, cleanup } from './helpers/testApp.js';

// ค่าเริ่มต้นสำหรับ production (T19, docs/DECISIONS.md #83): ติดตั้งตาม README แล้วลืมตั้งค่าบางอย่าง ต้องได้ระบบที่ปิดไว้ก่อน

const { env } = await import('../src/config/env.js');
const { userRepository } = await import('../src/modules/users/user.repository.js');

after(cleanup);

const backendDir = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..');
const repoDir = path.resolve(backendDir, '..');

/** โหลด config ใน process ใหม่ด้วย env ที่กำหนด (ไม่อ่าน backend/.env ของเครื่องเพราะค่าที่ส่งไปมีก่อน) */
const loadConfig = (vars) =>
  spawnSync(
    process.execPath,
    [
      '--input-type=module',
      '-e',
      "const { env } = await import('./src/config/env.js'); console.log(JSON.stringify({ metricsHost: env.telemetry.metricsHost, exposeErrorStack: env.exposeErrorStack }));",
    ],
    {
      cwd: backendDir,
      env: { PATH: process.env.PATH, DATABASE_FILE: 'data/unused.sqlite', ...vars },
      encoding: 'utf8',
    },
  );

describe('JWT_SECRET ใน production', () => {
  for (const secret of [
    'payneat-local-demo-secret',
    'change-this-secret-in-production',
    'test-secret',
  ]) {
    test(`ค่าที่เผยแพร่ใน repo (${secret}) → ไม่ยอมเริ่มพร้อมเหตุผล`, () => {
      const run = loadConfig({ NODE_ENV: 'production', JWT_SECRET: secret });
      assert.notEqual(run.status, 0);
      assert.match(run.stderr, /JWT_SECRET/);
      assert.match(run.stderr, /openssl rand -hex 32/);
    });
  }

  test('ค่าสุ่มที่สั้นเกินไป → ไม่ยอมเริ่ม', () => {
    const run = loadConfig({ NODE_ENV: 'production', JWT_SECRET: randomBytes(8).toString('hex') });
    assert.notEqual(run.status, 0);
    assert.match(run.stderr, /อย่างน้อย 32/);
  });

  test('ค่าสุ่มยาวพอ → เริ่มได้', () => {
    const run = loadConfig({ NODE_ENV: 'production', JWT_SECRET: randomBytes(32).toString('hex') });
    assert.equal(run.status, 0, run.stderr);
  });

  test('ตอนพัฒนาและเดโมยังใช้ค่าเดโมได้เหมือนเดิม', () => {
    const run = loadConfig({ NODE_ENV: 'development', JWT_SECRET: 'payneat-local-demo-secret' });
    assert.equal(run.status, 0, run.stderr);
  });
});

describe('ค่าเริ่มต้นอื่น', () => {
  test('/metrics ฟังเฉพาะเครื่องนี้ แม้ API ฟังทุก interface — เปิดกว้างได้เมื่อตั้ง METRICS_HOST เอง', () => {
    const base = { JWT_SECRET: 'payneat-local-demo-secret', HOST: '0.0.0.0' };
    assert.equal(JSON.parse(loadConfig(base).stdout).metricsHost, '127.0.0.1');
    const open = loadConfig({ ...base, METRICS_HOST: '0.0.0.0' });
    assert.equal(JSON.parse(open.stdout).metricsHost, '0.0.0.0');
  });

  test('stack ของ error แนบไปกับคำตอบเฉพาะเมื่อตั้ง EXPOSE_ERROR_STACK=true และไม่ใช่ production', () => {
    const base = { JWT_SECRET: randomBytes(32).toString('hex') };
    assert.equal(JSON.parse(loadConfig(base).stdout).exposeErrorStack, false);
    assert.equal(
      JSON.parse(loadConfig({ ...base, EXPOSE_ERROR_STACK: 'true' }).stdout).exposeErrorStack,
      true,
    );
    const prod = loadConfig({ ...base, NODE_ENV: 'production', EXPOSE_ERROR_STACK: 'true' });
    assert.equal(JSON.parse(prod.stdout).exposeErrorStack, false);
  });

  test('error 500 ไม่มี stack ในคำตอบเป็นค่าเริ่มต้น แม้ NODE_ENV=development', async (t) => {
    const { token } = await login('cashier', 'cashier123');
    const original = userRepository.findById;
    const originalEnv = env.nodeEnv;
    t.after(() => {
      userRepository.findById = original;
      env.nodeEnv = originalEnv;
      env.exposeErrorStack = false;
    });
    userRepository.findById = () => {
      throw new TypeError('simulated failure');
    };
    env.nodeEnv = 'development';

    const hidden = await api().get('/api/v1/customers').set(authHeader(token));
    assert.equal(hidden.status, 500);
    assert.equal(hidden.body.error.stack, undefined);
    assert.ok(!JSON.stringify(hidden.body).includes('simulated failure'));

    env.exposeErrorStack = true;
    const debug = await api().get('/api/v1/customers').set(authHeader(token));
    assert.match(debug.body.error.stack, /simulated failure/);
  });
});

test('ลบบัญชีที่เคยเปิดกะ → 409 ให้ปิดการใช้งานแทน และไม่มีอะไรถูกลบหรือบันทึก', async () => {
  const admin = await login('admin', 'admin123');
  const manager = await login('manager', 'manager123');
  const cashier = await login('cashier', 'cashier123');
  const current = await api().get('/api/v1/shifts/current').set(authHeader(cashier.token));
  if (!current.body.data) {
    const opened = await api()
      .post('/api/v1/shifts')
      .set(authHeader(cashier.token))
      .send({ openingCash: 500 });
    assert.equal(opened.status, 201, JSON.stringify(opened.body));
  }

  const res = await api().delete(`/api/v1/users/${cashier.user.id}`).set(authHeader(admin.token));
  assert.equal(res.status, 409);
  assert.equal(res.body.error.code, 'USER_HAS_HISTORY');
  const english = await api()
    .delete(`/api/v1/users/${cashier.user.id}`)
    .set(authHeader(admin.token))
    .set('Accept-Language', 'en');
  assert.match(english.body.error.message, /deactivate it instead/);

  const still = await api().get(`/api/v1/users/${cashier.user.id}`).set(authHeader(manager.token));
  assert.equal(still.status, 200);
  const audit = await api()
    .get('/api/v1/audit-logs?action=user.delete')
    .set(authHeader(admin.token));
  assert.ok(!audit.body.data.some((row) => row.entityId === cashier.user.id));

  // ปิดการใช้งานแทนได้ตามที่ข้อความแนะนำ
  const deactivated = await api()
    .patch(`/api/v1/users/${cashier.user.id}`)
    .set(authHeader(admin.token))
    .send({ isActive: false });
  assert.equal(deactivated.status, 200);
  assert.equal(deactivated.body.data.isActive, false);
});

describe('Docker Compose', () => {
  const compose = (file) => YAML.parse(fs.readFileSync(path.join(repoDir, file), 'utf8'));

  test('compose หลักหยุดพร้อมวิธีตั้งค่าถ้าไม่ได้ตั้ง JWT_SECRET (ไม่มีค่าสำรองในไฟล์)', () => {
    const api = compose('docker-compose.yml').services.api;
    assert.match(api.environment.JWT_SECRET, /^\$\{JWT_SECRET:\?.*openssl rand -hex 32.*\}$/);
  });

  test('compose หลัก: /metrics ให้ตัวเก็บใน compose network เรียกได้ แต่ไม่เปิดพอร์ตออกนอกเครื่อง', () => {
    const api = compose('docker-compose.yml').services.api;
    assert.equal(api.environment.METRICS_HOST, '0.0.0.0');
    assert.ok(api.ports.every((port) => !String(port).includes('9464')));
  });

  test('compose เดโมเปิดพอร์ตเฉพาะเครื่องตัวเอง ตามที่คู่มือติดตั้งบอก', () => {
    const { services } = compose('deploy/demo/docker-compose.demo.yml');
    const ports = Object.values(services).flatMap((service) => service.ports ?? []);
    assert.ok(ports.length >= 2);
    for (const port of ports) assert.match(String(port), /^127\.0\.0\.1:/);
  });
});
