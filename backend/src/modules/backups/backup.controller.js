// Copyright 2026 Suruch Chakrapeesirisuk
// SPDX-License-Identifier: Apache-2.0

import { asyncHandler } from '../../core/asyncHandler.js';
import { ok } from '../../core/response.js';
import { backupService } from './backup.service.js';

export const backupController = {
  status: asyncHandler(async (_req, res) => ok(res, backupService.status())),
  /** สำรองตอนนี้ — ตอบหลังสำรองเสร็จ พร้อมสถานะล่าสุด สำรองไม่สำเร็จยังตอบ 200 โดยบอกใน `result` */
  backupNow: asyncHandler(async (_req, res) => {
    const result = await backupService.backupNow();
    return ok(res, { result, status: backupService.status() });
  }),
};

export default backupController;
