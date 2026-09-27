# Copyright 2026 Suruch Chakrapeesirisuk
# SPDX-License-Identifier: Apache-2.0

# ---------- build ----------
FROM node:22-slim AS build
WORKDIR /app

# better-sqlite3 อาจต้อง build จาก source ถ้าไม่มี prebuilt ให้แพลตฟอร์มนี้
RUN apt-get update && apt-get install -y --no-install-recommends python3 make g++ \
    && rm -rf /var/lib/apt/lists/*

COPY package*.json ./
RUN npm ci --omit=dev

# ---------- runtime ----------
FROM node:22-slim AS runtime
WORKDIR /app
ENV NODE_ENV=production

COPY --from=build /app/node_modules ./node_modules
COPY package*.json ./
COPY src ./src
COPY docs ./docs
COPY contracts ./contracts
# ฟอนต์ไทยสำหรับ PDF เอกสารลูกหนี้ (ดู src/core/documentPdf.js)
COPY assets ./assets

# เก็บไฟล์ฐานข้อมูลไว้ใน volume เพื่อไม่ให้ข้อมูลหายเมื่อสร้าง container ใหม่
RUN mkdir -p /app/data && chown -R node:node /app
VOLUME ["/app/data"]

USER node
EXPOSE 3000

HEALTHCHECK --interval=30s --timeout=5s --start-period=10s --retries=3 \
  CMD node -e "fetch('http://127.0.0.1:3000/health').then(r=>process.exit(r.ok?0:1)).catch(()=>process.exit(1))"

CMD ["node", "src/server.js"]
