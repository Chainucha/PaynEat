// Copyright 2026 Suruch Chakrapeesirisuk
// SPDX-License-Identifier: Apache-2.0

import { Worker } from 'node:worker_threads';

/**
 * ตรวจ/สร้าง hash รหัสผ่านบน worker thread (DECISIONS #101) — bcrypt ราว 60 ms ต่อครั้ง ถ้ารันบน thread หลัก ทุกคำขออื่นของร้าน
 * ต้องรอ `bcrypt.compare` แบบ async ของ bcryptjs ไม่ช่วย: แบ่งงานเป็นช่วงละไม่เกิน 100 ms ซึ่งรหัสผ่านหนึ่งครั้งจบในช่วงเดียว
 *
 * worker ตัวเดียวพอ (เข้าสู่ระบบไม่ถี่) สร้างตอนใช้ครั้งแรก และไม่รั้ง process ไว้ตอนว่าง
 */
let worker = null;
let nextId = 0;
const pending = new Map();

const failPending = (error) => {
  for (const { reject } of pending.values()) reject(error);
  pending.clear();
};

const start = () => {
  const created = new Worker(new URL('./passwordHash.worker.js', import.meta.url));
  created.on('message', ({ id, result, error }) => {
    const job = pending.get(id);
    if (!job) return;
    pending.delete(id);
    if (pending.size === 0) created.unref();
    if (error) job.reject(new Error(error));
    else job.resolve(result);
  });
  created.on('error', (error) => {
    if (worker === created) worker = null;
    failPending(error);
  });
  created.on('exit', () => {
    if (worker === created) worker = null;
    failPending(new Error('Password hashing worker stopped'));
  });
  created.unref();
  return created;
};

const run = (op, args) =>
  new Promise((resolve, reject) => {
    worker ??= start();
    const id = (nextId += 1);
    pending.set(id, { resolve, reject });
    worker.ref();
    worker.postMessage({ id, op, args });
  });

export const comparePassword = (password, hash) => run('compare', [password, hash]);

export const hashPassword = (password, rounds = 10) => run('hash', [password, rounds]);
