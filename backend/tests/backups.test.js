// Copyright 2026 Suruch Chakrapeesirisuk
// SPDX-License-Identifier: Apache-2.0

import test, { after, describe, mock } from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';
import os from 'node:os';
import path from 'node:path';
import Database from 'better-sqlite3';

// สำรองข้อมูลอัตโนมัติและกู้คืน (ticket 33, DECISIONS #90, #94): ปิดกะ, รอบ 6 ชั่วโมง, ก่อน migration, ปุ่มสำรองตอนนี้,
// ชุดที่สอง, การเก็บย้อนหลัง, สถานะ/แถบเตือน, สิทธิ์ และคำสั่งกู้คืนทั้ง 4 กรณี

// ชุดที่สองต้องตั้งก่อนโหลด config — จึง import แบบ dynamic หลังตั้ง env
const copyDir = fs.mkdtempSync(path.join(os.tmpdir(), 'payneat-backup-copy-'));
process.env.BACKUP_COPY_DIR = copyDir;
process.env.BACKUP_KEEP_DAYS = '30';

const { api, login, authHeader, cleanup } = await import('./helpers/testApp.js');
const { env } = await import('../src/config/env.js');
const { getDb, closeDb } = await import('../src/db/index.js');
const { backupService, SCHEDULE_INTERVAL_MS, STALE_AFTER_HOURS } =
  await import('../src/modules/backups/backup.service.js');
const { migrateWithBackup, runMigrations } = await import('../src/db/migrate.js');
const { MIGRATIONS } = await import('../src/db/migrations/index.js');
const { restoreBackup } = await import('../src/db/restore.js');
const { startServerHeartbeat, stopServerHeartbeat } = await import('../src/db/serverLock.js');
const { registry } = await import('../src/core/telemetry/metrics.js');

after(() => {
  backupService.stopSchedule();
  stopServerHeartbeat();
  cleanup();
  fs.rmSync(copyDir, { recursive: true, force: true });
});

const backupDir = env.backup.dir;
const backupsIn = (dir) =>
  fs
    .readdirSync(dir)
    .filter((name) => name.startsWith('payneat-') && name.endsWith('.sqlite'))
    .sort();
const newestIn = (dir) => backupsIn(dir).at(-1);
const openBackup = (file) => new Database(file, { readonly: true, fileMustExist: true });
const integrity = (file) => {
  const db = openBackup(file);
  try {
    return db.pragma('integrity_check')[0].integrity_check;
  } finally {
    db.close();
  }
};

const get = (url, token) => api().get(url).set(authHeader(token));
const post = (url, token, body) =>
  api()
    .post(url)
    .set(authHeader(token))
    .send(body ?? {});
const patch = (url, token, body) =>
  api()
    .patch(url)
    .set(authHeader(token))
    .send(body ?? {});

const tokens = {};
const tokenOf = async (username, password) => {
  tokens[username] ??= (await login(username, password)).token;
  return tokens[username];
};
const admin = () => tokenOf('admin', 'admin123');
const manager = () => tokenOf('manager', 'manager123');

