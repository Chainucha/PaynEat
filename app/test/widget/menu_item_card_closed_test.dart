// Copyright 2026 Suruch Chakrapeesirisuk
// SPDX-License-Identifier: Apache-2.0

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:payneat_pos/core/localization/app_translations.dart';
import 'package:payneat_pos/core/localization/locale_service.dart';
import 'package:payneat_pos/features/menu/domain/entities/closed_station.dart';
import 'package:payneat_pos/features/menu/domain/entities/menu_item.dart';
import 'package:payneat_pos/features/menu/presentation/widgets/menu_item_card.dart';

void main() {
  testWidgets('จานของสถานีที่ปิด → ป้าย "บาร์ปิด" และแตะไม่ได้ (ticket 36)', (
    tester,
  ) async {
    var taps = 0;
    await tester.pumpWidget(
      GetMaterialApp(
        translations: AppTranslations(),
        locale: LocaleService.thai,
        home: Scaffold(
          body: SizedBox(
            width: 165,
            height: 190,
            child: MenuItemCard(
              item: const MenuItem(
                id: 1,
                categoryId: 1,
                name: 'ชาไทยเย็น',
                price: 45,
                closedStation: ClosedStation(id: 3, name: 'บาร์'),
              ),
              showAvailabilityBadge: true,
              onTap: () => taps++,
            ),
          ),
        ),
      ),
    );

    expect(find.text('บาร์ปิด'), findsOneWidget);
    await tester.tap(find.byType(MenuItemCard));
    expect(taps, 0);
  });

  testWidgets('English locale: Bar closed badge and not tappable (ticket 36)', (
    tester,
  ) async {
    var taps = 0;
    await tester.pumpWidget(
      GetMaterialApp(
        translations: AppTranslations(),
        locale: LocaleService.english,
        home: Scaffold(
          body: SizedBox(
            width: 165,
            height: 190,
            child: MenuItemCard(
              item: const MenuItem(
                id: 1,
                categoryId: 1,
                name: 'ชาไทยเย็น',
                price: 45,
                closedStation: ClosedStation(
                  id: 3,
                  name: 'บาร์',
                  nameEn: 'Bar',
                ),
              ),
              showAvailabilityBadge: true,
              onTap: () => taps++,
            ),
          ),
        ),
      ),
    );

    expect(find.text('Bar closed'), findsOneWidget);
    await tester.tap(find.byType(MenuItemCard));
    expect(taps, 0);
  });
}
