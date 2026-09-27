// Copyright 2026 Suruch Chakrapeesirisuk
// SPDX-License-Identifier: Apache-2.0

import { ApiError } from '../../core/ApiError.js';
import { toBaht } from '../../core/money.js';
import { auditLogService } from '../audit-logs/audit-log.service.js';
import { paymentRepository } from '../payments/payment.repository.js';
import { taxInvoiceRepository } from '../tax-invoices/tax-invoice.repository.js';
import { creditNoteRepository } from './credit-note.repository.js';
import { toCreditNoteDto } from './receivable.mapper.js';
import { customerInfo, emailHistory, nextDocumentNo, storeInfo } from './receivable.shared.js';

/**
 * ใบลดหนี้ (ดู docs/tickets/21-late-fees-credit-notes.md, docs/DECISIONS.md #56)
 *
 * การลดหนี้บิลขายเชื่อยังทำผ่าน refund เดิม (payment.service.js#refund) ตัวเลขยอดขายสุทธิ/ยอดค้าง
 * ทุกที่จึงไม่ต้องเปลี่ยน — service นี้แค่ออก "เอกสาร" ให้ทุกครั้งที่มีการลดหนี้ ในทรานแซกชันเดียวกัน
 * ใบลดหนี้ต้องบอกมูลค่าตามบิลเดิม มูลค่าที่ถูกต้อง ผลต่าง VAT ของผลต่าง และอ้างเลขใบกำกับภาษีเดิม (ถ้ามี)
 */
export const creditNoteService = {
  /** เรียกจากใน transaction ของ payment.service.js#refund เมื่อบิลที่ถูกคืนเป็นบิลขายเชื่อ */
  issueForRefund({ payment, order, refund, previousCredited, user }) {
    // ราคาขายรวม VAT อยู่แล้ว VAT ของผลต่างจึงแบ่งตามสัดส่วน VAT ในบิลเดิม ไม่ใช้อัตราปัจจุบัน
    // (ถ้าร้านแก้อัตรา VAT หลังขาย ใบลดหนี้ต้องใช้อัตราเดียวกับใบกำกับภาษีใบเดิม)
    const vatAmount = order.total > 0 ? Math.round((refund.amount * order.vat) / order.total) : 0;
    const taxInvoice = taxInvoiceRepository.findActiveByOrder(order.id);
    const row = creditNoteRepository.create({
      noteNo: nextDocumentNo('credit_notes', 'note_no', 'CN'),
      customerId: order.customer_id,
      paymentId: payment.id,
      refundId: refund.id,
      orderId: order.id,
      originalAmount: payment.amount,
      previousCredited,
      amount: refund.amount,
      vatAmount,
      taxInvoiceNo: taxInvoice?.running_number ?? null,
      reason: refund.reason,
      issuedBy: user.id,
    });
    auditLogService.log({
      actorUser: user,
      action: 'receivable.credit_note',
      summaryArgs: {
        noteNo: row.note_no,
        amount: toBaht(refund.amount),
        code: order.code,
        customer: row.customer_name,
      },
      entityType: 'credit_note',
      entityId: row.id,
      summary: `ออกใบลดหนี้ ${row.note_no} ${toBaht(refund.amount)} บาท ให้บิล #${order.code} ของ "${row.customer_name}"`,
      reason: refund.reason,
      metadata: {
        noteNo: row.note_no,
        paymentId: payment.id,
        amount: toBaht(refund.amount),
        taxInvoiceNo: row.tax_invoice_no,
      },
    });
    return row;
  },

  assertCreditPayment(paymentId) {
    const payment = paymentRepository.findById(paymentId);
    if (!payment) throw ApiError.notFound('ไม่พบรายการชำระเงินนี้');
    if (payment.method !== 'credit') {
      throw ApiError.badRequest(
        'ใบลดหนี้ออกได้เฉพาะบิลขายเชื่อ — บิลที่จ่ายแล้วให้ใช้คืนเงินตามปกติ',
      );
    }
    return payment;
  },

  get(id) {
    const row = creditNoteRepository.findById(id);
    if (!row) throw ApiError.notFound('ไม่พบใบลดหนี้นี้');
    return {
      ...toCreditNoteDto(row),
      store: storeInfo(),
      customer: customerInfo(row.customer_id),
      emails: emailHistory('credit_note', row.id),
    };
  },

  getByRefund(refundId) {
    const row = creditNoteRepository.findByRefundId(refundId);
    if (!row) throw ApiError.notFound('ไม่พบใบลดหนี้ของรายการนี้');
    return this.get(row.id);
  },
};

export default creditNoteService;
