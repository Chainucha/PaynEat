// Copyright 2026 Suruch Chakrapeesirisuk
// SPDX-License-Identifier: Apache-2.0

import { customerRepository } from '../customers/customer.repository.js';
import { pointsForAmount } from '../customers/loyalty.js';
import { orderRepository } from '../orders/order.repository.js';
import { refundRepository } from '../payments/refund.repository.js';
import { settingsService } from '../settings/settings.service.js';
import { receivableRepository } from './receivable.repository.js';

/**
 * แต้มสะสมของบิลขายเชื่อ (ดู docs/DECISIONS.md #59) — ได้ตอน "รับชำระครบ" ไม่ใช่ตอนลงบัญชี
 *
 * บิลที่จ่ายด้วยเงินจริงทั้งใบยังได้แต้มตอนปิดบิลเหมือนเดิม (payment.service.js#pay) ส่วนออเดอร์ที่มีส่วนใด
 * ขายเชื่อ pay() จะไม่ให้แต้ม แล้วให้ฟังก์ชันนี้ตัดสินทุกครั้งที่ยอดค้างของบิลนั้นขยับ: รับชำระหนี้,
 * ยกเลิกใบเสร็จรับชำระ, ลดหนี้ (ใบลดหนี้), ยกเลิกใบแจ้งดอกเบี้ย
 *
 * - ยอดค้างทุกบิลขายเชื่อของออเดอร์ (รวมดอกเบี้ยผิดนัด) เป็น 0 = ได้แต้มจากยอดขายสุทธิของออเดอร์
 *   (ยอดบิล − ยอดที่ลดหนี้/คืนเงิน) ดอกเบี้ยที่ลูกค้าจ่ายไม่นับเป็นยอดซื้อ
 * - กลับมาค้างอีก (ยกเลิกใบเสร็จ) = ดึงแต้มคืน แต่ลูกค้าอาจใช้แต้มไปแล้ว ยอดแต้มติดลบไม่ได้ จึงดึงคืน
 *   เท่าที่มี และ orders.points_earned เก็บ "แต้มที่ยังอยู่กับลูกค้าจริง" ไว้ รอบหน้าที่ชำระครบจะได้ไม่
 *   ให้แต้มซ้ำส่วนที่ดึงคืนไม่ได้
 *
 * เรียกภายใน transaction ของคนเรียกเสมอ แต้มกับเอกสารการเงินจึงสำเร็จหรือไม่สำเร็จไปพร้อมกัน
 */
export const creditPoints = {
  /** ออเดอร์นี้มีส่วนที่ขายเชื่อไหม — มี = pay() ไม่ให้แต้มตอนปิดบิล */
  hasCredit(orderId) {
    return receivableRepository.invoicesByOrder(orderId).length > 0;
  },

  /**
   * ปรับแต้มของออเดอร์ขายเชื่อให้ตรงกับยอดค้างตอนนี้
   * @returns {{ earned: number, revoked: number, shortfall: number }} แต้มที่ให้เพิ่ม / ดึงคืนได้ /
   *   ดึงคืนไม่ได้เพราะลูกค้าใช้ไปแล้ว (บันทึกลง audit ของคนเรียก)
   */
  sync(orderId) {
    const none = { earned: 0, revoked: 0, shortfall: 0 };
    const order = orderRepository.findById(orderId);
    if (!order?.customer_id) return none;
    const invoices = receivableRepository.invoicesByOrder(orderId);
    if (invoices.length === 0) return none;

    const settled =
      order.status === 'paid' && invoices.every((invoice) => invoice.outstanding <= 0);
    const netSales = order.total - refundRepository.totalByOrder(orderId);
    const target = settled
      ? pointsForAmount(netSales, settingsService.get().pointsEarnRateBaht)
      : 0;
    const current = order.points_earned ?? 0;

    if (target > current) {
      customerRepository.adjustPoints(order.customer_id, target - current);
      orderRepository.setPointsEarned(orderId, target);
      return { ...none, earned: target - current };
    }
    if (target < current) {
      const balance = customerRepository.findById(order.customer_id)?.points_balance ?? 0;
      const revoked = Math.min(current - target, balance);
      if (revoked > 0) customerRepository.adjustPoints(order.customer_id, -revoked);
      orderRepository.setPointsEarned(orderId, current - revoked);
      return { ...none, revoked, shortfall: current - target - revoked };
    }
    return none;
  },

  /** sync หลายออเดอร์ (เช่นใบเสร็จหนึ่งใบตัดหลายบิล) แล้วรวมผลไว้ใส่ audit */
  syncOrders(orderIds) {
    const total = { earned: 0, revoked: 0, shortfall: 0 };
    for (const orderId of new Set(orderIds)) {
      const result = this.sync(orderId);
      total.earned += result.earned;
      total.revoked += result.revoked;
      total.shortfall += result.shortfall;
    }
    return total;
  },
};

export default creditPoints;
