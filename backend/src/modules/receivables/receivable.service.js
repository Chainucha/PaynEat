// Copyright 2026 Suruch Chakrapeesirisuk
// SPDX-License-Identifier: Apache-2.0

import { ApiError } from '../../core/ApiError.js';
import { toBaht, toSatang } from '../../core/money.js';
import { getDb } from '../../db/index.js';
import { auditLogService } from '../audit-logs/audit-log.service.js';
import { toCustomerDto } from '../customers/customer.mapper.js';
import { shiftRepository } from '../shifts/shift.repository.js';
import { creditNoteRepository } from './credit-note.repository.js';
import { creditPoints } from './credit-points.js';
import { lateFeeRepository } from './late-fee.repository.js';
import { receivableRepository } from './receivable.repository.js';
import {
  daysOverdue,
  toBillingNoteDto,
  toCreditNoteDto,
  toInvoiceDto,
  toLateFeeDto,
  toReceiptDto,
} from './receivable.mapper.js';
import {
  customerInfo,
  emailHistory,
  loadCustomer,
  nextDocumentNo,
  storeInfo,
} from './receivable.shared.js';

/**
 * ลูกหนี้การค้า / ขายเชื่อ (ดู docs/tickets/20-b2b-credit.md, docs/DECISIONS.md #50)
 *
 * - บิลขายเชื่อ = payments.method 'credit' ที่ปิดบิลได้โดยยังไม่มีเงินเข้า
 * - ใบเสร็จรับชำระหนี้ตัดชำระบิลเก่าสุดก่อน (FIFO) และบันทึกการตัดไว้ตอนรับเงินเลย
 * - ใบวางบิลเป็นเอกสารรวบบิลค้างส่งให้ลูกค้า ไม่เปลี่ยนยอดหนี้ด้วยตัวเอง
 */

const AGING_BUCKETS = [
  { key: 'current', max: 0 },
  { key: 'days1to30', max: 30 },
  { key: 'days31to60', max: 60 },
  { key: 'days61to90', max: 90 },
  { key: 'over90', max: Infinity },
];

/** แยกยอดค้างตามอายุหนี้ (วันที่เกินกำหนด) — current = ยังไม่ถึงกำหนด */
const agingOf = (invoices, today) => {
  const buckets = Object.fromEntries(AGING_BUCKETS.map((bucket) => [bucket.key, 0]));
  for (const invoice of invoices) {
    if (invoice.outstanding <= 0) continue;
    const days = daysOverdue(invoice.due_date, today, invoice.outstanding);
    const bucket = AGING_BUCKETS.find((candidate) => days <= candidate.max);
    buckets[bucket.key] += invoice.outstanding;
  }
  return Object.fromEntries(Object.entries(buckets).map(([key, value]) => [key, toBaht(value)]));
};

const summarize = (customer, invoices, today) => {
  const open = invoices.filter((invoice) => invoice.outstanding > 0);
  const outstanding = open.reduce((acc, invoice) => acc + invoice.outstanding, 0);
  const overdue = open
    .filter((invoice) => daysOverdue(invoice.due_date, today, invoice.outstanding) > 0)
    .reduce((acc, invoice) => acc + invoice.outstanding, 0);
  return {
    customer: toCustomerDto(customer),
    creditLimit: toBaht(customer.credit_limit),
    creditTermDays: customer.credit_term_days,
    outstanding: toBaht(outstanding),
    overdue: toBaht(overdue),
    available: toBaht(Math.max(customer.credit_limit - outstanding, 0)),
    openInvoiceCount: open.length,
    oldestDueDate: open[0]?.due_date ?? null,
    aging: agingOf(invoices, today),
  };
};

/** ยอดที่ยังต้องเก็บของบิลในใบวางบิล ณ ตอนนี้ — ไม่เกินยอดที่ snapshot ไว้ตอนออกของแต่ละบิล */
const noteRemaining = (items) =>
  items.reduce((acc, item) => {
    const invoice = receivableRepository.invoiceByPaymentId(item.payment_id);
    return acc + Math.min(Math.max(invoice?.outstanding ?? 0, 0), item.amount);
  }, 0);

