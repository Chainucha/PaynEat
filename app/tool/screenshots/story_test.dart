// Copyright 2026 Suruch Chakrapeesirisuk
// SPDX-License-Identifier: Apache-2.0

@Tags(['screenshots'])
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:payneat_pos/app/routes/app_routes.dart';
import 'package:payneat_pos/core/constants/app_constants.dart';
import 'package:payneat_pos/core/demo/demo_store.dart';
import 'package:payneat_pos/core/localization/locale_service.dart';
import 'package:payneat_pos/features/home/presentation/controllers/home_controller.dart';
import 'package:payneat_pos/features/menu/presentation/controllers/menu_controller.dart';
import 'package:payneat_pos/features/payment/presentation/controllers/checkout_controller.dart';
import 'package:payneat_pos/features/shift/presentation/widgets/z_report_dialog.dart';

import 'screenshot_harness.dart';

/// ภาพประกอบ "เรื่องเล่า pain point" ของหน้า Landing และ README (docs/DECISIONS.md #70)
/// ถ่ายหน้าเดียวกันครบ 3 ภาษา เพื่อให้หน้า Landing แต่ละภาษาไม่ต้องยืมภาพภาษาอื่นมาใช้
///
/// ```
/// flutter test --update-goldens --dart-define=DEMO_MODE=true tool/screenshots/story_test.dart
/// ```
///
/// ได้ไฟล์ที่ `tool/screenshots/images/story/<ภาษา>-<ฉาก>.png` แล้วแปลงเป็น WebP ลง
/// `docs/landing/img/` ด้วย `tool/screenshots/publish_story.py`
const _creditCustomerId = 900;

const _langs = {
  'th': (
    locale: LocaleService.thai,
    meat: 'เนื้อสด & ของกลับบ้าน',
    ribeye: 'เนื้อวัวริบอาย',
    shortNote: 'เงินในลิ้นชักขาด 40 บาท',
    promos: (
      'แฮปปี้อาวร์บ่าย ลด 15%',
      'ลูกค้าใหม่ ลด 50 บาท',
      'สายเนื้อ ลด 10%',
    ),
  ),
  'en': (
    locale: LocaleService.english,
    meat: 'Fresh Meat & Take-home',
    ribeye: 'Beef Ribeye',
    shortNote: 'Drawer 40 baht short',
    promos: (
      'Afternoon happy hour 15% off',
      'Welcome 50 baht off',
      'Butcher counter 10% off',
    ),
  ),
  'ko': (
    locale: LocaleService.korean,
    meat: '정육 · 포장',
    ribeye: '소고기 꽃등심',
    shortNote: '현금 서랍 40바트 부족',
    promos: ('오후 해피아워 15% 할인', '처음 방문 50바트 할인', '정육 코너 10% 할인'),
  ),
};

