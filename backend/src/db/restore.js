// Copyright 2026 Suruch Chakrapeesirisuk
// SPDX-License-Identifier: Apache-2.0

import fs from 'node:fs';
import path from 'node:path';
import Database from 'better-sqlite3';
import { env } from '../config/env.js';
import { closeDb, getDb } from './index.js';
import { MIGRATIONS } from './migrations/index.js';
import { runningServer } from './serverLock.js';
import { backupService, integrityProblem } from '../modules/backups/backup.service.js';
import { auditLogService } from '../modules/audit-logs/audit-log.service.js';

/**
 * กู้คืนฐานข้อมูลจากไฟล์สำรอง (ticket 33, DECISIONS #90) — คำสั่งบนเครื่องเซิร์ฟเวอร์เท่านั้น ไม่มีปุ่มและไม่มี API
 *
 *   npm run db:restore -- data/backups/payneat-2026-09-29T221530+0700-shift-close.sqlite
 *
 * ตามลำดับ: ปฏิเสธถ้าเซิร์ฟเวอร์ยังทำงาน → ตรวจ integrity_check → ปฏิเสธไฟล์จาก PaynEat ที่ใหม่กว่า → สำรองฐานข้อมูล
 * ปัจจุบันเป็น pre-restore ก่อนเสมอ → แทนที่ → เขียน audit `system.restore` ลงฐานข้อมูลที่กู้แล้ว
 * ไฟล์ต้นทางไม่ถูกแก้ไข: ตรวจและแทนที่ด้วยสำเนาของมัน
 */

export class RestoreError extends Error {
  constructor(code, message) {
    super(message);
    this.code = code;
  }
}

const knownVersions = (migrations) => new Set(migrations.map((migration) => migration.version));

/** เวอร์ชัน migration ในไฟล์ หรือโยน RestoreError ถ้าไม่ใช่ฐานข้อมูลของ PaynEat */
const migrationsIn = (file) => {
  const db = new Database(file, { readonly: true, fileMustExist: true });
  try {
    const hasTable = db
      .prepare("SELECT 1 FROM sqlite_master WHERE type = 'table' AND name = 'schema_migrations'")
      .get();
    if (!hasTable) {
      throw new RestoreError(
        'NOT_PAYNEAT',
        'This file is not a PaynEat database (it has no schema_migrations table).',
      );
    }
    return db
      .prepare('SELECT version FROM schema_migrations')
      .all()
      .map((row) => row.version);
  } finally {
    db.close();
  }
};

export const restoreBackup = async (source, { migrations = MIGRATIONS, now = new Date() } = {}) => {
  if (env.databaseFile === ':memory:') {
    throw new RestoreError(
      'IN_MEMORY',
      'DATABASE_FILE is :memory: — there is nothing to restore into.',
    );
  }
  const server = runningServer(now);
  if (server) {
    throw new RestoreError(
      'SERVER_RUNNING',
      `The PaynEat server is still running (process ${server.pid} on ${server.host}). Stop it first: ` +
        'press Ctrl+C in its window, or run `docker compose stop api` for Docker. Then run this again.',
    );
  }

  const sourceFile = path.resolve(source ?? '');
  if (!source || !fs.existsSync(sourceFile) || !fs.statSync(sourceFile).isFile()) {
    throw new RestoreError('NOT_FOUND', `No backup file at ${sourceFile}.`);
  }

  // ทำงานกับสำเนาข้างไฟล์ฐานข้อมูล: ตรวจแล้วเปลี่ยนชื่อทับได้ทันที และไฟล์ต้นทางไม่ถูกเปลี่ยน
  fs.mkdirSync(path.dirname(env.databaseFile), { recursive: true });
  const staged = `${env.databaseFile}.restore-${process.pid}.partial`;
  fs.copyFileSync(sourceFile, staged);
  try {
    const problem = integrityProblem(staged);
    if (problem) {
      throw new RestoreError(
        'INTEGRITY_CHECK_FAILED',
        `The backup file is damaged and was not restored: ${problem}`,
      );
    }
    const known = knownVersions(migrations);
    const newer = migrationsIn(staged).filter((version) => !known.has(version));
    if (newer.length > 0) {
      throw new RestoreError(
        'NEWER_VERSION',
        `This backup was made by a newer PaynEat (migration ${newer.join(', ')}). ` +
          'Update PaynEat to that version or newer first, then restore it.',
      );
    }

    let preRestoreFile = null;
    if (fs.existsSync(env.databaseFile)) {
      const result = await backupService.createBackup('pre-restore', { db: getDb() });
      if (!result.ok) {
        throw new RestoreError(
          'PRE_RESTORE_BACKUP_FAILED',
          `Could not back up the current database first (${result.message}), so nothing was ` +
            `replaced. Make sure BACKUP_DIR (${env.backup.dir}) can be written to and has free space.`,
        );
      }
      preRestoreFile = result.file;
    }
    closeDb();

    for (const suffix of ['-wal', '-shm', '']) {
      fs.rmSync(`${env.databaseFile}${suffix}`, { force: true });
    }
    fs.renameSync(staged, env.databaseFile);

    const fileName = path.basename(sourceFile);
    auditLogService.log({
      actorUser: null,
      action: 'system.restore',
      entityType: 'system',
      summary: preRestoreFile
        ? `กู้คืนข้อมูลจากไฟล์ ${fileName} (ฐานข้อมูลก่อนกู้คืนสำรองไว้ที่ ${preRestoreFile})`
        : `กู้คืนข้อมูลจากไฟล์ ${fileName}`,
      summaryArgs: { file: fileName, preRestore: preRestoreFile ?? '' },
      metadata: { sourceFile: fileName, preRestoreFile },
    });
    closeDb();
    return { restoredFrom: fileName, preRestoreFile };
  } finally {
    fs.rmSync(staged, { force: true });
    for (const suffix of ['-wal', '-shm', '-journal'])
      fs.rmSync(`${staged}${suffix}`, { force: true });
  }
};

if (import.meta.url === `file://${process.argv[1]}`) {
  const out = (line) => process.stdout.write(`${line}\n`);
  try {
    const result = await restoreBackup(process.argv[2]);
    out(`Restored ${env.databaseFile} from ${result.restoredFrom}.`);
    if (result.preRestoreFile) {
      out(
        `The database it replaced is kept as ${path.join(env.backup.dir, result.preRestoreFile)}.`,
      );
    }
    out('Start the server again. A newer PaynEat updates the restored database when it starts.');
  } catch (error) {
    process.stderr.write(`Restore refused: ${error.message}\n`);
    if (!process.argv[2]) {
      process.stderr.write('Usage: npm run db:restore -- <backup file>\n');
    }
    process.exitCode = 1;
  }
}

export default restoreBackup;