describe('backup after closing a shift', () => {
  test('writes a verified backup that holds the closed shift, without failing the close', async () => {
    const token = await manager();
    const current = (await get('/api/v1/shifts/current', token)).body.data;
    assert.ok(current, 'the seed opens a shift');
    const before = backupsIn(backupDir).length;

    const res = await patch(`/api/v1/shifts/${current.id}/close`, token, {
      countedCash: current.openingCash + 125,
      note: 'ปิดกะทดสอบสำรองข้อมูล',
    });
    assert.equal(res.status, 200, JSON.stringify(res.body));
    assert.equal(res.body.data.status, 'closed');
    assert.equal(res.body.data.backup.ok, true, JSON.stringify(res.body.data.backup));
    assert.match(res.body.data.backup.file, /^payneat-.*-shift-close\.sqlite$/);

    const files = backupsIn(backupDir);
    assert.equal(files.length, before + 1);
    const file = path.join(backupDir, res.body.data.backup.file);
    assert.equal(integrity(file), 'ok');
    const copy = openBackup(file);
    try {
      const shift = copy
        .prepare('SELECT status, counted_cash, variance FROM shifts WHERE id = ?')
        .get(current.id);
      assert.equal(shift.status, 'closed');
      assert.equal(shift.counted_cash, res.body.data.countedCash * 100);
      assert.equal(shift.variance, res.body.data.variance * 100);
      // ไฟล์เดียวจบ ไม่มี -wal/-shm ติดมา และอยู่ในโหมด rollback journal
      assert.equal(copy.pragma('journal_mode', { simple: true }), 'delete');
    } finally {
      copy.close();
    }
    assert.ok(!fs.existsSync(`${file}-wal`));

    // ชุดที่สองได้ไฟล์เดียวกัน
    assert.deepEqual(
      fs.readFileSync(path.join(copyDir, res.body.data.backup.file)),
      fs.readFileSync(file),
    );
  });

  test(
    'keeps backups readable by the server account only',
    { skip: process.platform === 'win32' },
    () => {
      assert.equal(fs.statSync(backupDir).mode & 0o777, 0o700);
      for (const name of backupsIn(backupDir)) {
        assert.equal(fs.statSync(path.join(backupDir, name)).mode & 0o777, 0o600, name);
      }
    },
  );

  test('a failed backup does not fail the close: the shift closes and the answer says so', async () => {
    const token = await manager();
    await post('/api/v1/shifts', token, { openingCash: 500 });
    const current = (await get('/api/v1/shifts/current', token)).body.data;

    const hidden = `${backupDir}.away`;
    fs.renameSync(backupDir, hidden);
    fs.writeFileSync(backupDir, 'not a folder');
    try {
      const res = await patch(`/api/v1/shifts/${current.id}/close`, token, {
        countedCash: current.openingCash,
      });
      assert.equal(res.status, 200);
      assert.equal(res.body.data.status, 'closed');
      assert.equal(res.body.data.backup.ok, false);
      const status = (await get('/api/v1/backups/status', token)).body.data;
      assert.equal(status.warning, 'failed');
      assert.ok(status.primary.lastFailure.message);
    } finally {
      fs.rmSync(backupDir, { force: true });
      fs.renameSync(hidden, backupDir);
    }
    // ครั้งถัดไปสำเร็จ แถบเตือนหายเอง
    const res = await post('/api/v1/backups', await admin());
    assert.equal(res.body.data.result.ok, true);
    assert.equal(res.body.data.status.warning, null);
  });
});

describe('backing up while the shop keeps selling', () => {
  test('a large backup leaves the API free, and has no half-written transaction in it', async () => {
    const db = getDb();
    // ฐานข้อมูลใหญ่พอให้ online backup ทำหลายช่วง: หลายหมื่นแถวของบิลจำลองในตารางเฉพาะเทสต์
    db.exec(
      'CREATE TABLE IF NOT EXISTS load_orders (id INTEGER PRIMARY KEY, batch INTEGER NOT NULL, note TEXT NOT NULL)',
    );
    const insert = db.prepare('INSERT INTO load_orders (batch, note) VALUES (?, ?)');
    db.transaction(() => {
      for (let i = 0; i < 40000; i += 1) insert.run(-1, `order ${i} ${'x'.repeat(120)}`);
    })();

    let finished = false;
    const backup = backupService.createBackup('manual').finally(() => {
      finished = true;
    });

    // ระหว่างสำรอง: แต่ละ "การชำระเงิน" เขียนสองแถวในทรานแซกชันเดียว ไฟล์สำรองต้องมีครบคู่หรือไม่มีเลย
    const pay = db.transaction((batch) => {
      insert.run(batch, 'payment');
      insert.run(batch, 'receipt');
    });
    let writesDuringBackup = 0;
    let apiAnsweredDuringBackup = false;
    for (let batch = 1; batch <= 50 && !finished; batch += 1) {
      pay(batch);
      if (!finished) writesDuringBackup += 1;
      if (batch === 1) {
        const res = await get('/api/v1/shifts/current', await manager());
        apiAnsweredDuringBackup = res.status === 200 && !finished;
      }
      await new Promise((resolve) => setImmediate(resolve));
    }
    const result = await backup;
    assert.equal(result.ok, true, result.message);
    assert.ok(writesDuringBackup > 0, 'writes went through while the backup ran');
    assert.ok(apiAnsweredDuringBackup, 'the API answered while the backup ran');

    const file = path.join(backupDir, result.file);
    assert.equal(integrity(file), 'ok');
    const copy = openBackup(file);
    try {
      const halves = copy
        .prepare(
          'SELECT batch, COUNT(*) AS n FROM load_orders WHERE batch > 0 GROUP BY batch HAVING n <> 2',
        )
        .all();
      assert.deepEqual(halves, []);
      assert.equal(
        copy.prepare('SELECT COUNT(*) AS n FROM load_orders WHERE batch = -1').get().n,
        40000,
      );
    } finally {
      copy.close();
    }
    db.exec('DROP TABLE load_orders');
  });
});

