# Copyright 2026 Suruch Chakrapeesirisuk
# SPDX-License-Identifier: Apache-2.0

# ---------- build Flutter Web ----------
FROM ghcr.io/cirruslabs/flutter:3.35.1 AS build
WORKDIR /app

ARG API_BASE_URL=http://localhost:3000
ARG DEMO_MODE=false
# ลิงก์ใน QR ของโต๊ะ — ว่าง = ใช้ที่อยู่ที่เปิดแอปอยู่ ตั้งเมื่อพนักงานเปิดแอปจากที่อยู่ในวง LAN แต่ลูกค้าต้องสแกนเข้า
# โดเมนสาธารณะ (deploy/shop, docs/DECISIONS.md #104)
ARG SELF_ORDER_BASE_URL=

COPY pubspec.* ./
# pubspec อ้าง payneat_lints แบบ path (dev_dependency) — pub get ต้องเห็นแพ็กเกจนี้ก่อน ไม่งั้น
# resolve ไม่ผ่านตั้งแต่ขั้นนี้ ("payneat_lints from path which doesn't exist")
COPY tool/lints ./tool/lints
RUN flutter pub get

COPY . .
RUN flutter build web --release \
      --dart-define=API_BASE_URL=$API_BASE_URL \
      --dart-define=DEMO_MODE=$DEMO_MODE \
      --dart-define=SELF_ORDER_BASE_URL=$SELF_ORDER_BASE_URL

# ---------- serve ----------
FROM nginx:alpine AS runtime
COPY --from=build /app/build/web /usr/share/nginx/html
COPY nginx.conf /etc/nginx/conf.d/default.conf

EXPOSE 80
