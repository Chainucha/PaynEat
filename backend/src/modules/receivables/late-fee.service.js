// Copyright 2026 Suruch Chakrapeesirisuk
// SPDX-License-Identifier: Apache-2.0

import { ApiError } from '../../core/ApiError.js';
import { toBaht } from '../../core/money.js';
import { getDb } from '../../db/index.js';
import { auditLogService } from '../audit-logs/audit-log.service.js';
import { settingsService } from '../settings/settings.service.js';
import { creditPoints } from './credit-points.js';
import { lateFeeRepository } from './late-fee.repository.js';
import { receivableRepository } from './receivable.repository.js';
import { toLateFeeDto, toLateFeeLineDto } from './receivable.mapper.js';
import {
  customerInfo,
  emailHistory,
  loadCustomer,
  nextDocumentNo,
  storeInfo,
} from './receivable.shared.js';

/**
 * ดอกเบี้ยผิดนัดชำระ (ดู docs/tickets/21-late-fees-credit-notes.md, docs/DECISIONS.md #55)
 *
 * - ร้านตั้งอัตราต่อปี (0 = ไม่คิด สูงสุด 15%) และวันผ่อนผันหลังครบกำหนดที่หน้าตั้งค่า
 * - ดอกเบี้ยแบบธรรมดา (ไม่ทบต้น) คิดจาก "เงินต้นที่ยังค้าง" เท่านั้น — เงินที่ลูกค้าจ่ายมาถือว่าตัด
 *   ดอกเบี้ยก่อนแล้วจึงตัดต้นเงิน (ป.พ.พ. ม.329) เงินต้นค้าง = min(ยอดบิลหลังลดหนี้, ยอดค้างทั้งหมด)
 * - ผู้จัดการกดคิดเอง ระบบไม่บวกเงียบ ๆ ทุกคืน: ลูกค้าต้องได้เอกสารแจ้งทุกครั้งที่หนี้เพิ่ม
 * - คิดถึงวันนี้ (รวมวันนี้) รอบต่อไปเริ่มวันถัดจากวันที่คิดไปแล้ว จึงกดซ้ำวันเดิมไม่ได้ดอกเบี้ยซ้ำ
 */

const DAY_MS = 24 * 60 * 60 * 1000;

const addDays = (isoDate, days) =>
  new Date(Date.parse(`${isoDate}T00:00:00Z`) + days * DAY_MS).toISOString().slice(0, 10);

const daysInclusive = (from, to) =>
  Math.round((Date.parse(`${to}T00:00:00Z`) - Date.parse(`${from}T00:00:00Z`)) / DAY_MS) + 1;

/** ดอกเบี้ยของบิลเดียว ณ วันที่ asOf — null ถ้าไม่ต้องคิด (ยังไม่เกินกำหนด/ไม่มีเงินต้นค้าง/คิดไปแล้ว) */
const lineFor = (invoice, { annualRate, graceDays, asOf }) => {
  if (invoice.outstanding <= 0 || !invoice.due_date) return null;
  const principal = Math.min(invoice.amount - invoice.refunded, invoice.outstanding);
  if (principal <= 0) return null;

  const firstLateDay = addDays(invoice.due_date, graceDays + 1);
  const afterLastCharge = invoice.interest_through ? addDays(invoice.interest_through, 1) : null;
  const periodFrom =
    afterLastCharge && afterLastCharge > firstLateDay ? afterLastCharge : firstLateDay;
  if (periodFrom > asOf) return null;

  const days = daysInclusive(periodFrom, asOf);
  const amount = Math.round((principal * annualRate * days) / (100 * 365));
  if (amount < 1) return null;
  return {
    payment_id: invoice.payment_id,
    order_code: invoice.order_code,
    due_date: invoice.due_date,
    principal,
    period_from: periodFrom,
    period_to: asOf,
    days,
    amount,
  };
};

const computeLines = (customerId) => {
  const settings = settingsService.get();
  const context = {
    annualRate: settings.lateFeeAnnualRatePercent,
    graceDays: settings.lateFeeGraceDays,
    asOf: receivableRepository.todayDate(),
  };
  const lines =
    context.annualRate > 0
      ? receivableRepository
          .invoicesByCustomer(customerId)
          .map((invoice) => lineFor(invoice, context))
          .filter(Boolean)
      : [];
  return { ...context, lines };
};

const buildDto = (row) => toLateFeeDto(row, lateFeeRepository.items(row.id));

