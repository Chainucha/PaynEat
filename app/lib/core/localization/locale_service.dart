// Copyright 2026 Suruch Chakrapeesirisuk
// SPDX-License-Identifier: Apache-2.0

import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../demo/demo_names.dart';
import '../services/korean_font_service.dart';
import '../services/storage_service.dart';

/// สลับภาษาทั้งแอปและจำค่าไว้ในเครื่อง
class LocaleService {
  const LocaleService._();

  static const Locale thai = Locale('th', 'TH');
  static const Locale english = Locale('en', 'US');
  static const Locale korean = Locale('ko', 'KR');

  /// ภาษาที่ใช้อยู่ — ถอยไปไทยถ้ายังไม่ได้ตั้งค่า
  static String get languageCode => Get.locale?.languageCode ?? 'th';

  static bool get isThai => languageCode == 'th';
  static bool get isEnglish => languageCode == 'en';
  static bool get isKorean => languageCode == 'ko';

  /// ควรใช้ชื่อที่ไม่ใช่อักษรไทยไหม
  ///
  /// ข้อมูลที่ร้านจริงกรอกเองมักมีแค่ชื่อไทย ผู้ใช้ที่อ่านไทยไม่ออกจึงควรได้
  /// ชื่ออักษรละตินแทนชื่อไทยที่อ่านไม่ออกเลย เงื่อนไขจึงเป็น "ไม่ใช่ไทย"
  /// ไม่ใช่ "เป็นอังกฤษ" เพื่อให้ภาษาที่เพิ่มเข้ามาทีหลังได้พฤติกรรมนี้เอง
  static bool get prefersLatinNames => !isThai;

  /// ภาษาของเครื่องถ้าแอปรองรับ ไม่งั้นไทย — ใช้ตอนผู้ใช้ยังไม่เคยเลือกภาษาเอง
  static String get deviceLanguageCode {
    // อ่านผ่าน binding (ไม่ใช่ Get.deviceLocale ที่ชี้ PlatformDispatcher.instance ตรง ๆ)
    // ผลบนเครื่องจริงเหมือนกัน แต่เทสต์จำลองภาษาเครื่องได้
    final code = WidgetsBinding.instance.platformDispatcher.locale.languageCode;
    return const {'th', 'en', 'ko'}.contains(code) ? code : 'th';
  }

  static Locale localeOf(String code) => switch (code) {
    'en' => english,
    'ko' => korean,
    _ => thai,
  };

  static Future<void> change(Locale locale) async {
    // สลับเป็นเกาหลีก่อนฟอนต์เบื้องหลังโหลดเสร็จ ทั้งจอจะเป็นกล่องชั่วครู่ — รอให้เสร็จก่อน
    // (ปกติโหลดเสร็จไปแล้วตั้งแต่หลังเฟรมแรก ได้ Future เดิมทันที ดู KoreanFontService)
    if (locale.languageCode == 'ko') await KoreanFontService.ensureLoaded();
    Get.updateLocale(locale);
    syncDemoNames();
    if (Get.isRegistered<StorageService>()) {
      await Get.find<StorageService>().saveLocale(locale.languageCode);
    }
  }

  /// บอกชั้นข้อมูลสาธิตว่าตอนนี้ภาษาอะไร
  ///
  /// `DemoNames` อยู่ในชั้นข้อมูล เรียก `Get.locale` เองไม่ได้ (ดูคอมเมนต์ในไฟล์นั้น)
  /// จึงต้องมีคนป้อนให้ — ถ้าลืมเรียก ชื่อที่ประทับลงออเดอร์ใหม่จะค้างเป็นภาษาไทย
  /// ทั้งที่หน้าจอเป็นเกาหลี มีเทสต์คุมไว้ใน locale_service_test.dart
  static void syncDemoNames() => DemoNames.language = languageCode;
}
