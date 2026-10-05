// Copyright 2026 Suruch Chakrapeesirisuk
// SPDX-License-Identifier: Apache-2.0

import { z } from 'zod';

export const ORDER_STATUSES = ['open', 'in_kitchen', 'served', 'paid', 'cancelled'];
export const ORDER_ITEM_STATUSES = ['pending', 'cooking', 'ready', 'served', 'cancelled'];

// export ไว้ให้ public-order.schema.js ใช้ซ้ำ (ดู docs/tickets/17-qr-self-order.md) — กฎตรวจสอบ
// รายการอาหารต้องเหมือนกันทุกประการไม่ว่าใครเป็นคนเพิ่ม (พนักงานหรือลูกค้าสแกน QR เอง)
export const orderItemInputSchema = z.object({
  menuItemId: z.number().int().positive(),
  quantity: z.number().int().min(1, 'จำนวนต้องมากกว่า 0').max(99),
  optionIds: z.array(z.number().int().positive()).default([]),
  note: z.string().max(200).optional(),
  // น้ำหนักที่ชั่งได้ (กรัม) — ต้องมีเฉพาะเมนูขายตามน้ำหนัก (ดู docs/tickets/18-sell-by-weight.md)
  // เพดาน 99,999 กรัม เท่ากับช่องน้ำหนัก 5 หลักบนฉลากตาชั่ง (docs/tickets/19-barcode-scale.md)
  weightGrams: z
    .number()
    .int('น้ำหนักต้องเป็นกรัมเต็มหน่วย')
    .min(1, 'น้ำหนักต้องมากกว่า 0')
    .max(99999, 'น้ำหนักต่อบรรทัดต้องไม่เกิน 99.999 กก.')
    .optional(),
});

export const createOrderSchema = z
  .object({
    type: z.enum(['dine_in', 'takeaway', 'delivery']).default('dine_in'),
    tableId: z.number().int().positive().optional(),
    customerId: z.number().int().positive().optional(),
    guestCount: z.number().int().min(1).max(50).default(1),
    note: z.string().max(300).optional(),
    items: z.array(orderItemInputSchema).default([]),
    // ใช้เฉพาะตอนผู้เปิดออเดอร์เป็น admin ในโหมด "ทุกสาขา" (ดู docs/DECISIONS.md #36)
    branchId: z.number().int().positive().optional(),
  })
  .refine((data) => data.type !== 'dine_in' || data.tableId !== undefined, {
    message: 'ออเดอร์แบบทานที่ร้านต้องระบุโต๊ะ',
    path: ['tableId'],
  });

export const addItemsSchema = z.object({
  items: z.array(orderItemInputSchema).min(1, 'ต้องมีอย่างน้อย 1 รายการ'),
});

export const updateItemSchema = z.object({
  quantity: z.number().int().min(1).max(99).optional(),
  note: z.string().max(200).optional(),
});

export const updateItemStatusSchema = z.object({
  status: z.enum(ORDER_ITEM_STATUSES),
});

export const updateOrderSchema = z.object({
  guestCount: z.number().int().min(1).max(50).optional(),
  note: z.string().max(300).optional(),
});

export const discountSchema = z.object({
  type: z.enum(['none', 'amount', 'percent']),
  value: z.number().min(0).default(0),
});

export const redeemPromotionSchema = z.object({
  code: z.string().trim().min(1, 'กรุณากรอกโค้ดส่วนลด'),
});

export const cancelOrderSchema = z.object({
  reason: z.string().min(1, 'กรุณาระบุเหตุผลการยกเลิก').max(200),
});

export const moveTableSchema = z.object({
  tableId: z.number().int().positive(),
});

export const mergeOrderSchema = z.object({
  sourceOrderId: z.number().int().positive(),
});

export const listOrderQuerySchema = z.object({
  status: z.enum(ORDER_STATUSES).optional(),
  tableId: z.coerce.number().int().positive().optional(),
  waiterId: z.coerce.number().int().positive().optional(),
  customerId: z.coerce.number().int().positive().optional(),
  dateFrom: z.string().optional(),
  dateTo: z.string().optional(),
  activeOnly: z
    .enum(['true', 'false'])
    .transform((v) => v === 'true')
    .optional(),
  page: z.coerce.number().int().min(1).default(1),
  limit: z.coerce.number().int().min(1).max(100).default(20),
});

/**
 * คิวครัว (KDS) — `status` ส่งมาเป็นรายการคั่นด้วย comma, `station` เป็นรหัสสถานีครัว (ticket 34)
 * แยกสถานะที่ไม่รู้จักออกตั้งแต่ชั้นนี้ ไม่ปล่อยให้ค่าจาก query string ลงไปถึง SQL
 */
export const kitchenQueueQuerySchema = z.object({
  status: z
    .string()
    .optional()
    .transform((value) =>
      value === undefined
        ? undefined
        : value
            .split(',')
            .map((item) => item.trim())
            .filter((item) => item.length > 0),
    )
    .refine((list) => list === undefined || list.length > 0, {
      message: 'กรุณาระบุสถานะอย่างน้อยหนึ่งสถานะ',
    })
    .refine(
      (list) => list === undefined || list.every((item) => ORDER_ITEM_STATUSES.includes(item)),
      {
        message: `สถานะรายการอาหารต้องเป็นหนึ่งใน: ${ORDER_ITEM_STATUSES.join(', ')}`,
      },
    ),
  station: z
    .string()
    .trim()
    .regex(/^[a-z0-9_-]{2,20}$/, 'รหัสสถานีครัวไม่ถูกต้อง')
    .optional(),
});

export const idParamSchema = z.object({ id: z.coerce.number().int().positive() });

export const itemParamSchema = z.object({
  id: z.coerce.number().int().positive(),
  itemId: z.coerce.number().int().positive(),
});
