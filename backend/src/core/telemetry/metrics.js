// Copyright 2026 Suruch Chakrapeesirisuk
// SPDX-License-Identifier: Apache-2.0

import http from 'node:http';
import { collectDefaultMetrics, Counter, Gauge, Histogram, Registry } from 'prom-client';
import { env } from '../../config/env.js';
import { APP_NAME, logger } from './logger.js';

/**
 * metric แบบ Prometheus ตามสัญญา telemetry v1.1 — เสิร์ฟ `GET /metrics` บนพอร์ตของตัวเอง (METRICS_PORT)
 * ไม่ใช่พอร์ต API: docker compose ไม่เปิดพอร์ตนี้ออกนอกเครื่อง ตัวเก็บ metric เข้าถึงได้เฉพาะในเครือข่าย
 * ภายในเท่านั้น ร้านที่ forward พอร์ต API ออกเน็ตก็ไม่ได้เปิด /metrics ไปด้วย (DECISIONS #68)
 */
export const registry = new Registry();
collectDefaultMetrics({ register: registry });

const requests = new Counter({
  name: 'http_requests_total',
  help: 'HTTP requests handled, by route template and status.',
  labelNames: ['app', 'method', 'route', 'status'],
  registers: [registry],
});

const duration = new Histogram({
  name: 'http_request_duration_seconds',
  help: 'HTTP request duration in seconds, by route template.',
  labelNames: ['app', 'method', 'route'],
  buckets: [0.005, 0.01, 0.025, 0.05, 0.1, 0.25, 0.5, 1, 2.5, 5, 10],
  registers: [registry],
});

// สำรองข้อมูล (ticket 33) — ร้านที่ต่อ monitoring ตั้งเตือนจากสองตัวนี้ได้ เช่น ไม่สำเร็จเกิน 26 ชั่วโมง
const backupLastSuccess = new Gauge({
  name: 'payneat_backup_last_success_timestamp_seconds',
  help: 'Unix time of the last backup written and verified in BACKUP_DIR (0 = none yet).',
  labelNames: ['app'],
  registers: [registry],
});
backupLastSuccess.set({ app: APP_NAME }, 0);

const backupFailures = new Counter({
  name: 'payneat_backup_failures_total',
  help: 'Backups that failed, by destination: primary (BACKUP_DIR) or copy (BACKUP_COPY_DIR).',
  labelNames: ['app', 'destination'],
  registers: [registry],
});

export const recordBackupSuccess = (at) =>
  backupLastSuccess.set({ app: APP_NAME }, Math.floor(at.getTime() / 1000));

/** `destination` เป็น `primary` หรือ `copy` เท่านั้น — ไม่ใส่ path หรือข้อความ error ลง label */
export const recordBackupFailure = (destination) =>
  backupFailures.inc({ app: APP_NAME, destination });

/** `route` ต้องเป็น template (`/api/v1/orders/:id`) เสมอ ห้าม path จริง — ไม่งั้นจำนวน series โตไม่จำกัด */
export const observeRequest = (method, route, status, seconds) => {
  requests.inc({ app: APP_NAME, method, route, status: String(status) });
  duration.observe({ app: APP_NAME, method, route }, seconds);
};

/**
 * เปิดเซิร์ฟเวอร์ /metrics (server.js เรียกตอนเริ่ม) คืน http.Server ที่ฟังอยู่แล้ว — พอร์ต 0 = ให้ระบบเลือก
 * พอร์ตว่างเอง (เทสต์ใช้) ทุก path อื่นตอบ 404
 */
export const startMetricsServer = ({
  port = env.telemetry.metricsPort,
  host = env.telemetry.metricsHost,
} = {}) =>
  new Promise((resolve, reject) => {
    const server = http.createServer((req, res) => {
      if (req.method !== 'GET' || req.url?.split('?')[0] !== '/metrics') {
        res.writeHead(404).end();
        return;
      }
      registry
        .metrics()
        .then((body) => {
          res.writeHead(200, { 'Content-Type': registry.contentType });
          res.end(body);
        })
        .catch(() => res.writeHead(500).end());
    });
    server.once('error', reject);
    server.listen(port, host, () => {
      server.off('error', reject);
      // หลังเปิดพอร์ตได้แล้ว error ของเซิร์ฟเวอร์ metric ต้องไม่ทำให้ POS ล้มทั้งตัว
      server.on('error', (error) =>
        logger.error('Metrics server error', {
          error: { type: error.code ?? error.name, message: error.message },
        }),
      );
      resolve(server);
    });
  });
