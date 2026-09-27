// Copyright 2026 Suruch Chakrapeesirisuk
// SPDX-License-Identifier: Apache-2.0

import { asyncHandler } from '../../core/asyncHandler.js';
import { created, ok } from '../../core/response.js';
import { erpService } from './erp.service.js';

export const erpController = {
  mode: asyncHandler(async (_req, res) => ok(res, erpService.mode())),

  status: asyncHandler(async (_req, res) => ok(res, erpService.status())),

  connect: asyncHandler(async (req, res) => ok(res, await erpService.connect(req.body, req.user))),

  disconnect: asyncHandler(async (req, res) => ok(res, erpService.disconnect(req.user))),

  pull: asyncHandler(async (_req, res) => {
    const result = await erpService.pull({ manual: true });
    return ok(res, { result, status: erpService.status() });
  }),

  createBranch: asyncHandler(async (req, res) =>
    created(res, await erpService.createServedBranch(req.body, req.user)),
  ),
};

export default erpController;
