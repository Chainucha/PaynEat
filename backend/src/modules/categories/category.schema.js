// Copyright 2026 Suruch Chakrapeesirisuk
// SPDX-License-Identifier: Apache-2.0

import { z } from 'zod';

export const createCategorySchema = z.object({
  name: z.string().min(1, 'กรุณากรอกชื่อหมวดหมู่').max(60),
  nameEn: z.string().max(60).optional(),
  icon: z.string().max(8).optional(),
  sortOrder: z.number().int().min(0).optional(),
  // สถานีครัวตั้งต้นของทุกเมนูในหมวดหมู่นี้ (ticket 34) — null = ใช้สถานีค่าเริ่มต้นของร้าน
  // เมนูรายตัวทับค่านี้ได้ nullable จึงจำเป็น เพื่อแยก "ไม่ได้ส่งมา" ออกจาก "ล้างค่า"
  stationId: z.number().int().positive().nullable().optional(),
});

export const updateCategorySchema = createCategorySchema.partial().extend({
  isActive: z.boolean().optional(),
});

export const listCategoryQuerySchema = z.object({
  activeOnly: z
    .enum(['true', 'false'])
    .transform((value) => value === 'true')
    .optional(),
});

export const idParamSchema = z.object({ id: z.coerce.number().int().positive() });
