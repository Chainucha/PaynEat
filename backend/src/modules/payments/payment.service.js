// Copyright 2026 Suruch Chakrapeesirisuk
// SPDX-License-Identifier: Apache-2.0

import { ApiError } from '../../core/ApiError.js';
import { toSatang, toBaht } from '../../core/money.js';
import { buildPromptPayPayload } from '../../core/promptpay.js';
import { getDb } from '../../db/index.js';
import { emit, EVENTS } from '../../realtime/socket.js';
import { orderRepository } from '../orders/order.repository.js';
import { orderService } from '../orders/order.service.js';
import { calculateItemsShare } from '../orders/order.calculator.js';
import { tableRepository } from '../tables/table.repository.js';
import { settingsService } from '../settings/settings.service.js';
import { shiftRepository } from '../shifts/shift.repository.js';
import { auditLogService } from '../audit-logs/audit-log.service.js';
import { customerRepository } from '../customers/customer.repository.js';
import { ingredientService } from '../ingredients/ingredient.service.js';
import { creditNoteService } from '../receivables/credit-note.service.js';
import { creditPoints } from '../receivables/credit-points.js';
import { receivableService } from '../receivables/receivable.service.js';
import { paymentRepository } from './payment.repository.js';
import { refundRepository } from './refund.repository.js';
import { toPaymentDto } from './payment.mapper.js';
import { toRefundDto } from './refund.mapper.js';

/** ตรวจว่ารายการที่เลือกแยกบิลถูกต้อง — อยู่ในออเดอร์จริง ยังไม่ถูกยกเลิก และยังไม่ถูกจ่ายไปก่อนหน้า */
const assertItemsSelectable = (items, itemIds) => {
  const missing = itemIds.find((id) => !items.some((item) => item.id === id));
  if (missing) throw ApiError.badRequest('มีรายการที่ไม่ได้อยู่ในออเดอร์นี้');

  const targeted = items.filter((item) => itemIds.includes(item.id));
  const paidPick = targeted.find((item) => item.is_paid);
  if (paidPick) throw ApiError.conflict(`"${paidPick.name_snapshot}" ถูกจ่ายไปแล้ว`);
  const cancelledPick = targeted.find((item) => item.status === 'cancelled');
  if (cancelledPick) {
    throw ApiError.badRequest(`"${cancelledPick.name_snapshot}" ถูกยกเลิกไปแล้ว เลือกจ่ายไม่ได้`);
  }
};

/** คำนวณยอดที่ต้องจ่ายจากรายการที่เลือก — บังคับให้เท่ายอดคงเหลือพอดีถ้าเป็นรอบสุดท้าย กันเศษสตางค์ตกหล่น */
const computeItemsAmount = (order, items, itemIds, remaining) => {
  const settings = settingsService.get();
  const share = calculateItemsShare({
    items,
    selectedIds: itemIds,
    discountType: order.discount_type,
    discountValue: order.discount_value,
    vatRate: settings.vatRate,
    serviceChargeRate: settings.serviceChargeRate,
    vatIncluded: settings.vatIncluded,
  });
  return {
    amount: share.isLastBatch ? remaining : Math.min(share.total, remaining),
    share,
  };
};

