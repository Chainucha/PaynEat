// Copyright 2026 Suruch Chakrapeesirisuk
// SPDX-License-Identifier: Apache-2.0

// PaynEat POS — original project by SuruchBoss (https://github.com/SuruchBoss/PaynEat)
// Licensed under Apache License 2.0 — see LICENSE and NOTICE at repo root
import http from 'node:http';
import { env } from './config/env.js';
import { createApp } from './app.js';
import { migrateWithBackup } from './db/migrate.js';
import { seed } from './db/seed.js';
import { initSocket } from './realtime/socket.js';
import { closeDb } from './db/index.js';
import { startServerHeartbeat, stopServerHeartbeat } from './db/serverLock.js';
import { backupService } from './modules/backups/backup.service.js';
import { scaleService } from './modules/scale/scale.service.js';
import {
  checkErpTransportOnStartup,
  startErpPullSchedule,
  stopErpPullSchedule,
} from './modules/erp/erp.service.js';
import { logger } from './core/telemetry/logger.js';
import { startMetricsServer } from './core/telemetry/metrics.js';

// สำรองข้อมูล (ticket 33): ที่เก็บต้องไม่อยู่ในโฟลเดอร์ที่เว็บเสิร์ฟ และ migration ใหม่ต้องมีไฟล์สำรองก่อนเสมอ —
// ตั้งผิดหรือสำรองไม่สำเร็จ เซิร์ฟเวอร์ไม่เปิด และยังไม่มี migration ใดถูกรัน
try {
  backupService.validateDirectories();
  await migrateWithBackup();
} catch (error) {
  logger.critical(error.message);
  process.exit(1);
}
if (process.env.AUTO_SEED !== 'false') seed();
// นับการเปลี่ยนแปลงข้อมูลสำหรับรอบทุก 6 ชั่วโมงหลัง migration และ seed เขียนไปแล้ว
backupService.markBaseline();
backupService.startSchedule();
startServerHeartbeat();

const app = createApp();
const server = http.createServer(app);
initSocket(server);
scaleService.start();
// ดึง master data จาก PaynEat ERP ตามรอบ — เครื่องที่ใช้งานเดี่ยวไม่มีการเชื่อมต่อ จึงไม่มีอะไรเกิดขึ้น (ticket 25)
startErpPullSchedule();
// credential ไป ERP ทาง https เท่านั้น (ticket 32) — เตือนใน log ถ้าอนุญาต http และหยุดการเชื่อมต่อ http เดิมทันที
checkErpTransportOnStartup();

server.listen(env.port, env.host, () => {
  // log เป็น JSON บรรทัดละ object ตามสัญญา telemetry (ticket 24) — แทนป้ายต้อนรับแบบข้อความเดิม
  logger.info(
    `PaynEat POS API listening on http://localhost:${env.port} ` +
      `(REST /api/v1, docs /docs, health /health, realtime socket.io)`,
  );
  logger.info(
    `Database ${env.databaseFile}; scale driver ${env.scale.driver}; environment ${env.nodeEnv}`,
  );
});

let metricsServer;
startMetricsServer()
  .then((started) => {
    metricsServer = started;
    logger.info(`Metrics served on :${started.address().port}/metrics (not the API port)`);
  })
  .catch((error) => {
    // POS ขายต่อได้แม้ /metrics เปิดไม่ได้ (เช่นพอร์ตชน) — metric เป็นของเสริม ไม่ใช่เหตุให้ร้านขายไม่ได้
    logger.error(`Metrics server could not start on :${env.telemetry.metricsPort}`, {
      error: { type: error.code ?? error.name, message: error.message },
    });
  });

const shutdown = (signal) => {
  logger.info(`${signal} received, shutting down`);
  scaleService.stop();
  stopErpPullSchedule();
  backupService.stopSchedule();
  stopServerHeartbeat();
  metricsServer?.close();
  server.close(() => {
    closeDb();
    process.exit(0);
  });
};

process.on('SIGINT', () => shutdown('SIGINT'));
process.on('SIGTERM', () => shutdown('SIGTERM'));
