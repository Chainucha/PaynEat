// Copyright 2026 Suruch Chakrapeesirisuk
// SPDX-License-Identifier: Apache-2.0

import { getDb } from '../../db/index.js';
import { ApiError } from '../../core/ApiError.js';

/**
 * โหมดของเครื่องนี้ (ticket 25, DECISIONS #80): มีแถวใน erp_connection = เชื่อมต่อ PaynEat ERP, ไม่มี = ใช้งานเดี่ยว
 * แยกเป็นโมดูลเล็กให้ module อื่น (วัตถุดิบ สาขา สต๊อก) เช็คได้โดยไม่ต้องพึ่งตัว service ของ ERP
 */
export const isErpConnected = () =>
  Boolean(getDb().prepare('SELECT 1 FROM erp_connection WHERE id = 1').get());

/**
 * ในโหมดเชื่อมต่อ ข้อมูลที่ ERP เป็นเจ้าของ (วัตถุดิบ สาขา) แก้ที่ POS ไม่ได้ — ตอบ 409 พร้อมเหตุผล
 * code `MANAGED_BY_ERP` ให้แอปแยกกรณีนี้ออกจาก 409 อื่นได้
 */
export const assertNotManagedByErp = (message) => {
  if (isErpConnected()) throw new ApiError(409, message, { code: 'MANAGED_BY_ERP' });
};

export default { isErpConnected, assertNotManagedByErp };