export const paymentService = {
  listByOrder(orderId) {
    return paymentRepository.findByOrder(orderId).map(toPaymentDto);
  },

  /** สรุปยอดค้างชำระของออเดอร์ ใช้เปิดหน้าจ่ายเงิน */
  summary(orderId) {
    const order = orderRepository.findById(orderId);
    if (!order) throw ApiError.notFound('ไม่พบออเดอร์นี้');
    const paid = paymentRepository.totalPaid(orderId);
    return {
      orderId,
      total: toBaht(order.total),
      paid: toBaht(paid),
      remaining: toBaht(Math.max(order.total - paid, 0)),
      payments: this.listByOrder(orderId),
    };
  },

  /** ดูยอดที่ต้องจ่ายล่วงหน้าก่อนแยกบิล โดยยังไม่ตัดจ่ายจริง */
  splitPreview(orderId, itemIds) {
    const order = orderRepository.findById(orderId);
    if (!order) throw ApiError.notFound('ไม่พบออเดอร์นี้');
    if (order.status === 'cancelled') throw ApiError.conflict('ออเดอร์นี้ถูกยกเลิกแล้ว');
    if (order.status === 'paid') throw ApiError.conflict('ออเดอร์นี้ชำระเงินครบแล้ว');

    const items = orderRepository.findItems(order.id);
    assertItemsSelectable(items, itemIds);

    const alreadyPaid = paymentRepository.totalPaid(order.id);
    const remaining = Math.max(order.total - alreadyPaid, 0);
    const { amount, share } = computeItemsAmount(order, items, itemIds, remaining);

    return {
      orderId: order.id,
      itemIds,
      subtotal: toBaht(share.subtotal),
      discountAmount: toBaht(share.discountAmount),
      serviceCharge: toBaht(share.serviceCharge),
      vat: toBaht(share.vat),
      total: toBaht(amount),
      remaining: toBaht(remaining),
      isLastBatch: share.isLastBatch,
    };
  },

  pay(payload, user) {
    const shift = shiftRepository.findOpen();
    if (!shift) throw ApiError.conflict('ต้องเปิดกะก่อนจึงจะรับชำระเงินได้');

    const order = orderRepository.findById(payload.orderId);
    if (!order) throw ApiError.notFound('ไม่พบออเดอร์นี้');
    if (order.status === 'cancelled') throw ApiError.conflict('ออเดอร์นี้ถูกยกเลิกแล้ว');
    if (order.status === 'paid') throw ApiError.conflict('ออเดอร์นี้ชำระเงินครบแล้ว');

    const allItems = orderRepository.findItems(order.id);
    const activeItems = allItems.filter((item) => item.status !== 'cancelled');
    if (activeItems.length === 0) throw ApiError.badRequest('ออเดอร์ยังไม่มีรายการอาหาร');

    const alreadyPaid = paymentRepository.totalPaid(order.id);
    const remaining = order.total - alreadyPaid;

    const itemIds = payload.itemIds?.length ? payload.itemIds : null;
    let amount;
    if (itemIds) {
      assertItemsSelectable(allItems, itemIds);
      amount = computeItemsAmount(order, allItems, itemIds, remaining).amount;
    } else {
      amount = toSatang(payload.amount);
    }

    if (amount > remaining) {
      throw ApiError.badRequest(`ยอดชำระเกินยอดคงเหลือ (คงเหลือ ${toBaht(remaining)} บาท)`);
    }

    // ใช้แต้มสะสมแลกส่วนลดรอบจ่ายนี้ (ดู docs/tickets/09-customer-loyalty.md) — amount (ยอดที่นับ
    // เข้ายอดจ่ายของออเดอร์) ไม่เปลี่ยน มีแค่ยอดที่ต้องเก็บจริงผ่านช่องทางที่เลือก (chargedAmount)
    // ที่ลดลง เพื่อไม่ให้บัญชี alreadyPaid/isFullyPaid ของออเดอร์คลาดเคลื่อน
    const pointsToRedeem = payload.pointsToRedeem ?? 0;
    const settings = settingsService.get();

    // ขายเชื่อ (ดู docs/tickets/20-b2b-credit.md) — ปิดบิลโดยยังไม่มีเงินเข้า ยอดนี้กลายเป็นหนี้ของ
    // ลูกค้าที่ผูกกับออเดอร์ จึงต้องมีลูกค้าเครดิตที่วงเงินพอ และเป็นการตัดสินใจให้ลูกค้าติดเงินร้าน
    // พนักงานเสิร์ฟ (ที่รับชำระเงินสด/QR ได้ปกติ) จึงทำไม่ได้ แต้มสะสมใช้ร่วมไม่ได้ เพราะหนี้ต้องเท่ากับ
    // ยอดที่บันทึกในบิลพอดี ไม่งั้นยอดค้างจะไม่ตรงกับใบวางบิล
    let dueDate = null;
    if (payload.method === 'credit') {
      if (user?.role === 'waiter') {
        throw ApiError.forbidden('ขายเชื่อต้องให้แคชเชียร์หรือผู้จัดการเป็นคนทำรายการ');
      }
      if (!order.customer_id) {
        throw ApiError.badRequest('ขายเชื่อต้องผูกออเดอร์กับลูกค้าเครดิตก่อน');
      }
      if (pointsToRedeem > 0) {
        throw ApiError.badRequest('ขายเชื่อใช้แต้มสะสมแลกส่วนลดร่วมด้วยไม่ได้');
      }
      ({ dueDate } = receivableService.assertCanCharge(order.customer_id, amount));
    }
    let pointsRedeemedValue = 0;
    if (pointsToRedeem > 0) {
      if (!order.customer_id) {
        throw ApiError.badRequest('ต้องผูกลูกค้ากับออเดอร์นี้ก่อนจึงใช้แต้มสะสมได้');
      }
      const customer = customerRepository.findById(order.customer_id);
      if (!customer || pointsToRedeem > customer.points_balance) {
        throw ApiError.badRequest('แต้มสะสมของลูกค้าไม่พอ');
      }
      pointsRedeemedValue = toSatang(pointsToRedeem * settings.pointsRedeemValueBaht);
      if (pointsRedeemedValue > amount) {
        throw ApiError.badRequest('แต้มที่ใช้มีมูลค่าเกินยอดที่ต้องชำระรอบนี้');
      }
    }
    const chargedAmount = amount - pointsRedeemedValue;

    const receivedBaht = payload.received ?? toBaht(chargedAmount);
    if (payload.method === 'cash' && toSatang(receivedBaht) < chargedAmount) {
      throw ApiError.badRequest('เงินที่รับมาต้องไม่น้อยกว่ายอดที่ชำระ');
    }
    const received = payload.method === 'cash' ? toSatang(receivedBaht) : chargedAmount;
    const changeAmount = payload.method === 'cash' ? Math.max(received - chargedAmount, 0) : 0;
    const isFullyPaid = alreadyPaid + amount >= order.total;

    const run = getDb().transaction(() => {
      const payment = paymentRepository.create({
        orderId: order.id,
        shiftId: shift.id,
        method: payload.method,
        amount,
        received,
        changeAmount,
        reference: payload.reference,
        cashierId: user?.id,
        pointsRedeemed: pointsToRedeem,
        pointsRedeemedValue,
        dueDate,
      });

      // รับชำระเงินกระทบเงินสด/ยอดขายโดยตรง audit เหมือนคืนเงิน (refund) — ดู
      // docs/tickets/14-financial-audit-trail.md
      auditLogService.log({
        actorUser: user,
        action: 'payment.pay',
        summaryArgs: {
          code: order.code ?? order.id,
          amount: toBaht(chargedAmount),
          method: payload.method,
        },
        entityType: 'payment',
        entityId: payment.id,
        summary: `รับชำระเงิน ${toBaht(chargedAmount)} บาท (${payload.method}) ออเดอร์ #${order.code ?? order.id}`,
        metadata: {
          orderId: order.id,
          method: payload.method,
          amount: toBaht(amount),
          chargedAmount: toBaht(chargedAmount),
          pointsRedeemed: pointsToRedeem,
        },
      });

      if (pointsToRedeem > 0) {
        customerRepository.adjustPoints(order.customer_id, -pointsToRedeem);
      }
      if (itemIds) orderRepository.markItemsPaid(itemIds);

      if (isFullyPaid) {
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
          const earnRateSatang = toSatang(settings.pointsEarnRateBaht);
          const pointsEarned = Math.floor(order.total / earnRateSatang);
          if (pointsEarned > 0) {
            orderRepository.setPointsEarned(order.id, pointsEarned);
            customerRepository.adjustPoints(order.customer_id, pointsEarned);
          }
        }
      }
      return payment.id;
    });

    const paymentId = run();
    const result = {
      payment: toPaymentDto(paymentRepository.findById(paymentId)),
      order: orderService.getById(order.id),
      isFullyPaid,
      remaining: toBaht(Math.max(order.total - (alreadyPaid + amount), 0)),
    };

    if (isFullyPaid) {
      emit(EVENTS.ORDER_PAID, result.order);
      if (order.table_id) emit(EVENTS.TABLE_UPDATED, { id: order.table_id, status: 'available' });
    }
    emit(EVENTS.ORDER_UPDATED, result.order);
    return result;
  },

  /**
   * payload สำหรับ QR พร้อมเพย์ (ดู docs/tickets/16-promptpay-qr.md) — ให้ client เรนเดอร์เป็น
   * ภาพ QR เอง ไม่ generate ภาพที่ฝั่ง backend เพื่อไม่ต้องเพิ่ม dependency ฝั่งนี้ ยอด (amount)
   * เป็น optional ให้ตรงกับสเปก EMV QR เอง — ถ้าไม่ระบุจะได้ static QR ที่สแกนแล้วกรอกยอดเองได้
   */
  promptPayQr(amount) {
    const settings = settingsService.get();
    if (!settings.promptPayId) {
      throw ApiError.badRequest('ร้านยังไม่ได้ตั้งค่าเลขพร้อมเพย์ (ตั้งได้ที่หน้าตั้งค่าระบบ)');
    }
    return {
      payload: buildPromptPayPayload({ promptPayId: settings.promptPayId, amount }),
      promptPayId: settings.promptPayId,
      amount: amount ?? null,
    };
  },

  /** ข้อมูลสำหรับพิมพ์ใบเสร็จ */
  receipt(orderId) {
    const order = orderService.getById(orderId);
    const settings = settingsService.get();
    const payments = this.listByOrder(orderId);
    const refunds = refundRepository.findByOrder(orderId).map(toRefundDto);

    return {
      store: {
        name: settings.storeName,
        currency: settings.currency,
        vatRate: settings.vatRate,
        serviceChargeRate: settings.serviceChargeRate,
      },
      order,
      payments,
      refunds,
      refundedTotal: refunds.reduce((acc, refund) => acc + refund.amount, 0),
      paidAt: order.closedAt,
      changeTotal: payments.reduce((acc, payment) => acc + payment.change, 0),
    };
  },

  /**
   * คืนเงินหลังชำระเงินแล้ว (เต็มจำนวน/บางส่วน) — ผูกกับ payment โดยตรงเพราะออเดอร์
   * เดียวอาจมีหลาย payment (แยกจ่าย) แยกเป็น record ใหม่เสมอเพื่อเก็บ audit trail
   * ไม่แก้ payment เดิมหรือสถานะออเดอร์ — ยอดขายสุทธิหักออกตอนทำรายงานแทน
   */
  refund(paymentId, { amount, reason }, user) {
    const payment = paymentRepository.findById(paymentId);
    if (!payment) throw ApiError.notFound('ไม่พบรายการชำระเงินนี้');

    const amountSatang = toSatang(amount);
    const alreadyRefunded = refundRepository.totalByPayment(paymentId);
    const refundable = payment.amount - alreadyRefunded;
    if (amountSatang > refundable) {
      throw ApiError.badRequest(`คืนเงินเกินยอดที่คืนได้ (คืนได้สูงสุด ${toBaht(refundable)} บาท)`);
    }
    // บิลขายเชื่อไม่มีเงินให้คืน การคืนคือ "ลดหนี้" จึงลดได้ไม่เกินยอดที่ยังค้าง — ส่วนที่ลูกค้าชำระหนี้
    // มาแล้วต้องยกเลิกใบเสร็จรับชำระก่อน ไม่งั้นยอดค้างติดลบกลายเป็นร้านเป็นหนี้ลูกค้าโดยไม่มีใครเห็น
    if (payment.method === 'credit') {
      const creditRefundable = receivableService.creditRefundable(paymentId);
      if (amountSatang > creditRefundable) {
        throw ApiError.badRequest(
          `บิลขายเชื่อนี้ค้างชำระอยู่ ${toBaht(creditRefundable)} บาท ลดหนี้ได้ไม่เกินยอดนี้ ` +
            '(ส่วนที่ชำระแล้วต้องยกเลิกใบเสร็จรับชำระก่อน)',
        );
      }
    }

    // เงินสดที่คืนลูกค้าออกจากลิ้นชักจริง จึงต้องมีกะเปิดอยู่ให้ผูก — กฎเดียวกับตอนรับเงิน (ดู pay())
    // ไม่งั้นยอดที่คาดไว้ตอนปิดกะจะเกินเงินจริง แคชเชียร์ที่นับถูกจะถูกบันทึกว่าเงินขาด (DECISIONS #44)
    // คืนผ่าน QR/บัตร/โอนไม่แตะลิ้นชักจึงไม่บังคับ แต่ยังผูกกะไว้ถ้ามี ให้รู้ว่าคืนระหว่างกะไหน
    const shift = shiftRepository.findOpen();
    if (!shift && payment.method === 'cash') {
      throw ApiError.conflict('ต้องเปิดกะก่อนจึงจะคืนเงินสดได้');
    }

    const order = orderRepository.findById(payment.order_id);

    const refund = getDb().transaction(() => {
      const created = refundRepository.create({
        paymentId,
        orderId: payment.order_id,
        amount: amountSatang,
        reason,
        refundedBy: user.id,
        shiftId: shift?.id,
      });
      auditLogService.log({
        actorUser: user,
        action: 'payment.refund',
        summaryArgs: { code: order?.code ?? payment.order_id, amount: toBaht(amountSatang) },
        entityType: 'refund',
        entityId: created.id,
        summary: `คืนเงิน ${toBaht(amountSatang)} บาท ให้ออเดอร์ #${order?.code ?? payment.order_id}`,
        reason,
        metadata: { paymentId, orderId: payment.order_id, amount: toBaht(amountSatang) },
      });
      // ลดหนี้บิลขายเชื่อต้องมีเอกสารให้ลูกค้าเสมอ (ใบลดหนี้ DECISIONS #56) — ออกในทรานแซกชันเดียวกัน
      // ถ้าออกเอกสารไม่สำเร็จ การลดหนี้ก็ต้องไม่เกิด
      if (payment.method === 'credit') {
        creditNoteService.issueForRefund({
          payment,
          order,
          refund: created,
          previousCredited: alreadyRefunded,
          user,
        });
        // ลดหนี้ส่วนที่เหลือจนยอดค้างเป็น 0 = ชำระครบแล้ว ได้แต้มจากยอดสุทธิหลังลดหนี้ (#59)
        creditPoints.sync(payment.order_id);
      }
      return refundRepository.findById(created.id);
    })();

    const dto = toRefundDto(refund);
    emit(EVENTS.REFUND_CREATED, dto);
    return dto;
  },
};

export default paymentService;
