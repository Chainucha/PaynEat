// Copyright 2026 Suruch Chakrapeesirisuk
// SPDX-License-Identifier: Apache-2.0

import test, { describe } from 'node:test';
import assert from 'node:assert/strict';
import {
  backupFileName,
  filesToPrune,
  formatStamp,
  parseBackupFileName,
} from '../src/modules/backups/backup.files.js';

// ชื่อไฟล์สำรองและกติกาการเก็บย้อนหลัง (ticket 33) — ฟังก์ชันล้วน ไม่แตะดิสก์

const HOUR = 3600 * 1000;
const DAY = 24 * HOUR;
const at = (iso) => new Date(iso);
const name = (iso, reason) => backupFileName(at(iso), reason);

describe('file names', () => {
  test('carry the shop’s local time and the reason, and read back to the same instant', () => {
    const when = at('2026-09-29T15:15:30.000Z');
    const file = backupFileName(when, 'shift-close');
    assert.match(file, /^payneat-\d{4}-\d{2}-\d{2}T\d{6}[+-]\d{4}-shift-close\.sqlite$/);
    assert.ok(file.includes(formatStamp(when)));
    const parsed = parseBackupFileName(file);
    assert.equal(parsed.at.getTime(), when.getTime());
    assert.equal(parsed.reason, 'shift-close');
  });

  test('ignore files that are not PaynEat backups', () => {
    assert.equal(parseBackupFileName('payneat.sqlite'), null);
    assert.equal(parseBackupFileName('photo.jpg'), null);
    assert.equal(
      parseBackupFileName('.payneat-2026-09-29T221530+0700-manual.sqlite.partial'),
      null,
    );
    assert.ok(parseBackupFileName('payneat-2026-09-29T221530+0700-manual-2.sqlite'));
    assert.throws(() => backupFileName(new Date(), 'whenever'), /Unknown backup reason/);
  });
});

describe('retention', () => {
  const now = at('2026-10-20T12:00:00.000Z');

  test('keeps every file of the last 48 hours', () => {
    const files = [
      name('2026-10-20T11:00:00Z', 'scheduled'),
      name('2026-10-19T09:00:00Z', 'shift-close'),
      name('2026-10-18T13:00:00Z', 'manual'),
    ];
    assert.deepEqual(filesToPrune(files, { now, keepDays: 0 }), []);
  });

  test('keeps the newest file of each day for keepDays days, and drops the rest', () => {
    const newest = name('2026-10-20T11:00:00Z', 'scheduled');
    const day5 = [
      name(new Date(now - 5 * DAY - 2 * HOUR).toISOString(), 'scheduled'),
      name(new Date(now - 5 * DAY - HOUR).toISOString(), 'shift-close'),
    ];
    const ancient = name(new Date(now - 40 * DAY).toISOString(), 'shift-close');
    const pruned = filesToPrune([newest, ...day5, ancient], { now, keepDays: 30 });
    assert.deepEqual(pruned.sort(), [ancient, day5[0]].sort());
  });

  test('keeps pre-migration and pre-restore files for 90 days', () => {
    const files = [
      name('2026-10-20T11:00:00Z', 'manual'),
      name(new Date(now - 60 * DAY).toISOString(), 'pre-migration'),
      name(new Date(now - 60 * DAY - HOUR).toISOString(), 'pre-restore'),
      name(new Date(now - 91 * DAY).toISOString(), 'pre-migration'),
    ];
    assert.deepEqual(filesToPrune(files, { now, keepDays: 0 }), [files[3]]);
  });

  test('never leaves zero files, even with keepDays 0 and only old files', () => {
    const files = [
      name(new Date(now - 200 * DAY).toISOString(), 'shift-close'),
      name(new Date(now - 300 * DAY).toISOString(), 'shift-close'),
    ];
    assert.deepEqual(filesToPrune(files, { now, keepDays: 0 }), [files[1]]);
    assert.deepEqual(filesToPrune([], { now, keepDays: 0 }), []);
  });
});
