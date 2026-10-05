// Copyright 2026 Suruch Chakrapeesirisuk
// SPDX-License-Identifier: Apache-2.0

import 'package:flutter/foundation.dart';

/// ค่าคอนฟิกระดับแอป — เปลี่ยนได้ตอน build ด้วย
/// `flutter run --dart-define=API_BASE_URL=http://192.168.1.10:3000`
class AppConfig {
  const AppConfig._();

  static const String appName = 'PaynEat POS';
  static const String apiVersion = '/api/v1';

  static const String _baseUrlFromEnv = String.fromEnvironment('API_BASE_URL');

  /// โหมดสาธิต — ใช้ข้อมูลจำลองในเครื่องแทนการเรียก backend
  ///
  /// เปิดด้วย `flutter build web --dart-define=DEMO_MODE=true`
  /// ทำให้ deploy ขึ้น static hosting (เช่น GitHub Pages) แล้วกดเล่นได้ทันที
  /// โดยไม่ต้องมีเซิร์ฟเวอร์ — สลับได้เพราะชั้นบนรู้จักแค่ abstract ของ data source
  static const bool demoMode = bool.fromEnvironment('DEMO_MODE');

  /// URL ของ backend
  /// - Web / iOS simulator / desktop : localhost
  /// - Android emulator              : 10.0.2.2 (loopback ของเครื่อง host)
  static String get baseUrl {
    if (_baseUrlFromEnv.isNotEmpty) return _baseUrlFromEnv;
    if (kIsWeb) return 'http://localhost:3000';
    if (defaultTargetPlatform == TargetPlatform.android) {
      return 'http://10.0.2.2:3000';
    }
    return 'http://localhost:3000';
  }

  static String get apiBaseUrl => '$baseUrl$apiVersion';

  static const Duration connectTimeout = Duration(seconds: 15);
  static const Duration receiveTimeout = Duration(seconds: 20);

  /// ปิดกะและ "สำรองข้อมูลตอนนี้" รอให้สำรองฐานข้อมูลเสร็จก่อนตอบ (ticket 33) ร้านที่ข้อมูลหลายปี
  /// ใช้เวลานานกว่า [receiveTimeout] ได้ — ถ้ารอไม่ไหวจริง กะยังปิดแล้วและการสำรองยังทำต่อบนเซิร์ฟเวอร์
  static const Duration backupTimeout = Duration(minutes: 2);

  /// เปิด log ของ HTTP request เฉพาะตอน debug
  static bool get enableApiLog => kDebugMode;

  /// โดเมนสาธารณะที่ลูกค้าจะเปิดหน้าสั่งเองผ่าน QR (ดู docs/tickets/17-qr-self-order.md) — เว็บ
  /// ปล่อยว่างได้เพราะอ่านจาก Uri.base เอง (origin+path ของแอปที่รันอยู่จริง รวม base href
  /// ตอน deploy ขึ้น subpath เช่น GitHub Pages) ต้องตั้งค่านี้เฉพาะตอน build แอป native
  /// (Android/iOS/desktop) ที่ไม่มี Uri.base ให้อ้างอิงโดเมนเว็บที่ลูกค้าจะเปิดจริง เช่น
  /// `flutter build apk --dart-define=SELF_ORDER_BASE_URL=https://paynea.example.com/app/`
  static const String _selfOrderBaseUrlFromEnv = String.fromEnvironment(
    'SELF_ORDER_BASE_URL',
  );

  /// ลิงก์เต็มของหน้าสั่งเองผ่าน QR สำหรับโต๊ะหนึ่ง ๆ — เอาไปเข้ารหัสเป็นภาพ QR ให้ลูกค้าสแกน
  /// (route จริงคือ AppRoutes.selfOrder = '/order/:qrToken' ใช้ hash routing ค่าเริ่มต้นของแอป)
  static String selfOrderLink(String qrToken) {
    final base = _selfOrderBaseUrlFromEnv.isNotEmpty
        ? _selfOrderBaseUrlFromEnv
        : (kIsWeb ? '${Uri.base.origin}${Uri.base.path}' : baseUrl);
    final normalized = base.endsWith('/') ? base : '$base/';
    return '$normalized#/order/$qrToken';
  }
}