export const lateFeeService = {
  /** ดูก่อนว่าจะคิดดอกเบี้ยเท่าไร (ยังไม่บันทึก) — ใช้โชว์ในกล่องยืนยันก่อนกดออกเอกสาร */
  preview(customerId) {
    loadCustomer(customerId);
    const { annualRate, graceDays, asOf, lines } = computeLines(customerId);
    return {
      customerId,
      annualRate,
      graceDays,
      asOf,
      items: lines.map(toLateFeeLineDto),
      total: toBaht(lines.reduce((acc, line) => acc + line.amount, 0)),
    };
  },

  /** ออกใบแจ้งดอกเบี้ยผิดนัด (ผู้จัดการขึ้นไป) — ยอดในใบบวกเข้ายอดค้างของแต่ละบิลทันที */
  create({ customerId, note }, user) {
    const customer = loadCustomer(customerId);
    const { annualRate, asOf, lines } = computeLines(customerId);
    if (annualRate <= 0) {
      throw ApiError.conflict('ยังไม่ได้ตั้งอัตราดอกเบี้ยผิดนัด — ตั้งได้ที่หน้าตั้งค่า');
    }
    if (lines.length === 0) {
      throw ApiError.conflict('ไม่มีบิลที่ต้องคิดดอกเบี้ยเพิ่ม ณ วันนี้');
    }
    const total = lines.reduce((acc, line) => acc + line.amount, 0);

    const created = getDb().transaction(() => {
      const row = lateFeeRepository.create({
        chargeNo: nextDocumentNo('ar_charges', 'charge_no', 'LF'),
        customerId,
        total,
        annualRate,
        asOf,
        note,
        issuedBy: user.id,
      });
      for (const line of lines) {
        lateFeeRepository.addItem({
          chargeId: row.id,
          paymentId: line.payment_id,
          principal: line.principal,
          periodFrom: line.period_from,
          periodTo: line.period_to,
          days: line.days,
          amount: line.amount,
        });
      }
      auditLogService.log({
        actorUser: user,
        action: 'receivable.late_fee',
        summaryArgs: {
          total: toBaht(total),
          rate: annualRate,
          customer: customer.name,
          count: lines.length,
          chargeNo: row.charge_no,
        },
        entityType: 'ar_charge',
        entityId: row.id,
        summary:
          `คิดดอกเบี้ยผิดนัด ${toBaht(total)} บาท (${annualRate}% ต่อปี) ให้ "${customer.name}" ` +
          `${lines.length} บิล ใบแจ้ง ${row.charge_no}`,
        metadata: { customerId, total: toBaht(total), annualRate, asOf, billCount: lines.length },
      });
      return row;
    })();
    return this.get(created.id);
  },

  get(id) {
    const row = lateFeeRepository.findById(id);
    if (!row) throw ApiError.notFound('ไม่พบใบแจ้งดอกเบี้ยนี้');
    return {
      ...buildDto(row),
      store: storeInfo(),
      customer: customerInfo(row.customer_id),
      emails: emailHistory('late_fee', row.id),
    };
  },

  /**
   * ยกเลิกใบแจ้งดอกเบี้ย = ยกเว้นดอกเบี้ยให้ลูกค้า (ผู้จัดการขึ้นไป) — ทำได้เฉพาะตอนดอกเบี้ยในใบยังไม่ถูก
   * ชำระ ถ้าลูกค้าจ่ายมาแล้ว ยอดค้างจะติดลบกลายเป็นร้านติดเงินลูกค้า ต้องยกเลิกใบเสร็จรับชำระก่อน
   */
  void(id, reason, user) {
    const row = lateFeeRepository.findById(id);
    if (!row) throw ApiError.notFound('ไม่พบใบแจ้งดอกเบี้ยนี้');
    if (row.voided_at) throw ApiError.conflict('ใบแจ้งดอกเบี้ยนี้ถูกยกเลิกไปแล้ว');
    for (const item of lateFeeRepository.items(id)) {
      const invoice = receivableRepository.invoiceByPaymentId(item.payment_id);
      if ((invoice?.outstanding ?? 0) < item.amount) {
        throw ApiError.conflict(
          `ดอกเบี้ยของบิล #${item.order_code} ถูกชำระไปแล้ว — ยกเลิกใบเสร็จรับชำระก่อนจึงยกเลิกใบแจ้งนี้ได้`,
        );
      }
    }

    getDb().transaction(() => {
      lateFeeRepository.void(id, { reason, voidedBy: user.id });
      // ต้นเงินจ่ายครบแล้วเหลือแค่ดอกเบี้ยที่ยกเว้นให้ = บิลนั้นชำระครบ ได้แต้มสะสมตอนนี้ (#59)
      const points = creditPoints.syncOrders(
        lateFeeRepository.items(id).map((item) => item.order_id),
      );
      auditLogService.log({
        actorUser: user,
        action: 'receivable.late_fee_void',
        summaryArgs: {
          chargeNo: row.charge_no,
          total: toBaht(row.total),
          customer: row.customer_name,
        },
        entityType: 'ar_charge',
        entityId: id,
        summary: `ยกเลิกใบแจ้งดอกเบี้ย ${row.charge_no} (${toBaht(row.total)} บาท) ของ "${row.customer_name}"`,
        reason,
        metadata: {
          chargeNo: row.charge_no,
          total: toBaht(row.total),
          pointsEarned: points.earned,
        },
      });
    })();
    return buildDto(lateFeeRepository.findById(id));
  },
};

export default lateFeeService;
