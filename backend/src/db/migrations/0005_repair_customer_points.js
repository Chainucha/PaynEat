// Copyright 2026 Suruch Chakrapeesirisuk
// SPDX-License-Identifier: Apache-2.0

import { fileURLToPath } from 'node:url';

/**
 * Migration 0005 — ซ่อมยอดแต้มที่ไม่ใช่จำนวนเต็ม (T15 #84, docs/DECISIONS.md #89)
 *
 * ก่อนมีขั้นต่ำ 0.01 บาท อัตราสะสมแต้มที่ปัดแล้วเป็น 0 สตางค์ทำให้การหารได้ Infinity ซึ่ง SQLite เก็บลงคอลัมน์
 * INTEGER เป็นค่า REAL ได้ (typeof = 'real') API ส่งออกไปเป็น null และแลกแต้มเท่าไหร่ยอดก็ไม่ลด
 *
 * - `orders.points_earned` ที่ไม่ใช่จำนวนเต็ม → 0: อัตราตอนขายใช้คิดแต้มไม่ได้ เหมือนกฎปัจจุบัน (ไม่ได้แต้ม)
 * - `customers.points_balance` ที่ไม่ใช่จำนวนเต็ม → คิดใหม่จากประวัติ: แต้มที่ได้จากทุกบิลของลูกค้า (หลังซ่อมข้อแรก)
 *   − แต้มที่ใช้แลกไปแล้วทุกครั้ง ไม่ต่ำกว่า 0 ลูกค้าจึงยังได้แต้มที่สะสมมาตามปกติ ส่วนแต้มที่ใช้ไปตอนยอดเสียถูกหักออก
 * - ลูกค้าที่ถูกซ่อมมี audit log `customer.points_repair` ผู้ทำ "ระบบ" บอกยอดใหม่และที่มา ผู้ดูแลตรวจย้อนหลังได้
 *
 * ใช้ SQL ตรง ๆ ไม่เรียก service เพราะ migration ต้องให้ผลเหมือนเดิมเสมอแม้โค้ดส่วนอื่นเปลี่ยนภายหลัง
 */

/** ค่าที่ไม่ใช่จำนวนเต็ม — Infinity ถูกเก็บเป็น REAL */
const broken = (column) => `typeof(${column}) != 'integer'`;

export default {
  version: 5,
  name: 'repair_customer_points',
  files: [fileURLToPath(import.meta.url)],
  up(db) {
    const brokenOrders = db
      .prepare(`SELECT id, customer_id FROM orders WHERE ${broken('points_earned')}`)
      .all();
    db.prepare(`UPDATE orders SET points_earned = 0 WHERE ${broken('points_earned')}`).run();

    const customers = db
      .prepare(`SELECT id, name FROM customers WHERE ${broken('points_balance')} ORDER BY id`)
      .all();
    const earnedBy = db.prepare(
      'SELECT COALESCE(SUM(points_earned), 0) AS points FROM orders WHERE customer_id = ?',
    );
    const redeemedBy = db.prepare(
      `SELECT COALESCE(SUM(p.points_redeemed), 0) AS points
         FROM payments p JOIN orders o ON o.id = p.order_id
        WHERE o.customer_id = ?`,
    );
    const setBalance = db.prepare(
      "UPDATE customers SET points_balance = ?, updated_at = datetime('now') WHERE id = ?",
    );
    const audit = db.prepare(
      `INSERT INTO audit_logs (actor_user_id, actor_name, action, entity_type, entity_id, summary, metadata_json)
       VALUES (NULL, 'ระบบ', 'customer.points_repair', 'customer', ?, ?, ?)`,
    );

    for (const customer of customers) {
      const earned = earnedBy.get(customer.id).points;
      const redeemed = redeemedBy.get(customer.id).points;
      const points = Math.max(earned - redeemed, 0);
      setBalance.run(points, customer.id);
      audit.run(
        customer.id,
        `ซ่อมยอดแต้มของลูกค้า "${customer.name}" ที่เสีย เป็น ${points} แต้ม ` +
          `(คิดใหม่จากประวัติ: ได้ ${earned} ใช้ไป ${redeemed})`,
        JSON.stringify({
          resetOrderIds: brokenOrders
            .filter((order) => order.customer_id === customer.id)
            .map((order) => order.id),
          summaryArgs: { name: customer.name, points, earned, redeemed },
        }),
      );
    }
  },
};
