// Copyright 2026 Suruch Chakrapeesirisuk
// SPDX-License-Identifier: Apache-2.0

import http from 'node:http';

/**
 * PaynEat ERP ปลอมสำหรับเทสต์ (ticket 25) — ตอบ `GET /api/v1/pos/instance` และ `GET /api/v1/master-data/changes`
 * ตามสัญญา POS v1 จาก state ที่เทสต์กำหนดเอง ไม่ต้องรัน ERP จริง
 *
 * - `state.changes` คือ change log ทั้งหมดของ ERP แจกเป็นหน้าตาม `since`/`limit` (บังคับหน้าเล็กได้ด้วย `pageLimit`)
 * - `state.failures` คิวคำตอบพิเศษ `{ path, status, body, headers }` ใช้ครั้งเดียวต่อคำขอที่ path ตรงกัน
 * - `state.requests` บันทึกทุกคำขอที่เข้ามา (path, query, header ที่เกี่ยวข้อง) ให้เทสต์ตรวจ
 */
export const CREDENTIAL = `pnepos_${'A1b2C3d4E5'.repeat(4)}xyz`;

export const instanceBody = (overrides = {}) => ({
  code: 'POS-SUKHUMVIT-1',
  name: 'Sukhumvit front counter',
  contractVersion: '1.0.0',
  branches: [{ code: 'SUKHUMVIT', nameTh: 'สาขาสุขุมวิท', nameEn: 'Sukhumvit', active: true }],
  ...overrides,
});

let nextId = 1;
const uuid = () => {
  const n = String(nextId++).padStart(12, '0');
  return `00000000-0000-4000-8000-${n}`;
};

export const itemChange = (version, itemCode, overrides = {}) => {
  const id = overrides.id ?? uuid();
  return {
    version,
    entityType: 'item',
    entityId: id,
    entityCode: itemCode,
    action: overrides.action ?? 'created',
    data: {
      id,
      itemCode,
      nameTh: overrides.nameTh ?? `สินค้า ${itemCode}`,
      nameEn: overrides.nameEn ?? `Item ${itemCode}`,
      baseUnitCode: overrides.baseUnitCode ?? 'kg',
      variableWeight: false,
      shelfLifeDays: 3,
      active: overrides.active ?? true,
      purchaseUnits: [{ unitCode: 'case', factor: '10' }],
      version,
      ...(overrides.extra ?? {}),
    },
    changedAt: '2026-09-27T03:00:00.000Z',
  };
};

export const locationChange = (version, locationCode, overrides = {}) => {
  const id = overrides.id ?? uuid();
  return {
    version,
    entityType: 'location',
    entityId: id,
    entityCode: locationCode,
    action: overrides.action ?? 'updated',
    data: {
      id,
      locationCode,
      type: 'branch',
      nameTh: overrides.nameTh ?? `สาขา ${locationCode}`,
      nameEn: overrides.nameEn ?? `Branch ${locationCode}`,
      active: overrides.active ?? true,
      supersededBy: overrides.supersededBy ?? null,
      version,
    },
    changedAt: '2026-09-27T04:00:00.000Z',
  };
};

const send = (res, status, body, headers = {}) => {
  const text = body === undefined ? '' : typeof body === 'string' ? body : JSON.stringify(body);
  res.writeHead(status, { 'Content-Type': 'application/json', ...headers });
  res.end(text);
};

const credentialRejected = (path, reason) => ({
  statusCode: 401,
  code: 'POS_CREDENTIAL_REJECTED',
  message: 'This POS credential was rejected.',
  details: { reason },
  path,
  requestId: 'stub-request-0001',
  timestamp: '2026-09-27T05:00:00.000Z',
});

export const startErpStub = async () => {
  const state = {
    credential: CREDENTIAL,
    revoked: false,
    instance: instanceBody(),
    changes: [],
    pageLimit: undefined,
    failures: [],
    requests: [],
  };

  const server = http.createServer((req, res) => {
    const url = new URL(req.url, 'http://stub');
    state.requests.push({
      path: url.pathname,
      query: Object.fromEntries(url.searchParams),
      authorization: req.headers.authorization,
      requestId: req.headers['x-request-id'],
    });

    const failure = state.failures.findIndex((f) => !f.path || f.path === url.pathname);
    if (failure !== -1) {
      const [{ status, body, headers }] = state.failures.splice(failure, 1);
      return send(res, status, body, headers);
    }

    if (req.headers.authorization !== `Bearer ${state.credential}`) {
      return send(res, 401, credentialRejected(url.pathname, 'credential_unknown'));
    }
    if (state.revoked) {
      return send(res, 401, credentialRejected(url.pathname, 'credential_revoked'));
    }

    if (url.pathname === '/api/v1/pos/instance') return send(res, 200, state.instance);

    if (url.pathname === '/api/v1/master-data/changes') {
      const since = Number(url.searchParams.get('since') ?? 0);
      const limit = Math.min(
        Number(url.searchParams.get('limit') ?? 500),
        state.pageLimit ?? Number.POSITIVE_INFINITY,
      );
      const after = state.changes.filter((c) => c.version > since);
      const page = after.slice(0, limit);
      return send(res, 200, {
        latestVersion: state.changes.reduce((max, c) => Math.max(max, c.version), 0),
        changes: page,
        hasMore: after.length > page.length,
      });
    }

    return send(res, 404, { statusCode: 404, code: 'NOT_FOUND', message: 'Not found' });
  });

  await new Promise((resolve) => server.listen(0, '127.0.0.1', resolve));
  const { port } = server.address();
  return {
    url: `http://127.0.0.1:${port}`,
    state,
    /** คำขอไปยัง path นี้ตั้งแต่ index ที่กำหนด (ใช้ดูว่าดึงต่อจากเวอร์ชันไหน) */
    requestsTo: (path, from = 0) => state.requests.slice(from).filter((r) => r.path === path),
    close: () => new Promise((resolve) => server.close(resolve)),
  };
};
