// Copyright 2026 Suruch Chakrapeesirisuk
// SPDX-License-Identifier: Apache-2.0

import { Router } from 'express';
import { authenticate, authorize } from '../../middlewares/auth.js';
import { validate } from '../../middlewares/validate.js';
import { orderController } from './order.controller.js';
import {
  createOrderSchema,
  addItemsSchema,
  updateItemSchema,
  updateItemStatusSchema,
  updateOrderSchema,
  discountSchema,
  redeemPromotionSchema,
  cancelOrderSchema,
  moveTableSchema,
  mergeOrderSchema,
  listOrderQuerySchema,
  kitchenQueueQuerySchema,
  idParamSchema,
  itemParamSchema,
} from './order.schema.js';

const router = Router();
router.use(authenticate);

const service = authorize('admin', 'manager', 'waiter', 'cashier');
const manager = authorize('admin', 'manager');

// เส้นทางเฉพาะต้องมาก่อน /:id เสมอ ไม่งั้นจะโดน pattern ทั่วไปจับไปก่อน
router.get(
  '/kitchen/queue',
  authorize('admin', 'manager', 'kitchen', 'waiter'),
  validate({ query: kitchenQueueQuerySchema }),
  orderController.kitchenQueue,
);
router.get('/code/:code', orderController.byCode);
router.get('/table/:id/open', validate({ params: idParamSchema }), orderController.openByTable);

router.get('/', validate({ query: listOrderQuerySchema }), orderController.list);
router.post('/', service, validate({ body: createOrderSchema }), orderController.create);
router.get('/:id', validate({ params: idParamSchema }), orderController.detail);
router.patch(
  '/:id',
  service,
  validate({ params: idParamSchema, body: updateOrderSchema }),
  orderController.update,
);

router.post(
  '/:id/items',
  service,
  validate({ params: idParamSchema, body: addItemsSchema }),
  orderController.addItems,
);
router.patch(
  '/:id/items/:itemId',
  service,
  validate({ params: itemParamSchema, body: updateItemSchema }),
  orderController.updateItem,
);
router.delete(
  '/:id/items/:itemId',
  service,
  validate({ params: itemParamSchema }),
  orderController.removeItem,
);
router.patch(
  '/:id/items/:itemId/status',
  authorize('admin', 'manager', 'kitchen', 'waiter'),
  validate({ params: itemParamSchema, body: updateItemStatusSchema }),
  orderController.updateItemStatus,
);

router.post(
  '/:id/send-to-kitchen',
  service,
  validate({ params: idParamSchema }),
  orderController.sendToKitchen,
);
router.post(
  '/:id/discount',
  authorize('admin', 'manager', 'cashier'),
  validate({ params: idParamSchema, body: discountSchema }),
  orderController.applyDiscount,
);
router.post(
  '/:id/promotion/redeem',
  authorize('admin', 'manager', 'cashier', 'waiter'),
  validate({ params: idParamSchema, body: redeemPromotionSchema }),
  orderController.redeemPromotion,
);
router.delete(
  '/:id/promotion',
  authorize('admin', 'manager', 'cashier', 'waiter'),
  validate({ params: idParamSchema }),
  orderController.removePromotion,
);
router.get(
  '/:id/eligible-promotions',
  validate({ params: idParamSchema }),
  orderController.eligiblePromotions,
);
router.post(
  '/:id/cancel',
  manager,
  validate({ params: idParamSchema, body: cancelOrderSchema }),
  orderController.cancel,
);
router.patch(
  '/:id/move-table',
  service,
  validate({ params: idParamSchema, body: moveTableSchema }),
  orderController.moveTable,
);
router.post(
  '/:id/merge',
  service,
  validate({ params: idParamSchema, body: mergeOrderSchema }),
  orderController.merge,
);

export default router;
