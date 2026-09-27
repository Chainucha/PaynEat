// Copyright 2026 Suruch Chakrapeesirisuk
// SPDX-License-Identifier: Apache-2.0

import 'package:flutter_test/flutter_test.dart';
import 'package:payneat_pos/core/localization/app_translations.dart';
import 'package:payneat_pos/features/audit_log/data/models/audit_log_model.dart';
import 'package:payneat_pos/features/audit_log/presentation/audit_summary_text.dart';

final _translations = AppTranslations().keys;

/// ตรวจว่า audit log ทุกรายการประกอบประโยคใหม่จาก `metadata.summaryArgs` ได้ครบ (DECISIONS #74)
///
/// - ภาษาไทย: ประโยคที่ประกอบได้ต้องตรงกับ `summary` ที่บันทึกไว้ทุกตัวอักษร — พิสูจน์ว่าค่าที่
///   ส่งมาครบและถูกตัว (ประโยคไทยที่บันทึกใช้รหัสดิบของสถานะ/ช่องทางชำระ/สิทธิ์ เช่น `cooking`
///   จึงให้คำแปลของรหัสพวกนั้นคืนรหัสเดิม)
/// - อังกฤษ/เกาหลี: ต้องประกอบได้ ไม่มี `@ชื่อ` ค้าง และไม่มีอักษรไทยเหลือนอกจากค่าที่ผู้ใช้กรอกเอง
void expectAuditSummariesRenderable(List<Map<String, dynamic>> logs) {
  for (final raw in logs) {
    final log = AuditLogModel.fromJson(raw);
    final args = (log.metadata?['summaryArgs'] as Map?)
        ?.cast<String, dynamic>();
    expect(args, isNotNull, reason: '${log.action} ไม่ได้ส่ง summaryArgs');

    final th = _translations['th_TH']!;
    final thai = AuditSummaryText.render(log, (key) {
      final isCode =
          key.startsWith('order_item_status_') ||
          key.startsWith('payment_method_') ||
          key.startsWith('role_');
      return isCode ? key : th[key] ?? key;
    });
    expect(thai, log.summary, reason: log.action);

    final typed = _typedValues(args!);
    for (final locale in ['en_US', 'ko_KR']) {
      final strings = _translations[locale]!;
      final text = AuditSummaryText.render(log, (key) => strings[key] ?? key);
      expect(text, isNotNull, reason: '${log.action} ($locale)');
      var rest = text!;
      for (final value in typed) {
        rest = rest.replaceAll(value, '');
      }
      // ตัดค่าที่ผู้ใช้กรอกออกก่อน อีเมลปลายทางมี @ อยู่แล้วโดยธรรมชาติ
      expect(rest, isNot(contains(RegExp(r'@[A-Za-z]'))), reason: text);
      expect(
        rest,
        isNot(contains(RegExp('[฀-๿]'))),
        reason: '${log.action} ($locale) ยังมีอักษรไทย: $text',
      );
    }
  }
}

/// ข้อความที่ผู้ใช้กรอกเอง (ชื่อเมนู ชื่อลูกค้า หน่วย ฯลฯ) — แสดงตามที่กรอก ไม่แปล
List<String> _typedValues(Object? value) => switch (value) {
  final String text => [text],
  final Map<dynamic, dynamic> map => [
    for (final v in map.values) ..._typedValues(v),
  ],
  final List<dynamic> list => [for (final v in list) ..._typedValues(v)],
  _ => const [],
};
