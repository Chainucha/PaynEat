// Copyright 2026 Suruch Chakrapeesirisuk
// SPDX-License-Identifier: Apache-2.0

import 'package:flutter_test/flutter_test.dart';
import 'package:payneat_pos/core/services/storage_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('StorageService', () {
    test('เก็บและอ่านเซสชันกลับมาได้', () async {
      final storage = await StorageService.init();

      await storage.saveSession(
        token: 'token-123',
        user: {
          'id': 1,
          'name': 'ทดสอบ',
          'username': 'test',
          'role': 'waiter',
          'isActive': true,
        },
      );

      expect(storage.token, 'token-123');
      expect(storage.user?['username'], 'test');
    });

    test('ล้างเซสชันแล้วต้องไม่เหลือข้อมูล', () async {
      final storage = await StorageService.init();

      await storage.saveSession(token: 'token-123', user: const {'id': 1});
      await storage.clear();

      expect(storage.token, isNull);
      expect(storage.user, isNull);
    });

    test(
      'ยังใช้งานได้แม้ storage ถาวรไม่พร้อม (ถอยไปใช้หน่วยความจำ)',
      () async {
        // ตั้ง timeout สั้นมากเพื่อบังคับให้เข้าเส้นทาง fallback
        final storage = await StorageService.init(timeout: Duration.zero);

        await storage.saveSession(token: 'memory-token', user: const {'id': 9});

        expect(storage.token, 'memory-token');
        expect(storage.user?['id'], 9);
      },
    );

    test(
      'สถานีครัวที่จอเลือกไว้ไม่ถูกล้างตอน logout (ผูกกับเครื่อง ไม่ใช่บัญชี)',
      () async {
        final storage = await StorageService.init();

        await storage.saveSession(token: 'token-123', user: const {'id': 1});
        await storage.saveKitchenStation('bar');
        await storage.clear();

        expect(storage.token, isNull);
        expect(storage.kitchenStation, 'bar');
      },
    );
  });
}
