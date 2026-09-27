// Copyright 2026 Suruch Chakrapeesirisuk
// SPDX-License-Identifier: Apache-2.0

import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:payneat_pos/core/localization/app_translations.dart';
import 'package:payneat_pos/core/localization/locale_service.dart';
import 'package:payneat_pos/features/audit_log/domain/entities/audit_log.dart';
import 'package:payneat_pos/features/audit_log/presentation/audit_summary_text.dart';

/// action ที่มีแต่ฝั่ง backend (Demo Mode ยังไม่เขียน log พวกนี้ เทสต์ของ DemoStore จึงไม่ครอบคลุม)
/// ใช้ summaryArgs รูปเดียวกับที่ backend เขียนจริง (tests/audit-summary-args.test.js)
void main() {
  final strings = AppTranslations().keys;
  String Function(String) lookup(String locale) =>
      (key) => strings[locale]![key] ?? key;

  AuditLog log(String action, Map<String, dynamic>? args, {String? summary}) =>
      AuditLog(
        id: 1,
        actorName: 'Somchai',
        action: action,
        entityType: 'order',
        summary: summary ?? 'ประโยคไทยที่บันทึกไว้',
        createdAt: '2026-09-26T10:00:00Z',
        metadata: args == null ? null : {'summaryArgs': args},
      );

  test('รับชำระเงิน — ช่องทางชำระแปลตามภาษา', () {
    final paid = log('payment.pay', {
      'code': 'ORD-1',
      'amount': 250.5,
      'method': 'qr',
    });
    expect(
      AuditSummaryText.render(paid, lookup('en_US')),
      'Received 250.5 baht (PromptPay / QR) for order #ORD-1',
    );
    expect(
      AuditSummaryText.render(paid, lookup('ko_KR')),
      '주문 #ORD-1 결제 250.5바트 수납 (프롬프트페이 / QR)',
    );
  });

  test('เปิด/ปิดกะ ย้ายโต๊ะ รวมบิล ใช้/เอาโค้ดส่วนลดออก ประกอบได้ทุกภาษา', () {
    final logs = [
      log('shift.open', {'cash': 1000}),
      log('shift.close', {'counted': 960, 'expected': 1000, 'variance': -40}),
      log('order.move_table', {
        'code': 'ORD-1',
        'fromTable': 'A1',
        'toTable': 'B2',
      }),
      log('order.merge', {'source': 'ORD-1', 'target': 'ORD-2'}),
      log('order.promotion_redeem', {
        'code': 'ORD-1',
        'promoCode': 'WELCOME50',
        'promoName': 'Welcome',
      }),
      log('order.promotion_remove', {'code': 'ORD-1'}),
    ];
    for (final locale in ['th_TH', 'en_US', 'ko_KR']) {
      for (final entry in logs) {
        final text = AuditSummaryText.render(entry, lookup(locale));
        expect(text, isNotNull, reason: '${entry.action} $locale');
        expect(text, isNot(contains('@')), reason: text);
      }
    }
    expect(
      AuditSummaryText.render(logs[1], lookup('en_US')),
      'Closed the shift: counted 960 baht, expected 1000 baht '
      '(difference -40 baht)',
    );
    expect(
      AuditSummaryText.render(logs[2], lookup('th_TH')),
      'ย้ายออเดอร์ #ORD-1 จากโต๊ะ "A1" ไปโต๊ะ "B2"',
    );
  });

  test('อีเมลปลายทางมี @ — แทนค่ารอบเดียว ไม่เอาไปแทนซ้ำ', () {
    final sent = log('receivable.document_email', {
      'document': 'billing_note',
      'number': 'BN69-000001',
      'customer': 'Seoul BBQ Co., Ltd.',
      'to': 'accounts@customer.example',
    });
    expect(
      AuditSummaryText.render(sent, lookup('en_US')),
      'Emailed billing note BN69-000001 of "Seoul BBQ Co., Ltd." '
      'to accounts@customer.example',
    );
  });

  test(
    'log เก่าที่ไม่มี summaryArgs และ action ที่ไม่รู้จัก ถอยกลับไปใช้ประโยคที่บันทึกไว้',
    () {
      Get.locale = LocaleService.korean;
      addTearDown(() => Get.locale = LocaleService.thai);
      expect(
        AuditSummaryText.of(log('order.cancel', null)),
        'ประโยคไทยที่บันทึกไว้',
      );
      expect(
        AuditSummaryText.of(log('something.new', {'code': 'X'})),
        'ประโยคไทยที่บันทึกไว้',
      );
    },
  );

  test('ภาษาไทยแสดงประโยคที่บันทึกไว้ตรง ๆ เสมอ (เป็นหลักฐาน)', () {
    Get.locale = LocaleService.thai;
    expect(
      AuditSummaryText.of(log('order.cancel', {'code': 'ORD-9'})),
      'ประโยคไทยที่บันทึกไว้',
    );
  });
}
