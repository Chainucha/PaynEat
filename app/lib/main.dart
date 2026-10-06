// Copyright 2026 Suruch Chakrapeesirisuk
// SPDX-License-Identifier: Apache-2.0

// PaynEat POS — original project by SuruchBoss (https://github.com/SuruchBoss/PaynEat)
// Licensed under Apache License 2.0 — see LICENSE and NOTICE at repo root
import 'package:flutter/material.dart';
import 'package:get/get.dart';

import 'app/app.dart';
import 'core/localization/locale_service.dart';
import 'core/services/korean_font_service.dart';
import 'core/services/storage_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // storage ต้องพร้อมก่อนสร้างแอป เพราะ InitialBinding ต้องใช้อ่าน token
  final storage = await StorageService.init();
  Get.put<StorageService>(storage, permanent: true);

  // ฟอนต์เกาหลี: เปิดมาเป็นภาษาเกาหลีรอก่อนเฟรมแรก (หน้าแรกเป็นเกาหลีทั้งหน้า)
  // ภาษาอื่นโหลดเบื้องหลังหลังเฟรมแรก ไม่ถ่วงการเปิดแอป (ดู KoreanFontService)
  final language = storage.locale ?? LocaleService.deviceLanguageCode;
  if (language == 'ko') {
    await KoreanFontService.ensureLoaded();
  } else {
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => KoreanFontService.ensureLoaded(),
    );
  }

  runApp(const PaynEatApp());
}
