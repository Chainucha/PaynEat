// Copyright 2026 Suruch Chakrapeesirisuk
// SPDX-License-Identifier: Apache-2.0

import { z } from 'zod';

/** ที่อยู่ของ PaynEat ERP: http(s) เท่านั้น ไม่มีชื่อผู้ใช้/รหัสผ่าน query หรือ # ในที่อยู่ */
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
  }, 'ที่อยู่ของ PaynEat ERP ต้องเป็น http:// หรือ https:// เช่น https://erp.example.com');

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
