// Copyright 2026 Suruch Chakrapeesirisuk
// SPDX-License-Identifier: Apache-2.0

import { env } from '../../config/env.js';
import { ApiError } from '../../core/ApiError.js';
import { mailer } from '../../core/mailer.js';
import { getDb } from '../../db/index.js';
import { auditLogService } from '../audit-logs/audit-log.service.js';
import { settingsRepository } from './settings.repository.js';

const NUMBER_KEYS = new Set([
  'vat_rate',
  'service_charge_rate',
  'points_earn_rate_baht',
  'points_redeem_value_baht',
  'scale_label_plu_digits',
  'late_fee_annual_rate',
  'late_fee_grace_days',
]);
const BOOLEAN_KEYS = new Set(['vat_included']);

export const settingsService = {
  /** โครงสร้างที่ฝั่ง client ใช้ได้ทันที (ค่า default มาจาก .env ถ้ายังไม่เคยตั้ง) */
  get() {
    const raw = Object.fromEntries(settingsRepository.all().map((row) => [row.key, row.value]));
    return {
      storeName: raw.store_name ?? env.store.name,
      currency: raw.currency ?? env.store.currency,
      vatRate: Number(raw.vat_rate ?? env.store.vatRate),
      serviceChargeRate: Number(raw.service_charge_rate ?? env.store.serviceChargeRate),
      vatIncluded: (raw.vat_included ?? String(env.store.vatIncluded)) === 'true',
      // ข้อมูลร้านสำหรับออกใบกำกับภาษี (ดู docs/tickets/07-tax-invoice.md) — ไม่มีค่า default
      // จาก .env เพราะร้านที่ไม่ได้จด VAT ไม่จำเป็นต้องมี ปล่อยว่างได้จนกว่าจะตั้งค่าเอง
      storeTaxId: raw.store_tax_id ?? null,
      storeAddress: raw.store_address ?? null,
      storeBranch: raw.store_branch ?? null,
      // เลขพร้อมเพย์ของร้าน (เบอร์โทร/เลขบัตรประชาชน/เลขผู้เสียภาษี) — ใช้สร้าง QR รับเงินจริง
      // (ดู docs/tickets/16-promptpay-qr.md) แยกจาก storeTaxId เพราะร้านอาจอยากใช้เบอร์โทร
      // เป็นเลขพร้อมเพย์ ต่างจากเลขผู้เสียภาษีที่ใช้ออกใบกำกับภาษี
      promptPayId: raw.promptpay_id ?? null,
      // แต้มสะสม (ดู docs/tickets/09-customer-loyalty.md)
      pointsEarnRateBaht: Number(raw.points_earn_rate_baht ?? env.store.pointsEarnRateBaht),
      pointsRedeemValueBaht: Number(
        raw.points_redeem_value_baht ?? env.store.pointsRedeemValueBaht,
      ),
      // รูปแบบฉลากตาชั่ง (ดู docs/tickets/19-barcode-scale.md) — ค่าเริ่มต้น "20" + PLU 5 หลัก +
      // น้ำหนัก 5 หลัก (กรัม) เป็นรูปแบบที่ตาชั่งพิมพ์ฉลากส่วนใหญ่ตั้งมาจากโรงงาน แอปใช้แยกฉลากเอง
      scaleLabelPrefix: raw.scale_label_prefix ?? '20',
      scaleLabelPluDigits: Number(raw.scale_label_plu_digits ?? 5),
      // ดอกเบี้ยผิดนัดชำระของลูกหนี้ขายเชื่อ (ดู docs/tickets/21-late-fees-credit-notes.md) — ค่าเริ่มต้น
      // 0 = ไม่คิด ร้านต้องตกลงกับลูกค้าไว้ก่อน (เช่น ระบุในใบวางบิล/สัญญา) จึงค่อยเปิด
      lateFeeAnnualRatePercent: Number(raw.late_fee_annual_rate ?? 0),
      lateFeeGraceDays: Number(raw.late_fee_grace_days ?? 0),
      // อ่านอย่างเดียว — มาจาก env (SMTP_HOST) ไม่ใช่ตาราง settings แอปใช้ซ่อน/เปิดปุ่ม "ส่งอีเมล"
      emailEnabled: mailer.isConfigured(),
    };
  },

  update(payload, actingUser) {
    const map = {
      storeName: 'store_name',
      currency: 'currency',
      vatRate: 'vat_rate',
      serviceChargeRate: 'service_charge_rate',
      vatIncluded: 'vat_included',
      storeTaxId: 'store_tax_id',
      storeAddress: 'store_address',
      storeBranch: 'store_branch',
      promptPayId: 'promptpay_id',
      pointsEarnRateBaht: 'points_earn_rate_baht',
      pointsRedeemValueBaht: 'points_redeem_value_baht',
      scaleLabelPrefix: 'scale_label_prefix',
      scaleLabelPluDigits: 'scale_label_plu_digits',
      lateFeeAnnualRatePercent: 'late_fee_annual_rate',
      lateFeeGraceDays: 'late_fee_grace_days',
    };
    // เฉพาะ VAT/ค่าบริการ (ตัวเลขที่กระทบยอดขายทุกบิลทันที) และอัตราดอกเบี้ยผิดนัด (กระทบหนี้ลูกค้า)
    // ที่ต้อง log — ดู docs/tickets/08-audit-log.md
    const before = this.get();

    // ฉลากตาชั่งยาว 13 หลักเสมอ: prefix + PLU + น้ำหนัก + check digit — schema ตรวจได้เฉพาะตอนส่งมา
    // คู่กัน ส่งมาแค่ช่องเดียวต้องเทียบกับค่าที่บันทึกไว้เดิมตรงนี้ (docs/tickets/19-barcode-scale.md)
    const prefix = payload.scaleLabelPrefix ?? before.scaleLabelPrefix;
    const pluDigits = payload.scaleLabelPluDigits ?? before.scaleLabelPluDigits;
    const weightDigits = 12 - prefix.length - pluDigits;
    if (weightDigits < 4 || weightDigits > 6) {
      throw ApiError.badRequest('รูปแบบฉลากตาชั่ง: prefix + PLU ต้องเหลือหลักน้ำหนัก 4–6 หลัก');
    }

    getDb().transaction(() => {
      for (const [field, key] of Object.entries(map)) {
        if (payload[field] === undefined) continue;
        const value =
          NUMBER_KEYS.has(key) || BOOLEAN_KEYS.has(key) ? String(payload[field]) : payload[field];
        settingsRepository.set(key, value);
      }

      const rateChanges = [];
      // ค่าเดียวกันแบบไม่ผูกภาษา ให้แอปประกอบประโยคเป็นภาษาที่ผู้ดูเลือก (DECISIONS #74)
      const changes = [];
      if (payload.vatRate !== undefined && payload.vatRate !== before.vatRate) {
        rateChanges.push(`VAT ${before.vatRate}% → ${payload.vatRate}%`);
        changes.push({ field: 'vat', from: before.vatRate, to: payload.vatRate });
      }
      if (
        payload.serviceChargeRate !== undefined &&
        payload.serviceChargeRate !== before.serviceChargeRate
      ) {
        rateChanges.push(`ค่าบริการ ${before.serviceChargeRate}% → ${payload.serviceChargeRate}%`);
        changes.push({
          field: 'service',
          from: before.serviceChargeRate,
          to: payload.serviceChargeRate,
        });
      }
      if (
        payload.lateFeeAnnualRatePercent !== undefined &&
        payload.lateFeeAnnualRatePercent !== before.lateFeeAnnualRatePercent
      ) {
        rateChanges.push(
          `ดอกเบี้ยผิดนัด ${before.lateFeeAnnualRatePercent}% → ${payload.lateFeeAnnualRatePercent}% ต่อปี`,
        );
        changes.push({
          field: 'late_fee',
          from: before.lateFeeAnnualRatePercent,
          to: payload.lateFeeAnnualRatePercent,
        });
      }
      if (rateChanges.length && actingUser) {
        auditLogService.log({
          actorUser: actingUser,
          action: 'settings.update',
          summaryArgs: { changes },
          entityType: 'settings',
          entityId: null,
          summary: `แก้ไขการตั้งค่า: ${rateChanges.join(', ')}`,
          metadata: {
            previousVatRate: before.vatRate,
            newVatRate: payload.vatRate,
            previousServiceChargeRate: before.serviceChargeRate,
            newServiceChargeRate: payload.serviceChargeRate,
            previousLateFeeAnnualRatePercent: before.lateFeeAnnualRatePercent,
            newLateFeeAnnualRatePercent: payload.lateFeeAnnualRatePercent,
          },
        });
      }
    })();

    return this.get();
  },
};

export default settingsService;
