// Copyright 2026 Suruch Chakrapeesirisuk
// SPDX-License-Identifier: Apache-2.0

import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

/** Migration 0008 — ปิด/เปิดสถานีครัวรายสาขา (ticket 36, docs/DECISIONS.md #102) ทั้งหมดอยู่ใน .sql */

const sql = path.join(path.dirname(fileURLToPath(import.meta.url)), '0008_station_closures.sql');

export default {
  version: 8,
  name: 'station_closures',
  files: [fileURLToPath(import.meta.url), sql],
  up(db) {
    db.exec(fs.readFileSync(sql, 'utf8'));
  },
};
