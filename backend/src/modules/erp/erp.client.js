// Copyright 2026 Suruch Chakrapeesirisuk
// SPDX-License-Identifier: Apache-2.0

import { randomUUID } from 'node:crypto';
import { env } from '../../config/env.js';
import { contractErrors, contractMajor, SUPPORTED_CONTRACT_MAJOR } from './erp.contract.js';

/**
 * เรียก PaynEat ERP ตามสัญญา POS v1 (ticket 25, DECISIONS #80) — ทุกคำขอมี `Authorization: Bearer <credential>`
 * และ `x-request-id` ที่สร้างใหม่ ซึ่งเป็น correlation id ของบรรทัด log ทั้งสองฝั่ง
 *
 * คำตอบทุกแบบกลายเป็นผลลัพธ์ที่ผ่าน schema ของสัญญาแล้ว หรือ ErpCallError ที่บอก `kind` ให้ผู้เรียกตัดสินใจ:
 * - `credential_rejected` — 401: credential ถูกเพิกถอนหรือ ERP ไม่รู้จัก เรียกซ้ำไม่ช่วย หยุดจนกว่าจะได้ credential ใหม่
 * - `rate_limited` — 429: รอ `Retry-After` วินาที
 * - `unavailable` — 5xx: ERP ตอบไม่ได้ชั่วคราว (503 อาจมี `Retry-After`)
 * - `network` — ต่อไม่ถึง / หมดเวลา
 * - `unsupported_contract` — ERP ใช้สัญญา major ที่ POS รุ่นนี้ไม่รู้จัก
 * - `invalid_response` — 2xx แต่ body ไม่ตรงสัญญา
 * - `refused` — สถานะอื่น (400, 403, 404…): ที่อยู่ผิด, proxy, หรือสัญญาไม่ตรงกัน
 *
 * credential ไม่ถูกใส่ในข้อความ error หรือค่าใดที่คืนออกไป
 */
export class ErpCallError extends Error {
  constructor(kind, { status, reason, retryAfterSeconds, contractVersion, problems } = {}) {
    super(`PaynEat ERP call failed: ${kind}${status ? ` (HTTP ${status})` : ''}`);
    this.name = 'ErpCallError';
    this.kind = kind;
    this.status = status;
    // details.reason ของ ERP (credential_revoked, credential_unknown…) — เฉพาะเมื่อ ERP บอกมาเอง ไม่เดา
    this.reason = reason;
    this.retryAfterSeconds = retryAfterSeconds;
    this.contractVersion = contractVersion;
    // จุดที่คำตอบผิดสัญญา (path + ข้อความ ไม่มีค่าของข้อมูล)
    this.problems = problems;
  }
}

/** `Retry-After` เป็นวินาทีหรือวันที่ HTTP → วินาที (ไม่ติดลบ) หรือ undefined */
export const parseRetryAfter = (header, now = Date.now()) => {
  if (header === null || header === undefined || header === '') return undefined;
  const text = String(header).trim();
  if (/^\d+$/.test(text)) return Number(text);
  const at = Date.parse(text);
  return Number.isNaN(at) ? undefined : Math.max(0, Math.ceil((at - now) / 1000));
};

/**
 * URL ฐานของ ERP → URL ของ endpoint (รองรับ ERP ที่อยู่ใต้ path เช่น https://host/erp/)
 * ที่อยู่ของ ERP ถูกตรวจรูปแบบแล้วตอนบันทึก (erp.schema.js)
 */
const endpoint = (baseUrl, path, query) => {
  const base = baseUrl.endsWith('/') ? baseUrl : `${baseUrl}/`;
  const url = new URL(path, base);
  for (const [key, value] of Object.entries(query ?? {})) url.searchParams.set(key, String(value));
  return url;
};

const readJson = async (response) => {
  const text = await response.text();
  if (!text) return undefined;
  try {
    return JSON.parse(text);
  } catch {
    return undefined;
  }
};

