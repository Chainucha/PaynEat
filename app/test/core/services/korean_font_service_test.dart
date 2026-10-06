// Copyright 2026 Suruch Chakrapeesirisuk
// SPDX-License-Identifier: Apache-2.0

import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:payneat_pos/core/services/korean_font_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  tearDown(KoreanFontService.reset);

  group('KoreanFontService.ensureLoaded', () {
    test(
      'ลงทะเบียน NotoSansKR ครบ 4 น้ำหนักครั้งเดียว แม้เรียกซ้ำหลายที่พร้อมกัน',
      () async {
        final loaded = <String>[];
        final registered = <String, int>{};
        KoreanFontService.loadAsset = (asset) async {
          loaded.add(asset);
          return ByteData(0);
        };
        KoreanFontService.register = (family, fonts) async {
          await Future.wait(fonts);
          registered[family] = fonts.length;
        };

        await Future.wait([
          KoreanFontService.ensureLoaded(),
          KoreanFontService.ensureLoaded(),
        ]);
        await KoreanFontService.ensureLoaded();

        expect(registered, {'NotoSansKR': 4});
        expect(loaded, KoreanFontService.assets);
      },
    );

    test('โหลดไม่สำเร็จไม่โยน error ออกไป และเรียกครั้งต่อไปลองใหม่', () async {
      var attempts = 0;
      KoreanFontService.loadAsset = (_) async => ByteData(0);
      KoreanFontService.register = (family, fonts) async {
        attempts++;
        if (attempts == 1) throw Exception('network down');
      };

      await KoreanFontService.ensureLoaded();
      await KoreanFontService.ensureLoaded();

      expect(attempts, 2);
    });
  });

  test('ไฟล์ฟอนต์เกาหลีทุกไฟล์อยู่ใน asset bundle จริง', () async {
    // ลืมประกาศใน `assets:` ของ pubspec = แอปเปิดได้ แต่ตัวอักษรเกาหลีเป็นกล่องทุกจอ
    for (final asset in KoreanFontService.assets) {
      final data = await rootBundle.load(asset);
      expect(data.lengthInBytes, greaterThan(100000), reason: asset);
    }
  });

  test(
    'NotoSansKR ไม่อยู่ใน fonts: ของ pubspec (ไม่งั้นเว็บโหลดก่อนเฟรมแรกอีก)',
    () {
      final pubspec = File('pubspec.yaml').readAsStringSync();
      final fontsSection = pubspec
          .split(RegExp(r'^  assets:', multiLine: true))
          .first;
      expect(
        fontsSection.contains('family: NotoSansKR'),
        isFalse,
        reason: 'ดู DECISIONS #97 — ให้ KoreanFontService โหลดตอนรันแทน',
      );
    },
  );
}
