// Copyright 2026 Suruch Chakrapeesirisuk
// SPDX-License-Identifier: Apache-2.0

import '../../../core/errors/failures.dart';

/// เพดานจำนวนต่อรายการของ QR เมื่อ backend ไม่ได้ส่งค่ามาในเมนู (backend รุ่นก่อนมีเพดาน) — ตรงกับค่า
/// เริ่มต้นของ `SELF_ORDER_MAX_QTY_PER_LINE` ปกติหน้า QR ใช้ค่าที่ร้านตั้งไว้จริงจาก
/// `GET /public/tables/:qrToken/menu` (DECISIONS #99)
const int defaultSelfOrderMaxQuantityPerLine = 10;

/// เพดานจำนวนรวมต่อบิลของ QR ในโหมดสาธิต — ตรงกับค่าเริ่มต้นของ `SELF_ORDER_MAX_ORDER_QTY`
const int defaultSelfOrderMaxOrderQuantity = 60;

/// `error.code` ที่ backend ส่งมาเมื่อออเดอร์ QR เกินเพดาน (`public-order.service.js`)
const String selfOrderLimitErrorCode = 'SELF_ORDER_LIMIT';

/// ออเดอร์นี้เกินเพดานของ QR — เป็นกติกาของร้าน ไม่ใช่ระบบขัดข้อง ลูกค้าต้องเรียกพนักงานสั่งต่อ
bool isSelfOrderLimit(Failure failure) =>
    failure is ServerFailure && failure.code == selfOrderLimitErrorCode;
