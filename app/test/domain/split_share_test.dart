// Copyright 2026 Suruch Chakrapeesirisuk
// SPDX-License-Identifier: Apache-2.0

import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:payneat_pos/features/order/domain/services/bill_calculator.dart';
import 'package:payneat_pos/features/order/domain/services/split_share.dart';

/// แยกจ่ายตามรายการปันส่วนลด (มือ + โปรโมชัน), Service Charge และ VAT ตามโหมดของร้าน และผลรวมของทุกคนเท่ายอดบิลพอดี
/// — ตัวเลขชุดเดียวกับ backend/tests/split-share.test.js (T10 #83, docs/DECISIONS.md #88)
void main() {
  /// จ่ายทีละกลุ่มตามลำดับ คืนยอดของแต่ละกลุ่ม (บาท) — รอบสุดท้ายรับยอดคงเหลือเหมือนหน้าจอแยกบิล
  List<({SplitShare share, double amount})> payInGroups({
    required List<double> lines,
    required List<List<int>> groups,
    required BillBreakdown bill,
    required bool vatIncluded,
  }) {
    final paid = <int>{};
    var collected = 0.0;
    return [
      for (final (index, group) in groups.indexed)
        () {
          double sum(Iterable<int> ids) =>
              ids.fold<double>(0, (acc, id) => acc + lines[id]);
          final share = splitShare(
            billSubtotal: bill.subtotal,
            billDiscount: bill.discount + bill.promotionDiscount,
            billServiceCharge: bill.serviceCharge,
            billVat: bill.vat,
            paidBeforeSubtotal: sum(paid),
            selectedSubtotal: sum(group),
            vatIncluded: vatIncluded,
          );
          final remaining = ((bill.total - collected) * 100).round() / 100;
          final amount = index == groups.length - 1
              ? remaining
              : min(share.total, remaining);
          collected += amount;
          paid.addAll(group);
          return (share: share, amount: amount);
        }(),
    ];
  }

  test(
    'บิล 160 + 320 มีโปรลด 50% (282.48): รายการ 160 จ่าย 94.16 และ 320 จ่าย 188.32 ไม่ว่าใครจ่ายก่อน',
    () {
      const calculator = BillCalculator();
      final bill = calculator.fromSubtotal(480, promotionDiscountAmount: 240);
      expect(bill.total, 282.48);
      const lines = [160.0, 320.0];

      final cheapFirst = payInGroups(
        lines: lines,
        groups: [
          [0],
          [1],
        ],
        bill: bill,
        vatIncluded: false,
      );
      expect(cheapFirst.map((r) => r.amount), [94.16, 188.32]);
      expect(cheapFirst.first.share.discountAmount, 80);
      expect(cheapFirst.first.share.serviceCharge, 8);
      expect(cheapFirst.first.share.vat, 6.16);

      final dearFirst = payInGroups(
        lines: lines,
        groups: [
          [1],
          [0],
        ],
        bill: bill,
        vatIncluded: false,
      );
      expect(dearFirst.map((r) => r.amount), [188.32, 94.16]);
    },
  );

  test('โหมด VAT รวมในราคา บิล 160 + 80 (264): จ่าย 176.00 และ 88.00', () {
    const calculator = BillCalculator(vatIncluded: true);
    final bill = calculator.fromSubtotal(240);
    expect(bill.total, 264);

    final result = payInGroups(
      lines: const [160, 80],
      groups: [
        [0],
        [1],
      ],
      bill: bill,
      vatIncluded: true,
    );
    expect(result.map((r) => r.amount), [176.0, 88.0]);
    expect(result.first.share.vat, greaterThan(0));
    expect(
      result.first.share.total,
      result.first.share.subtotal -
          result.first.share.discountAmount +
          result.first.share.serviceCharge,
    );
  });

  test(
    'property: ทุกชุดค่าผสมของโปร/ส่วนลด/โหมด VAT/การแบ่งกลุ่ม ผลรวมทุกคน = ยอดบิล และแต่ละคนจ่ายตามสัดส่วน',
    () {
      final random = Random(20260928);
      for (var run = 0; run < 2000; run++) {
        final count = 1 + random.nextInt(6);
        final lines = [
          for (var i = 0; i < count; i++) (100 + random.nextInt(99900)) / 100,
        ];
        final subtotal = lines.fold<double>(0, (a, b) => a + b);
        final vatIncluded = random.nextBool();
        final calculator = BillCalculator(
          vatRate: random.nextBool() ? 0.07 : 0,
          serviceChargeRate: random.nextBool() ? 0.1 : 0,
          vatIncluded: vatIncluded,
        );
        final bill = calculator.fromSubtotal(
          subtotal,
          discountAmount: random.nextInt(3) == 0
              ? (random.nextDouble() * subtotal * 0.6 * 100).floor() / 100
              : 0,
          discountPercent: random.nextInt(3) == 0
              ? random.nextInt(50).toDouble()
              : 0,
          promotionDiscountAmount: random.nextInt(3) == 0
              ? (random.nextDouble() * subtotal * 0.5 * 100).floor() / 100
              : 0,
        );

        final groups = <List<int>>[];
        for (var i = 0; i < count; i++) {
          final target = random.nextInt(groups.length + 1);
          if (target == groups.length) groups.add([]);
          groups[target].add(i);
        }
        groups.shuffle(random);

        final results = payInGroups(
          lines: lines,
          groups: groups,
          bill: bill,
          vatIncluded: vatIncluded,
        );
        final context = '$lines $groups ${bill.total} vatIncluded=$vatIncluded';
        final sum = results.fold<double>(0, (acc, r) => acc + r.amount);
        expect(
          (sum * 100).round(),
          (bill.total * 100).round(),
          reason: 'ผลรวมต้องเท่ายอดบิล $context',
        );
        for (final (index, (:share, :amount)) in results.indexed) {
          final parts =
              share.subtotal -
              share.discountAmount +
              share.serviceCharge +
              (vatIncluded ? 0 : share.vat);
          expect(
            (parts * 100).round(),
            (share.total * 100).round(),
            reason: 'ตัวเลขในส่วนแบ่งต้องรวมได้ยอดของคนนั้น $context',
          );
          expect(
            (amount * 100).round(),
            (share.total * 100).round(),
            reason:
                'แบ่งตามรายการล้วน ยอดที่เก็บ = ส่วนแบ่งทุกรอบ ($index) $context',
          );
          final fair = bill.total * share.subtotal / bill.subtotal;
          expect(
            (amount - fair).abs(),
            lessThanOrEqualTo(0.03 + 1e-9),
            reason: 'รอบที่ ${index + 1} ห่างจากสัดส่วนเกิน 3 สตางค์ $context',
          );
        }
      }
    },
  );
}