describe('scheduled backups', () => {
  test('every six hours, only when something changed since the last backup', async () => {
    await backupService.createBackup('manual');
    assert.equal(await backupService.runScheduled(), null, 'nothing changed: no backup');

    await post('/api/v1/shifts', await manager(), { openingCash: 300 });
    const result = await backupService.runScheduled();
    assert.equal(result.ok, true);
    assert.match(result.file, /-scheduled\.sqlite$/);
    assert.equal(await backupService.runScheduled(), null);
  });

  test('runs on its own clock', async () => {
    mock.timers.enable({ apis: ['setInterval'] });
    const run = mock.method(backupService, 'runScheduled', async () => null);
    try {
      backupService.startSchedule();
      mock.timers.tick(SCHEDULE_INTERVAL_MS - 1);
      assert.equal(run.mock.callCount(), 0);
      mock.timers.tick(1);
      assert.equal(run.mock.callCount(), 1);
      mock.timers.tick(SCHEDULE_INTERVAL_MS);
      assert.equal(run.mock.callCount(), 2);
    } finally {
      backupService.stopSchedule();
      run.mock.restore();
      mock.timers.reset();
    }
  });
});

describe('before a migration', () => {
  const extra = {
    version: 9001,
    name: 'test_extra_column',
    checksum: 'test-9001',
    up(db) {
      db.exec('CREATE TABLE test_backup_marker (id INTEGER PRIMARY KEY)');
    },
  };
  const tableExists = (name) =>
    Boolean(
      getDb().prepare("SELECT 1 FROM sqlite_master WHERE type = 'table' AND name = ?").get(name),
    );

  test('refuses to migrate when the backup fails, and leaves the database unchanged', async () => {
    const hidden = `${backupDir}.away`;
    fs.renameSync(backupDir, hidden);
    fs.writeFileSync(backupDir, 'not a folder');
    try {
      await assert.rejects(migrateWithBackup({ migrations: [...MIGRATIONS, extra] }), (error) => {
        assert.match(error.message, /No migration was run/);
        assert.match(error.message, /9001_test_extra_column/);
        return true;
      });
      assert.equal(tableExists('test_backup_marker'), false);
      assert.equal(
        getDb().prepare('SELECT 1 FROM schema_migrations WHERE version = 9001').get(),
        undefined,
      );
    } finally {
      fs.rmSync(backupDir, { force: true });
      fs.renameSync(hidden, backupDir);
    }
  });

  test('backs up first, then migrates', async () => {
    const before = backupsIn(backupDir).filter((n) => n.includes('pre-migration')).length;
    await migrateWithBackup({ migrations: [...MIGRATIONS, extra] });
    const after = backupsIn(backupDir).filter((n) => n.includes('pre-migration'));
    assert.equal(after.length, before + 1);
    const copy = openBackup(path.join(backupDir, after.at(-1)));
    try {
      const marker = copy
        .prepare("SELECT 1 FROM sqlite_master WHERE type = 'table' AND name = 'test_backup_marker'")
        .get();
      assert.equal(marker, undefined, 'the backup is the database before the migration');
    } finally {
      copy.close();
    }
    assert.equal(tableExists('test_backup_marker'), true);
    // ไม่มี migration ค้าง: เปิดเครื่องครั้งถัดไปไม่สำรองซ้ำ
    const count = backupsIn(backupDir).length;
    await migrateWithBackup({ migrations: [...MIGRATIONS, extra] });
    assert.equal(backupsIn(backupDir).length, count);

    // ถอยกลับให้เทสต์อื่นในไฟล์นี้เห็น schema ปกติ
    getDb().exec('DROP TABLE test_backup_marker');
    getDb().prepare('DELETE FROM schema_migrations WHERE version = 9001').run();
    assert.deepEqual(runMigrations(getDb()), []);
  });
});

