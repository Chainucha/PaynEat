// Copyright 2026 Suruch Chakrapeesirisuk
// SPDX-License-Identifier: Apache-2.0

import fs from 'node:fs';
import os from 'node:os';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
import request from 'supertest';

const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '../..');
const dbFile = path.join(root, `data/test-${process.pid}-${Date.now()}.sqlite`);

// ต้องตั้งค่า env ก่อน import โมดูลที่อ่าน config (จึงใช้ dynamic import ด้านล่าง)
process.env.NODE_ENV = 'test';
process.env.JWT_SECRET = 'test-secret';
process.env.DATABASE_FILE = dbFile;
// ไฟล์สำรองของแต่ละไฟล์เทสต์อยู่ในโฟลเดอร์ชั่วคราวของตัวเอง (ปิดกะในเทสต์สำรองทุกครั้ง — ticket 33)
const backupDir = fs.mkdtempSync(path.join(os.tmpdir(), 'payneat-test-backups-'));
process.env.BACKUP_DIR = backupDir;

const { createApp } = await import('../../src/app.js');
const { seed } = await import('../../src/db/seed.js');
const { closeDb } = await import('../../src/db/index.js');

seed();

export const app = createApp();
export const api = () => request(app);

/** ล็อกอินแล้วคืน token + user สำหรับใช้ใน test */
export const login = async (username, password) => {
  const res = await request(app).post('/api/v1/auth/login').send({ username, password });
  if (res.status !== 200) {
    throw new Error(`login ล้มเหลว (${res.status}): ${JSON.stringify(res.body)}`);
  }
  return res.body.data;
};

export const authHeader = (token) => ({ Authorization: `Bearer ${token}` });

export const cleanup = () => {
  closeDb();
  fs.rmSync(backupDir, { recursive: true, force: true });
  for (const suffix of ['', '-wal', '-shm', '.backup-status.json', '.running']) {
    const file = `${dbFile}${suffix}`;
    if (fs.existsSync(file)) fs.rmSync(file);
  }
};
