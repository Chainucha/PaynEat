// Copyright 2026 Suruch Chakrapeesirisuk
// SPDX-License-Identifier: Apache-2.0

import { asyncHandler } from '../../core/asyncHandler.js';
import { ok } from '../../core/response.js';
import { authService } from './auth.service.js';
import { guardLogin, guardPasswordChange } from './auth.attempts.js';

export const authController = {
  login: asyncHandler(async (req, res) =>
    ok(
      res,
      guardLogin(req, res, () => authService.login(req.body)),
    ),
  ),

  selectBranch: asyncHandler(async (req, res) =>
    ok(res, authService.selectBranch(req.user, req.body.branchId ?? null)),
  ),

  me: asyncHandler(async (req, res) => ok(res, authService.me(req.user.id, req.branchId))),

  changePassword: asyncHandler(async (req, res) => {
    guardPasswordChange(req, res, () => authService.changePassword(req.user.id, req.body));
    return ok(res, { message: 'เปลี่ยนรหัสผ่านเรียบร้อยแล้ว' });
  }),
};

export default authController;
