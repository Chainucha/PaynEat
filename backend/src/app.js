// Copyright 2026 Suruch Chakrapeesirisuk
// SPDX-License-Identifier: Apache-2.0

import fs from 'node:fs';
import path from 'node:path';
import express from 'express';
import cors from 'cors';
import helmet from 'helmet';
import compression from 'compression';
import swaggerUi from 'swagger-ui-express';
import YAML from 'yaml';
import { env } from './config/env.js';
import { errorHandler, notFoundHandler } from './middlewares/errorHandler.js';
import { requestContext } from './middlewares/requestContext.js';
import apiRoutes from './routes.js';

export const createApp = () => {
  const app = express();
  // หลัง reverse proxy: req.ip อ่านจาก X-Forwarded-For ตามจำนวน/รายชื่อ proxy ที่ตั้งไว้ (ค่าเริ่มต้นปิด
  // เพราะถ้าไม่มี proxy อยู่หน้าเซิร์ฟเวอร์จริง req.ip จะมาจาก header ที่ไคลเอนต์ส่งมาเอง) — ดู env.js#parseTrustProxy
  app.set('trust proxy', env.trustProxy);

  // ตัวแรกสุด: ทุกคำขอ (รวมที่ถูก cors/helmet/body parser ปฏิเสธ) ได้ x-request-id และบรรทัด
  // http.request.completed ตามสัญญา telemetry — แทน log แบบข้อความเดิม (ticket 24)
  app.use(requestContext);
  // ปิด CSP เฉพาะ /docs (Swagger UI ต้องใช้ inline script/style) ที่อื่นทั้งหมดเป็น JSON
  // ล้วนแต่ยังเปิด CSP ไว้เป็น defense-in-depth (ดู security review #7)
  app.use((req, res, next) => {
    const isDocs =
      req.path === '/docs' || req.path.startsWith('/docs/') || req.path === '/openapi.json';
    return helmet({ contentSecurityPolicy: !isDocs })(req, res, next);
  });
  // credentials ใช้คู่กับ origin แบบ wildcard ('*') ไม่ได้ตามสเปก CORS/Fetch (เบราว์เซอร์ปฏิเสธ
  // อยู่แล้ว) จึงเปิดเฉพาะตอนตั้ง CORS_ORIGIN เป็นรายชื่อ origin จริงเท่านั้น (ดู security review #6)
  // exposedHeaders: แอปเว็บ (คนละ origin กับ API) อ่าน x-request-id จาก response ได้ — เบราว์เซอร์ซ่อน header
  // ที่ไม่อยู่ในรายการมาตรฐานไว้ถ้าไม่ประกาศตรงนี้ (ticket 24)
  app.use(
    cors({
      origin: env.corsOrigin,
      credentials: env.corsOrigin !== '*',
      exposedHeaders: ['x-request-id'],
    }),
  );
  app.use(compression());
  // 3mb เพื่อรองรับรูปเมนูที่ส่งมาเป็น base64 data URL (ดู menu.schema.js: imageUrl)
  app.use(express.json({ limit: '3mb' }));
  app.use(express.urlencoded({ extended: true }));

  app.get('/health', (_req, res) =>
    res.json({
      success: true,
      data: {
        status: 'ok',
        service: 'payneat-api',
        env: env.nodeEnv,
        timestamp: new Date().toISOString(),
      },
    }),
  );

  // เอกสาร API (Swagger UI) — เปิดที่ /docs
  const openApiPath = path.join(env.rootDir, 'docs/openapi.yaml');
  if (fs.existsSync(openApiPath)) {
    const spec = YAML.parse(fs.readFileSync(openApiPath, 'utf8'));
    app.use('/docs', swaggerUi.serve, swaggerUi.setup(spec, { customSiteTitle: 'PaynEat API' }));
    app.get('/openapi.json', (_req, res) => res.json(spec));
  }

  app.use('/api/v1', apiRoutes);

  app.use(notFoundHandler);
  app.use(errorHandler);

  return app;
};

export default createApp;
