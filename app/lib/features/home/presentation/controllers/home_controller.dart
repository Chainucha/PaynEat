// Copyright 2026 Suruch Chakrapeesirisuk
// SPDX-License-Identifier: Apache-2.0

import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/services/session_service.dart';
import '../../../auth/domain/entities/user.dart';
import '../../../../core/utils/app_clock.dart';

/// เมนูนำทาง 1 ช่อง
class HomeDestination {
  const HomeDestination({
    required this.label,
    required this.icon,
    required this.selectedIcon,
    required this.page,
  });

  final String label;
  final IconData icon;
  final IconData selectedIcon;
  final Widget page;
}

/// ตัวควบคุมโครงหน้าหลัก — เลือกเมนูที่แสดงตามบทบาทของผู้ใช้
///
/// พนักงานแต่ละคนเห็นเฉพาะสิ่งที่ตัวเองต้องใช้ ทำให้จอไม่รกและลดโอกาสกดผิด
class HomeController extends GetxController {
  HomeController({
    required SessionService session,
    required this.destinationsBuilder,
  }) : _session = session;

  final SessionService _session;

  /// ฟังก์ชันสร้างรายการเมนูจากบทบาท (ฉีดเข้ามาเพื่อให้เทสต์ง่ายและไม่ผูกกับ widget)
  final List<HomeDestination> Function(String role) destinationsBuilder;

  final RxInt currentIndex = 0.obs;
  late final List<HomeDestination> destinations;

  @override
  void onInit() {
    super.onInit();
    destinations = destinationsBuilder(user?.role ?? UserRole.waiter);
  }

  User? get user => _session.currentUser;

  String get greeting {
    final hour = AppClock.now().hour;
    if (hour < 12) return 'home_greeting_morning'.tr;
    if (hour < 17) return 'home_greeting_afternoon'.tr;
    return 'home_greeting_evening'.tr;
  }

  String get currentTitle =>
      destinations.isEmpty ? '' : destinations[currentIndex.value].label.tr;

  void changeTab(int index) {
    if (index < 0 || index >= destinations.length) return;
    currentIndex.value = index;
  }

  /// ปุ่มบนแถบเตือนการสำรองข้อมูล (ticket 33) — ไปแท็บตั้งค่าที่มีส่วนสำรองข้อมูล
  void openSettings() =>
      changeTab(destinations.indexWhere((d) => d.label == 'home_nav_settings'));
}
