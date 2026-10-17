// Copyright 2026 Suruch Chakrapeesirisuk
// SPDX-License-Identifier: Apache-2.0

import { Router } from 'express';
import { authenticate, authorize } from '../../middlewares/auth.js';
import { validate } from '../../middlewares/validate.js';
import { kitchenStationController } from './kitchen-station.controller.js';
import {
  createKitchenStationSchema,
  updateKitchenStationSchema,
  listKitchenStationQuerySchema,
  idParamSchema,
} from './kitchen-station.schema.js';

const router = Router();
const manager = authorize('admin', 'manager');
const operator = authorize('admin', 'manager', 'kitchen');

// อ่านได้ทุกบทบาทที่ล็อกอิน — จอครัวต้องอ่านรายการสถานีมาทำชิปกรอง
router.get(
  '/',
  authenticate,
  validate({ query: listKitchenStationQuerySchema }),
  kitchenStationController.list,
);
// สถานะเปิด/ปิดรายสาขา (ticket 36) — ต้องอยู่ก่อน '/:id' ไม่งั้น "status" ถูกตีเป็น id แล้วได้ 422
// อ่านได้ทุกบทบาท (แบนเนอร์ "บาร์ปิดตั้งแต่ ... โดย ..." บนหน้าสั่งอาหารของพนักงานเสิร์ฟ) แต่ปิด/เปิด
// ได้เฉพาะครัว/ผู้จัดการ/แอดมิน — ครัวปิดได้ทุกสถานีในสาขาของตัวเอง ไม่จำกัดเฉพาะสถานีที่ผูก (#98)
router.get('/status', authenticate, kitchenStationController.status);
router.post(
  '/:id/close',
  authenticate,
  operator,
  validate({ params: idParamSchema }),
  kitchenStationController.close,
);
router.post(
  '/:id/open',
  authenticate,
  operator,
  validate({ params: idParamSchema }),
  kitchenStationController.open,
);
router.get(
  '/:id',
  authenticate,
  validate({ params: idParamSchema }),
  kitchenStationController.detail,
);
router.post(
  '/',
  authenticate,
  manager,
  validate({ body: createKitchenStationSchema }),
  kitchenStationController.create,
);
router.patch(
  '/:id',
  authenticate,
  manager,
  validate({ params: idParamSchema, body: updateKitchenStationSchema }),
  kitchenStationController.update,
);
router.delete(
  '/:id',
  authenticate,
  manager,
  validate({ params: idParamSchema }),
  kitchenStationController.remove,
);

export default router;
