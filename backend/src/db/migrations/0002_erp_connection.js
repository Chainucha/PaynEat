// Copyright 2026 Suruch Chakrapeesirisuk
// SPDX-License-Identifier: Apache-2.0

import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

/** Migration 0002 — ตารางของโหมดเชื่อมต่อ PaynEat ERP (ticket 25, docs/DECISIONS.md #80) ทั้งหมดอยู่ใน .sql */

const sql = path.join(path.dirname(fileURLToPath(import.meta.url)), '0002_erp_connection.sql');

export default {
  version: 2,
  name: 'erp_connection',
  files: [fileURLToPath(import.meta.url), sql],
  up(db) {
    db.exec(fs.readFileSync(sql, 'utf8'));
  },
};