describe('the second copy', () => {
  test('fails on its own: the first copy still succeeds and the status says which one failed', async () => {
    const hidden = `${copyDir}.away`;
    fs.renameSync(copyDir, hidden);
    fs.writeFileSync(copyDir, 'not a folder');
    try {
      const result = await backupService.createBackup('manual');
      assert.equal(result.ok, true);
      assert.equal(result.copy.ok, false);
      const status = (await get('/api/v1/backups/status', await admin())).body.data;
      assert.equal(status.warning, null, 'the first copy is fine: no banner');
      assert.equal(status.copy.configured, true);
      assert.equal(status.copy.failing, true);
      assert.ok(status.copy.lastFailure.message);
    } finally {
      fs.rmSync(copyDir, { force: true });
      fs.renameSync(hidden, copyDir);
    }
    const again = await backupService.createBackup('manual');
    assert.equal(again.copy.ok, true);
    assert.equal(backupService.status().copy.failing, false);
  });
});

describe('status and the warning banner', () => {
  test('warns once no backup has succeeded for 26 hours', async () => {
    const status = backupService.status();
    const last = new Date(status.primary.lastSuccess.at);
    assert.equal(backupService.status(new Date(last.getTime() + 25 * 3600 * 1000)).warning, null);
    assert.equal(
      backupService.status(new Date(last.getTime() + (STALE_AFTER_HOURS * 3600 + 1) * 1000))
        .warning,
      'stale',
    );
  });

  test('is shown to admin and manager only', async () => {
    assert.equal((await get('/api/v1/backups/status', await admin())).status, 200);
    assert.equal((await get('/api/v1/backups/status', await manager())).status, 200);
    for (const [username, password] of [
      ['cashier', 'cashier123'],
      ['waiter1', 'waiter123'],
      ['kitchen', 'kitchen123'],
    ]) {
      const res = await get('/api/v1/backups/status', await tokenOf(username, password));
      assert.equal(res.status, 403, username);
    }
  });

  test('exports the last success and failures as metrics', async () => {
    const text = await registry.metrics();
    const last =
      /payneat_backup_last_success_timestamp_seconds\{app="payneat-pos-api"\} (\d+)/.exec(text);
    assert.ok(Number(last?.[1]) > 0, text);
    assert.match(
      text,
      /payneat_backup_failures_total\{app="payneat-pos-api",destination="primary"\} [1-9]/,
    );
    assert.match(
      text,
      /payneat_backup_failures_total\{app="payneat-pos-api",destination="copy"\} [1-9]/,
    );
  });
});

