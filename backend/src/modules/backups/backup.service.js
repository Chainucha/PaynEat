// Copyright 2026 Suruch Chakrapeesirisuk
// SPDX-License-Identifier: Apache-2.0

import fs from 'node:fs';
import path from 'node:path';
import Database from 'better-sqlite3';
import { env } from '../../config/env.js';
import { getDb } from '../../db/index.js';
import { logger } from '../../core/telemetry/logger.js';
import { recordBackupFailure, recordBackupSuccess } from '../../core/telemetry/metrics.js';
import {
  backupFileName,
  countBackups,
  filesToPrune,
  newestBackup,
  parseBackupFileName,
} from './backup.files.js';

/**
 * สำรองข้อมูลอัตโนมัติ (ticket 33, DECISIONS #90, #94)
 *
 * - ใช้ online backup API ของ SQLite (`db.backup()`) ไม่คัดลอกไฟล์ตรงๆ เพราะฐานข้อมูลใช้ WAL ไฟล์ที่คัดลอกระหว่าง
 *   เซิร์ฟเวอร์ทำงานอาจไม่ครบ backup API ทำทีละช่วงและคืน event loop ระหว่างช่วง จึงขายต่อได้ระหว่างสำรอง
 * - เขียนลงชื่อชั่วคราวก่อน ตรวจ `integrity_check` ผ่านแล้วค่อย rename เป็นชื่อจริง ไฟล์ที่ไม่ผ่านถูกลบและนับเป็นความล้มเหลว
 * - ชุดที่สอง (`BACKUP_COPY_DIR`) ล้มเหลวแยกจากชุดแรก ลบไฟล์เก่าเฉพาะหลังสำรองใหม่สำเร็จ และไม่ลบจนเหลือ 0 ไฟล์
 * - สำรองทีละครั้ง: คำขอที่มาระหว่างสำรองอยู่ต่อคิว ไม่เขียนไฟล์พร้อมกัน
 */

/** เกินเท่านี้ชั่วโมงโดยไม่มีสำรองที่สำเร็จ = แถบเตือนของ admin และ manager */
export const STALE_AFTER_HOURS = 26;
/** สำรองตามรอบระหว่างเซิร์ฟเวอร์ทำงาน ถ้ามีข้อมูลเปลี่ยนตั้งแต่ครั้งก่อน */
export const SCHEDULE_INTERVAL_MS = 6 * 60 * 60 * 1000;

const HOUR = 60 * 60 * 1000;
const PARTIAL_SUFFIX = '.partial';

/** โฟลเดอร์ที่ระบบเสิร์ฟผ่าน HTTP หรือเผยแพร่ออกไป — ไฟล์สำรองห้ามอยู่ในนี้ */
export const servedDirectories = () => [
  path.join(env.rootDir, 'docs'),
  path.join(env.rootDir, '..', 'docs'),
  path.join(env.rootDir, '..', 'app', 'web'),
  path.join(env.rootDir, '..', 'app', 'build', 'web'),
];

const isInside = (child, parent) => {
  const relative = path.relative(path.resolve(parent), path.resolve(child));
  return relative === '' || (!relative.startsWith('..') && !path.isAbsolute(relative));
};

const enabled = () => env.databaseFile !== ':memory:';
/** สถานะล่าสุดอยู่ข้างไฟล์ฐานข้อมูล แยกตามฐานข้อมูล ไม่อยู่ในฐานข้อมูลเอง (การเขียนสถานะไม่นับเป็นข้อมูลเปลี่ยน) */
const statusFile = () => `${env.databaseFile}.backup-status.json`;

const emptyDestination = () => ({ lastSuccess: null, lastFailure: null });
let state;
let queue = Promise.resolve();
let running = false;
let changesAtLastBackup = null;
let timer = null;

const loadState = () => {
  if (state) return state;
  state = { primary: emptyDestination(), copy: emptyDestination(), lowDiskSpace: false };
  try {
    const saved = JSON.parse(fs.readFileSync(statusFile(), 'utf8'));
    state = {
      primary: { ...emptyDestination(), ...saved.primary },
      copy: { ...emptyDestination(), ...saved.copy },
      lowDiskSpace: Boolean(saved.lowDiskSpace),
    };
  } catch {
    // ยังไม่เคยสำรอง หรือไฟล์สถานะเสีย: เริ่มจากไฟล์สำรองที่มีอยู่จริงในโฟลเดอร์แทน (ดู status())
  }
  return state;
};

const saveState = () => {
  try {
    fs.writeFileSync(statusFile(), JSON.stringify(state, null, 2), { mode: 0o600 });
  } catch (error) {
    logger.warning('Could not save the backup status file', {
      error: { type: error.code ?? error.name, message: error.message },
    });
  }
};

