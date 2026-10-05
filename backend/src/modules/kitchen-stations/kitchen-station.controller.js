// Copyright 2026 Suruch Chakrapeesirisuk
// SPDX-License-Identifier: Apache-2.0

import { asyncHandler } from '../../core/asyncHandler.js';
import { ok, created, noContent } from '../../core/response.js';
import { kitchenStationService } from './kitchen-station.service.js';

export const kitchenStationController = {
  list: asyncHandler(async (req, res) =>
    ok(res, kitchenStationService.list(req.validated?.query ?? {})),
  ),
  detail: asyncHandler(async (req, res) =>
    ok(res, kitchenStationService.getById(req.validated.params.id)),
  ),
  create: asyncHandler(async (req, res) => created(res, kitchenStationService.create(req.body))),
  update: asyncHandler(async (req, res) =>
    ok(res, kitchenStationService.update(req.validated.params.id, req.body)),
  ),
  remove: asyncHandler(async (req, res) => {
    kitchenStationService.remove(req.validated.params.id);
    return noContent(res);
  }),
};

export default kitchenStationController;
