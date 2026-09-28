// Copyright 2026 Suruch Chakrapeesirisuk
// SPDX-License-Identifier: Apache-2.0

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:payneat_pos/core/constants/app_constants.dart';
import 'package:payneat_pos/core/localization/app_translations.dart';
import 'package:payneat_pos/core/localization/locale_service.dart';
import 'package:payneat_pos/features/order/domain/entities/order_item.dart';
import 'package:payneat_pos/features/order/presentation/widgets/order_item_tile.dart';

/// รายการที่ครัวเคยทำแล้วถูกเลิกทำกลับไปรอทำ ต้องไม่มีปุ่มลบ — ใช้ปุ่มยกเลิกที่ผู้จัดการเท่านั้นเห็น
/// (T05 #104, docs/DECISIONS.md #86)
void main() {
  OrderItem item({String? kitchenReached}) => OrderItem(
    id: 1,
    orderId: 1,
    name: 'ผัดกะเพรา',
    unitPrice: 75,
    quantity: 1,
    lineTotal: 75,
    status: OrderItemStatus.pending,
    kitchenReached: kitchenReached,
  );

  Future<void> pump(
    WidgetTester tester,
    OrderItem item, {
    required bool manager,
  }) => tester.pumpWidget(
    GetMaterialApp(
      translations: AppTranslations(),
      locale: LocaleService.thai,
      home: Scaffold(
        body: OrderItemTile(
          item: item,
          onAdvance: () {},
          onRemove: () {},
          onCancel: manager ? () {} : null,
        ),
      ),
    ),
  );

  // ประเมินหลัง pump เพื่อให้ได้คำแปลจริงที่ปุ่มแสดง
  Finder remove() => find.byTooltip('order_remove_item'.tr);
  Finder cancel() => find.byTooltip('order_cancel_item'.tr);

  testWidgets('รายการที่ครัวยังไม่เคยแตะ มีปุ่มลบ', (tester) async {
    await pump(tester, item(), manager: false);
    expect(remove(), findsOneWidget);
    expect(cancel(), findsNothing);
  });

  testWidgets(
    'ถูกเลิกทำกลับมารอทำ: พนักงานเสิร์ฟไม่มีทั้งปุ่มลบและปุ่มยกเลิก',
    (tester) async {
      await pump(tester, item(kitchenReached: 'ready'), manager: false);
      expect(remove(), findsNothing);
      expect(cancel(), findsNothing);
    },
  );

  testWidgets('ถูกเลิกทำกลับมารอทำ: ผู้จัดการเห็นปุ่มยกเลิก (void) แทนปุ่มลบ', (
    tester,
  ) async {
    await pump(tester, item(kitchenReached: 'ready'), manager: true);
    expect(remove(), findsNothing);
    expect(cancel(), findsOneWidget);
  });
}
