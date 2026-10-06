// Copyright 2026 Suruch Chakrapeesirisuk
// SPDX-License-Identifier: Apache-2.0

import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

/** Migration 0007 — ผูกพนักงานกับสถานีครัว (ticket 35, docs/DECISIONS.md #95) ทั้งหมดอยู่ใน .sql */

const sql = path.join(path.dirname(fileURLToPath(import.meta.url)), '0007_user_stations.sql');

export default {
  version: 7,
  name: 'user_stations',
  files: [fileURLToPath(import.meta.url), sql],
  up(db) {
    db.exec(fs.readFileSync(sql, 'utf8'));
  },
};
