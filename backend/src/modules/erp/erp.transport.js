// Copyright 2026 Suruch Chakrapeesirisuk
// SPDX-License-Identifier: Apache-2.0

import { env } from '../../config/env.js';

/**
 * credential ของเครื่องเดินทางไปหา PaynEat ERP ทางไหน (ticket 32, DECISIONS #82, สัญญา POS v1 หัวข้อ "Transport"):
 * - `https` — เข้ารหัสและตรวจใบรับรองเสมอ (CA ภายในของเชนใช้ `NODE_EXTRA_CA_CERTS` ไม่มีค่าตั้งค่าที่ปิดการตรวจ)
 * - `loopback` — http ไปเครื่องเดียวกัน (`localhost`, `127.0.0.0/8`, `[::1]`) ไม่ผ่านเครือข่าย
 * - `insecure_allowed` — http ในเครือข่ายปิดที่ผู้ดูแลเซิร์ฟเวอร์อนุญาตเองด้วย `ERP_ALLOW_INSECURE_HTTP=true`
 *   (ตั้งจากหน้าจอไม่ได้) หน้าตั้งค่าแสดงคำเตือนตลอดเวลาที่ใช้
 * - `insecure_blocked` — http อย่างอื่น: ไม่ส่ง credential ไม่มีคำขอไป ERP เลย
 *
 * ใช้ร่วมกันระหว่างตอนบันทึกที่อยู่ (`PUT /erp/connection`), ตัวเรียก ERP (ทุกคำขอ) และ `ERP_URL` ของ ticket 28
 */
export const ERP_TRANSPORTS = ['https', 'loopback', 'insecure_allowed', 'insecure_blocked'];

/**
 * host ที่เป็น loopback ตัดสินจากตัวอักษรของ host หลัง URL parser จัดรูปแล้วเท่านั้น — ไม่ resolve DNS
 * (ชื่ออย่าง `127.example.com` หรือชื่อที่ resolve เป็น 127.0.0.1 จึงไม่นับ) parser แปลง IPv4 ทุกรูป
 * (`127.1`, `2130706433`) เป็นเลขสี่ชุดแล้ว และแปลง IPv6 loopback ทุกรูปเป็น `[::1]`
 */
export const isLoopbackHost = (hostname) =>
  hostname === 'localhost' ||
  hostname === '[::1]' ||
  /^127\.\d{1,3}\.\d{1,3}\.\d{1,3}$/.test(hostname);

/** ที่อยู่ของ ERP → ช่องทางตาม `ERP_TRANSPORTS` (ที่อยู่ผ่านการตรวจรูปแบบของ erp.schema.js มาแล้ว) */
export const erpTransport = (baseUrl, { allowInsecureHttp = env.erp.allowInsecureHttp } = {}) => {
  const url = new URL(baseUrl);
  if (url.protocol === 'https:') return 'https';
  if (isLoopbackHost(url.hostname)) return 'loopback';
  return allowInsecureHttp ? 'insecure_allowed' : 'insecure_blocked';
};
