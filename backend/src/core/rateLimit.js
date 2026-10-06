// Copyright 2026 Suruch Chakrapeesirisuk
// SPDX-License-Identifier: Apache-2.0

import { ApiError } from './ApiError.js';

/**
 * ตัวนับแบบ fixed-window เก็บ state ในหน่วยความจำล้วน (เขียนเองแทนพึ่ง express-rate-limit เพราะ
 * โจทย์เล็ก — เทียบหลักการเดียวกับที่เขียน `Result<T>`/PromptPay TLV เอง ดู docs/DECISIONS.md #3)
 * ใช้ได้เฉพาะเซิร์ฟเวอร์ instance เดียว (ตามที่โปรเจกต์นี้ deploy จริง) — ถ้าต้องขยายเป็นหลาย instance
 * ต้องย้าย state ไป Redis หรือเทียบเท่า
 *
 * คีย์บางชุดโตได้ไม่จำกัด (IP, username ที่พิมพ์มา ดู core/failedAttempts.js) จึงลบ bucket ที่หมด
 * window แล้วทิ้งตอนเขียน — กวาดทั้ง Map อย่างมากรอบละครั้งต่อ windowMs หน่วยความจำจึงไม่เกินจำนวน
 * คีย์ที่ถูกใช้ภายในราว 2 window ล่าสุด และไม่ต้องมี timer ค้างใน process
 *
 * `now` เปลี่ยนได้เฉพาะในเทสต์ (เลื่อนเวลาโดยไม่ต้องรอจริง)
 */
export const createWindowCounter = ({ windowMs, now = Date.now }) => {
  const buckets = new Map();
  let lastSweep = now();

  const isExpired = (bucket, at) => at - bucket.start > windowMs;

  const sweep = (at) => {
    if (at - lastSweep < windowMs) return;
    lastSweep = at;
    for (const [key, bucket] of buckets) {
      if (isExpired(bucket, at)) buckets.delete(key);
    }
  };

  return {
    /** bucket ที่ยังอยู่ใน window (`{ start, count }`) หรือ undefined */
    peek(key, at = now()) {
      const bucket = buckets.get(key);
      return bucket && !isExpired(bucket, at) ? bucket : undefined;
    },

    /** นับเพิ่ม 1 — ไม่มี bucket หรือหมด window แล้วเริ่ม window ใหม่ที่ 1 คืน bucket หลังนับ */
    hit(key, at = now()) {
      sweep(at);
      const bucket = buckets.get(key);
      if (!bucket || isExpired(bucket, at)) {
        const fresh = { start: at, count: 1 };
        buckets.set(key, fresh);
        return fresh;
      }
      bucket.count += 1;
      return bucket;
    },

    reset(key) {
      buckets.delete(key);
    },

    /** จำนวน bucket ที่ยังเก็บอยู่ (รวมที่หมด window แต่ยังไม่ถึงรอบกวาด) — ใช้ในเทสต์ */
    get size() {
      return buckets.size;
    },
  };
};

/** middleware จำกัดจำนวน request ต่อคีย์ — เกิน `max` ภายใน `windowMs` ได้ 429 */
export const rateLimit = ({ windowMs, max, keyFn }) => {
  const counter = createWindowCounter({ windowMs });
  return (req, _res, next) => {
    const bucket = counter.hit(keyFn(req));
    if (bucket.count > max) {
      return next(ApiError.tooManyRequests());
    }
    return next();
  };
};

export default rateLimit;