describe('backup now, and no way to download a backup', () => {
  test('only the admin may back up now', async () => {
    const res = await post('/api/v1/backups', await admin());
    assert.equal(res.status, 200);
    assert.equal(res.body.data.result.ok, true);
    assert.match(res.body.data.result.file, /-manual(-\d+)?\.sqlite$/);
    for (const [username, password] of [
      ['manager', 'manager123'],
      ['cashier', 'cashier123'],
      ['waiter1', 'waiter123'],
      ['kitchen', 'kitchen123'],
    ]) {
      const denied = await post('/api/v1/backups', await tokenOf(username, password));
      assert.equal(denied.status, 403, username);
    }
  });

  test('no endpoint lists or sends a backup file', async () => {
    const file = newestIn(backupDir);
    for (const url of [
      '/api/v1/backups',
      `/api/v1/backups/${file}`,
      `/api/v1/backups/${file}/download`,
      `/api/v1/backups/files`,
    ]) {
      const res = await get(url, await admin());
      assert.equal(res.status, 404, url);
      assert.ok(!res.text.includes('SQLite format 3'), url);
    }
  });
});

describe('where backups may live', () => {
  test('never inside a folder that is served or published on the web', () => {
    const original = env.backup.dir;
    try {
      env.backup.dir = path.join(env.rootDir, '..', 'docs', 'landing', 'backups');
      assert.throws(() => backupService.validateDirectories(), /served or published on the web/);
      env.backup.dir = path.join(env.rootDir, 'docs');
      assert.throws(() => backupService.validateDirectories(), /served or published on the web/);
      env.backup.dir = original;
      assert.doesNotThrow(() => backupService.validateDirectories());
    } finally {
      env.backup.dir = original;
    }
  });
});

describe('restoring a backup', () => {
  const restoreDir = fs.mkdtempSync(path.join(os.tmpdir(), 'payneat-restore-'));
  after(() => fs.rmSync(restoreDir, { recursive: true, force: true }));

  test('is refused while the server runs', async () => {
    const file = path.join(backupDir, newestIn(backupDir));
    startServerHeartbeat();
    try {
      await assert.rejects(restoreBackup(file), { code: 'SERVER_RUNNING' });
    } finally {
      stopServerHeartbeat();
    }
  });

  test('is refused for a damaged file, and the database stays as it was', async () => {
    const good = fs.readFileSync(path.join(backupDir, newestIn(backupDir)));
    const damaged = path.join(restoreDir, 'damaged.sqlite');
    // หัวไฟล์ SQLite ถูกต้อง แต่หน้าข้อมูลถูกเขียนทับกลางไฟล์
    const bytes = Buffer.from(good);
    bytes.fill(0x5a, 8192, bytes.length - 8192);
    fs.writeFileSync(damaged, bytes);
    const before = getDb().prepare('SELECT COUNT(*) AS n FROM shifts').get().n;
    await assert.rejects(restoreBackup(damaged), { code: 'INTEGRITY_CHECK_FAILED' });
    assert.equal(getDb().prepare('SELECT COUNT(*) AS n FROM shifts').get().n, before);

    fs.writeFileSync(path.join(restoreDir, 'not-a-database.sqlite'), 'hello');
    await assert.rejects(restoreBackup(path.join(restoreDir, 'not-a-database.sqlite')), {
      code: 'INTEGRITY_CHECK_FAILED',
    });
    await assert.rejects(restoreBackup(path.join(restoreDir, 'missing.sqlite')), {
      code: 'NOT_FOUND',
    });
  });

  test('is refused for a backup made by a newer PaynEat', async () => {
    const newer = path.join(restoreDir, 'newer.sqlite');
    fs.copyFileSync(path.join(backupDir, newestIn(backupDir)), newer);
    const db = new Database(newer);
    db.prepare(
      "INSERT INTO schema_migrations (version, name, checksum) VALUES (9999, 'future', 'x')",
    ).run();
    db.close();
    await assert.rejects(restoreBackup(newer), (error) => {
      assert.equal(error.code, 'NEWER_VERSION');
      assert.match(error.message, /9999/);
      return true;
    });
  });

  test('restores a good backup: the current database is kept as pre-restore, and it is audited', async () => {
    const token = await manager();
    const current = (await get('/api/v1/shifts/current', token)).body.data;
    if (current) {
      await patch(`/api/v1/shifts/${current.id}/close`, token, {
        countedCash: current.openingCash,
      });
    }
    const made = await backupService.createBackup('manual');
    const source = path.join(backupDir, made.file);
    const sourceBytes = fs.readFileSync(source);
    const inBackup = openBackup(source);
    const shiftsInBackup = inBackup.prepare('SELECT COUNT(*) AS n FROM shifts').get().n;
    inBackup.close();

    // งานหลังไฟล์สำรอง: หายไปหลังกู้คืน แต่ยังอยู่ในไฟล์ pre-restore
    await post('/api/v1/shifts', token, { openingCash: 777 });
    const shiftsNow = getDb().prepare('SELECT COUNT(*) AS n FROM shifts').get().n;
    assert.equal(shiftsNow, shiftsInBackup + 1);

    const result = await restoreBackup(source);
    assert.equal(result.restoredFrom, path.basename(source));
    assert.match(result.preRestoreFile, /-pre-restore\.sqlite$/);
    assert.deepEqual(fs.readFileSync(source), sourceBytes, 'the backup file itself is not changed');

    const preRestore = openBackup(path.join(backupDir, result.preRestoreFile));
    assert.equal(preRestore.prepare('SELECT COUNT(*) AS n FROM shifts').get().n, shiftsNow);
    preRestore.close();

    assert.equal(getDb().prepare('SELECT COUNT(*) AS n FROM shifts').get().n, shiftsInBackup);
    const audit = getDb()
      .prepare(
        "SELECT actor_name, summary, metadata_json FROM audit_logs WHERE action = 'system.restore'",
      )
      .all();
    assert.equal(audit.length, 1);
    assert.equal(JSON.parse(audit[0].metadata_json).sourceFile, path.basename(source));
    assert.match(audit[0].summary, /กู้คืนข้อมูลจากไฟล์/);

    // แอปยังทำงานกับฐานข้อมูลที่กู้แล้วได้ทันทีหลังเปิดเซิร์ฟเวอร์ใหม่
    closeDb();
    const res = await get('/api/v1/audit-logs?action=system.restore', await admin());
    assert.equal(res.status, 200);
  });
});

