// Copyright 2026 Suruch Chakrapeesirisuk
// SPDX-License-Identifier: Apache-2.0

import 'dotenv/config';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
import { parseCorsOrigin } from './cors.js';
import { SEVERITIES } from '../core/telemetry/logRecord.js';

const rootDir = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '../..');

const toInt = (value, fallback) => {
  const parsed = Number.parseInt(value ?? '', 10);
  return Number.isNaN(parsed) ? fallback : parsed;
};

// ห้ามมี fallback secret ที่ใช้งานได้จริงในโค้ด — ถ้าใครก็ตามที่เห็นซอร์สนี้รู้ค่า default
// ก็ปลอม JWT สิทธิ์ admin ได้ทันทีถ้าเซิร์ฟเวอร์ไหนลืมตั้งค่า env นี้ (ดู SECURITY.md)
// จึงบังคับให้ตั้งค่าเองเสมอ ไม่ตั้งค่าก็ไม่ต้องให้เซิร์ฟเวอร์ start (fail-closed)
if (!process.env.JWT_SECRET) {
  throw new Error(
    'ต้องตั้งค่า JWT_SECRET ใน environment ก่อนรันเซิร์ฟเวอร์ (ดู .env.example) — ' +
      'ไม่มีค่าเริ่มต้นให้เพื่อความปลอดภัย',
  );
}

/** ความยาวขั้นต่ำของ JWT_SECRET ใน production (`openssl rand -hex 32` ได้ 64 ตัว) */
export const JWT_SECRET_MIN_LENGTH = 32;

/** ค่าที่อยู่ใน repo (ตัวอย่าง เดโม เทสต์) — production ต้องใช้ค่าที่ร้านสุ่มเอง (T19, DECISIONS #83) */
const PUBLISHED_JWT_SECRETS = new Set([
  'change-this-secret-in-production',
  'payneat-local-demo-secret',
  'test-secret',
  'e2e-secret',
]);

/** เหตุผลที่ JWT_SECRET ใช้ใน production ไม่ได้ หรือ undefined ถ้าใช้ได้ — ตอนพัฒนา/เดโมไม่ตรวจ */
export const jwtSecretProblem = (secret, nodeEnv) => {
  if (nodeEnv !== 'production') return undefined;
  if (PUBLISHED_JWT_SECRETS.has(secret)) {
    return 'JWT_SECRET เป็นค่าตัวอย่างที่เผยแพร่อยู่ใน repo — ตั้งค่าสุ่มของร้านเอง เช่นจาก `openssl rand -hex 32`';
  }
  if (secret.length < JWT_SECRET_MIN_LENGTH) {
    return `JWT_SECRET ใน production ต้องยาวอย่างน้อย ${JWT_SECRET_MIN_LENGTH} ตัวอักษร — ตั้งค่าสุ่ม เช่นจาก \`openssl rand -hex 32\``;
  }
  return undefined;
};

const jwtProblem = jwtSecretProblem(process.env.JWT_SECRET, process.env.NODE_ENV);
if (jwtProblem) throw new Error(jwtProblem);