const buildNoteDto = (row) => {
  const items = receivableRepository.noteItems(row.id);
  return toBillingNoteDto(row, items, noteRemaining(items));
};

const buildReceiptDto = (row) => toReceiptDto(row, receivableRepository.receiptAllocations(row.id));

export const receivableService = {
  /** รายชื่อลูกค้าเครดิตพร้อมยอดค้าง/เกินกำหนด/อายุหนี้ — ค้างมากสุดขึ้นก่อน */
  listCustomers() {
    const today = receivableRepository.todayDate();
    return receivableRepository
      .creditCustomers()
      .map((customer) =>
        summarize(customer, receivableRepository.invoicesByCustomer(customer.id), today),
      )
      .sort((a, b) => b.overdue - a.overdue || b.outstanding - a.outstanding);
  },

  /** รายการเดินบัญชีของลูกค้าหนึ่งราย: บิลขายเชื่อทุกใบ + ใบเสร็จ + ใบวางบิล + ใบลดหนี้ + ใบแจ้งดอกเบี้ย */
  statement(customerId) {
    const customer = loadCustomer(customerId);
    const today = receivableRepository.todayDate();
    const invoices = receivableRepository.invoicesByCustomer(customerId);
    return {
      ...summarize(customer, invoices, today),
      today,
      invoices: invoices.map((invoice) => toInvoiceDto(invoice, today)),
      receipts: receivableRepository.receiptsByCustomer(customerId).map(buildReceiptDto),
      billingNotes: receivableRepository.notesByCustomer(customerId).map(buildNoteDto),
      creditNotes: creditNoteRepository.byCustomer(customerId).map(toCreditNoteDto),
      lateFees: lateFeeRepository
        .byCustomer(customerId)
        .map((row) => toLateFeeDto(row, lateFeeRepository.items(row.id))),
    };
  },

  /**
   * ใช้ตอนรับชำระค่าอาหารด้วยวิธี "ขายเชื่อ" (payment.service.js#pay) — คืนวันครบกำหนดของบิลนี้
   * ถ้าผ่านทุกเงื่อนไข: ลูกค้ามีวงเงิน และยอดค้างเดิม + ยอดนี้ไม่เกินวงเงิน
   */
  assertCanCharge(customerId, amountSatang) {
    const customer = loadCustomer(customerId);
    if (customer.credit_limit <= 0) {
      throw ApiError.conflict(
        `ลูกค้า "${customer.name}" ยังไม่มีวงเงินเครดิต — ผู้จัดการตั้งวงเงินได้ที่หน้าลูกค้า`,
      );
    }
    const outstanding = receivableRepository.outstandingByCustomer(customerId);
    const available = customer.credit_limit - outstanding;
    if (amountSatang > available) {
      throw ApiError.conflict(
        `เกินวงเงินเครดิตของ "${customer.name}" — วงเงิน ${toBaht(customer.credit_limit)} บาท ` +
          `ค้างอยู่ ${toBaht(outstanding)} บาท ใช้ได้อีก ${toBaht(Math.max(available, 0))} บาท`,
      );
    }
    return { customer, dueDate: receivableRepository.dateAfterDays(customer.credit_term_days) };
  },

  /** ยอดที่ยังลดหนี้ได้ของบิลขายเชื่อ — ไม่เกินยอดค้าง (ส่วนที่ชำระหนี้แล้วต้องยกเลิกใบเสร็จก่อน)
   * payment.service.js จำกัดไม่ให้เกินยอดบิลที่ยังไม่ถูกลดด้วยอีกชั้น ดอกเบี้ยจึงลดด้วยใบลดหนี้ไม่ได้
   * (ยกเลิกใบแจ้งดอกเบี้ยแทน) */
  creditRefundable(paymentId) {
    return Math.max(receivableRepository.invoiceByPaymentId(paymentId)?.outstanding ?? 0, 0);
  },

  /**
   * รับชำระหนี้ — ตัดบิลที่ค้างเก่าสุดก่อน ถ้าระบุ billingNoteId จะตัดเฉพาะบิลในใบวางบิลนั้น
   * (ลูกค้าจ่ายตามใบวางบิลที่ถือมา) รับเกินยอดค้างไม่ได้ เพราะระบบนี้ไม่มีบัญชีเงินรับล่วงหน้า
   * เงินสดต้องมีกะเปิดอยู่ให้ผูก และเข้ายอดเงินสดที่ควรมีตอนปิดกะนั้น (เหมือนรับค่าอาหาร)
   */
  createReceipt({ customerId, amount, method, reference, note, billingNoteId }, user) {
    const customer = loadCustomer(customerId);
    const amountSatang = toSatang(amount);

    let candidates = receivableRepository
      .invoicesByCustomer(customerId)
      .filter((invoice) => invoice.outstanding > 0);
    if (billingNoteId) {
      const billingNote = receivableRepository.findNote(billingNoteId);
      if (!billingNote || billingNote.customer_id !== customer.id) {
        throw ApiError.badRequest('ใบวางบิลนี้ไม่ใช่ของลูกค้ารายนี้');
      }
      if (billingNote.voided_at) throw ApiError.conflict('ใบวางบิลนี้ถูกยกเลิกแล้ว');
      const onNote = new Set(
        receivableRepository.noteItems(billingNoteId).map((item) => item.payment_id),
      );
      candidates = candidates.filter((invoice) => onNote.has(invoice.payment_id));
    }

    const payable = candidates.reduce((acc, invoice) => acc + invoice.outstanding, 0);
    if (payable <= 0) throw ApiError.conflict('ไม่มียอดค้างชำระให้รับชำระ');
    if (amountSatang > payable) {
      throw ApiError.badRequest(`รับชำระเกินยอดค้าง (ค้างอยู่ ${toBaht(payable)} บาท)`);
    }

    const shift = shiftRepository.findOpen();
    if (!shift && method === 'cash') {
      throw ApiError.conflict('ต้องเปิดกะก่อนจึงจะรับชำระหนี้เป็นเงินสดได้');
    }

    const receipt = getDb().transaction(() => {
      const created = receivableRepository.createReceipt({
        receiptNo: nextDocumentNo('ar_receipts', 'receipt_no', 'RC'),
        customerId,
        amount: amountSatang,
        method,
        reference,
        note,
        shiftId: shift?.id,
        receivedBy: user.id,
      });

      let remaining = amountSatang;
      const touchedOrders = [];
      for (const invoice of candidates) {
        if (remaining <= 0) break;
        const applied = Math.min(remaining, invoice.outstanding);
        receivableRepository.addAllocation({
          receiptId: created.id,
          paymentId: invoice.payment_id,
          amount: applied,
        });
        touchedOrders.push(invoice.order_id);
        remaining -= applied;
      }
      // บิลที่ใบเสร็จนี้ปิดยอดได้ครบ ลูกค้าได้แต้มสะสมตอนนี้ (DECISIONS #59)
      const points = creditPoints.syncOrders(touchedOrders);

      auditLogService.log({
        actorUser: user,
        action: 'receivable.receipt',
        summaryArgs: {
          amount: toBaht(amountSatang),
          method,
          customer: customer.name,
          receiptNo: created.receipt_no,
        },
        entityType: 'ar_receipt',
        entityId: created.id,
        summary: `รับชำระหนี้ ${toBaht(amountSatang)} บาท (${method}) จาก "${customer.name}" ใบเสร็จ ${created.receipt_no}`,
        metadata: {
          customerId,
          amount: toBaht(amountSatang),
          method,
          billingNoteId,
          pointsEarned: points.earned,
        },
      });
      return created;
    })();

    return buildReceiptDto(receivableRepository.findReceipt(receipt.id));
  },

  getReceipt(id) {
    const row = receivableRepository.findReceipt(id);
    if (!row) throw ApiError.notFound('ไม่พบใบเสร็จรับชำระนี้');
    return {
      ...buildReceiptDto(row),
      store: storeInfo(),
      customer: customerInfo(row.customer_id),
      emails: emailHistory('receipt', row.id),
    };
  },

  /**
   * ยกเลิกใบเสร็จรับชำระ (ผู้จัดการขึ้นไป) — ยอดที่ตัดไว้กลับเป็นหนี้ค้างทันที เพราะยอดค้างคำนวณจาก
   * ใบเสร็จที่ยังไม่ถูกยกเลิกเท่านั้น ใบเสร็จเงินสดยกเลิกได้เฉพาะระหว่างกะที่รับเงินยังเปิดอยู่:
   * ยอดคาดไว้ตอนปิดกะคิดใหม่ให้ถูกเอง ส่วนกะที่ปิดไปแล้วบันทึกยอดไว้แล้ว ถ้ายกเลิกย้อนหลังเงินใน
   * ลิ้นชักกับตัวเลขในระบบจะไม่มีทางตรงกันอีก
   */
  voidReceipt(id, reason, user) {
    const row = receivableRepository.findReceipt(id);
    if (!row) throw ApiError.notFound('ไม่พบใบเสร็จรับชำระนี้');
    if (row.voided_at) throw ApiError.conflict('ใบเสร็จนี้ถูกยกเลิกไปแล้ว');
    if (row.method === 'cash') {
      const shift = row.shift_id ? shiftRepository.findById(row.shift_id) : null;
      if (!shift || shift.status !== 'open') {
        throw ApiError.conflict(
          'กะที่รับเงินสดใบนี้ปิดไปแล้ว ยกเลิกย้อนหลังไม่ได้ — ให้คืนเงินลูกค้าเป็นรายการใหม่แทน',
        );
      }
    }

    getDb().transaction(() => {
      receivableRepository.voidReceipt(id, { reason, voidedBy: user.id });
      // บิลกลับมาค้าง = แต้มที่ได้ตอนชำระครบถูกดึงคืน (เท่าที่ลูกค้ายังมีอยู่ — DECISIONS #59)
      const points = creditPoints.syncOrders(
        receivableRepository.receiptAllocations(id).map((line) => line.order_id),
      );
      auditLogService.log({
        actorUser: user,
        action: 'receivable.receipt_void',
        summaryArgs: {
          receiptNo: row.receipt_no,
          amount: toBaht(row.amount),
          customer: row.customer_name,
        },
        entityType: 'ar_receipt',
        entityId: id,
        summary: `ยกเลิกใบเสร็จรับชำระหนี้ ${row.receipt_no} (${toBaht(row.amount)} บาท) ของ "${row.customer_name}"`,
        reason,
        metadata: {
          receiptNo: row.receipt_no,
          amount: toBaht(row.amount),
          method: row.method,
          pointsRevoked: points.revoked,
          pointsNotRecovered: points.shortfall,
        },
      });
    })();
    return buildReceiptDto(receivableRepository.findReceipt(id));
  },

  /**
   * ออกใบวางบิล — ไม่ระบุ paymentIds = รวบทุกบิลค้างที่ยังไม่อยู่ในใบวางบิลอื่น บิลหนึ่งอยู่ในใบวางบิล
   * ที่ยังไม่ถูกยกเลิกได้ใบเดียว (กันส่งเก็บเงินซ้ำ) วันนัดชำระค่าเริ่มต้นคือวันครบกำหนดช้าสุดของบิลที่
   * รวมไว้ แต่ไม่ก่อนวันนี้
   */
  createBillingNote({ customerId, paymentIds, dueDate, note }, user) {
    const customer = loadCustomer(customerId);
    const open = receivableRepository
      .invoicesByCustomer(customerId)
      .filter((invoice) => invoice.outstanding > 0);

    let selected;
    if (paymentIds?.length) {
      const byId = new Map(open.map((invoice) => [invoice.payment_id, invoice]));
      selected = paymentIds.map((paymentId) => {
        const invoice = byId.get(paymentId);
        if (!invoice) {
          throw ApiError.badRequest(`บิล id=${paymentId} ไม่ใช่บิลค้างชำระของลูกค้ารายนี้`);
        }
        if (invoice.billing_note_no) {
          throw ApiError.conflict(
            `บิล #${invoice.order_code} อยู่ในใบวางบิล ${invoice.billing_note_no} แล้ว`,
          );
        }
        return invoice;
      });
    } else {
      selected = open.filter((invoice) => !invoice.billing_note_no);
    }
    if (selected.length === 0) {
      throw ApiError.conflict('ไม่มีบิลค้างชำระที่ยังไม่ได้วางบิล');
    }

    const today = receivableRepository.todayDate();
    const latestDue = selected.reduce(
      (latest, invoice) => (invoice.due_date > latest ? invoice.due_date : latest),
      today,
    );
    const total = selected.reduce((acc, invoice) => acc + invoice.outstanding, 0);

    const created = getDb().transaction(() => {
      const row = receivableRepository.createNote({
        noteNo: nextDocumentNo('billing_notes', 'note_no', 'BN'),
        customerId,
        total,
        dueDate: dueDate ?? latestDue,
        note,
        issuedBy: user.id,
      });
      for (const invoice of selected) {
        receivableRepository.addNoteItem({
          noteId: row.id,
          paymentId: invoice.payment_id,
          amount: invoice.outstanding,
        });
      }
      auditLogService.log({
        actorUser: user,
        action: 'receivable.billing_note',
        summaryArgs: {
          noteNo: row.note_no,
          customer: customer.name,
          count: selected.length,
          total: toBaht(total),
        },
        entityType: 'billing_note',
        entityId: row.id,
        summary: `ออกใบวางบิล ${row.note_no} ให้ "${customer.name}" ${selected.length} บิล รวม ${toBaht(total)} บาท`,
        metadata: { customerId, total: toBaht(total), billCount: selected.length },
      });
      return row;
    })();

    return this.getBillingNote(created.id);
  },

  getBillingNote(id) {
    const row = receivableRepository.findNote(id);
    if (!row) throw ApiError.notFound('ไม่พบใบวางบิลนี้');
    return {
      ...buildNoteDto(row),
      store: storeInfo(),
      customer: customerInfo(row.customer_id),
      emails: emailHistory('billing_note', row.id),
    };
  },

  /** ยกเลิกใบวางบิล (ผู้จัดการขึ้นไป) — ไม่กระทบยอดหนี้ บิลในใบนั้นกลับไปวางบิลใหม่ได้ */
  voidBillingNote(id, reason, user) {
    const row = receivableRepository.findNote(id);
    if (!row) throw ApiError.notFound('ไม่พบใบวางบิลนี้');
    if (row.voided_at) throw ApiError.conflict('ใบวางบิลนี้ถูกยกเลิกไปแล้ว');

    getDb().transaction(() => {
      receivableRepository.voidNote(id, { reason, voidedBy: user.id });
      auditLogService.log({
        actorUser: user,
        action: 'receivable.billing_note_void',
        summaryArgs: { noteNo: row.note_no, customer: row.customer_name },
        entityType: 'billing_note',
        entityId: id,
        summary: `ยกเลิกใบวางบิล ${row.note_no} ของ "${row.customer_name}"`,
        reason,
        metadata: { noteNo: row.note_no },
      });
    })();
    return buildNoteDto(receivableRepository.findNote(id));
  },
};

export default receivableService;
