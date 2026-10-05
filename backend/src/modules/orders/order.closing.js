// Copyright 2026 Suruch Chakrapeesirisuk
// SPDX-License-Identifier: Apache-2.0

import { tableRepository } from '../tables/table.repository.js';
import { settingsService } from '../settings/settings.service.js';
import { ingredientService } from '../ingredients/ingredient.service.js';
import { customerRepository } from '../customers/customer.repository.js';
import { pointsForAmount } from '../customers/loyalty.js';
import { creditPoints } from '../receivables/credit-points.js';
import { orderRepository } from './order.repository.js';

/**
 * ปิดบิลที่ร้านเก็บเงินครบยอดสุทธิแล้ว — ใช้ทั้งตอนรับชำระรอบสุดท้าย (`paymentService.pay`) และตอนแก้บิลจนยอดเท่ากับเงินที่รับไว้
 * พอดี (T07 #105, DECISIONS #95) ต้องเรียกใน transaction ของผู้เรียก ไม่ส่ง event เอง
 */
export const closeFullyPaidOrder = (order) => {
  const activeItems = orderRepository
    .findItems(order.id)
    .filter((item) => item.status !== 'cancelled');
  // สินค้าที่ขายไปต้องออกจากสต๊อกเสมอ แม้บิลนั้นไม่เคยผ่านปุ่ม "ส่งเข้าครัว" — หน้าร้านขายของ
  // (เช่นเคาน์เตอร์เนื้อที่ชั่งแล้วจ่ายเลย) หรือบิลที่จ่ายก่อนทำอาหาร เดิมไม่ถูกตัดสต๊อกเลย
  // stock_deducted กันตัดซ้ำรายการที่ส่งครัวไปแล้ว (ดู docs/DECISIONS.md #51)
  for (const item of activeItems) {
    if (!item.stock_deducted) {
      ingredientService.deductForOrderItem(item);
      orderRepository.updateItem(item.id, { stockDeducted: true });
    }
  }
  orderRepository.updateStatus(order.id, 'paid', { closedAt: new Date().toISOString() });
  if (order.table_id) tableRepository.setStatus(order.table_id, 'available');
  // สะสมแต้มให้ลูกค้าที่ผูกไว้ครั้งเดียวตอนออเดอร์นี้จ่ายครบ (ไม่ผูกลูกค้า = ไม่ได้แต้ม)
  // ออเดอร์ที่มีส่วนขายเชื่อยังไม่ได้เงินจริง แต้มรอไปให้ตอนรับชำระหนี้ครบ (credit-points.js, #59)
  // — ให้ sync ตัดสิน เผื่อส่วนขายเชื่อถูกชำระหนี้ครบไปก่อนที่ส่วนที่เหลือของบิลจะจ่ายรอบนี้
  if (order.customer_id && creditPoints.hasCredit(order.id)) {
    creditPoints.sync(order.id);
  } else if (order.customer_id) {
    const pointsEarned = pointsForAmount(order.total, settingsService.get().pointsEarnRateBaht);
    if (pointsEarned > 0) {
      orderRepository.setPointsEarned(order.id, pointsEarned);
      customerRepository.adjustPoints(order.customer_id, pointsEarned);
    }
  }
};
