// Copyright 2026 Suruch Chakrapeesirisuk
// SPDX-License-Identifier: Apache-2.0

import { z } from 'zod';

export const createBranchSchema = z.object({
  name: z.string().min(1, 'กรุณากรอกชื่อสาขา').max(120),
  code: z.string().min(1).max(32).optional(),
  address: z.string().max(500).optional(),
});

export const updateBranchSchema = z.object({
  name: z.string().min(1).max(120).optional(),
  code: z.string().min(1).max(32).optional(),
  address: z.string().max(500).optional(),
  isActive: z.boolean().optional(),
});

export const idParamSchema = z.object({ id: z.coerce.number().int().positive() });
