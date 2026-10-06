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

// อ่านได้ทุกบทบาทที่ล็อกอิน — จอครัวต้องอ่านรายการสถานีมาทำชิปกรอง
router.get(
  '/',
  authenticate,
  validate({ query: listKitchenStationQuerySchema }),
  kitchenStationController.list,
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
