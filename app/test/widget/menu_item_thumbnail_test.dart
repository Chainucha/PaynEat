// Copyright 2026 Suruch Chakrapeesirisuk
// SPDX-License-Identifier: Apache-2.0

import 'package:flutter_test/flutter_test.dart';
import 'package:payneat_pos/app/config/app_config.dart';
import 'package:payneat_pos/features/menu/presentation/widgets/menu_item_thumbnail.dart';

/// รูปเมนูที่อัปโหลดไว้มาจาก API เป็น path ไม่ใช่ตัวรูป (DECISIONS #101)
void main() {
  test('path รูปจาก API ต่อท้าย baseUrl ของเซิร์ฟเวอร์', () {
    expect(
      MenuItemThumbnail.resolveUrl('/api/v1/public/menu-images/12?v=1-a'),
      '${AppConfig.baseUrl}/api/v1/public/menu-images/12?v=1-a',
    );
  });

  test('URL เต็มใช้ตามเดิม', () {
    const url = 'https://images.example.com/pad-thai.jpg';
    expect(MenuItemThumbnail.resolveUrl(url), url);
  });
}