/** ลบไฟล์ชั่วคราวแบบไม่โยน error — การเก็บกวาดที่ล้ม (เช่นโฟลเดอร์กลายเป็นไฟล์) ต้องไม่บังผลของการสำรองจริง */
const removeQuietly = (file) => {
  try {
    fs.rmSync(file, { force: true });
  } catch {
    // ไม่มีอะไรให้ลบ หรือลบไม่ได้ — ไม่ใช่ผลของการสำรอง
  }
};

const listDir = (dir) => {
  try {
    return fs.readdirSync(dir);
  } catch {
    return [];
  }
};

/** สร้างโฟลเดอร์และจำกัดสิทธิ์ให้เจ้าของเท่านั้น (0700) — บน Windows ไม่มีโหมดแบบ POSIX จึงข้าม */
const prepareDirectory = (dir) => {
  fs.mkdirSync(dir, { recursive: true, mode: 0o700 });
  if (process.platform !== 'win32') {
    try {
      fs.chmodSync(dir, 0o700);
    } catch (error) {
      // ไดรฟ์บางแบบ (เช่น USB ที่เป็น FAT) ไม่มีสิทธิ์แบบ POSIX ให้ตั้ง — ยังเขียนได้ แต่บอกไว้ใน log
      logger.warning(`Could not restrict permissions of the backup folder ${dir}`, {
        error: { type: error.code ?? error.name, message: error.message },
      });
    }
  }
  fs.accessSync(dir, fs.constants.W_OK);
};

const restrictFile = (file) => {
  if (process.platform !== 'win32') {
    try {
      fs.chmodSync(file, 0o600);
    } catch {
      // ระบบไฟล์ที่ไม่มีสิทธิ์แบบ POSIX — ดู prepareDirectory()
    }
  }
};

const uniqueName = (dir, date, reason) => {
  const base = backupFileName(date, reason);
  if (!fs.existsSync(path.join(dir, base))) return base;
  for (let n = 2; ; n += 1) {
    const candidate = base.replace(/\.sqlite$/, `-${n}.sqlite`);
    if (!fs.existsSync(path.join(dir, candidate))) return candidate;
  }
};

const databaseSize = () =>
  ['', '-wal'].reduce((total, suffix) => {
    try {
      return total + fs.statSync(`${env.databaseFile}${suffix}`).size;
    } catch {
      return total;
    }
  }, 0);

/** true ถ้าดิสก์ของโฟลเดอร์มีที่ว่างน้อยกว่า 2 เท่าของฐานข้อมูล — เตือน แต่ยังลองสำรอง */
const diskSpaceIsLow = (dir) => {
  try {
    const stats = fs.statfsSync(dir);
    return stats.bavail * stats.bsize < 2 * databaseSize();
  } catch {
    return false;
  }
};

/**
 * ตรวจไฟล์ฐานข้อมูลด้วย `integrity_check` และเปลี่ยนเป็น rollback journal (ไฟล์เดียว ไม่มี -wal/-shm ติดมา)
 * คืน null ถ้าผ่าน หรือข้อความที่บอกว่าเสียตรงไหน
 */
export const integrityProblem = (file, { readonly = false } = {}) => {
  let check;
  try {
    check = new Database(file, { readonly, fileMustExist: true });
    if (!readonly) check.pragma('journal_mode = DELETE');
    const rows = check.pragma('integrity_check');
    const messages = rows.map((row) => row.integrity_check);
    return messages.length === 1 && messages[0] === 'ok' ? null : messages.join('; ');
  } catch (error) {
    return error.message;
  } finally {
    check?.close();
  }
};

const failureOf = (error, reason, at) => ({
  at: at.toISOString(),
  reason,
  code: error.code ?? 'BACKUP_FAILED',
  message: error.message,
});

const prune = (dir, now) => {
  try {
    for (const name of filesToPrune(listDir(dir), { now, keepDays: env.backup.keepDays })) {
      fs.rmSync(path.join(dir, name), { force: true });
    }
  } catch (error) {
    logger.warning(`Could not remove old backups in ${dir}`, {
      error: { type: error.code ?? error.name, message: error.message },
    });
  }
};

