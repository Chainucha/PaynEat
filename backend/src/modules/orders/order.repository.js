// Copyright 2026 Suruch Chakrapeesirisuk
// SPDX-License-Identifier: Apache-2.0

import { getDb } from '../../db/index.js';

const ORDER_SELECT = `
  SELECT o.*,
         t.name AS table_name,
         t.zone AS table_zone,
         u.name AS waiter_name,
         c.name AS customer_name,
         c.phone AS customer_phone
    FROM orders o
    LEFT JOIN dining_tables t ON t.id = o.table_id
    LEFT JOIN users u ON u.id = o.waiter_id
    LEFT JOIN customers c ON c.id = o.customer_id
`;

export const orderRepository = {
  /** เลขที่ออเดอร์รูปแบบ ORD-YYYYMMDD-0001 (รันต่อวัน) */
  nextCode() {
    const today = new Date();
    const datePart = [
      today.getFullYear(),
      String(today.getMonth() + 1).padStart(2, '0'),
      String(today.getDate()).padStart(2, '0'),
    ].join('');
    const prefix = `ORD-${datePart}`;
    const last = getDb()
      .prepare('SELECT code FROM orders WHERE code LIKE ? ORDER BY id DESC LIMIT 1')
      .get(`${prefix}%`);
    const sequence = last ? Number(last.code.split('-')[2]) + 1 : 1;
    return `${prefix}-${String(sequence).padStart(4, '0')}`;
  },

  /**
   * เลขคิวรับอาหารสำหรับ takeaway รันต่อวันแยกจาก `code` (เริ่มที่ 1 ใหม่ทุกวัน) — ใช้ตอนเรียก
   * ลูกค้ามารับอาหารหน้าร้าน (ดู docs/tickets/10-takeaway-delivery-flow.md)
   */
  nextQueueNumber() {
    const last = getDb()
      .prepare(
        `
        SELECT MAX(queue_number) AS maxNumber
          FROM orders
         WHERE type = 'takeaway'
           AND date(created_at) = date('now')
      `,
      )
      .get();
    return (last?.maxNumber ?? 0) + 1;
  },

  findAll({
    status,
    statuses,
    tableId,
    waiterId,
    customerId,
    dateFrom,
    dateTo,
    branchId,
    page = 1,
    limit = 20,
  } = {}) {
    const clauses = [];
    const params = [];

    // branchId เป็น null/undefined เฉพาะ admin โหมด "ทุกสาขา" (ดู docs/DECISIONS.md #36)
    if (branchId) {
      clauses.push('o.branch_id = ?');
      params.push(branchId);
    }
    if (status) {
      clauses.push('o.status = ?');
      params.push(status);
    }
    if (statuses?.length) {
      clauses.push(`o.status IN (${statuses.map(() => '?').join(',')})`);
      params.push(...statuses);
    }
    if (tableId) {
      clauses.push('o.table_id = ?');
      params.push(tableId);
    }
    if (waiterId) {
      clauses.push('o.waiter_id = ?');
      params.push(waiterId);
    }
    if (customerId) {
      clauses.push('o.customer_id = ?');
      params.push(customerId);
    }
    if (dateFrom) {
      clauses.push('date(o.created_at) >= date(?)');
      params.push(dateFrom);
    }
    if (dateTo) {
      clauses.push('date(o.created_at) <= date(?)');
      params.push(dateTo);
    }

    const where = clauses.length ? `WHERE ${clauses.join(' AND ')}` : '';
    const db = getDb();
    const total = db.prepare(`SELECT COUNT(*) AS c FROM orders o ${where}`).get(...params).c;
    const rows = db
      .prepare(`${ORDER_SELECT} ${where} ORDER BY o.created_at DESC, o.id DESC LIMIT ? OFFSET ?`)
      .all(...params, limit, (page - 1) * limit);

    return { rows, total };
  },

  findById(id) {
    return getDb().prepare(`${ORDER_SELECT} WHERE o.id = ?`).get(id);
  },

  findByCode(code) {
    return getDb().prepare(`${ORDER_SELECT} WHERE o.code = ?`).get(code);
  },

  findOpenByTable(tableId) {
    return getDb()
      .prepare(
        `${ORDER_SELECT} WHERE o.table_id = ? AND o.status IN ('open','in_kitchen','served') LIMIT 1`,
      )
      .get(tableId);
  },

  /** category_id มาจาก menu_items ปัจจุบัน (ไม่ใช่ snapshot) — ใช้ตอนจับคู่เงื่อนไขโปรโมชันตามหมวดหมู่ */
  findItems(orderId) {
    return getDb()
      .prepare(
        `
        SELECT oi.*, m.category_id AS category_id
          FROM order_items oi
          LEFT JOIN menu_items m ON m.id = oi.menu_item_id
         WHERE oi.order_id = ?
         ORDER BY oi.id
      `,
      )
      .all(orderId);
  },

  findItemsByStatuses(statuses) {
    const placeholders = statuses.map(() => '?').join(',');
    return getDb()
      .prepare(
        `
        SELECT oi.*, o.code AS order_code, o.type AS order_type, t.name AS table_name
          FROM order_items oi
          JOIN orders o ON o.id = oi.order_id
          LEFT JOIN dining_tables t ON t.id = o.table_id
         WHERE oi.status IN (${placeholders})
           AND o.status IN ('in_kitchen', 'served')
         ORDER BY oi.created_at
      `,
      )
      .all(...statuses);
  },

  findItemById(itemId) {
    return getDb().prepare('SELECT * FROM order_items WHERE id = ?').get(itemId);
  },

  create({ code, type, tableId, waiterId, customerId, guestCount, note, queueNumber, branchId }) {
    const info = getDb()
      .prepare(
        `
        INSERT INTO orders (code, type, table_id, waiter_id, customer_id, guest_count, note, queue_number, branch_id)
        VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)
      `,
      )
      .run(
        code,
        type,
        tableId ?? null,
        waiterId ?? null,
        customerId ?? null,
        guestCount ?? 1,
        note ?? null,
        queueNumber ?? null,
        branchId,
      );
    return this.findById(info.lastInsertRowid);
  },

  addItem(orderId, item) {
    const info = getDb()
      .prepare(
        `
        INSERT INTO order_items
          (order_id, menu_item_id, name_snapshot, unit_price, quantity, options_json, options_price, line_total, weight_grams, note)
        VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
      `,
      )
      .run(
        orderId,
        item.menuItemId,
        item.nameSnapshot,
        item.unitPrice,
        item.quantity,
        JSON.stringify(item.options ?? []),
        item.optionsPrice,
        item.lineTotal,
        item.weightGrams ?? null,
        item.note ?? null,
      );
    return this.findItemById(info.lastInsertRowid);
  },

  updateItem(itemId, { quantity, note, lineTotal, status, stockDeducted, kitchenReached }) {
    getDb()
      .prepare(
        `
        UPDATE order_items
           SET quantity        = COALESCE(?, quantity),
               note            = COALESCE(?, note),
               line_total      = COALESCE(?, line_total),
               status          = COALESCE(?, status),
               stock_deducted  = COALESCE(?, stock_deducted),
               kitchen_reached = COALESCE(?, kitchen_reached),
               updated_at      = datetime('now')
         WHERE id = ?
      `,
      )
      .run(
        quantity ?? null,
        note ?? null,
        lineTotal ?? null,
        status ?? null,
        stockDeducted === undefined ? null : Number(stockDeducted),
        kitchenReached ?? null,
        itemId,
      );
    return this.findItemById(itemId);
  },

  removeItem(itemId) {
    return getDb().prepare('DELETE FROM order_items WHERE id = ?').run(itemId).changes > 0;
  },

  markItemsStatus(orderId, fromStatus, toStatus) {
    return getDb()
      .prepare(
        "UPDATE order_items SET status = ?, updated_at = datetime('now') WHERE order_id = ? AND status = ?",
      )
      .run(toStatus, orderId, fromStatus).changes;
  },

  /** ส่วนลดมือของบิล — ยอดคำนวณใหม่ใน transaction เดียวกันโดย orderService (changeOrder) */
  setDiscount(orderId, { discountType, discountValue }) {
    getDb()
      .prepare(
        "UPDATE orders SET discount_type = ?, discount_value = ?, updated_at = datetime('now') WHERE id = ?",
      )
      .run(discountType, discountValue, orderId);
  },

  /** โปรโมชันที่ผูกกับบิล (null = ถอด) — ยอดคำนวณใหม่ใน transaction เดียวกันโดย orderService (changeOrder) */
  setPromotion(orderId, { promotionId, promotionName, promotionCode }) {
    getDb()
      .prepare(
        `UPDATE orders
            SET promotion_id = ?, promotion_name_snapshot = ?, promotion_code_snapshot = ?,
                updated_at = datetime('now')
          WHERE id = ?`,
      )
      .run(promotionId ?? null, promotionName ?? null, promotionCode ?? null, orderId);
  },

  updateTotals(orderId, totals) {
    getDb()
      .prepare(
        `
        UPDATE orders
           SET subtotal                  = ?,
               discount_type             = ?,
               discount_value            = ?,
               discount_amount           = ?,
               promotion_id              = ?,
               promotion_name_snapshot   = ?,
               promotion_code_snapshot   = ?,
               promotion_discount_amount = ?,
               service_charge            = ?,
               vat                       = ?,
               total                     = ?,
               updated_at                = datetime('now')
         WHERE id = ?
      `,
      )
      .run(
        totals.subtotal,
        totals.discountType,
        totals.discountValue,
        totals.discountAmount,
        totals.promotionId ?? null,
        totals.promotionName ?? null,
        totals.promotionCode ?? null,
        totals.promotionDiscountAmount ?? 0,
        totals.serviceCharge,
        totals.vat,
        totals.total,
        orderId,
      );
  },

  updateStatus(orderId, status, { closedAt = null, cancelledReason = null } = {}) {
    getDb()
      .prepare(
        `
        UPDATE orders
           SET status           = ?,
               closed_at        = COALESCE(?, closed_at),
               cancelled_reason = COALESCE(?, cancelled_reason),
               updated_at       = datetime('now')
         WHERE id = ?
      `,
      )
      .run(status, closedAt, cancelledReason, orderId);
    return this.findById(orderId);
  },

  /** บันทึกแต้มสะสมที่ลูกค้าได้รับตอนออเดอร์นี้จ่ายครบ (ครั้งเดียว ดู payment.service.js#pay) */
  setPointsEarned(orderId, points) {
    getDb()
      .prepare("UPDATE orders SET points_earned = ?, updated_at = datetime('now') WHERE id = ?")
      .run(points, orderId);
    return this.findById(orderId);
  },

  updateTable(orderId, tableId) {
    getDb()
      .prepare("UPDATE orders SET table_id = ?, updated_at = datetime('now') WHERE id = ?")
      .run(tableId, orderId);
    return this.findById(orderId);
  },

  /** ย้ายรายการอาหารทั้งหมดของออเดอร์หนึ่งไปอยู่ในอีกออเดอร์หนึ่ง (ใช้ตอนรวมบิล) */
  reassignItems(fromOrderId, toOrderId) {
    return getDb()
      .prepare(
        "UPDATE order_items SET order_id = ?, updated_at = datetime('now') WHERE order_id = ?",
      )
      .run(toOrderId, fromOrderId).changes;
  },

  /** รายการที่เลือกแยกจ่าย — จำ payment ที่จ่ายไว้ด้วย เพื่อปลดเมื่อ payment นั้นถูกคืนเงินครบ (T06 #82) */
  markItemsPaid(itemIds, paymentId) {
    if (!itemIds.length) return 0;
    const placeholders = itemIds.map(() => '?').join(',');
    return getDb()
      .prepare(
        `UPDATE order_items SET is_paid = 1, paid_by_payment_id = ?, updated_at = datetime('now')
          WHERE id IN (${placeholders})`,
      )
      .run(paymentId, ...itemIds).changes;
  },

  /** payment ที่แยกจ่ายถูกคืนเงินครบบนบิลที่ยังเปิด — รายการของ payment นั้นกลับเป็นยังไม่จ่าย (T06 #82) */
  releaseItemsPaidBy(paymentId) {
    return getDb()
      .prepare(
        `UPDATE order_items SET is_paid = 0, paid_by_payment_id = NULL, updated_at = datetime('now')
          WHERE paid_by_payment_id = ?`,
      )
      .run(paymentId).changes;
  },

  updateMeta(orderId, { guestCount, note }) {
    getDb()
      .prepare(
        `
        UPDATE orders
           SET guest_count = COALESCE(?, guest_count),
               note        = COALESCE(?, note),
               updated_at  = datetime('now')
         WHERE id = ?
      `,
      )
      .run(guestCount ?? null, note ?? null, orderId);
    return this.findById(orderId);
  },
};

export default orderRepository;
