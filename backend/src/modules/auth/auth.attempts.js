// Copyright 2026 Suruch Chakrapeesirisuk
// SPDX-License-Identifier: Apache-2.0

import { env } from '../../config/env.js';
import { ApiError } from '../../core/ApiError.js';
import { createFailedAttemptLimiter } from '../../core/failedAttempts.js';

/**
 * พักการเข้าสู่ระบบชั่วคราวหลังใส่รหัสผ่านผิดซ้ำหลายครั้ง (ค่าตั้งที่ AUTH_MAX_FAILED_ATTEMPTS /
 * AUTH_FAILED_ATTEMPT_WINDOW_MINUTES)
 *
 * login นับแยกสองคีย์: IP ของเครื่อง และ username (ตัวพิมพ์เล็ก ตัดช่องว่าง) — พนักงานทั้งร้านมักออกเน็ต
 * ผ่าน IP เดียวกัน จึงล้างทั้งสองคีย์เมื่อมีคนเข้าสู่ระบบสำเร็จ ไม่ให้คนหนึ่งพิมพ์ผิดแล้วทั้งร้านเข้าไม่ได้
 * ทั้ง window ส่วนเปลี่ยนรหัสผ่านนับต่อบัญชีที่ login อยู่ (ใส่รหัสผ่านปัจจุบันผิด)
 *
 * IP คือ req.ip — ถ้าเซิร์ฟเวอร์อยู่หลัง reverse proxy ต้องตั้ง TRUST_PROXY (ดู app.js) ไม่อย่างนั้นทุกคำขอ
 * จะเป็น IP ของ proxy ตัวเดียวกันหมด
 */
const limiterOptions = {
  maxFailures: env.auth.maxFailedAttempts,
  windowMs: env.auth.failedAttemptWindowMs,
};
const loginAttempts = createFailedAttemptLimiter(limiterOptions);
const passwordChangeAttempts = createFailedAttemptLimiter(limiterOptions);

/**
 * รัน `action` ถ้าคีย์ยังไม่ถูกพัก — ล้มเหลวแบบ `isFailure` นับเพิ่ม, สำเร็จล้างตัวนับ, error อื่น
 * (เช่นบัญชีถูกปิด) ไม่นับทั้งสองทาง ถูกพักอยู่ได้ 429 พร้อม header Retry-After (วินาที)
 */
const guard = (limiter, keys, res, isFailure, action) => {
  const waitSeconds = limiter.retryAfterSeconds(keys);
  if (waitSeconds > 0) {
    res.set('Retry-After', String(waitSeconds));
    throw ApiError.tooManyRequests(
      `ใส่รหัสผ่านผิดหลายครั้งเกินไป กรุณาลองใหม่ในอีก ${Math.ceil(waitSeconds / 60)} นาที`,
    );
  }
  try {
    const result = action();
    limiter.reset(keys);
    return result;
  } catch (err) {
    if (isFailure(err)) limiter.recordFailure(keys);
    throw err;
  }
};

const isStatus = (statusCode) => (err) => err instanceof ApiError && err.statusCode === statusCode;

export const guardLogin = (req, res, action) =>
  guard(
    loginAttempts,
    [`ip:${req.ip}`, `user:${String(req.body.username).trim().toLowerCase()}`],
    res,
    isStatus(401),
    action,
  );

export const guardPasswordChange = (req, res, action) =>
  guard(passwordChangeAttempts, [`user-id:${req.user.id}`], res, isStatus(400), action);
