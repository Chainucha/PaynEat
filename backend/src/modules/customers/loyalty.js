// Copyright 2026 Suruch Chakrapeesirisuk
// SPDX-License-Identifier: Apache-2.0

import { toSatang } from '../../core/money.js';

/**
 * อัตราแต้มสะสม (T15 #84, docs/DECISIONS.md #89) — ทุกจุดที่แปลงยอดเงินเป็นแต้มหรือแต้มเป็นเงินใช้ตัวนี้
 *
 * เงินในระบบเป็นสตางค์ อัตราที่ต่ำกว่า 0.01 บาทจึงกลายเป็น 0 สตางค์ ซึ่งเอาไปหารไม่ได้ ตั้งค่าใหม่ต้องไม่ต่ำกว่า
 * `MIN_POINT_RATE_BAHT` (settings.service.js) แต่ค่าที่บันทึกไว้ก่อนมีกฎนี้อาจยังต่ำกว่าอยู่ ตัวคำนวณจึงต้องไม่เชื่อค่าตั้ง
 */
export const MIN_POINT_RATE_BAHT = 0.01;

/** อัตราเป็นสตางค์ หรือ 0 ถ้าใช้ไม่ได้ (ต่ำกว่า 1 สตางค์ ไม่ใช่ตัวเลข หรือไม่จำกัด) */
const rateSatang = (rateBaht) => {
  const satang = toSatang(rateBaht);
  return Number.isSafeInteger(satang) && satang >= 1 ? satang : 0;
};

/** แต้มที่ได้จากยอดซื้อ (สตางค์) ตามอัตรา "จ่ายกี่บาทได้ 1 แต้ม" — อัตราใช้ไม่ได้ = ไม่ได้แต้ม */
export const pointsForAmount = (amountSatang, earnRateBaht) => {
  const rate = rateSatang(earnRateBaht);
  if (rate === 0 || !(amountSatang > 0)) return 0;
  return Math.floor(amountSatang / rate);
};

/** มูลค่าเป็นสตางค์ของ 1 แต้มตอนแลก — 0 ถ้าอัตราใช้ไม่ได้ (คนเรียกต้องไม่ยอมให้แลก) */
export const pointValueSatang = (redeemValueBaht) => rateSatang(redeemValueBaht);