describe('retention', () => {
  test('removes old files by the rule after a new backup, and never the newest', async () => {
    const day = 24 * 3600 * 1000;
    const { backupFileName } = await import('../src/modules/backups/backup.files.js');
    // เที่ยงวันตามเวลาร้าน: สองไฟล์ของวันเดียวกันไม่คร่อมเที่ยงคืน
    const noon = new Date();
    noon.setHours(12, 0, 0, 0);
    const daysAgo = (days, hour = 12) =>
      new Date(noon.getTime() - days * day - (12 - hour) * 3600 * 1000);
    const old = [
      backupFileName(daysAgo(40), 'shift-close'),
      backupFileName(daysAgo(40, 11), 'pre-migration'),
      backupFileName(daysAgo(100), 'pre-migration'),
      backupFileName(daysAgo(10, 11), 'scheduled'),
      backupFileName(daysAgo(10), 'shift-close'),
    ];
    for (const name of old) fs.writeFileSync(path.join(backupDir, name), 'old');
    fs.writeFileSync(path.join(backupDir, 'notes-from-the-owner.txt'), 'keep me');

    const result = await backupService.createBackup('manual');
    assert.equal(result.ok, true);
    const left = new Set(fs.readdirSync(backupDir));
    assert.equal(left.has(old[0]), false, 'past BACKUP_KEEP_DAYS');
    assert.equal(left.has(old[1]), true, 'a pre-migration file is kept 90 days');
    assert.equal(left.has(old[2]), false, 'past 90 days');
    assert.equal(left.has(old[3]), false, 'not the newest of its day');
    assert.equal(left.has(old[4]), true, 'the newest of its day');
    assert.equal(left.has('notes-from-the-owner.txt'), true, 'other files are never touched');
    assert.equal(left.has(result.file), true);
  });
});
