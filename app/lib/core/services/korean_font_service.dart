// Copyright 2026 Suruch Chakrapeesirisuk
// SPDX-License-Identifier: Apache-2.0

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// โหลดฟอนต์เกาหลี (NotoSansKR) ตอนรันแทนการประกาศใน `fonts:` ของ pubspec
///
/// ฟอนต์ที่ประกาศใน `fonts:` ถูกโหลดครบทุกไฟล์ก่อนเฟรมแรกบนเว็บ — NotoSansKR
/// 4 น้ำหนักรวม 3.2MB (1.5MB หลัง gzip) ราว 30% ของการเปิดครั้งแรก ผู้ใช้ไทย/อังกฤษ
/// และลูกค้าที่สแกน QR จึงรอฟอนต์ที่หน้าแรกไม่ได้ใช้ (docs/DECISIONS.md #97)
///
/// ยังต้องโหลดให้ทุกคน ไม่ใช่แค่คนที่ตั้งภาษาเกาหลี เพราะข้อมูลที่คนอื่นกรอกเป็น
/// ภาษาเกาหลีต้องอ่านได้ในทุกภาษา (#74) — ผู้ใช้ภาษาเกาหลีรอก่อนเฟรมแรกเหมือนเดิม
/// ส่วนภาษาอื่นโหลดเบื้องหลังหลังเฟรมแรก ตัวอักษรเกาหลีที่โผล่ระหว่างนั้นวาดใหม่เอง
/// เมื่อฟอนต์มาถึง ชื่อ family ยังเป็น `NotoSansKR` เดิม `AppTheme.fontFamilyFallback`
/// จึงไม่ต้องแก้
class KoreanFontService {
  const KoreanFontService._();

  static const String family = 'NotoSansKR';

  static const List<String> assets = [
    'assets/fonts/NotoSansKR-400.ttf',
    'assets/fonts/NotoSansKR-500.ttf',
    'assets/fonts/NotoSansKR-700.ttf',
    'assets/fonts/NotoSansKR-800.ttf',
  ];

  /// ตัวอ่านไฟล์ฟอนต์ — เทสต์สลับเป็นตัวปลอมได้
  @visibleForTesting
  static Future<ByteData> Function(String asset) loadAsset = rootBundle.load;

  /// ตัวลงทะเบียนฟอนต์ — เทสต์สลับเป็นตัวปลอมได้ (FontLoader จริงต้องมี engine)
  @visibleForTesting
  static Future<void> Function(String family, List<Future<ByteData>> fonts)
  register = _registerWithFontLoader;

  static Future<void>? _loading;

  /// เริ่มโหลดครั้งเดียว เรียกซ้ำได้ทุกที่ (ได้ Future เดิม) — โหลดไม่สำเร็จเรียกใหม่จะลองอีกรอบ
  static Future<void> ensureLoaded() => _loading ??= _load();

  static Future<void> _load() async {
    try {
      await register(family, [for (final a in assets) loadAsset(a)]);
    } catch (e) {
      // เน็ตหลุดกลางทางไม่ควรทำให้แอปล้ม ตัวอักษรเกาหลีหล่นไปฟอนต์สำรองของเครื่องแทน
      _loading = null;
      debugPrint('KoreanFontService: load failed ($e)');
    }
  }

  static Future<void> _registerWithFontLoader(
    String family,
    List<Future<ByteData>> fonts,
  ) {
    final loader = FontLoader(family);
    for (final font in fonts) {
      loader.addFont(font);
    }
    return loader.load();
  }

  @visibleForTesting
  static void reset() {
    _loading = null;
    loadAsset = rootBundle.load;
    register = _registerWithFontLoader;
  }
}
