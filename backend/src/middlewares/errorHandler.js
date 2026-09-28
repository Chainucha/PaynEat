// Copyright 2026 Suruch Chakrapeesirisuk
// SPDX-License-Identifier: Apache-2.0

import { env } from '../config/env.js';
import { ApiError } from '../core/ApiError.js';
import { languageOf, messageTemplate, translateMessage } from '../i18n/errorMessages.js';
import { RESPONSE_ERROR } from './requestContext.js';

const INTERNAL_ERROR_TEXT = 'เกิดข้อผิดพลาดภายในระบบ';
const INVALID_BODY_TEXT = 'ข้อมูลที่ส่งมาไม่ถูกต้อง';
const BODY_TOO_LARGE_TEXT = 'ข้อมูลที่ส่งมาใหญ่เกินไป';

export const notFoundHandler = (req, _res, next) => {
  next(ApiError.notFound(`ไม่พบเส้นทาง ${req.method} ${req.originalUrl}`));
};

/**
 * status 4xx ที่ Express/body parser แนบมากับ error ของตัวเอง (JSON พัง, body ใหญ่เกิน) — เดิมตกเป็น 500
 * และข้อความของ error พวกนี้ยกเนื้อ body มาบางส่วน (`Unexpected token ... "{"password":...`) ถ้าถูกเขียน
 * ลง log ในฐานะ 500 ก็คือ body ของคำขอหลุดไปอยู่ใน log ซึ่งสัญญา telemetry ห้าม (ticket 24)
 */
const clientErrorStatus = (err) => {
  const status = err?.status ?? err?.statusCode;
  return Number.isInteger(status) && status >= 400 && status < 500 ? status : undefined;
};

/**
 * `error` ในบรรทัด log ของคำขอ 5xx — error ที่ไม่ได้คาดไว้ (บั๊ก) ใช้ชื่อและข้อความจริง ส่วน ApiError 5xx
 * ที่โยนตั้งใจ (ส่งอีเมล/เรียก AI ไม่สำเร็จ) ใช้ code กับข้อความแม่แบบภาษาอังกฤษจากแคตตาล็อก เพราะข้อความ
 * จริงแทรกค่าจากภายนอกไว้ได้ (คำตอบของ SMTP มีอีเมลผู้รับ) — stack ถูกเขียนเฉพาะ LOG_LEVEL=DEBUG
 */
const describeFailure = (err, isApiError) =>
  isApiError
    ? { type: err.code, message: messageTemplate(err.message) ?? err.code }
    : { type: err?.name ?? 'Error', message: String(err?.message ?? err), stack: err?.stack };

export const errorHandler = (err, req, res, _next) => {
  const isApiError = err instanceof ApiError;
  const clientStatus = isApiError ? undefined : clientErrorStatus(err);
  const statusCode = isApiError ? err.statusCode : (clientStatus ?? 500);
  // แอปส่ง Accept-Language ตามภาษาที่ผู้ใช้เลือก — ข้อความต้นฉบับในโค้ดเป็นภาษาไทย (DECISIONS #64)
  const lang = languageOf(req);
  const details =
    isApiError && Array.isArray(err.details)
      ? err.details.map((d) =>
          d && typeof d === 'object' && 'message' in d
            ? { ...d, message: translateMessage(d.message, lang) }
            : d,
        )
      : isApiError
        ? err.details
        : undefined;

  // ไม่เขียน log ตรงนี้ — บรรทัด http.request.completed ของคำขอนี้รายงานให้เอง บรรทัดเดียวต่อคำขอ
  if (statusCode >= 500) res.locals[RESPONSE_ERROR] = describeFailure(err, isApiError);

  const text = isApiError
    ? err.message
    : clientStatus === 413
      ? BODY_TOO_LARGE_TEXT
      : clientStatus
        ? INVALID_BODY_TEXT
        : INTERNAL_ERROR_TEXT;

  res.status(statusCode).json({
    success: false,
    error: {
      code: isApiError
        ? err.code
        : clientStatus
          ? ApiError.defaultCode(clientStatus)
          : 'INTERNAL_ERROR',
      message: translateMessage(text, lang),
      details,
      // รหัสเดียวกับ header x-request-id — ร้านแจ้งรหัสนี้แล้วค้น log ของคำขอนี้ได้ตรงตัว
      requestId: req.requestId,
      stack: env.exposeErrorStack && statusCode >= 500 && !isApiError ? err.stack : undefined,
    },
  });
};
