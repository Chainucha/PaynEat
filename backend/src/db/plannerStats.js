// Copyright 2026 Suruch Chakrapeesirisuk
// SPDX-License-Identifier: Apache-2.0

import { getDb } from './index.js';
import { logger } from '../core/telemetry/logger.js';

/**
 * สถิติของ query planner (`sqlite_stat1`) — ไม่มีสถิติ SQLite เดาว่าทุก index เลือกได้ดีเท่ากัน แล้วเลือกผิด
 * เช่นหน้าผังโต๊ะไล่ออเดอร์ทุกใบในอดีตของแต่ละโต๊ะ (ข้อมูล 1 ปี: 37 ms → 0.1 ms หลัง ANALYZE) ดู
 * docs/DECISIONS.md #101
 *
 * `PRAGMA optimize` อย่างเดียวไม่พอ: ทดสอบแล้วไม่วิเคราะห์ใหม่แม้ออเดอร์โตจาก 600 เป็น 110,000 แถว สถิติที่เก็บตอน
 * ร้านเพิ่งเปิดจึงค้างไปตลอด เลยตรวจเองจากจำนวนออเดอร์ (ตารางที่โตเร็วสุด) — ไม่มีสถิติ หรือจำนวนเปลี่ยนไปตั้งแต่
 * 2 เท่าขึ้นไปจากตอนวิเคราะห์ครั้งก่อน ก็รัน ANALYZE ทั้งฐานข้อมูล (ข้อมูล 1 ปีใช้ราว 0.25 วินาที)
 */
export const REFRESH_INTERVAL_MS = 6 * 60 * 60 * 1000;
const GROWTH_FACTOR = 2;

const analyzedOrderCount = (db) => {
  const hasStats = db
    .prepare("SELECT 1 FROM sqlite_master WHERE type = 'table' AND name = 'sqlite_stat1'")
    .get();
  if (!hasStats) return null;
  // แถวแรกของ stat คือจำนวนแถวของตารางตอนวิเคราะห์ — ทุก index ของตารางเดียวกันได้ค่าเดียวกัน
  const row = db.prepare("SELECT stat FROM sqlite_stat1 WHERE tbl = 'orders' LIMIT 1").get();
  return row ? Number(row.stat.split(' ')[0]) : null;
};

/** รัน ANALYZE ถ้าสถิติไม่มีหรือเก่าเกินไป — คืน true ถ้าได้รัน */
export const refreshPlannerStats = (db = getDb()) => {
  const current = db.prepare('SELECT COUNT(*) AS n FROM orders').get().n;
  const analyzed = analyzedOrderCount(db);
  const stale =
    analyzed === null || current >= analyzed * GROWTH_FACTOR || current * GROWTH_FACTOR <= analyzed;
  if (!stale) return false;
  db.exec('ANALYZE');
  return true;
};

let timer = null;

const refreshQuietly = () => {
  try {
    refreshPlannerStats();
  } catch (error) {
    // สถิติเป็นของเสริมความเร็ว ไม่ใช่เหตุให้ร้านขายไม่ได้
    logger.warning('Could not refresh query planner statistics', {
      error: { type: error.code ?? error.name, message: error.message },
    });
  }
};

/** ตรวจครั้งแรกทันที (หลัง migration) แล้วตรวจซ้ำตามรอบ */
export const startPlannerStatsSchedule = (intervalMs = REFRESH_INTERVAL_MS) => {
  if (timer) return;
  refreshQuietly();
  timer = setInterval(refreshQuietly, intervalMs);
  timer.unref?.();
};

export const stopPlannerStatsSchedule = () => {
  if (timer) clearInterval(timer);
  timer = null;
};
