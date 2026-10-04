// Copyright 2026 Suruch Chakrapeesirisuk
// SPDX-License-Identifier: Apache-2.0

import 'package:flutter/widgets.dart';
import 'package:get/get.dart';

import '../../core/services/session_service.dart';
import 'app_routes.dart';

/// ดันผู้ใช้ไปหน้าราก (splash) ถ้าเปิดหน้าของพนักงานโดยที่เซสชันยังไม่ถูกเริ่ม
///
/// ตอนรีเฟรชเบราว์เซอร์ที่ `/#/home` Flutter web เปิด route จาก URL ตรงๆ ข้าม splash
/// ทำให้ `AuthController.bootstrap()` ไม่ถูกเรียก → ไม่มีการต่อ socket → ป้าย "ออฟไลน์"
/// ค้าง ทั้งที่ token ยังใช้ได้และ REST ยังดึงข้อมูลมาได้ การส่งกลับไป splash ให้ bootstrap
/// ทำงานตามปกติ (ยืนยัน token → เริ่มเซสชัน → ต่อ socket → กลับ home)
class SessionGuard extends GetMiddleware {
  @override
  RouteSettings? redirect(String? route) {
    if (Get.find<SessionService>().currentUser != null) return null;
    return const RouteSettings(name: AppRoutes.splash);
  }
}
