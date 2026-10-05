// Copyright 2026 Suruch Chakrapeesirisuk
// SPDX-License-Identifier: Apache-2.0

import fs from 'node:fs';
import os from 'node:os';
import { env } from '../config/env.js';

/**
 * ไฟล์บอกว่าเซิร์ฟเวอร์กำลังใช้ฐานข้อมูลนี้อยู่ (ticket 33) — คำสั่งกู้คืนอ่านไฟล์นี้แล้วปฏิเสธถ้าเซิร์ฟเวอร์ยังทำงาน
 *
 * ใช้เวลาที่เขียนล่าสุด (heartbeat) ไม่ใช่ PID: ใน Docker คำสั่งกู้คืนรันในคอนเทนเนอร์อีกตัว (`docker compose run`)
 * ที่มองไม่เห็น process ของเซิร์ฟเวอร์ แต่เห็นไฟล์นี้ใน volume เดียวกัน ไฟล์ที่ไม่ได้เขียนนานเกิน
 * RUNNING_STALE_MS ถือว่าค้างจากเซิร์ฟเวอร์ที่ดับไปแล้ว (ไฟฟ้าดับ) ไม่ขวางการกู้คืน
 */
export const HEARTBEAT_MS = 10 * 1000;
export const RUNNING_STALE_MS = 30 * 1000;

export const runningFile = () => `${env.databaseFile}.running`;

let timer = null;
let startedAt = null;

const write = () => {
  const record = {
    pid: process.pid,
    host: os.hostname(),
    startedAt,
    heartbeatAt: new Date().toISOString(),
  };
  try {
    fs.writeFileSync(runningFile(), JSON.stringify(record));
  } catch {
    // เขียนไม่ได้ก็ไม่ใช่เหตุให้ร้านขายไม่ได้ — คำสั่งกู้คืนยังตรวจ heartbeat ที่เขียนได้ล่าสุด
  }
};

export const startServerHeartbeat = () => {
  if (env.databaseFile === ':memory:' || timer) return;
  startedAt = new Date().toISOString();
  write();
  timer = setInterval(write, HEARTBEAT_MS);
  timer.unref?.();
};

export const stopServerHeartbeat = () => {
  if (timer) clearInterval(timer);
  timer = null;
  fs.rmSync(runningFile(), { force: true });
};

/** ข้อมูลของเซิร์ฟเวอร์ที่ยังทำงานกับฐานข้อมูลนี้ หรือ null ถ้าไม่มี (หรือไฟล์ค้างจากเซิร์ฟเวอร์ที่ดับไปแล้ว) */
export const runningServer = (now = new Date()) => {
  try {
    const record = JSON.parse(fs.readFileSync(runningFile(), 'utf8'));
    const age = now - new Date(record.heartbeatAt);
    return age >= 0 && age < RUNNING_STALE_MS ? record : null;
  } catch {
    return null;
  }
};
