// Copyright 2026 Suruch Chakrapeesirisuk
// SPDX-License-Identifier: Apache-2.0

import { Router } from 'express';
import { authenticate, authorize } from '../../middlewares/auth.js';
import { validate } from '../../middlewares/validate.js';
import { erpController } from './erp.controller.js';
import { connectErpSchema } from './erp.schema.js';

const router = Router();
const admin = authorize('admin');

// โหมดของเครื่อง (ใช้งานเดี่ยว/เชื่อมต่อ ERP) — ทุกบทบาทอ่านได้ หน้าวัตถุดิบใช้ตัดสินว่าเป็นอ่านอย่างเดียวไหม
router.get('/mode', authenticate, erpController.mode);

// ตั้งค่าการเชื่อมต่อ — admin เท่านั้น (ticket 25) คำตอบไม่มี credential ไม่ว่าเส้นไหน
router.get('/connection', authenticate, admin, erpController.status);
router.put(
  '/connection',
  authenticate,
  admin,
  validate({ body: connectErpSchema }),
  erpController.connect,
);
router.delete('/connection', authenticate, admin, erpController.disconnect);
router.post('/pull', authenticate, admin, erpController.pull);

export default router;
