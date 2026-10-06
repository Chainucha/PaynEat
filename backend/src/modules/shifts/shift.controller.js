// Copyright 2026 Suruch Chakrapeesirisuk
// SPDX-License-Identifier: Apache-2.0

import { asyncHandler } from '../../core/asyncHandler.js';
import { ok, created } from '../../core/response.js';
import { shiftService } from './shift.service.js';
import { backupService } from '../backups/backup.service.js';

export const shiftController = {
  current: asyncHandler(async (req, res) => ok(res, shiftService.current())),
  detail: asyncHandler(async (req, res) => ok(res, shiftService.getById(req.validated.params.id))),
  list: asyncHandler(async (req, res) => ok(res, shiftService.list(req.validated?.query ?? {}))),
  open: asyncHandler(async (req, res) => created(res, shiftService.open(req.body, req.user))),
  // ปิดกะ = สิ้นวันของร้าน จึงสำรองข้อมูลต่อทันที (ticket 33) หลังบันทึกกะสำเร็จแล้ว — สำรองไม่สำเร็จไม่ทำให้
  // ปิดกะล้ม คำตอบบอกผลใน `backup` ให้แอปแสดงคำเตือนแทน
  close: asyncHandler(async (req, res) => {
    const shift = shiftService.close(req.validated.params.id, req.body, req.user);
    const backup = await backupService.afterShiftClose();
    return ok(res, { ...shift, backup });
  }),
};

export default shiftController;
