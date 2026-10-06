// Copyright 2026 Suruch Chakrapeesirisuk
// SPDX-License-Identifier: Apache-2.0

import { asyncHandler } from '../../core/asyncHandler.js';
import { ok, created, paginated } from '../../core/response.js';
import { orderService } from './order.service.js';

export const orderController = {
  list: asyncHandler(async (req, res) => {
    const query = req.validated.query;
    const { orders, total } = orderService.list(query, req.branchId);
    return paginated(res, orders, { page: query.page, limit: query.limit, total });
  }),

  detail: asyncHandler(async (req, res) => ok(res, orderService.getById(req.validated.params.id))),

  byCode: asyncHandler(async (req, res) => ok(res, orderService.getByCode(req.params.code))),

  openByTable: asyncHandler(async (req, res) =>
    ok(res, orderService.getOpenByTable(req.validated.params.id)),
  ),

  create: asyncHandler(async (req, res) =>
    created(res, orderService.create(req.body, req.user, req.branchId)),
  ),

  update: asyncHandler(async (req, res) =>
    ok(res, orderService.updateMeta(req.validated.params.id, req.body)),
  ),

  addItems: asyncHandler(async (req, res) =>
    created(res, orderService.addItems(req.validated.params.id, req.body.items, req.user)),
  ),

  updateItem: asyncHandler(async (req, res) =>
    ok(
      res,
      orderService.updateItem(
        req.validated.params.id,
        req.validated.params.itemId,
        req.body,
        req.user,
      ),
    ),
  ),

  removeItem: asyncHandler(async (req, res) =>
    ok(
      res,
      orderService.removeItem(req.validated.params.id, req.validated.params.itemId, req.user),
    ),
  ),

  updateItemStatus: asyncHandler(async (req, res) =>
    ok(
      res,
      orderService.updateItemStatus(
        req.validated.params.id,
        req.validated.params.itemId,
        req.body.status,
        req.user,
      ),
    ),
  ),

  moveTable: asyncHandler(async (req, res) =>
    ok(res, orderService.moveTable(req.validated.params.id, req.body.tableId, req.user)),
  ),

  merge: asyncHandler(async (req, res) =>
    ok(res, orderService.mergeOrders(req.validated.params.id, req.body.sourceOrderId, req.user)),
  ),

  sendToKitchen: asyncHandler(async (req, res) =>
    ok(res, orderService.sendToKitchen(req.validated.params.id)),
  ),

  applyDiscount: asyncHandler(async (req, res) =>
    ok(res, orderService.applyDiscount(req.validated.params.id, req.body, req.user)),
  ),

  redeemPromotion: asyncHandler(async (req, res) =>
    ok(res, orderService.redeemPromotionCode(req.validated.params.id, req.body.code, req.user)),
  ),

  removePromotion: asyncHandler(async (req, res) =>
    ok(res, orderService.removePromotion(req.validated.params.id, req.user)),
  ),

  eligiblePromotions: asyncHandler(async (req, res) =>
    ok(res, orderService.listEligiblePromotions(req.validated.params.id)),
  ),

  cancel: asyncHandler(async (req, res) =>
    ok(res, orderService.cancel(req.validated.params.id, req.body.reason, req.user)),
  ),

  kitchenQueue: asyncHandler(async (req, res) => {
    const { status, station } = req.validated.query;
    return ok(
      res,
      orderService.kitchenQueue(status, { branchId: req.branchId, stationCode: station }),
    );
  }),
};

export default orderController;