const copyToSecondDestination = (source, name, reason, now) => {
  const dir = env.backup.copyDir;
  if (!dir) return null;
  const at = now.toISOString();
  const partial = path.join(dir, `.${name}${PARTIAL_SUFFIX}`);
  try {
    prepareDirectory(dir);
    fs.copyFileSync(source, partial);
    restrictFile(partial);
    fs.renameSync(partial, path.join(dir, name));
    state.copy.lastSuccess = { at, file: name, reason };
    prune(dir, now);
    return { ok: true, file: name };
  } catch (error) {
    removeQuietly(partial);
    state.copy.lastFailure = failureOf(error, reason, now);
    recordBackupFailure('copy');
    logger.error(`Copying the backup to BACKUP_COPY_DIR (${dir}) failed`, {
      labels: { reason },
      error: { type: error.code ?? error.name, message: error.message },
    });
    return { ok: false, code: state.copy.lastFailure.code, message: error.message };
  }
};

const changesNow = (db) => db.prepare('SELECT total_changes() AS n').get().n;

const runBackup = async (reason, { db, now }) => {
  const dir = env.backup.dir;
  const startedAt = now();
  loadState();
  let partial;
  try {
    prepareDirectory(dir);
    // สำรองทีละครั้ง ไฟล์ .partial ที่เหลืออยู่จึงค้างจากครั้งที่เครื่องดับกลางทาง
    for (const leftover of listDir(dir).filter(
      (n) => n.startsWith('.') && n.endsWith(PARTIAL_SUFFIX),
    )) {
      removeQuietly(path.join(dir, leftover));
    }
    state.lowDiskSpace = diskSpaceIsLow(dir);
    if (state.lowDiskSpace) {
      logger.warning(
        `Disk space for backups in ${dir} is less than twice the size of the database`,
        { labels: { reason } },
      );
    }
    const name = uniqueName(dir, startedAt, reason);
    partial = path.join(dir, `.${name}${PARTIAL_SUFFIX}`);
    await db.backup(partial);
    const problem = integrityProblem(partial);
    if (problem) {
      throw Object.assign(new Error(`The backup failed its integrity check: ${problem}`), {
        code: 'INTEGRITY_CHECK_FAILED',
      });
    }
    restrictFile(partial);
    const file = path.join(dir, name);
    fs.renameSync(partial, file);
    partial = undefined;

    const finishedAt = now();
    const sizeBytes = fs.statSync(file).size;
    state.primary.lastSuccess = { at: finishedAt.toISOString(), file: name, sizeBytes, reason };
    changesAtLastBackup = changesNow(db);
    recordBackupSuccess(finishedAt);
    logger.info(`Backup written: ${name} (${sizeBytes} bytes)`, { labels: { reason } });

    const copy = copyToSecondDestination(file, name, reason, finishedAt);
    prune(dir, finishedAt);
    saveState();
    return { ok: true, file: name, sizeBytes, copy };
  } catch (error) {
    if (partial) removeQuietly(partial);
    state.primary.lastFailure = failureOf(error, reason, now());
    recordBackupFailure('primary');
    logger.error(`Backup failed (${reason})`, {
      labels: { reason },
      error: { type: error.code ?? error.name, message: error.message },
    });
    saveState();
    return { ok: false, code: state.primary.lastFailure.code, message: error.message };
  }
};

const toResultDto = (result) =>
  result.ok
    ? { ok: true, file: result.file, sizeBytes: result.sizeBytes, copy: result.copy }
    : { ok: false, code: result.code, message: result.message };

