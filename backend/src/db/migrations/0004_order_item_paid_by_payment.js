// Copyright 2026 Suruch Chakrapeesirisuk
// SPDX-License-Identifier: Apache-2.0

import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

/** Migration 0004 — `order_items.paid_by_payment_id` (T06 #82, docs/DECISIONS.md #87) ทั้งหมดอยู่ใน .sql */

const sql = path.join(
  path.dirname(fileURLToPath(import.meta.url)),
  '0004_order_item_paid_by_payment.sql',
);

export default {
  version: 4,
  name: 'order_item_paid_by_payment',
  files: [fileURLToPath(import.meta.url), sql],
  up(db) {
    db.exec(fs.readFileSync(sql, 'utf8'));
  },
};
