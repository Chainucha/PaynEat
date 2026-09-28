// Copyright 2026 Suruch Chakrapeesirisuk
// SPDX-License-Identifier: Apache-2.0

import 'package:flutter_test/flutter_test.dart';
import 'package:payneat_pos/features/customer/domain/services/loyalty_points.dart';

/// อัตราแต้มสะสม — ตัวเลขชุดเดียวกับ backend/src/modules/customers/loyalty.js (T15 #84, docs/DECISIONS.md #89)
void main() {
  test('คิดเป็นสตางค์เหมือน backend: ยอด ÷ อัตรา ปัดลง', () {
    expect(pointsForAmount(480, 25), 19);
    expect(pointsForAmount(500, 25), 20);
    expect(pointsForAmount(100, 0.1), 1000);
    expect(pointsForAmount(1, 0.01), 100);
    // 0.015 บาท = 1.5 สตางค์ ปัดเป็น 2 สตางค์ต่อแต้มแบบ Math.round ของ backend
    expect(pointsForAmount(1, 0.015), 50);
  });

  test('อัตราที่ใช้ไม่ได้ให้ 0 แต้ม ไม่ใช่ Infinity หรือ exception', () {
    for (final rate in [0.0, 0.004, -25.0, double.nan, double.infinity]) {
      expect(pointsForAmount(480, rate), 0, reason: '$rate');
    }
    expect(pointsForAmount(0, 25), 0);
    expect(pointsForAmount(-100, 25), 0);
    expect(pointsForAmount(double.nan, 25), 0);
  });

  test('มูลค่าแต้มเป็นสตางค์ — ต่ำกว่า 0.01 บาทเป็น 0 (แลกไม่ได้)', () {
    expect(pointValueSatang(1), 100);
    expect(pointValueSatang(0.01), 1);
    expect(pointValueSatang(0.004), 0);
    expect(pointValueSatang(0), 0);
    expect(pointValueSatang(double.nan), 0);
  });

  test('ขั้นต่ำที่ตั้งได้คือ 0.01 บาท', () {
    expect(isValidPointRate(0.01), isTrue);
    expect(isValidPointRate(25), isTrue);
    for (final value in [null, 0.009, 0.004, 0.0, -1.0, double.nan]) {
      expect(isValidPointRate(value), isFalse, reason: '$value');
    }
    expect(isValidPointRate(double.infinity), isFalse);
  });
}
