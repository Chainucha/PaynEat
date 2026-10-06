// Copyright 2026 Suruch Chakrapeesirisuk
// SPDX-License-Identifier: Apache-2.0

import { toBaht } from '../../core/money.js';

export const toOrderItemDto = (row) => {
  if (!row) return null;
  // ไม่ใส่ค่าเริ่มต้นตรงนี้ เพราะทั้ง try และ catch เขียนทับทุกเส้นทางอยู่แล้ว
  // (ESLint 10 เปิดกฎ no-useless-assignment เป็นค่าเริ่มต้น จึงจับจุดนี้ได้)
  let options;
  try {
    options = JSON.parse(row.options_json ?? '[]');
  } catch {
    options = [];
  }

  return {
    id: row.id,
    orderId: row.order_id,
    menuItemId: row.menu_item_id,
    name: row.name_snapshot,
    unitPrice: toBaht(row.unit_price),
    quantity: row.quantity,
    // ขายตามน้ำหนัก (docs/tickets/18-sell-by-weight.md) — null = ขายเป็นชิ้น
    weightGrams: row.weight_grams ?? null,
    options: options.map((option) => ({ ...option, priceDelta: toBaht(option.priceDelta ?? 0) })),
    optionsPrice: toBaht(row.options_price),
    lineTotal: toBaht(row.line_total),
    note: row.note,
    status: row.status,
    // ขั้นที่ครัวเคยทำถึง (cooking/ready/served) ไม่ถอยลงแม้เลิกทำ — null = ครัวยังไม่เคยเริ่ม (T05 #104)
    kitchenReached: row.kitchen_reached ?? null,
    // สถานีครัวถูกประทับลงรายการตอนบันทึก (ticket 34) ย้ายเมนูไปสถานีอื่นหรือเปลี่ยนชื่อสถานีทีหลัง
    // จึงไม่ดึงตั๋วที่ครัวกำลังทำอยู่ข้ามจอ และไม่เปลี่ยนชื่อบนตั๋วที่ค้างอยู่
    stationId: row.station_id ?? null,
    stationName: row.station_name_snapshot ?? null,
    isPaid: Boolean(row.is_paid),
    createdAt: row.created_at,
    updatedAt: row.updated_at,
    // เผื่อกรณีดึงมาจากคิวครัวที่ join ข้อมูลออเดอร์มาด้วย
    orderCode: row.order_code,
    stationCode: row.station_code,
    tableName: row.table_name,
    orderType: row.order_type,
  };
};

export const toOrderDto = (row, items = []) => {
  if (!row) return null;
  return {
    id: row.id,
    code: row.code,
    type: row.type,
    branchId: row.branch_id ?? null,
    tableId: row.table_id,
    tableName: row.table_name,
    tableZone: row.table_zone,
    queueNumber: row.queue_number ?? null,
    waiterId: row.waiter_id,
    waiterName: row.waiter_name,
    customerId: row.customer_id,
    customerName: row.customer_name,
    customerPhone: row.customer_phone,
    pointsEarned: row.points_earned ?? 0,
    guestCount: row.guest_count,
    status: row.status,
    note: row.note,
    subtotal: toBaht(row.subtotal),
    discountType: row.discount_type,
    discountValue:
      row.discount_type === 'percent' ? row.discount_value / 100 : toBaht(row.discount_value),
    discountAmount: toBaht(row.discount_amount),
    promotionId: row.promotion_id ?? null,
    promotionName: row.promotion_name_snapshot ?? null,
    promotionCode: row.promotion_code_snapshot ?? null,
    promotionDiscountAmount: toBaht(row.promotion_discount_amount ?? 0),
    serviceCharge: toBaht(row.service_charge),
    vat: toBaht(row.vat),
    total: toBaht(row.total),
    cancelledReason: row.cancelled_reason,
    createdAt: row.created_at,
    updatedAt: row.updated_at,
    closedAt: row.closed_at,
    items: items.map(toOrderItemDto),
    itemCount: items.filter((item) => item.status !== 'cancelled').length,
  };
};
