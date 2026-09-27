// Copyright 2026 Suruch Chakrapeesirisuk
// SPDX-License-Identifier: Apache-2.0

import { ApiError } from '../../core/ApiError.js';
import { toBaht, toSatang } from '../../core/money.js';
import { getDb } from '../../db/index.js';
import { emit, EVENTS } from '../../realtime/socket.js';
import { auditLogService } from '../audit-logs/audit-log.service.js';
import { receivableRepository } from '../receivables/receivable.repository.js';
import { shiftRepository } from './shift.repository.js';
import { toShiftDto } from './shift.mapper.js';

export const shiftService = {
  current() {
    return toShiftDto(shiftRepository.findOpen());
  },

  getById(id) {
    const shift = shiftRepository.findById(id);
    if (!shift) throw ApiError.notFound('ไม่พบกะนี้');
    return toShiftDto(shift);
  },

  list(query) {
    return shiftRepository.list(query).map(toShiftDto);
  },

  /** เปิด/ปิดกะกระทบเงินสดหน้าร้านโดยตรง (โดยเฉพาะปิดกะที่คำนวณส่วนต่าง) จึงต้อง audit
   * เหมือนเหตุการณ์เสี่ยงอื่น ๆ — ดู docs/tickets/14-financial-audit-trail.md */
  open({ openingCash }, user) {
    if (shiftRepository.findOpen()) {
      throw ApiError.conflict('มีกะที่เปิดอยู่แล้ว ต้องปิดกะเดิมก่อนเปิดกะใหม่');
    }
    const run = getDb().transaction(() => {
      const shift = shiftRepository.open({ openedBy: user.id, openingCash: toSatang(openingCash) });
      auditLogService.log({
        actorUser: user,
        action: 'shift.open',
        summaryArgs: { cash: toBaht(shift.opening_cash) },
        entityType: 'shift',
        entityId: shift.id,
        summary: `เปิดกะ เงินสดตั้งต้น ${toBaht(shift.opening_cash)} บาท`,
        metadata: { openingCash: shift.opening_cash },
      });
      return shift;
    });
    const dto = toShiftDto(run());
    emit(EVENTS.SHIFT_OPENED, dto);
    return dto;
  },

  close(id, { countedCash, note }, user) {
    const shift = shiftRepository.findById(id);
    if (!shift) throw ApiError.notFound('ไม่พบกะนี้');
    if (shift.status !== 'open') throw ApiError.conflict('กะนี้ปิดไปแล้ว');

    // เงินที่ควรอยู่ในลิ้นชัก = เงินทอนตั้งต้น + เงินสดที่รับเข้า (ค่าอาหาร + รับชำระหนี้ลูกค้าเครดิต)
    // − เงินสดที่คืนลูกค้าออกไประหว่างกะนี้ (ดู docs/DECISIONS.md #44, #50)
    const expectedCash =
      shift.opening_cash +
      shiftRepository.cashInDuring(id) +
      receivableRepository.cashReceivedDuring(id) -
      shiftRepository.cashRefundedDuring(id);
    const counted = toSatang(countedCash);
    const variance = counted - expectedCash;

    const run = getDb().transaction(() => {
      const closed = shiftRepository.close(id, {
        closedBy: user.id,
        expectedCash,
        countedCash: counted,
        variance,
        note,
      });
      auditLogService.log({
        actorUser: user,
        action: 'shift.close',
        summaryArgs: {
          counted: toBaht(counted),
          expected: toBaht(expectedCash),
          variance: toBaht(variance),
        },
        entityType: 'shift',
        entityId: id,
        summary: `ปิดกะ นับได้ ${toBaht(counted)} บาท คาดไว้ ${toBaht(expectedCash)} บาท (ส่วนต่าง ${toBaht(variance)} บาท)`,
        reason: note,
        metadata: { expectedCash, countedCash: counted, variance },
      });
      return closed;
    });
    const dto = toShiftDto(run());
    emit(EVENTS.SHIFT_CLOSED, dto);
    return dto;
  },
};

export default shiftService;
