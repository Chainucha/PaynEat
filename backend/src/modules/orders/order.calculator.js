// Copyright 2026 Suruch Chakrapeesirisuk
// SPDX-License-Identifier: Apache-2.0

import { percentOf } from '../../core/money.js';

/**
 * ราคาของรายการอาหาร 1 บรรทัด (สตางค์) — ขายเป็นชิ้น: (ราคา + ตัวเลือก) × จำนวน, ขายตามน้ำหนัก:
 * (ราคาต่อกก. + ตัวเลือก) × กรัม / 1000 ปัดเป็นสตางค์ (ตัวเลือกของสินค้าชั่งน้ำหนักจึงเป็น "บวกต่อกก."
 * เช่น หมักซอส +40 บาท/กก.) ฝั่งแอปคิดด้วยสูตรเดียวกันใน cart_line.dart ต้องตรงกันทุกสตางค์
 * (ดู docs/DECISIONS.md #48)
 */
export const lineTotalFor = ({ unitPrice, optionsPrice = 0, quantity = 1, weightGrams = null }) => {
  const perUnit = Number(unitPrice) + Number(optionsPrice);
  if (weightGrams) return Math.round((perUnit * Number(weightGrams)) / 1000);
  return perUnit * Number(quantity);
};

/** ยอดรวมอาหารของรายการที่ยังไม่ถูกยกเลิก — ใช้ทั้งใน calculateBill และตอนประเมินโปรโมชัน */
export const sumActiveSubtotal = (items) =>
  items
    .filter((item) => item.status !== 'cancelled')
    .reduce((acc, item) => acc + Number(item.line_total ?? item.lineTotal ?? 0), 0);

/**
 * คำนวณยอดบิล — ฟังก์ชันบริสุทธิ์ (pure) เพื่อให้เทสต์ได้ง่ายและใช้ซ้ำได้ทั้ง preview/บันทึกจริง
 * ทุกค่าเป็น "สตางค์" (integer)
 *
 * ลำดับการคำนวณตามธรรมเนียมร้านอาหารไทย:
 *   1) ยอดรวมอาหาร (subtotal)
 *   2) หักส่วนลด (ส่วนลดมือ + ส่วนลดจากโปรโมชัน รวมกันแต่ไม่เกิน subtotal)
 *   3) บวก Service Charge จากยอดหลังหักส่วนลด
 *   4) บวก VAT จาก (ยอดหลังหักส่วนลด + Service Charge)
 *
 * ถ้า vatIncluded = true จะถือว่าราคาที่ตั้งไว้รวม VAT แล้ว
 * ระบบจะแยกส่วน VAT ออกมาแสดงเท่านั้น ไม่บวกเพิ่ม
 *
 * promotionDiscountAmount ถูกประเมินไว้ล่วงหน้าโดย promotion.engine.js (แยกจากไฟล์นี้
 * เพราะการจับคู่เงื่อนไขโปรโมชันไม่ใช่ตรรกะคิดเงิน) ฟังก์ชันนี้แค่นำมารวมกับส่วนลดมือ
 */
export const calculateBill = ({
  items = [],
  discountType = 'none',
  discountValue = 0,
  promotionDiscountAmount = 0,
  vatRate = 0.07,
  serviceChargeRate = 0.1,
  vatIncluded = false,
}) => {
  const subtotal = sumActiveSubtotal(items);

  let discountAmount = 0;
  if (discountType === 'amount') {
    discountAmount = Math.min(Math.max(Number(discountValue), 0), subtotal);
  } else if (discountType === 'percent') {
    const percent = Math.min(Math.max(Number(discountValue), 0), 10000); // เก็บเป็น basis point ของ % * 100
    discountAmount = Math.min(Math.round((subtotal * percent) / 10000), subtotal);
  }

  // ส่วนลดโปรโมชันรวมกับส่วนลดมือได้ แต่รวมกันแล้วต้องไม่เกิน subtotal
  const remainingAfterManualDiscount = Math.max(subtotal - discountAmount, 0);
  const promotionAmount = Math.min(
    Math.max(Number(promotionDiscountAmount) || 0, 0),
    remainingAfterManualDiscount,
  );

  const afterDiscount = subtotal - discountAmount - promotionAmount;
  const serviceCharge = percentOf(afterDiscount, serviceChargeRate);

  let vat;
  let total;
  if (vatIncluded) {
    // ราคารวม VAT แล้ว → ถอด VAT ออกมาแสดง (base = total / (1 + rate))
    const gross = afterDiscount + serviceCharge;
    vat = gross - Math.round(gross / (1 + vatRate));
    total = gross;
  } else {
    vat = percentOf(afterDiscount + serviceCharge, vatRate);
    total = afterDiscount + serviceCharge + vat;
  }

  return {
    subtotal,
    discountType,
    discountValue: Number(discountValue) || 0,
    discountAmount,
    promotionDiscountAmount: promotionAmount,
    serviceCharge,
    vat,
    total,
  };
};