/** reason ที่ ERP ส่งมาใน body ของ error ตามสัญญา — ถ้า body ไม่ตรง schema ของ error ถือว่าไม่รู้ */
const errorReason = (body) =>
  body && contractErrors('error', body).length === 0 ? body.details?.reason : undefined;

const failureFor = async (response) => {
  const { status } = response;
  const body = await readJson(response);
  const retryAfterSeconds = parseRetryAfter(response.headers.get('retry-after'));
  if (status === 401)
    return new ErpCallError('credential_rejected', { status, reason: errorReason(body) });
  if (status === 429) return new ErpCallError('rate_limited', { status, retryAfterSeconds });
  if (status >= 500) return new ErpCallError('unavailable', { status, retryAfterSeconds });
  return new ErpCallError('refused', { status, reason: errorReason(body) });
};

/**
 * GET หนึ่งครั้ง คืน `{ body, requestId }` ที่ผ่าน schema `kind` ของสัญญาแล้ว
 * `requestId` ใช้เป็น correlation_id ของบรรทัด log เรื่องคำขอนี้ ERP ก็ log ด้วยค่าเดียวกัน
 */
const get = async (
  { baseUrl, credential },
  path,
  kind,
  { query, requestId = randomUUID(), precheck } = {},
) => {
  let response;
  try {
    response = await fetch(endpoint(baseUrl, path, query), {
      headers: {
        Accept: 'application/json',
        Authorization: `Bearer ${credential}`,
        'x-request-id': requestId,
      },
      // ไม่ตามการ redirect: credential ต้องไปถึงที่อยู่ที่ผู้ดูแลตั้งเท่านั้น — 3xx ถูกรายงานเป็น refused พร้อมสถานะ
      redirect: 'manual',
      signal: AbortSignal.timeout(env.erp.timeoutMs),
    });
  } catch {
    // ข้อความของ fetch อาจยก URL มาทั้งเส้น (ไม่มี credential แต่ไม่จำเป็นต้องเก็บ) — บอกแค่ประเภท
    throw new ErpCallError('network');
  }

  if (!response.ok) throw await failureFor(response);
  const body = await readJson(response);
  if (body === undefined) {
    throw new ErpCallError('invalid_response', {
      status: response.status,
      problems: [{ path: '/', message: 'not JSON' }],
    });
  }
  precheck?.(body);
  const problems = contractErrors(kind, body);
  if (problems.length) {
    throw new ErpCallError('invalid_response', { status: response.status, problems });
  }
  return { body, requestId };
};

/** ตรวจ major ของ contractVersion ในคำตอบของ instance (เรียกก่อนตรวจ schema) */
export const assertSupportedContract = (body) => {
  const major = contractMajor(body?.contractVersion);
  if (major !== undefined && major !== SUPPORTED_CONTRACT_MAJOR) {
    throw new ErpCallError('unsupported_contract', { contractVersion: body.contractVersion });
  }
};

export const erpClient = {
  /**
   * `GET /api/v1/pos/instance` — รหัส instance, เวอร์ชันสัญญา และสาขาที่ ERP ให้ดูแล
   * เช็ค major ก่อนตรวจ schema: schema ของ v1 รับแค่ `1.x.y` สัญญา 2.0 จึงต้องได้เหตุผลที่ถูก ไม่ใช่ "คำตอบผิดรูปแบบ"
   */
  getInstance(connection, options) {
    return get(connection, 'api/v1/pos/instance', 'posInstance', {
      ...options,
      precheck: assertSupportedContract,
    });
  },

  /** `GET /api/v1/master-data/changes?since=N&limit=` — หนึ่งหน้าของการเปลี่ยนแปลงหลังเวอร์ชัน N */
  getChanges(connection, since, limit, options) {
    return get(connection, 'api/v1/master-data/changes', 'masterDataChanges', {
      ...options,
      query: { since, limit },
    });
  },
};

export default erpClient;
