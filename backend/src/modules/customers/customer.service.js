// Copyright 2026 Suruch Chakrapeesirisuk
// SPDX-License-Identifier: Apache-2.0

import { ApiError } from '../../core/ApiError.js';
import { toBaht, toSatang } from '../../core/money.js';
import { getDb } from '../../db/index.js';
import { auditLogService } from '../audit-logs/audit-log.service.js';
import { receivableRepository } from '../receivables/receivable.repository.js';
import { customerRepository } from './customer.repository.js';
import { toCustomerDto } from './customer.mapper.js';

/** รายละเอียดลูกค้าพร้อมยอดหนี้ค้างปัจจุบัน — หน้าเก็บเงินใช้โชว์วงเงินที่เหลือก่อนกดขายเชื่อ */
const withCredit = (row) => {
  const outstanding = receivableRepository.outstandingByCustomer(row.id);
  return {
    ...toCustomerDto(row),
    creditOutstanding: toBaht(outstanding),
    creditAvailable: toBaht(Math.max(row.credit_limit - outstanding, 0)),
  };
};

export const customerService = {
  list(filters) {
    const { rows, total } = customerRepository.findAll(filters);
    return { customers: rows.map(toCustomerDto), total };
  },

  getById(id) {
    const customer = customerRepository.findById(id);
    if (!customer) throw ApiError.notFound('ไม่พบลูกค้านี้');
    return withCredit(customer);
  },

  /** ตั้งวงเงินเครดิต (ผู้จัดการขึ้นไป) — ลดวงเงินต่ำกว่ายอดค้างได้ แค่ขายเชื่อเพิ่มไม่ได้จนกว่าจะชำระ */
  updateCredit(id, { creditLimit, creditTermDays, taxId, address, email }, user) {
    const before = customerRepository.findById(id);
    if (!before) throw ApiError.notFound('ไม่พบลูกค้านี้');
    const limit = toSatang(creditLimit);

    const updated = getDb().transaction(() => {
      const row = customerRepository.updateCredit(id, {
        creditLimit: limit,
        creditTermDays,
        taxId: taxId || null,
        address: address || null,
        email: email === undefined ? before.email : email || null,
      });
      if (limit !== before.credit_limit || creditTermDays !== before.credit_term_days) {
        auditLogService.log({
          actorUser: user,
          action: 'customer.credit_update',
          summaryArgs: {
            name: before.name,
            fromLimit: toBaht(before.credit_limit),
            toLimit: toBaht(limit),
            fromDays: before.credit_term_days,
            toDays: creditTermDays,
          },
          entityType: 'customer',
          entityId: id,
          summary:
            `ตั้งวงเงินเครดิต "${before.name}" ${toBaht(before.credit_limit)} → ${toBaht(limit)} บาท` +
            ` เครดิต ${before.credit_term_days} → ${creditTermDays} วัน`,
          metadata: {
            previousCreditLimit: toBaht(before.credit_limit),
            newCreditLimit: toBaht(limit),
            previousTermDays: before.credit_term_days,
            newTermDays: creditTermDays,
          },
        });
      }
      return row;
    })();
    return withCredit(updated);
  },

  create({ name, phone, email }) {
    if (customerRepository.findByPhone(phone)) {
      throw ApiError.conflict('เบอร์โทรนี้มีลูกค้าอยู่แล้วในระบบ');
    }
    return toCustomerDto(customerRepository.create({ name, phone, email }));
  },
};

export default customerService;
