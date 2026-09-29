// Copyright 2026 Suruch Chakrapeesirisuk
// SPDX-License-Identifier: Apache-2.0

import { asyncHandler } from '../../core/asyncHandler.js';
import { ok, created, noContent } from '../../core/response.js';
import { userService } from './user.service.js';

export const userController = {
  list: asyncHandler(async (req, res) =>
    ok(res, userService.list(req.validated?.query ?? {}, req.user)),
  ),

  detail: asyncHandler(async (req, res) =>
    ok(res, userService.getById(req.validated.params.id, req.user)),
  ),

  create: asyncHandler(async (req, res) =>
    created(res, userService.create(req.body, req.user, req.branchId)),
  ),

  update: asyncHandler(async (req, res) =>
    ok(res, userService.update(req.validated.params.id, req.body, req.user)),
  ),

  resetPassword: asyncHandler(async (req, res) =>
    ok(res, userService.resetPassword(req.validated.params.id, req.body.password, req.user)),
  ),

  remove: asyncHandler(async (req, res) => {
    userService.remove(req.validated.params.id, req.user);
    return noContent(res);
  }),
};

export default userController;
