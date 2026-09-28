// Copyright 2026 Suruch Chakrapeesirisuk
// SPDX-License-Identifier: Apache-2.0

import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

/** Migration 0003 — `order_items.kitchen_reached` (T05 #104, docs/DECISIONS.md #86) ทั้งหมดอยู่ใน .sql */

const sql = path.join(
  path.dirname(fileURLToPath(import.meta.url)),
  '0003_order_item_kitchen_reached.sql',
);

export default {
  version: 3,
  name: 'order_item_kitchen_reached',
  files: [fileURLToPath(import.meta.url), sql],
  up(db) {
    db.exec(fs.readFileSync(sql, 'utf8'));
  },
};