export const env = {
  rootDir,
  nodeEnv: process.env.NODE_ENV ?? 'development',
  // แนบ stack ของ error 500 ไปกับคำตอบ — เฉพาะตอนดีบักที่ตั้งเองชัดเจน และไม่ทำงานใน production
  exposeErrorStack:
    process.env.EXPOSE_ERROR_STACK === 'true' && process.env.NODE_ENV !== 'production',
  isTest: process.env.NODE_ENV === 'test',
  port: toInt(process.env.PORT, 3000),
  host: process.env.HOST ?? '0.0.0.0',
  databaseFile: process.env.DATABASE_FILE
    ? path.resolve(rootDir, process.env.DATABASE_FILE)
    : path.resolve(rootDir, 'data/payneat.sqlite'),
  jwt: {
    secret: process.env.JWT_SECRET,
    expiresIn: process.env.JWT_EXPIRES_IN ?? '12h',
  },
  // ไม่ตั้งค่า หรือมี '*' = wildcard เป็น string ตรง ๆ (array ['*'] ไม่ match origin ไหนเลย — ดู cors.js)
  corsOrigin: parseCorsOrigin(process.env.CORS_ORIGIN),
  // ค่าเริ่มต้นของร้าน ใช้ตอนคำนวณบิล (ปรับได้ที่ตาราง settings)
  store: {
    name: process.env.STORE_NAME ?? 'PaynEat Restaurant',
    currency: process.env.CURRENCY ?? 'THB',
    vatRate: Number(process.env.VAT_RATE ?? 0.07),
    serviceChargeRate: Number(process.env.SERVICE_CHARGE_RATE ?? 0.1),
    vatIncluded: (process.env.VAT_INCLUDED ?? 'false') === 'true',
    // แต้มสะสม (ดู docs/tickets/09-customer-loyalty.md) — ค่าเริ่มต้น: ซื้อครบ 25 บาทได้ 1 แต้ม
    // ใช้แต้มแลกได้ 1 แต้ม = 1 บาท (ปรับได้ที่หน้าตั้งค่า)
    pointsEarnRateBaht: Number(process.env.POINTS_EARN_RATE_BAHT ?? 25),
    pointsRedeemValueBaht: Number(process.env.POINTS_REDEEM_VALUE_BAHT ?? 1),
  },
  // ผู้ช่วย AI ถามตอบข้อมูลร้าน (ดู docs/tickets/15-ai-ask-your-data.md) — ปิดเองอัตโนมัติถ้าไม่ตั้ง
  // ANTHROPIC_API_KEY (คืน 503 ที่ endpoint แทนที่จะ throw ตอน start เหมือน JWT_SECRET เพราะฟีเจอร์นี้
  // เป็นของเสริมที่ปิดได้โดยไม่กระทบ POS หลัก ต่างจาก auth ที่ทั้งระบบพังถ้าไม่มี)
  aiAssistant: {
    apiKey: process.env.ANTHROPIC_API_KEY,
    model: process.env.AI_ASSISTANT_MODEL ?? 'claude-opus-5',
    dailyLimitPerUser: toInt(process.env.AI_ASSISTANT_DAILY_LIMIT, 20),
  },
  // ส่งเอกสารลูกหนี้ (ใบวางบิล ฯลฯ) เป็น PDF ทางอีเมล (ดู docs/tickets/23-document-pdf-email.md) — ปิด
  // เองถ้าไม่ตั้ง SMTP_HOST (endpoint ส่งอีเมลคืน 503 ดาวน์โหลด PDF ยังใช้ได้) หลักเดียวกับผู้ช่วย AI
  // MAIL_TRANSPORT=json ใช้ในเทสต์/E2E: nodemailer สร้างอีเมลครบทุกส่วนแต่ไม่ส่งออกไปจริง
  mail: {
    transport: process.env.MAIL_TRANSPORT === 'json' ? 'json' : 'smtp',
    host: process.env.SMTP_HOST,
    port: toInt(process.env.SMTP_PORT, 587),
    secure: (process.env.SMTP_SECURE ?? String(process.env.SMTP_PORT === '465')) === 'true',
    user: process.env.SMTP_USER,
    pass: process.env.SMTP_PASS,
    from: process.env.MAIL_FROM ?? process.env.SMTP_USER,
  },
  // ตาชั่งต่อสาย (ดู docs/tickets/22-live-scale-camera-scan.md) — เซิร์ฟเวอร์ร้านอ่านน้ำหนักแล้วกระจายให้
  // แอปทุกเครื่องผ่าน socket.io ค่าเริ่มต้นปิด (off) ร้านที่ไม่มีตาชั่งไม่ต้องตั้งอะไร
  //   tcp       — ตาชั่งที่มีพอร์ต LAN หรือต่อผ่านกล่องแปลง Serial→Ethernet
  //   serial    — ต่อ USB/RS-232 เข้าเครื่องที่รันเซิร์ฟเวอร์ตรง (ต้องมีแพ็กเกจ serialport)
  //   simulator — ตาชั่งจำลอง ใช้เดโม/ทดสอบหน้าร้านโดยไม่มีเครื่องจริง
  scale: {
    driver: ['tcp', 'serial', 'simulator'].includes(process.env.SCALE_DRIVER)
      ? process.env.SCALE_DRIVER
      : 'off',
    host: process.env.SCALE_TCP_HOST ?? '127.0.0.1',
    port: toInt(process.env.SCALE_TCP_PORT, 4001),
    serialPath: process.env.SCALE_SERIAL_PATH,
    baudRate: toInt(process.env.SCALE_BAUD_RATE, 9600),
    // ตาชั่งแบบถาม-ตอบ (ไม่ส่งน้ำหนักเองต่อเนื่อง) ต้องส่งคำสั่งขอน้ำหนักเป็นระยะ เช่น MT-SICS ใช้ "SI"
    pollCommand: process.env.SCALE_POLL_COMMAND,
    pollMs: toInt(process.env.SCALE_POLL_MS, 500),
  },
  // โหมดเชื่อมต่อ PaynEat ERP (ticket 25) — URL และ credential ตั้งที่หน้าตั้งค่าของแอป ไม่ใช่ env (DECISIONS #80)
  //   ERP_PULL_INTERVAL_SECONDS — ดึง master data ทุกกี่วินาที (0 = ไม่ดึงเองตามรอบ ดึงเมื่อกดปุ่มเท่านั้น)
  //   ERP_TIMEOUT_MS            — รอคำตอบของ ERP นานสุดต่อคำขอ
  //   ERP_ALLOW_INSECURE_HTTP   — true = ยอมส่ง credential ผ่าน http:// ที่ไม่ใช่ loopback ได้ เฉพาะเครือข่ายปิด
  //                               (เช่นเดโมที่ POS กับ ERP อยู่ใน Docker network เดียวกัน) — ticket 32, DECISIONS #82
  erp: {
    pullIntervalSeconds: Math.max(0, toInt(process.env.ERP_PULL_INTERVAL_SECONDS, 300)),
    timeoutMs: Math.max(1000, toInt(process.env.ERP_TIMEOUT_MS, 15000)),
    allowInsecureHttp: process.env.ERP_ALLOW_INSECURE_HTTP === 'true',
    pageSize: 500,
  },
  // log และ metric ตามสัญญา telemetry v1.1 ของระบบนิเวศ PaynEat (ดู docs/tickets/24-telemetry-contract.md)
  //   LOG_FORMAT=gcp — เฉพาะ deployment บน Google Cloud: ย้าย labels/trace ไปที่ key ที่ Cloud Logging อ่าน
  //   METRICS_PORT   — /metrics อยู่พอร์ตของตัวเอง ไม่ใช่พอร์ต API (DECISIONS #68) docker compose ไม่เปิดพอร์ตนี้
  telemetry: {
    logLevel: SEVERITIES.includes(process.env.LOG_LEVEL?.toUpperCase())
      ? process.env.LOG_LEVEL.toUpperCase()
      : 'INFO',
    logFormat: process.env.LOG_FORMAT === 'gcp' ? 'gcp' : 'default',
    gcpProject: process.env.GOOGLE_CLOUD_PROJECT || undefined,
    metricsPort: toInt(process.env.METRICS_PORT, 9464),
    // ค่าเริ่มต้นฟังเฉพาะเครื่องนี้ — ตัวเก็บ metric ในเครื่องอื่น (เช่น compose network) ตั้ง METRICS_HOST เอง
    metricsHost: process.env.METRICS_HOST || '127.0.0.1',
  },
};

// /metrics บนพอร์ตเดียวกับ API = เปิดสาธารณะไปพร้อม API ทันทีที่ร้าน forward พอร์ต API ออกเน็ต ซึ่งสัญญาห้าม
if (env.telemetry.metricsPort !== 0 && env.telemetry.metricsPort === env.port) {
  throw new Error('METRICS_PORT ต้องไม่ใช่พอร์ตเดียวกับ PORT — /metrics ห้ามเปิดสาธารณะคู่กับ API');
}

export default env;
