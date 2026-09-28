// Copyright 2026 Suruch Chakrapeesirisuk
// SPDX-License-Identifier: Apache-2.0

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:payneat_pos/core/localization/app_translations.dart';
import 'package:payneat_pos/core/localization/locale_service.dart';
import 'package:payneat_pos/core/usecases/result.dart';
import 'package:payneat_pos/features/settings/domain/entities/store_settings.dart';
import 'package:payneat_pos/features/settings/domain/repositories/settings_repository.dart';
import 'package:payneat_pos/features/settings/domain/usecases/settings_usecases.dart';
import 'package:payneat_pos/features/settings/presentation/controllers/settings_controller.dart';

/// ฟอร์มตั้งค่าแจ้งเตือนอัตราแต้มที่ต่ำกว่า 0.01 บาทก่อนส่ง และแสดงอัตราทศนิยมตามจริง
/// (T15 #84, docs/DECISIONS.md #89) — save() เรียก AppDialogs (Get.snackbar) จึงต้องมี GetMaterialApp
class _RecordingSettingsRepository implements SettingsRepository {
  StoreSettings stored = StoreSettings.fallback;
  final updates = <double?>[];

  @override
  Future<Result<StoreSettings>> get() async => Result.success(stored);

  @override
  Future<Result<StoreSettings>> update({
    String? storeName,
    double? vatRate,
    double? serviceChargeRate,
    bool? vatIncluded,
    String? storeTaxId,
    String? storeAddress,
    String? storeBranch,
    double? pointsEarnRateBaht,
    double? pointsRedeemValueBaht,
    String? promptPayId,
    String? scaleLabelPrefix,
    int? scaleLabelPluDigits,
    double? lateFeeAnnualRatePercent,
    int? lateFeeGraceDays,
  }) async {
    updates.add(pointsEarnRateBaht);
    return Result.success(stored);
  }
}

void main() {
  late _RecordingSettingsRepository repository;
  late SettingsController controller;

  Future<void> pumpApp(WidgetTester tester) async {
    repository = _RecordingSettingsRepository();
    controller = SettingsController(
      getSettings: GetSettingsUseCase(repository),
      updateSettings: UpdateSettingsUseCase(repository),
    );
    await tester.pumpWidget(
      GetMaterialApp(
        translations: AppTranslations(),
        locale: LocaleService.thai,
        home: const Scaffold(),
      ),
    );
  }

  /// ปิด snackbar ให้หมดก่อนจบเทสต์ ไม่ให้เหลือ timer ค้าง
  Future<void> settle(WidgetTester tester) async {
    await tester.pump(const Duration(seconds: 5));
    await tester.pumpAndSettle();
    controller.onClose();
  }

  Future<void> fillAndSave(
    WidgetTester tester, {
    required String earnRate,
    required String redeemValue,
  }) async {
    await controller.load();
    controller.pointsEarnRateController.text = earnRate;
    controller.pointsRedeemValueController.text = redeemValue;
    await controller.save();
    await tester.pump();
  }

  testWidgets(
    'อัตราสะสมต่ำกว่า 0.01 บาท → แจ้งเตือนขั้นต่ำ และไม่ส่งไปบันทึก',
    (tester) async {
      await pumpApp(tester);
      for (final value in ['0.004', '0', '-1', 'abc']) {
        await fillAndSave(tester, earnRate: value, redeemValue: '1');
        expect(
          find.text('settings_points_earn_rate_error'.tr),
          findsOneWidget,
          reason: value,
        );
        await tester.pump(const Duration(seconds: 5));
        await tester.pumpAndSettle();
      }
      expect(repository.updates, isEmpty);
      await settle(tester);
    },
  );

  testWidgets(
    'มูลค่าแต้มต่ำกว่า 0.01 บาท → แจ้งเตือนขั้นต่ำ และไม่ส่งไปบันทึก',
    (tester) async {
      await pumpApp(tester);
      await fillAndSave(tester, earnRate: '25', redeemValue: '0');
      expect(
        find.text('settings_points_redeem_value_error'.tr),
        findsOneWidget,
      );
      expect(repository.updates, isEmpty);
      await settle(tester);
    },
  );

  testWidgets('0.01 บาทพอดีส่งไปบันทึกได้', (tester) async {
    await pumpApp(tester);
    await fillAndSave(tester, earnRate: '0.01', redeemValue: '0.01');
    expect(repository.updates, [0.01]);
    await settle(tester);
  });

  testWidgets('อัตราสะสมทศนิยมแสดงตามจริง ไม่ปัดเป็นจำนวนเต็มแล้วบันทึกทับ', (
    tester,
  ) async {
    await pumpApp(tester);
    repository.stored = const StoreSettings(
      storeName: 'ร้านทดสอบ',
      currency: 'THB',
      vatRate: 0.07,
      serviceChargeRate: 0,
      vatIncluded: false,
      pointsEarnRateBaht: 0.5,
    );
    await controller.load();
    expect(controller.pointsEarnRateController.text, '0.5');
    await controller.save();
    await tester.pump();
    expect(repository.updates, [0.5]);
    await settle(tester);
  });
}
