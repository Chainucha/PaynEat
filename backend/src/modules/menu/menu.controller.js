// Copyright 2026 Suruch Chakrapeesirisuk
// SPDX-License-Identifier: Apache-2.0

import { asyncHandler } from '../../core/asyncHandler.js';
import { ok, created, noContent, paginated } from '../../core/response.js';
import { menuService } from './menu.service.js';

export const menuController = {
  list: asyncHandler(async (req, res) => {
    const query = req.validated.query;
    const { items, total } = menuService.list(query, req.branchId);
    return paginated(res, items, { page: query.page, limit: query.limit, total });
  }),

  detail: asyncHandler(async (req, res) => ok(res, menuService.getById(req.validated.params.id))),

  create: asyncHandler(async (req, res) =>
    created(res, menuService.create(req.body, req.branchId)),
  ),

  update: asyncHandler(async (req, res) =>
    ok(res, menuService.update(req.validated.params.id, req.body, req.user)),
  ),

  // URL ที่มี v ตรงรูปปัจจุบันไม่มีวันชี้ไปรูปอื่น จึง cache ได้ยาว — v เก่า/ไม่มี v ให้ถามใหม่ทุกครั้ง (DECISIONS #101)
  image: asyncHandler(async (req, res) => {
    const image = menuService.image(req.validated.params.id, req.query.v);
    res.set({
      'Content-Type': image.mimeType,
      'Cache-Control': image.isCurrent ? 'public, max-age=31536000, immutable' : 'no-cache',
      // แอปเว็บตอนพัฒนาอยู่คนละ origin กับ API — helmet ตั้ง same-origin ไว้ ซึ่งบล็อกรูปข้าม origin
      'Cross-Origin-Resource-Policy': 'cross-origin',
    });
    return res.send(image.bytes);
  }),

  setAvailability: asyncHandler(async (req, res) =>
    ok(res, menuService.setAvailability(req.validated.params.id, req.body.isAvailable)),
  ),

  remove: asyncHandler(async (req, res) => {
    menuService.remove(req.validated.params.id);
    return noContent(res);
  }),
};

export default menuController;
