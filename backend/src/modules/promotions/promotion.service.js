// Copyright 2026 Suruch Chakrapeesirisuk
// SPDX-License-Identifier: Apache-2.0

import { ApiError } from '../../core/ApiError.js';
import { toSatang } from '../../core/money.js';
import { getDb } from '../../db/index.js';
import { auditLogService } from '../audit-logs/audit-log.service.js';
import { promotionRepository } from './promotion.repository.js';
import { toPromotionDto } from './promotion.mapper.js';

/** แปลงเงื่อนไข input (บาท) → เก็บเป็นสตางค์ก่อนบันทึกเป็น JSON */
const toConditionsJson = (conditions = {}) =>
  JSON.stringify({
    ...conditions,
    minSubtotal: conditions.minSubtotal ? toSatang(conditions.minSubtotal) : undefined,
  });

/** แปลงค่าส่วนลด input → หน่วยเก็บจริง (percent: basis point, amount: สตางค์, bogo: ไม่ใช้) */
const toStoredValue = (type, value) => {
  if (type === 'percent') return Math.round((value ?? 0) * 100);
  if (type === 'amount') return toSatang(value ?? 0);
  return 0;
};

const assertCodeAvailable = (code, excludeId) => {
  if (!code) return;
  const existing = promotionRepository.findByCode(code);
  if (existing && existing.id !== excludeId) {
    throw ApiError.conflict(`โค้ด "${code}" มีโปรโมชันอื่นใช้อยู่แล้ว`);
  }
};

export const promotionService = {
  list(filters) {
    return promotionRepository.findAll(filters).map(toPromotionDto);
  },

  getById(id) {
    const promotion = promotionRepository.findById(id);
    if (!promotion) throw ApiError.notFound('ไม่พบโปรโมชันนี้');
    return toPromotionDto(promotion);
  },

  create(payload, actingUser) {
    assertCodeAvailable(payload.code, undefined);
    const run = getDb().transaction(() => {
      const created = promotionRepository.create({
        name: payload.name,
        type: payload.type,
        value: toStoredValue(payload.type, payload.value),
        code: payload.code ?? null,
        conditionsJson: toConditionsJson(payload.conditions),
        isActive: payload.isActive,
        validFrom: payload.validFrom ?? null,
        validTo: payload.validTo ?? null,
      });
      // Audit สำหรับฝ่ายบัญชี (ดู docs/tickets/14-financial-audit-trail.md) — สร้าง/แก้/ลบ
      // โปรโมชันทุกครั้งกระทบยอดขาย/ส่วนลดโดยตรง ต่างจากแก้ field ที่ไม่กระทบราคาของเมนู
      auditLogService.log({
        actorUser: actingUser,
        action: 'promotion.create',
        summaryArgs: { name: created.name },
        entityType: 'promotion',
        entityId: created.id,
        summary: `สร้างโปรโมชัน "${created.name}"`,
        metadata: { type: created.type, value: payload.value, code: created.code },
      });
      return created;
    });
    return toPromotionDto(run());
  },

  update(id, payload, actingUser) {
    const existing = promotionRepository.findById(id);
    if (!existing) throw ApiError.notFound('ไม่พบโปรโมชันนี้');

    if (payload.code !== undefined) assertCodeAvailable(payload.code, id);
    const type = payload.type ?? existing.type;

    const run = getDb().transaction(() => {
      const updated = promotionRepository.update(id, {
        name: payload.name,
        type: payload.type,
        value: payload.value === undefined ? undefined : toStoredValue(type, payload.value),
        code: payload.code,
        conditionsJson: payload.conditions ? toConditionsJson(payload.conditions) : undefined,
        isActive: payload.isActive,
        validFrom: payload.validFrom,
        validTo: payload.validTo,
      });
      auditLogService.log({
        actorUser: actingUser,
        action: 'promotion.update',
        summaryArgs: { name: updated.name },
        entityType: 'promotion',
        entityId: id,
        summary: `แก้ไขโปรโมชัน "${updated.name}"`,
        metadata: { before: toPromotionDto(existing), after: toPromotionDto(updated) },
      });
      return updated;
    });
    return toPromotionDto(run());
  },

  remove(id, actingUser) {
    const existing = promotionRepository.findById(id);
    if (!existing) throw ApiError.notFound('ไม่พบโปรโมชันนี้');
    getDb().transaction(() => {
      promotionRepository.remove(id);
      auditLogService.log({
        actorUser: actingUser,
        action: 'promotion.delete',
        summaryArgs: { name: existing.name },
        entityType: 'promotion',
        entityId: id,
        summary: `ลบโปรโมชัน "${existing.name}"`,
        metadata: { type: existing.type, code: existing.code },
      });
    })();
  },
};

export default promotionService;
