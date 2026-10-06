// Copyright 2026 Suruch Chakrapeesirisuk
// SPDX-License-Identifier: Apache-2.0

import { z } from 'zod';

const optionSchema = z.object({
  name: z.string().min(1).max(60),
  priceDelta: z.number().min(0).default(0),
  isDefault: z.boolean().optional(),
});

const optionGroupSchema = z.object({
  name: z.string().min(1).max(60),
  minSelect: z.number().int().min(0).default(0),
  maxSelect: z.number().int().min(1).default(1),
  isRequired: z.boolean().default(false),
  options: z.array(optionSchema).min(1, 'กลุ่มตัวเลือกต้องมีอย่างน้อย 1 ตัวเลือก'),
});

const ingredientLinkSchema = z.object({
  ingredientId: z.number().int().positive(),
  qtyPerUnit: z.number().positive(),
});

const ingredientLinksSchema = z
  .array(ingredientLinkSchema)
  .optional()
  .refine(
    (links) => !links || new Set(links.map((link) => link.ingredientId)).size === links.length,
    { message: 'เลือกวัตถุดิบซ้ำกันในเมนูเดียวไม่ได้' },
  );

export const createMenuItemSchema = z.object({
  categoryId: z.number().int().positive(),
  name: z.string().min(1, 'กรุณากรอกชื่อเมนู').max(120),
  nameEn: z.string().max(120).optional(),
  description: z.string().max(500).optional(),
  price: z.number().min(0, 'ราคาต้องไม่ติดลบ'),
  imageUrl: z.string().url('รูปแบบ URL ไม่ถูกต้อง').optional().or(z.literal('')),
  isAvailable: z.boolean().optional(),
  isRecommended: z.boolean().optional(),
  prepMinutes: z.number().int().min(0).max(240).optional(),
  sortOrder: z.number().int().min(0).optional(),
  optionGroups: z.array(optionGroupSchema).optional(),
  ingredients: ingredientLinksSchema,
  // ขายตามน้ำหนัก — price กลายเป็นราคาต่อกิโลกรัม (ดู docs/tickets/18-sell-by-weight.md)
  soldByWeight: z.boolean().optional(),
  // บาร์โค้ดสินค้าสำเร็จรูป / รหัสสินค้าบนฉลากตาชั่ง (ดู docs/tickets/19-barcode-scale.md) — ส่ง ''
  // เพื่อล้างค่า
  barcode: z
    .string()
    .trim()
    .max(32)
    .regex(/^[0-9A-Za-z-]+$/, 'บาร์โค้ดใช้ได้เฉพาะตัวเลข ตัวอักษรอังกฤษ และขีด')
    .optional()
    .or(z.literal('')),
  scalePlu: z
    .string()
    .trim()
    .regex(/^\d{1,6}$/, 'รหัสสินค้าบนตาชั่ง (PLU) ต้องเป็นตัวเลข 1–6 หลัก')
    .optional()
    .or(z.literal('')),
  // สถานีครัวของจานนี้ (ticket 34) — null = "ตามหมวดหมู่" ซึ่งถอยไปหาสถานีค่าเริ่มต้นถ้าหมวดหมู่
  // ก็ไม่ได้กำหนดไว้ nullable จึงจำเป็น ไม่ใช่แค่ optional: ต้องแยก "ไม่ได้ส่งมา" ออกจาก "ล้างค่า"
  stationId: z.number().int().positive().nullable().optional(),
  // ใช้เฉพาะตอนผู้สร้างเป็น admin ในโหมด "ทุกสาขา" (ดู docs/DECISIONS.md #36) — คนอื่นถูกกำหนด
  // สาขาให้อัตโนมัติจาก req.branchId เสมอ
  branchId: z.number().int().positive().optional(),
});

export const updateMenuItemSchema = createMenuItemSchema.partial();

export const toggleAvailabilitySchema = z.object({
  isAvailable: z.boolean(),
});

export const listMenuQuerySchema = z.object({
  categoryId: z.coerce.number().int().positive().optional(),
  search: z.string().max(120).optional(),
  availableOnly: z
    .enum(['true', 'false'])
    .transform((v) => v === 'true')
    .optional(),
  recommendedOnly: z
    .enum(['true', 'false'])
    .transform((v) => v === 'true')
    .optional(),
  page: z.coerce.number().int().min(1).default(1),
  limit: z.coerce.number().int().min(1).max(200).default(100),
});

export const idParamSchema = z.object({ id: z.coerce.number().int().positive() });