export const backupService = {
  /**
   * ตรวจค่าตั้งตอนเปิดเครื่อง — โยน error ถ้าที่เก็บไฟล์สำรองอยู่ในโฟลเดอร์ที่เว็บเสิร์ฟ หรือสองที่เก็บเป็นที่เดียวกัน
   */
  validateDirectories() {
    const targets = [['BACKUP_DIR', env.backup.dir]];
    if (env.backup.copyDir) targets.push(['BACKUP_COPY_DIR', env.backup.copyDir]);
    for (const [name, dir] of targets) {
      const served = servedDirectories().find((parent) => isInside(dir, parent));
      if (served) {
        throw new Error(
          `${name} (${dir}) is inside ${served}, which is served or published on the web. ` +
            'A backup holds customer phone numbers and password hashes: choose a folder outside it.',
        );
      }
    }
    if (env.backup.copyDir && path.resolve(env.backup.copyDir) === path.resolve(env.backup.dir)) {
      throw new Error(
        'BACKUP_COPY_DIR is the same folder as BACKUP_DIR: point it at another disk, such as a USB drive or a NAS.',
      );
    }
  },

  /**
   * สำรองหนึ่งครั้ง (เข้าคิวถ้ามีอีกครั้งกำลังทำอยู่) คืน `{ ok, file, sizeBytes, copy }` หรือ `{ ok: false, code, message }`
   * ไม่โยน error — ผู้เรียกตัดสินเองว่าความล้มเหลวหยุดงานของตัวเองหรือไม่ (ปิดกะไม่หยุด ก่อน migration หยุด)
   */
  createBackup(reason, { db = getDb(), now = () => new Date() } = {}) {
    if (!enabled())
      return Promise.resolve({ ok: false, code: 'DISABLED', message: 'in-memory database' });
    const run = queue.then(async () => {
      running = true;
      try {
        return await runBackup(reason, { db, now });
      } finally {
        running = false;
      }
    });
    queue = run.catch(() => {});
    return run;
  },

  /** หลังปิดกะสำเร็จ — คืนผลแบบย่อให้แอปแสดงคำเตือนถ้าสำรองไม่สำเร็จ การปิดกะไม่ล้มตาม */
  async afterShiftClose() {
    return toResultDto(await this.createBackup('shift-close'));
  },

  /** กด "สำรองข้อมูลตอนนี้" (admin) */
  async backupNow() {
    return toResultDto(await this.createBackup('manual'));
  },

  /** เริ่มนับการเปลี่ยนแปลงข้อมูลจากตอนนี้ — เรียกหลังเปิดเครื่องเสร็จ (migration และ seed เขียนข้อมูลไปแล้ว) */
  markBaseline(db = getDb()) {
    changesAtLastBackup = changesNow(db);
  },

  /** รอบทุก 6 ชั่วโมง: สำรองเฉพาะเมื่อมีข้อมูลเปลี่ยนตั้งแต่ครั้งก่อน คืน null ถ้าไม่มีอะไรเปลี่ยน */
  async runScheduled(db = getDb()) {
    if (changesAtLastBackup !== null && changesNow(db) === changesAtLastBackup) return null;
    return this.createBackup('scheduled', { db });
  },

  startSchedule(intervalMs = SCHEDULE_INTERVAL_MS) {
    if (!enabled() || timer) return;
    timer = setInterval(() => {
      this.runScheduled().catch(() => {});
    }, intervalMs);
    timer.unref?.();
  },

  stopSchedule() {
    if (timer) clearInterval(timer);
    timer = null;
  },

  /** สถานะสำหรับหน้าตั้งค่าและแถบเตือน — ไม่มีเนื้อหาของไฟล์ และไม่มีทางดาวน์โหลดไฟล์ */
  status(now = new Date()) {
    loadState();
    const primaryNames = listDir(env.backup.dir);
    let lastSuccess = state.primary.lastSuccess;
    if (!lastSuccess) {
      // ไม่มีไฟล์สถานะ (เช่น ลบทิ้งไป) แต่มีไฟล์สำรองในโฟลเดอร์ — ใช้ไฟล์ล่าสุดที่มีอยู่จริง
      const newest = newestBackup(primaryNames);
      if (newest) {
        let sizeBytes = null;
        try {
          sizeBytes = fs.statSync(path.join(env.backup.dir, newest.name)).size;
        } catch {
          // ไฟล์หายระหว่างอ่าน
        }
        lastSuccess = {
          at: newest.at.toISOString(),
          file: newest.name,
          sizeBytes,
          reason: newest.reason,
        };
      }
    }
    const lastFailure = state.primary.lastFailure;
    const failedLast =
      Boolean(lastFailure) && (!lastSuccess || new Date(lastFailure.at) > new Date(lastSuccess.at));
    const stale = !lastSuccess || now - new Date(lastSuccess.at) > STALE_AFTER_HOURS * HOUR;
    let warning = null;
    if (failedLast) warning = 'failed';
    else if (!lastSuccess) warning = 'never';
    else if (stale) warning = 'stale';

    const copyConfigured = Boolean(env.backup.copyDir);
    const copy = state.copy;
    return {
      enabled: enabled(),
      running,
      warning,
      staleAfterHours: STALE_AFTER_HOURS,
      lowDiskSpace: state.lowDiskSpace,
      primary: {
        dir: env.backup.dir,
        fileCount: countBackups(primaryNames),
        lastSuccess,
        lastFailure,
      },
      copy: {
        configured: copyConfigured,
        dir: env.backup.copyDir ?? null,
        fileCount: copyConfigured ? countBackups(listDir(env.backup.copyDir)) : 0,
        lastSuccess: copyConfigured ? copy.lastSuccess : null,
        lastFailure: copyConfigured ? copy.lastFailure : null,
        failing:
          copyConfigured &&
          Boolean(copy.lastFailure) &&
          (!copy.lastSuccess || new Date(copy.lastFailure.at) > new Date(copy.lastSuccess.at)),
      },
    };
  },

  /** สำหรับเทสต์: ลืมสถานะในหน่วยความจำ ให้อ่านจากไฟล์ใหม่ */
  resetForTests() {
    state = undefined;
    changesAtLastBackup = null;
    this.stopSchedule();
  },
};

export { parseBackupFileName };
export default backupService;
