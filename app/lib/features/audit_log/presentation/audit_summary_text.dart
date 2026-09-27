// Copyright 2026 Suruch Chakrapeesirisuk
// SPDX-License-Identifier: Apache-2.0

import 'package:get/get.dart';

import '../domain/entities/audit_log.dart';

/// ประโยคสรุปของ audit log ในภาษาที่ผู้ดูเลือก (DECISIONS #74)
///
/// `summary` ที่ backend บันทึกเป็นภาษาไทยเสมอ เพราะเป็นหลักฐานและลง CSV ให้ฝ่ายบัญชี แต่ผู้ใช้แอป
/// ภาษาเกาหลี/อังกฤษอ่านไม่ออก — log ที่เขียนหลังข้อ #74 จึงเก็บค่าที่ใช้ประกอบประโยคไว้ใน
/// `metadata.summaryArgs` แล้วแอปประกอบประโยคใหม่จากคำแปล ภาษาไทยยังแสดงประโยคที่บันทึกไว้
/// ตรง ๆ ส่วน log เก่าที่ไม่มี summaryArgs หรือ action ที่แอปยังไม่รู้จัก ถอยกลับไปใช้ `summary` เดิม
class AuditSummaryText {
  const AuditSummaryText._();

  static String of(AuditLog log) {
    if (Get.locale?.languageCode == 'th') return log.summary;
    return render(log, (key) => key.tr) ?? log.summary;
  }

  /// ประกอบประโยคด้วยคำแปลจาก [translate] — คืน null ถ้าประกอบไม่ได้ (ไม่มีค่า/ไม่มีคำแปล)
  static String? render(AuditLog log, String Function(String key) translate) {
    final raw = log.metadata?['summaryArgs'];
    if (raw is! Map) return null;
    final args = raw.cast<String, dynamic>();

    String label(String key, Object? code) {
      final value = translate(key);
      return value == key ? _text(code) : value;
    }

    String line(Object? item) {
      final row = (item as Map).cast<String, dynamic>();
      final grams = row['weightGrams'] as num?;
      return grams != null && grams > 0
          ? _fill(translate('audit_summary_line_weight'), {
              'name': _text(row['name']),
              'kg': (grams / 1000).toStringAsFixed(3),
            })
          : _fill(translate('audit_summary_line_quantity'), {
              'name': _text(row['name']),
              'quantity': _text(row['quantity']),
            });
    }

    final values = {for (final e in args.entries) e.key: _text(e.value)};
    var key = 'audit_summary_${log.action.replaceAll('.', '_')}';

    switch (log.action) {
      case 'order.discount':
        key = '${key}_${args['type']}';
      case 'ingredient.stock_adjust':
        final delta = args['delta'] as num? ?? 0;
        key = '${key}_${delta > 0 ? 'in' : 'out'}';
        values['qty'] = _text(delta.abs());
      case 'order.item.add':
        values['lines'] = [
          for (final item in args['items'] as List? ?? const []) line(item),
        ].join(', ');
      case 'order.item.remove':
        values['line'] = line(args);
      case 'order_item.void':
        values['status'] = label(
          'order_item_status_${args['status']}',
          args['status'],
        );
      case 'payment.pay' || 'receivable.receipt':
        values['method'] = label(
          'payment_method_${args['method']}',
          args['method'],
        );
      case 'user.role_change':
        values['from'] = label('role_${args['from']}', args['from']);
        values['to'] = label('role_${args['to']}', args['to']);
      case 'receivable.document_email':
        values['document'] = label(
          'audit_summary_document_${args['document']}',
          args['document'],
        );
      case 'settings.update':
        values['changes'] = [
          for (final change in args['changes'] as List? ?? const [])
            _fill(
              translate('audit_summary_setting_${(change as Map)['field']}'),
              {'from': _text(change['from']), 'to': _text(change['to'])},
            ),
        ].join(', ');
    }

    final template = translate(key);
    if (template == key) return null;
    final sentence = _fill(template, values);
    return args['demo'] == true
        ? sentence + translate('audit_summary_demo_not_sent')
        : sentence;
  }

  /// แทน `@ชื่อ` ด้วยค่าในรอบเดียว — ค่าที่มี @ อยู่ข้างใน (เช่นอีเมล) จะไม่ถูกแทนซ้ำ
  static String _fill(String template, Map<String, String> values) => template
      .replaceAllMapped(RegExp(r'@(\w+)'), (m) => values[m[1]] ?? m[0]!);

  /// ตัวเลขแบบเดียวกับที่ประโยคไทยพิมพ์ — 250.0 เป็น "250", 12.5 คงเดิม
  static String _text(Object? value) => switch (value) {
    null => '',
    double v when v == v.roundToDouble() => v.toInt().toString(),
    _ => value.toString(),
  };
}
