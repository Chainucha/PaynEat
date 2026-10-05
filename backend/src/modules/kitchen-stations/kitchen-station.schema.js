// Copyright 2026 Suruch Chakrapeesirisuk
// SPDX-License-Identifier: Apache-2.0

import { z } from 'zod';

/** รหัสสถานีที่ใช้ใน API และในค่าที่จอครัวจำไว้ต่อเครื่อง — ตัวเล็ก ตัวเลข ขีด เท่านั้น */
export const STATION_CODE_PATTERN = /^[a-z0-9_-]{2,20}$/;

export const createKitchenStationSchema = z.object({
  code: z.string().regex(STATION_CODE_PATTERN, 'รหัสสถานีใช้ a-z 0-9 - _ ยาว 2-20 ตัว'),
  name: z.string().min(1, 'กรุณากรอกชื่อสถานีครัว').max(60),
  nameEn: z.string().max(60).optional(),
  nameKo: z.string().max(60).optional(),
  icon: z.string().max(8).optional(),
  sortOrder: z.number().int().min(0).optional(),
});

/**
 * `code` แก้ไม่ได้หลังสร้าง — จอครัวแต่ละเครื่องจำสถานีที่เลือกไว้ด้วยรหัสนี้ และ `?station=` ก็ใช้รหัสนี้
 * เปลี่ยนรหัสทีหลังเท่ากับทำให้จอที่ตั้งไว้แล้วเด้งกลับเป็น "ทุกสถานี" เงียบ ๆ ถ้าต้องเปลี่ยนให้สร้างสถานีใหม่
 * แล้วปิดใช้งานตัวเก่า (ชื่อที่แสดงแก้ได้ตามปกติ)
 */
export const updateKitchenStationSchema = createKitchenStationSchema
  .omit({ code: true })
  .partial()
  .extend({
    isActive: z.boolean().optional(),
    isDefault: z.boolean().optional(),
  });

export const listKitchenStationQuerySchema = z.object({
  activeOnly: z
    .enum(['true', 'false'])
    .transform((value) => value === 'true')
    .optional(),
});

export const idParamSchema = z.object({ id: z.coerce.number().int().positive() });
