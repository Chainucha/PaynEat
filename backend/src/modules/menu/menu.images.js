// Copyright 2026 Suruch Chakrapeesirisuk
// SPDX-License-Identifier: Apache-2.0

/**
 * รูปเมนูที่อัปโหลดจากแอปเก็บเป็น data URL (base64) ใน `menu_items.image_url` เหมือนเดิม แต่ไม่ส่งไปทั้งก้อนใน
 * รายการเมนูอีกแล้ว — รายการส่ง path สั้น ๆ `/api/v1/public/menu-images/:id?v=...` แทน และรูปโหลดแยกทีละรูปพร้อม
 * cache ระยะยาว (DECISIONS #101) เมนู 30 รูปเคยทำให้รายการเมนูหนัก 6 MB ทุกครั้งที่เปิดหน้ารับออเดอร์หรือสแกน QR
 *
 * `v` เปลี่ยนทุกครั้งที่แก้เมนู (updated_at) และตามขนาดรูป URL ของรูปใหม่จึงไม่ซ้ำของเดิม cache ไม่ค้างรูปเก่า
 * URL ภายนอก (http/https) ส่งต่อตามเดิม
 */
export const MENU_IMAGE_PATH = '/api/v1/public/menu-images';

// เสิร์ฟจาก origin ของเราเอง จึงรับเฉพาะรูปที่เบราว์เซอร์ไม่รันโค้ดได้ — ไม่รับ SVG/HTML ที่อาจถูกเก็บมาเป็น data URL
const SERVABLE_DATA_URL = /^data:(image\/(?:jpeg|png|webp|gif));base64,/;

// path ที่ API ส่งออกไปเอง (มีหรือไม่มี origin นำหน้าก็ได้) — ฟอร์มแก้เมนูของแอปรุ่นเก่าส่งค่านี้กลับมาตอนบันทึก
const SERVED_PATH = /^(?:https?:\/\/[^/]+)?\/api\/v1\/public\/menu-images\/\d+(?:\?v=[\w-]+)?$/;

export const isInlineImage = (value) => typeof value === 'string' && value.startsWith('data:');

export const isServedImagePath = (value) => typeof value === 'string' && SERVED_PATH.test(value);

export const imageVersion = (row) =>
  `${String(row.updated_at ?? '').replace(/\D/g, '')}-${row.image_url.length.toString(36)}`;

/** ค่า `imageUrl` ที่ส่งให้แอป */
export const menuImageUrl = (row) =>
  isInlineImage(row.image_url)
    ? `${MENU_IMAGE_PATH}/${row.id}?v=${imageVersion(row)}`
    : (row.image_url ?? null);

/** แยก data URL ของรูปเมนูเป็นชนิดไฟล์ + ไบต์ หรือ null ถ้าไม่ใช่รูปที่เสิร์ฟได้ */
export const decodeMenuImage = (value) => {
  if (typeof value !== 'string') return null;
  const match = SERVABLE_DATA_URL.exec(value);
  if (!match) return null;
  return { mimeType: match[1], bytes: Buffer.from(value.slice(match[0].length), 'base64') };
};
