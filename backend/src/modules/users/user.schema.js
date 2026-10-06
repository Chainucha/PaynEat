// Copyright 2026 Suruch Chakrapeesirisuk
// SPDX-License-Identifier: Apache-2.0

import { z } from 'zod';

export const ROLES = ['admin', 'manager', 'waiter', 'cashier', 'kitchen'];

export const createUserSchema = z.object({
  name: z.string().min(2, 'ชื่อต้องมีอย่างน้อย 2 ตัวอักษร').max(80),
  username: z
    .string()
    .min(3, 'username ต้องมีอย่างน้อย 3 ตัวอักษร')
    .max(40)
    .regex(/^[a-zA-Z0-9_.-]+$/, 'username ใช้ได้เฉพาะ a-z 0-9 . _ -'),
  password: z.string().min(6, 'รหัสผ่านต้องมีอย่างน้อย 6 ตัวอักษร').max(72),
  role: z.enum(ROLES),
  // ใช้เฉพาะตอนผู้สร้างเป็น admin ในโหมด "ทุกสาขา" (ดู docs/DECISIONS.md #36) — คนอื่นถูกกำหนด
  // สาขาให้อัตโนมัติจากสาขาที่ตัวเองกำลังทำงานอยู่ (req.branchId) เสมอ ไม่ต้องส่งฟิลด์นี้มา
  branchId: z.number().int().positive().optional(),
  // สถานีครัวที่รับผิดชอบ (ticket 35) — [] หรือไม่ส่งมา = ไม่ผูกสถานี ซึ่งหมายถึง "เห็นทุกสถานี"
  // มีผลกับบทบาทที่เห็นจอครัวเท่านั้น (admin/manager/kitchen/waiter) บทบาทอื่นเก็บไว้เฉย ๆ ได้
  stationIds: z.array(z.number().int().positive()).max(20).optional(),
});

export const updateUserSchema = z.object({
  name: z.string().min(2).max(80).optional(),
  role: z.enum(ROLES).optional(),
  isActive: z.boolean().optional(),
  // ส่งมาเป็นชุดเต็มเสมอ (ไม่ใช่ส่วนเพิ่ม) — [] = ถอดสถานีออกทั้งหมด, ไม่ส่ง = ไม่แตะ
  stationIds: z.array(z.number().int().positive()).max(20).optional(),
});

export const resetPasswordSchema = z.object({
  password: z.string().min(6).max(72),
});

export const listUserQuerySchema = z.object({
  role: z.enum(ROLES).optional(),
  isActive: z
    .enum(['true', 'false'])
    .transform((value) => value === 'true')
    .optional(),
});

export const idParamSchema = z.object({
  id: z.coerce.number().int().positive(),
});
