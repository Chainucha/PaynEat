// Copyright 2026 Suruch Chakrapeesirisuk
// SPDX-License-Identifier: Apache-2.0

/// ส่วนแบ่งบิลของรายการที่เลือกแยกจ่าย (บาท)
class SplitShare {
  const SplitShare({
    required this.subtotal,
    required this.discountAmount,
    required this.serviceCharge,
    required this.vat,
    required this.total,
    required this.vatIncluded,
  });

  final double subtotal;

  /// ส่วนลดมือ + ส่วนลดโปรโมชัน ที่ปันมาให้รายการเหล่านี้
  final double discountAmount;
  final double serviceCharge;

  /// VAT ของส่วนนี้ — โหมด VAT รวมในราคาอยู่ใน [total] แล้ว แสดงให้รู้เท่านั้น
  final double vat;
  final double total;
  final bool vatIncluded;
}

/// ปันส่วนลด (มือ + โปรโมชัน), Service Charge และ VAT ของทั้งบิลให้รายการที่เลือกแยกจ่าย ตามสัดส่วน subtotal
/// — mirror ของ `calculateItemsShare` ใน backend/src/modules/orders/order.calculator.js (T10 #83,
/// docs/DECISIONS.md #88)
///
/// ปัดแบบสะสมเป็นสตางค์: ส่วนของรอบนี้ = ปัด(ยอดทั้งบิล × (จ่ายแล้ว + รอบนี้) / ทั้งบิล) − ปัด(ยอดทั้งบิล × จ่ายแล้ว / ทั้งบิล)
/// ผลรวมของทุกรอบจึงเท่ายอดทั้งบิลพอดีไม่ว่าจะแบ่งกี่คนหรือจ่ายลำดับไหน
SplitShare splitShare({
  required double billSubtotal,
  required double billDiscount,
  required double billServiceCharge,
  required double billVat,
  required double paidBeforeSubtotal,
  required double selectedSubtotal,
  required bool vatIncluded,
}) {
  int satang(double baht) => (baht * 100).round();
  final full = satang(billSubtotal);
  final before = satang(paidBeforeSubtotal);
  final after = before + satang(selectedSubtotal);

  int portion(double amount) {
    if (full <= 0) return 0;
    final value = satang(amount);
    return _roundHalfUp(value * after / full) -
        _roundHalfUp(value * before / full);
  }

  final subtotal = satang(selectedSubtotal);
  final discount = portion(billDiscount);
  final serviceCharge = portion(billServiceCharge);
  final vat = portion(billVat);
  final total = subtotal - discount + serviceCharge + (vatIncluded ? 0 : vat);

  return SplitShare(
    subtotal: subtotal / 100,
    discountAmount: discount / 100,
    serviceCharge: serviceCharge / 100,
    vat: vat / 100,
    total: total / 100,
    vatIncluded: vatIncluded,
  );
}

/// ปัดครึ่งขึ้นเหมือน `Math.round` ของ JavaScript (Dart `round()` ปัดครึ่งออกจากศูนย์ ค่าที่นี่ไม่ติดลบจึงเหมือนกัน)
int _roundHalfUp(double value) => (value + 0.5).floor();
