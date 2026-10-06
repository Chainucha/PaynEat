// Copyright 2026 Suruch Chakrapeesirisuk
// SPDX-License-Identifier: Apache-2.0

import { createWindowCounter } from './rateLimit.js';

/**
 * นับครั้งที่ทำไม่สำเร็จต่อคีย์ (เช่นใส่รหัสผ่านผิด) ครบ `maxFailures` ภายใน `windowMs` แล้วพักคีย์นั้นไว้
 * จนหมด window — ต่างจาก rateLimit ตรงที่นับเฉพาะครั้งที่ล้มเหลว และครั้งที่สำเร็จล้างตัวนับทิ้ง
 * (คนที่พิมพ์ผิดสองสามครั้งแล้วเข้าได้ ไม่ต้องแบกตัวนับเดิมไปทั้ง window)
 *
 * หนึ่งคำขอเช็กได้หลายคีย์พร้อมกัน (IP + username) — คีย์ใดคีย์หนึ่งครบก็พัก และรอตามคีย์ที่นานสุด
 * state อยู่ในหน่วยความจำและลบ bucket ที่หมดอายุเองตามที่ createWindowCounter ทำ
 */
export const createFailedAttemptLimiter = ({ maxFailures, windowMs, now = Date.now }) => {
  const counter = createWindowCounter({ windowMs, now });

  return {
    /** วินาทีที่ต้องรอก่อนลองใหม่ได้ (0 = ลองได้เลย) */
    retryAfterSeconds(keys) {
      const at = now();
      let waitMs = 0;
      for (const key of keys) {
        const bucket = counter.peek(key, at);
        if (bucket && bucket.count >= maxFailures) {
          waitMs = Math.max(waitMs, bucket.start + windowMs - at);
        }
      }
      return waitMs > 0 ? Math.max(1, Math.ceil(waitMs / 1000)) : 0;
    },

    recordFailure(keys) {
      const at = now();
      for (const key of keys) counter.hit(key, at);
    },

    reset(keys) {
      for (const key of keys) counter.reset(key);
    },

    /** จำนวนคีย์ที่ยังเก็บอยู่ — ใช้ในเทสต์ */
    get size() {
      return counter.size;
    },
  };
};

export default createFailedAttemptLimiter;
