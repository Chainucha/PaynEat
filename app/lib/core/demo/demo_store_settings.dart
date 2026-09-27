// Copyright 2026 Suruch Chakrapeesirisuk
// SPDX-License-Identifier: Apache-2.0

part of 'demo_store.dart';

// ------------------------------------------------------------ settings ---
extension DemoStoreSettings on DemoStore {
  /// mirror ของ settings.service.js#update — เฉพาะ VAT/ค่าบริการ (ตัวเลขที่กระทบยอดขาย
  /// ทุกบิลทันที) ที่ต้อง log เป็น audit log ส่วนฟิลด์อื่น (ชื่อร้าน ที่อยู่ ฯลฯ) ไม่ต้อง
  /// (ดู docs/tickets/08-audit-log.md)
  Map<String, dynamic> updateSettings(
    Map<String, dynamic> changes, {
    int? actorId,
  }) {
    final previousVatRate = settings['vatRate'] as double;
    final previousServiceChargeRate = settings['serviceChargeRate'] as double;
    final previousLateFeeRate =
        (settings['lateFeeAnnualRatePercent'] as num?)?.toDouble() ?? 0;

    // ฉลากตาชั่ง 13 หลัก: prefix + PLU + น้ำหนัก 4–6 หลัก + check digit (mirror ของ
    // settings.service.js — ดู docs/tickets/19-barcode-scale.md)
    final prefix =
        (changes['scaleLabelPrefix'] ?? settings['scaleLabelPrefix']) as String;
    final pluDigits =
        (changes['scaleLabelPluDigits'] ?? settings['scaleLabelPluDigits'])
            as int;
    final weightDigits = 12 - prefix.length - pluDigits;
    if (!RegExp(r'^2\d{0,2}$').hasMatch(prefix) ||
        weightDigits < 4 ||
        weightDigits > 6) {
      throw ApiException(
        message: 'settings_scale_label_invalid'.tr,
        statusCode: 400,
      );
    }

    // ดอกเบี้ยผิดนัด 0–15% ต่อปี ผ่อนผัน 0–365 วัน (mirror ของ settings.routes.js)
    final rate = (changes['lateFeeAnnualRatePercent'] as num?)?.toDouble();
    final grace = (changes['lateFeeGraceDays'] as num?)?.toInt();
    if ((rate != null && (rate < 0 || rate > 15)) ||
        (grace != null && (grace < 0 || grace > 365))) {
      throw ApiException(
        message: 'settings_late_fee_invalid'.tr,
        statusCode: 422,
      );
    }

    changes.forEach((key, value) => settings[key] = value);

    final newVatRate = changes['vatRate'] as double?;
    final newServiceChargeRate = changes['serviceChargeRate'] as double?;
    final rateChanges = <String>[];
    // ค่าเดียวกันแบบไม่ผูกภาษา ให้หน้าประวัติแสดงเป็นภาษาของผู้ดู (DECISIONS #74)
    final changedRates = <Map<String, dynamic>>[];
    if (newVatRate != null && newVatRate != previousVatRate) {
      rateChanges.add(
        'VAT ${_jsNumber(previousVatRate)}% → ${_jsNumber(newVatRate)}%',
      );
      changedRates.add({
        'field': 'vat',
        'from': previousVatRate,
        'to': newVatRate,
      });
    }
    if (newServiceChargeRate != null &&
        newServiceChargeRate != previousServiceChargeRate) {
      rateChanges.add(
        'ค่าบริการ ${_jsNumber(previousServiceChargeRate)}% → ${_jsNumber(newServiceChargeRate)}%',
      );
      changedRates.add({
        'field': 'service',
        'from': previousServiceChargeRate,
        'to': newServiceChargeRate,
      });
    }
    // ดอกเบี้ยผิดนัดกระทบหนี้ลูกค้า — log เหมือน VAT/ค่าบริการ (ticket 21)
    final newLateFeeRate = (changes['lateFeeAnnualRatePercent'] as num?)
        ?.toDouble();
    if (newLateFeeRate != null && newLateFeeRate != previousLateFeeRate) {
      rateChanges.add(
        'ดอกเบี้ยผิดนัด ${_jsNumber(previousLateFeeRate)}% → ${_jsNumber(newLateFeeRate)}% ต่อปี',
      );
      changedRates.add({
        'field': 'late_fee',
        'from': previousLateFeeRate,
        'to': newLateFeeRate,
      });
    }
    if (rateChanges.isNotEmpty) {
      _logAudit(
        actorId: actorId,
        action: 'settings.update',
        summaryArgs: {'changes': changedRates},
        entityType: 'settings',
        summary: 'แก้ไขการตั้งค่า: ${rateChanges.join(', ')}',
        metadata: {
          'previousVatRate': previousVatRate,
          'newVatRate': newVatRate,
          'previousServiceChargeRate': previousServiceChargeRate,
          'newServiceChargeRate': newServiceChargeRate,
        },
      );
    }

    return settings;
  }
}