void main() {
  setUpAll(() async {
    await ScreenshotHarness.loadFonts();
    ScreenshotHarness.freezeClock();
  });
  tearDownAll(() {
    ScreenshotHarness.reseedIn('th');
    ScreenshotHarness.unfreezeClock();
  });

  for (final entry in _langs.entries) {
    final lang = entry.key;
    final cfg = entry.value;

    group('เรื่องเล่า $lang', () {
      late ({
        int openOrderId,
        int kitchenOrderId,
        int paidOrderId,
        int takeawayOrderId,
        int customerId,
      })
      ids;

      setUpAll(() => ids = ScreenshotHarness.reseedIn(lang));

      Future<void> launch(
        WidgetTester tester,
        Size size, {
        bool highContrast = false,
      }) => ScreenshotHarness.launchApp(
        tester,
        size,
        locale: cfg.locale,
        highContrast: highContrast,
        // ภาพมือถือถูกวางในหน้า Landing เกือบเท่าจอจริง — 3x ให้ตัวหนังสือคมบนจอ retina
        pixelRatio: size == ScreenshotHarness.phone ? 3 : 2,
      );

      Future<void> openTab(WidgetTester tester, String label) async {
        final controller = Get.find<HomeController>();
        final index = controller.destinations.indexWhere(
          (destination) => destination.label == label,
        );
        expect(index, isNonNegative, reason: 'ไม่พบเมนู "$label"');
        controller.changeTab(index);
        await ScreenshotHarness.settle(tester);
      }

      Future<void> shot(WidgetTester tester, String scene) =>
          ScreenshotHarness.capture(tester, 'story/$lang-$scene');

      // --- 1. ชั่วโมงเร่งด่วน: ผังโต๊ะ + จอครัว -------------------------------
      testWidgets('$lang ผังโต๊ะ', (tester) async {
        await launch(tester, ScreenshotHarness.phone);
        await ScreenshotHarness.loginAs(tester, 'waiter1', 'waiter123');
        await shot(tester, 'rush-tables');
      });

      testWidgets('$lang จอครัว', (tester) async {
        await launch(tester, ScreenshotHarness.tablet);
        await ScreenshotHarness.loginAs(tester, 'kitchen', 'kitchen123');
        await shot(tester, 'rush-kitchen');
      });

      // --- 2. คนไม่พอ: ลูกค้าสั่งเองผ่าน QR ------------------------------------
      testWidgets('$lang QR สั่งเอง', (tester) async {
        await launch(tester, ScreenshotHarness.phone);
        unawaited(Get.toNamed<void>('/order/demo-table-1'));
        await ScreenshotHarness.settle(tester);
        await shot(tester, 'staff-self-order');
      });

      // --- 3. จ่ายเร็ว: QR พร้อมเพย์ที่ยอดบิลจริง -------------------------------
      testWidgets('$lang พร้อมเพย์', (tester) async {
        await launch(tester, ScreenshotHarness.phone);
        await ScreenshotHarness.loginAs(tester, 'cashier', 'cashier123');
        unawaited(
          Get.toNamed<void>(
            AppRoutes.checkout,
            arguments: {'orderId': ids.openOrderId},
          ),
        );
        await ScreenshotHarness.settle(tester);
        Get.find<CheckoutController>().selectMethod(PaymentMethod.qr);
        await ScreenshotHarness.settle(tester);
        await shot(tester, 'pay-promptpay');
      });

      // --- 5. ของหมดกลางเซอร์วิส: สต็อกวัตถุดิบ --------------------------------
      testWidgets('$lang วัตถุดิบ', (tester) async {
        await launch(tester, ScreenshotHarness.desktop);
        await ScreenshotHarness.loginAs(tester, 'admin', 'admin123');
        await openTab(tester, 'home_nav_ingredients');
        await shot(tester, 'stock-ingredients');
      });

      // --- 6. เคาน์เตอร์เนื้อ/ขายส่ง: ตาชั่ง + บัญชีลูกหนี้ ------------------------
      testWidgets('$lang ตาชั่ง', (tester) async {
        await launch(tester, ScreenshotHarness.tablet);
        await ScreenshotHarness.loginAs(tester, 'cashier', 'cashier123');
        unawaited(Get.toNamed<void>(AppRoutes.newOrder));
        await ScreenshotHarness.settle(tester);
        final browse = Get.find<MenuBrowseController>();
        browse.selectCategory(
          browse.categories.firstWhere((c) => c.displayName == cfg.meat).id,
        );
        await ScreenshotHarness.settle(tester);
        await tester.ensureVisible(find.text(cfg.ribeye).first);
        await tester.tap(find.text(cfg.ribeye).first);
        await ScreenshotHarness.settle(tester, rounds: 30);
        await shot(tester, 'b2b-scale');
      });

      testWidgets('$lang บัญชีลูกหนี้', (tester) async {
        await launch(tester, ScreenshotHarness.desktop);
        await ScreenshotHarness.loginAs(tester, 'manager', 'manager123');
        unawaited(
          Get.toNamed<void>(
            AppRoutes.customerStatement,
            arguments: {'customerId': _creditCustomerId},
          ),
        );
        await ScreenshotHarness.settle(tester);
        await shot(tester, 'b2b-statement');
      });

      // --- 7. เจ้าของมองไม่เห็นภาพรวม: แดชบอร์ด + รายงาน -----------------------
      testWidgets('$lang แดชบอร์ด', (tester) async {
        await launch(tester, ScreenshotHarness.desktop);
        await ScreenshotHarness.loginAs(tester, 'admin', 'admin123');
        await shot(tester, 'owner-dashboard');
      });

      // --- 8. ลูกค้าไม่กลับมา: โปรโมชัน + ลูกค้าสะสมแต้ม -------------------------
      testWidgets('$lang โปรโมชัน', (tester) async {
        // ข้อมูลสาธิตไม่มีโปรโมชันติดมา — ใส่แบบใช้โค้ด/มีเงื่อนไขเวลา ไม่ให้ไปลดบิลที่ฉากอื่นใช้อยู่
        final store = DemoStore.instance;
        final (happyHour, welcome, butcher) = cfg.promos;
        store.savePromotion({
          'name': happyHour,
          'type': 'percent',
          'value': 15.0,
          'conditions': const {
            'daysOfWeek': [1, 2, 3, 4, 5],
            'startTime': '14:00',
            'endTime': '17:00',
          },
        }, actorId: 1);
        store.savePromotion({
          'name': welcome,
          'type': 'amount',
          'value': 50.0,
          'code': 'WELCOME50',
          'conditions': const {'minSubtotal': 500},
        }, actorId: 1);
        store.savePromotion({
          'name': butcher,
          'type': 'percent',
          'value': 10.0,
          'code': 'BUTCHER10',
          'conditions': const {
            'daysOfWeek': [6, 0],
          },
        }, actorId: 1);
        await launch(tester, ScreenshotHarness.desktop);
        await ScreenshotHarness.loginAs(tester, 'admin', 'admin123');
        await openTab(tester, 'home_nav_promotions');
        await shot(tester, 'loyal-promotions');
      });

      testWidgets('$lang ลูกค้าสะสมแต้ม', (tester) async {
        await launch(tester, ScreenshotHarness.desktop);
        await ScreenshotHarness.loginAs(tester, 'admin', 'admin123');
        await openTab(tester, 'home_nav_customers');
        await shot(tester, 'loyal-customers');
      });

      // --- 9. หน้างานโหด: จอครัวคอนทราสต์สูง ------------------------------------
      testWidgets('$lang จอครัวคอนทราสต์สูง', (tester) async {
        await launch(tester, ScreenshotHarness.tablet, highContrast: true);
        await ScreenshotHarness.loginAs(tester, 'kitchen', 'kitchen123');
        await shot(tester, 'floor-contrast');
      });

      // --- 4. เงินรั่ว: ประวัติการทำรายการ + ปิดกะ/Z-report ----------------------
      testWidgets('$lang ประวัติการทำรายการ', (tester) async {
        await launch(tester, ScreenshotHarness.desktop);
        await ScreenshotHarness.loginAs(tester, 'admin', 'admin123');
        await openTab(tester, 'home_nav_audit_log');
        await shot(tester, 'cash-audit');
      });

      // ปิดกะจริงในข้อมูลสาธิต จึงต้องอยู่ท้ายกลุ่ม — หลังจากนี้ร้านไม่มีกะเปิด รับเงินไม่ได้
      testWidgets('$lang ปิดกะ + Z-report', (tester) async {
        final store = DemoStore.instance;
        final shift = store.currentShift()!;
        final shiftId = shift['id'] as int;
        final cashIn = store.payments
            .where(
              (row) =>
                  row['shiftId'] == shiftId &&
                  row['method'] == PaymentMethod.cash,
            )
            .fold<double>(0, (sum, row) => sum + (row['amount'] as num));
        final expected = (shift['openingCash'] as num) + cashIn;
        // นับเงินขาด 40 บาท — ภาพต้องโชว์ว่าระบบจับส่วนต่างได้ทันทีตอนปิดกะ
        store.closeShift(
          shiftId,
          countedCash: expected - 40,
          note: cfg.shortNote,
          closedById: 2,
        );

        await launch(tester, ScreenshotHarness.desktop);
        await ScreenshotHarness.loginAs(tester, 'manager', 'manager123');
        await openTab(tester, 'home_nav_shift');
        unawaited(ZReportDialog.show(shiftId));
        await ScreenshotHarness.settle(tester, rounds: 20);
        await shot(tester, 'cash-zreport');
      });
    });
  }
}
