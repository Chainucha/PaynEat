// Copyright 2026 Suruch Chakrapeesirisuk
// SPDX-License-Identifier: Apache-2.0

/// อัตราแต้มสะสม — mirror ของ backend `src/modules/customers/loyalty.js` (T15 #84, docs/DECISIONS.md #89)
///
/// เงินคิดเป็นสตางค์ อัตราที่ต่ำกว่า 0.01 บาทจึงเป็น 0 สตางค์ซึ่งเอาไปหารไม่ได้ ตั้งค่าใหม่ต้องไม่ต่ำกว่า
/// [minPointRateBaht] ส่วนค่าที่บันทึกไว้ก่อนมีกฎนี้ ตัวคำนวณให้ผลเป็น 0 แต้มแทนที่จะพัง
library;

/// อัตราสะสมแต้มและมูลค่าแต้มต่ำสุดที่ตั้งได้ (บาท)
const double minPointRateBaht = 0.01;

/// ตั้งค่านี้ได้ไหม — ใช้ตรวจฟอร์มก่อนส่ง เงื่อนไขเดียวกับ backend
bool isValidPointRate(double? baht) =>
    baht != null && baht.isFinite && baht >= minPointRateBaht;

int _satang(double baht) => baht.isFinite ? (baht * 100).round() : 0;

/// อัตราเป็นสตางค์ หรือ 0 ถ้าใช้ไม่ได้
int _rateSatang(double rateBaht) {
  final satang = _satang(rateBaht);
  return satang >= 1 ? satang : 0;
}

/// แต้มที่ได้จากยอดซื้อตามอัตรา "จ่ายกี่บาทได้ 1 แต้ม" — อัตราใช้ไม่ได้ = ไม่ได้แต้ม
int pointsForAmount(double amountBaht, double earnRateBaht) {
  final rate = _rateSatang(earnRateBaht);
  final amount = _satang(amountBaht);
  if (rate == 0 || amount <= 0) return 0;
  return amount ~/ rate;
}

/// มูลค่าเป็นสตางค์ของ 1 แต้มตอนแลก — 0 ถ้าอัตราใช้ไม่ได้ (ต้องไม่ยอมให้แลก)
int pointValueSatang(double redeemValueBaht) => _rateSatang(redeemValueBaht);
