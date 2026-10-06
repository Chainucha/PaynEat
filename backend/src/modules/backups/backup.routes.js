// Copyright 2026 Suruch Chakrapeesirisuk
// SPDX-License-Identifier: Apache-2.0

import { Router } from 'express';
import { authenticate, authorize } from '../../middlewares/auth.js';
import { backupController } from './backup.controller.js';

/**
 * สำรองข้อมูล (ticket 33) — มีแค่สถานะกับปุ่มสำรองตอนนี้ ไม่มี endpoint ดาวน์โหลดหรือกู้คืนไฟล์สำรอง
 * (DECISIONS #90): ไฟล์สำรองมีเบอร์โทรลูกค้าและ hash รหัสผ่าน เข้าถึงได้เฉพาะคนที่เข้าเครื่องเซิร์ฟเวอร์ได้
 */
const router = Router();
router.use(authenticate);

// manager เห็นสถานะเพื่อรู้ว่าต้องบอกเจ้าของร้าน แต่สั่งสำรองเองไม่ได้
router.get('/status', authorize('admin', 'manager'), backupController.status);
router.post('/', authorize('admin'), backupController.backupNow);

export default router;
