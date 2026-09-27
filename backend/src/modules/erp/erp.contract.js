// Copyright 2026 Suruch Chakrapeesirisuk
// SPDX-License-Identifier: Apache-2.0

import fs from 'node:fs';
import path from 'node:path';
import Ajv2020 from 'ajv/dist/2020.js';
import addFormats from 'ajv-formats';
import { env } from '../../config/env.js';

/**
 * สัญญา POS v1 ของ PaynEat ERP ที่ POS ปักไว้ (สำเนาใน backend/contracts/erp-pos, ticket 25, DECISIONS #80)
 * คำตอบของ ERP ทุกคำตอบผ่าน JSON Schema ตัวเดียวกับที่ ERP ใช้ทดสอบฝั่งตัวเอง — ไม่เขียน schema ซ้ำอีกชุด
 * ที่อาจเพี้ยนไปจากสัญญาได้เงียบ ๆ
 */
export const CONTRACT_DIR = path.join(env.rootDir, 'contracts/erp-pos/v1');

/** major ของสัญญาที่ POS รุ่นนี้เขียนมาให้ใช้ — ERP ตอบ contractVersion major อื่น = ปฏิเสธการเชื่อมต่อ */
export const SUPPORTED_CONTRACT_MAJOR = 1;

const loadSchema = (name) => JSON.parse(fs.readFileSync(path.join(CONTRACT_DIR, name), 'utf8'));

// strict: false — schema ของสัญญาใช้ keyword `description` กับ `format` ปนกับ `$ref` ซึ่ง ajv โหมด strict เตือน
// allErrors: รายงานทุกจุดที่ผิด ไม่ใช่แค่จุดแรก (ใช้ในข้อความ error ของ log)
const ajv = new Ajv2020({ strict: false, allErrors: true });
addFormats(ajv);

const validators = {
  posInstance: ajv.compile(loadSchema('pos-instance.schema.json')),
  masterDataChanges: ajv.compile(loadSchema('master-data-changes.schema.json')),
  error: ajv.compile(loadSchema('error.schema.json')),
};

/** ตรวจคำตอบกับ schema ของสัญญา คืน [] ถ้าถูก หรือรายการจุดที่ผิด (path + ข้อความ ไม่มีค่าของข้อมูล) */
export const contractErrors = (kind, body) => {
  const validate = validators[kind];
  if (validate(body)) return [];
  return validate.errors.map((error) => ({
    path: error.instancePath || '/',
    message: error.message ?? error.keyword,
  }));
};

/** major ของ contractVersion แบบ semver ('1.4.0' → 1) หรือ undefined ถ้ารูปแบบผิด */
export const contractMajor = (version) => {
  const match = /^(\d+)\.\d+\.\d+$/.exec(String(version ?? ''));
  return match ? Number(match[1]) : undefined;
};

/** รหัสสถานที่กลางของระบบนิเวศ (สาขา, POS instance) — รูปแบบเดียวกับสัญญา */
export const LOCATION_CODE_PATTERN = /^[A-Z0-9][A-Z0-9-]{1,31}$/;

export default { contractErrors, contractMajor, SUPPORTED_CONTRACT_MAJOR, LOCATION_CODE_PATTERN };