/**
 * คำนวณส่วนแบ่งบิลของ "บางรายการ" ในออเดอร์ — ใช้กับฟีเจอร์แยกบิลรายคน (itemized split)
 * (T10 #83, docs/DECISIONS.md #88)
 *
 * หลักการ: ส่วนลด (มือ + โปรโมชัน), Service Charge และ VAT ของทั้งบิลปันตามสัดส่วน subtotal ของรายการ
 * ปัดเศษแบบสะสม: ส่วนของรอบนี้ = ปัด(ยอดทั้งบิล × (จ่ายแล้ว + รอบนี้) / ทั้งบิล) − ปัด(ยอดทั้งบิล × จ่ายแล้ว / ทั้งบิล)
 * "จ่ายแล้ว" คือ subtotal ของรายการที่แยกจ่ายไปก่อนหน้า ผลรวมของทุกรอบจึงเท่ายอดทั้งบิลพอดีไม่ว่าจะแบ่งกี่คน
 * หรือเลือกลำดับไหน และรอบสุดท้าย (เลือกรายการที่ยังไม่จ่ายครบทุกรายการ) ได้เศษที่เหลือโดยอัตโนมัติ
 *
 * ยอดของรอบนี้ = subtotal − ส่วนลด + Service Charge (+ VAT เฉพาะโหมด VAT แยก — โหมด VAT รวมในราคา VAT อยู่ในยอดแล้ว
 * แสดงเพื่อให้รู้เท่านั้น) ผู้เรียกยังต้องบังคับยอดรอบสุดท้ายให้เท่ายอดคงเหลือจริงเสมอ (`isLastBatch`) เผื่อบิลเคยรับเงิน
 * แบบระบุยอด ถูกคืนเงิน หรือเปลี่ยนหลังแยกจ่ายไปแล้ว
 */
export const calculateItemsShare = ({
  items = [],
  selectedIds = [],
  discountType = 'none',
  discountValue = 0,
  promotionDiscountAmount = 0,
  vatRate = 0.07,
  serviceChargeRate = 0.1,
  vatIncluded = false,
}) => {
  const active = items.filter((item) => item.status !== 'cancelled');
  const unpaidActive = active.filter((item) => !item.is_paid);
  const selected = active.filter((item) => selectedIds.includes(item.id));
  const paidBefore = active.filter((item) => item.is_paid && !selectedIds.includes(item.id));

  const full = calculateBill({
    items: active,
    discountType,
    discountValue,
    promotionDiscountAmount,
    vatRate,
    serviceChargeRate,
    vatIncluded,
  });

  const selectedSubtotal = sumActiveSubtotal(selected);
  const before = sumActiveSubtotal(paidBefore);
  const after = before + selectedSubtotal;
  // ส่วนของยอด `amount` ทั้งบิลที่ตกกับรายการรอบนี้ ปัดแบบสะสมให้ผลรวมทุกรอบไม่คลาดแม้แต่สตางค์เดียว
  const portion = (amount) =>
    full.subtotal > 0
      ? Math.round((amount * after) / full.subtotal) - Math.round((amount * before) / full.subtotal)
      : 0;

  const discountAmount = portion(full.discountAmount + full.promotionDiscountAmount);
  const serviceCharge = portion(full.serviceCharge);
  const vat = portion(full.vat);
  const total = selectedSubtotal - discountAmount + serviceCharge + (vatIncluded ? 0 : vat);

  const isLastBatch =
    unpaidActive.length > 0 && unpaidActive.every((item) => selectedIds.includes(item.id));

  return {
    subtotal: selectedSubtotal,
    discountAmount,
    serviceCharge,
    vat,
    vatIncluded,
    total,
    isLastBatch,
    fullTotal: full.total,
  };
};

export default calculateBill;
