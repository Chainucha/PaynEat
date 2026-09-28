// Copyright 2026 Suruch Chakrapeesirisuk
// SPDX-License-Identifier: Apache-2.0

import { z } from 'zod';
import { LOCATION_CODE_PATTERN } from './erp.contract.js';

/**
 * ที่อยู่ของ PaynEat ERP: รูปแบบ http(s) ไม่มีชื่อผู้ใช้/รหัสผ่าน query หรือ # ในที่อยู่
 * http:// ใช้ได้เฉพาะ loopback หรือเมื่อผู้ดูแลเซิร์ฟเวอร์อนุญาต — erp.service ตรวจต่อและตอบ 400 (ticket 32, erp.transport.js)
 */
const erpUrl = z
  .string()
  .trim()
  .max(500)
  .refine((value) => {
    try {
      const url = new URL(value);
      return (
        ['http:', 'https:'].includes(url.protocol) &&
        !url.username &&
        !url.password &&
        !url.search &&
        !url.hash
      );
    } catch {
      return false;
    }
  }, 'ที่อยู่ของ PaynEat ERP ต้องเป็น URL แบบ https:// เช่น https://erp.example.com');

export const connectErpSchema = z.object({
  erpUrl,
  // machine credential ที่ ERP แสดงครั้งเดียวตอนลงทะเบียน POS instance (สัญญา POS v1: ขึ้นต้นด้วย pnepos_)
  credential: z
    .string()
    .trim()
    .regex(
      /^pnepos_[A-Za-z0-9_-]{16,200}$/,
      'credential ต้องขึ้นต้นด้วย pnepos_ ตามที่ PaynEat ERP แสดงตอนลงทะเบียน POS',
    ),
});

/** "สร้างสาขานี้ในเครื่อง": รหัสสาขาที่ ERP ให้เครื่องนี้ดูแล (รูปแบบรหัสสถานที่ของสัญญา POS v1) */
export const createServedBranchSchema = z.object({
  code: z
    .string()
    .trim()
    .regex(
      LOCATION_CODE_PATTERN,
      'รหัสสาขาต้องเป็นตัวพิมพ์ใหญ่ A-Z ตัวเลข หรือ - ยาว 2-32 ตัว และขึ้นต้นด้วยตัวอักษรหรือตัวเลข',
    ),
});
