// Copyright 2026 Suruch Chakrapeesirisuk
// SPDX-License-Identifier: Apache-2.0

import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

/** Migration 0006 — สถานีครัว (ticket 34, docs/DECISIONS.md #97) ทั้งหมดอยู่ใน .sql */

const sql = path.join(path.dirname(fileURLToPath(import.meta.url)), '0006_kitchen_stations.sql');

export default {
  version: 6,
  name: 'kitchen_stations',
  files: [fileURLToPath(import.meta.url), sql],
  up(db) {
    db.exec(fs.readFileSync(sql, 'utf8'));
  },
};
