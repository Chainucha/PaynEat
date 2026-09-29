// Copyright 2026 Suruch Chakrapeesirisuk
// SPDX-License-Identifier: Apache-2.0

import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../../core/widgets/app_dialogs.dart';
import '../../../customer/domain/services/loyalty_points.dart';
import '../../domain/entities/store_settings.dart';
import '../../domain/usecases/settings_usecases.dart';

/// ตั้งค่าร้าน — ชื่อร้าน, VAT, Service Charge
class SettingsController extends GetxController {
  SettingsController({
    required GetSettingsUseCase getSettings,
    required UpdateSettingsUseCase updateSettings,
  }) : _getSettings = getSettings,
       _updateSettings = updateSettings;

  final GetSettingsUseCase _getSettings;
  final UpdateSettingsUseCase _updateSettings;

  final Rx<StoreSettings> settings = StoreSettings.fallback.obs;
  final RxBool isLoading = true.obs;
  final RxBool isSaving = false.obs;
  final RxnString errorMessage = RxnString();
  final RxBool vatIncluded = false.obs;

  final TextEditingController storeNameController = TextEditingController();
  final TextEditingController vatController = TextEditingController();
  final TextEditingController serviceChargeController = TextEditingController();
  final TextEditingController storeTaxIdController = TextEditingController();
  final TextEditingController storeAddressController = TextEditingController();
  final TextEditingController storeBranchController = TextEditingController();
  final TextEditingController pointsEarnRateController =
      TextEditingController();
  final TextEditingController pointsRedeemValueController =
      TextEditingController();
  final TextEditingController promptPayIdController = TextEditingController();

  /// รูปแบบฉลากตาชั่ง (ดู docs/tickets/19-barcode-scale.md)
  final TextEditingController scaleLabelPrefixController =
      TextEditingController();
  final RxInt scaleLabelPluDigits = 5.obs;

  /// ดอกเบี้ยผิดนัดของลูกหนี้ขายเชื่อ (ดู docs/tickets/21-late-fees-credit-notes.md)
  final TextEditingController lateFeeRateController = TextEditingController();
  final TextEditingController lateFeeGraceController = TextEditingController();

  @override
  void onInit() {
    super.onInit();
    load();
  }

  @override
  void onClose() {
    storeNameController.dispose();
    vatController.dispose();
    serviceChargeController.dispose();
    storeTaxIdController.dispose();
    storeAddressController.dispose();
    storeBranchController.dispose();
    pointsEarnRateController.dispose();
    pointsRedeemValueController.dispose();
    promptPayIdController.dispose();
    scaleLabelPrefixController.dispose();
    lateFeeRateController.dispose();
    lateFeeGraceController.dispose();
    super.onClose();
  }

  Future<void> load() async {
    isLoading.value = true;
    errorMessage.value = null;

    final result = await _getSettings();

    isLoading.value = false;
    result.fold(
      onSuccess: (data) {
        settings.value = data;
        storeNameController.text = data.storeName;
        vatController.text = data.vatPercent.toStringAsFixed(0);
        serviceChargeController.text = data.serviceChargePercent
            .toStringAsFixed(0);
        vatIncluded.value = data.vatIncluded;
        storeTaxIdController.text = data.storeTaxId ?? '';
        storeAddressController.text = data.storeAddress ?? '';
        storeBranchController.text = data.storeBranch ?? '';
        // อัตราต่ำสุด 0.01 บาท — แสดงทศนิยมตามจริง ปัดเป็นจำนวนเต็มแล้วกดบันทึกจะเปลี่ยนค่าเอง (T15 #84)
        pointsEarnRateController.text = _trimZeros(data.pointsEarnRateBaht);
        pointsRedeemValueController.text = data.pointsRedeemValueBaht
            .toStringAsFixed(2);
        promptPayIdController.text = data.promptPayId ?? '';
        scaleLabelPrefixController.text = data.scaleLabelPrefix;
        scaleLabelPluDigits.value = data.scaleLabelPluDigits;
        lateFeeRateController.text = _trimZeros(data.lateFeeAnnualRatePercent);
        lateFeeGraceController.text = '${data.lateFeeGraceDays}';
      },
      onFailure: (failure) => errorMessage.value = failure.message,
    );
  }

  Future<void> save() async {
    final vatPercent = double.tryParse(vatController.text.trim());
    final servicePercent = double.tryParse(serviceChargeController.text.trim());

    if (vatPercent == null || vatPercent < 0 || vatPercent > 100) {
      AppDialogs.error('settings_vat_range_error'.tr);
      return;
    }
    if (servicePercent == null || servicePercent < 0 || servicePercent > 100) {
      AppDialogs.error('settings_service_charge_range_error'.tr);
      return;
    }
    final pointsEarnRate = double.tryParse(
      pointsEarnRateController.text.trim(),
    );
    final pointsRedeemValue = double.tryParse(
      pointsRedeemValueController.text.trim(),
    );
    // ขั้นต่ำ 0.01 บาทเท่ากับ backend (T15 #84) — ต่ำกว่านี้เป็น 0 สตางค์ ใช้คิดแต้มไม่ได้
    if (!isValidPointRate(pointsEarnRate)) {
      AppDialogs.error('settings_points_earn_rate_error'.tr);
      return;
    }
    if (!isValidPointRate(pointsRedeemValue)) {
      AppDialogs.error('settings_points_redeem_value_error'.tr);
      return;
    }
    // ฉลาก EAN-13 = prefix + PLU + น้ำหนัก + check digit — ต้องเหลือหลักน้ำหนัก 4–6 หลัก
    // (กฎเดียวกับ backend settings.routes.js ตรวจก่อนยิงให้ข้อความผิดพลาดชัดกว่า 422)
    final scalePrefix = scaleLabelPrefixController.text.trim();
    final weightDigits = 12 - scalePrefix.length - scaleLabelPluDigits.value;
    if (!RegExp(r'^2\d{0,2}$').hasMatch(scalePrefix) ||
        weightDigits < 4 ||
        weightDigits > 6) {
      AppDialogs.error('settings_scale_label_invalid'.tr);
      return;
    }

    // เพดาน 15% ต่อปีเท่ากับ backend (settings.routes.js) — ตรวจก่อนยิงให้ข้อความชัดกว่า 422
    final lateFeeRate = double.tryParse(
      lateFeeRateController.text.trim().isEmpty
          ? '0'
          : lateFeeRateController.text.trim(),
    );
    final lateFeeGrace = int.tryParse(
      lateFeeGraceController.text.trim().isEmpty
          ? '0'
          : lateFeeGraceController.text.trim(),
    );
    if (lateFeeRate == null ||
        lateFeeRate < 0 ||
        lateFeeRate > 15 ||
        lateFeeGrace == null ||
        lateFeeGrace < 0 ||
        lateFeeGrace > 365) {
      AppDialogs.error('settings_late_fee_invalid'.tr);
      return;
    }

    isSaving.value = true;
    final result = await _updateSettings(
      UpdateSettingsParams(
        storeName: storeNameController.text.trim(),
        vatRate: vatPercent / 100,
        serviceChargeRate: servicePercent / 100,
        vatIncluded: vatIncluded.value,
        storeTaxId: storeTaxIdController.text.trim(),
        storeAddress: storeAddressController.text.trim(),
        storeBranch: storeBranchController.text.trim(),
        pointsEarnRateBaht: pointsEarnRate,
        pointsRedeemValueBaht: pointsRedeemValue,
        promptPayId: promptPayIdController.text.trim(),
        scaleLabelPrefix: scalePrefix,
        scaleLabelPluDigits: scaleLabelPluDigits.value,
        lateFeeAnnualRatePercent: lateFeeRate,
        lateFeeGraceDays: lateFeeGrace,
      ),
    );
    isSaving.value = false;

    result.fold(
      onSuccess: (data) {
        settings.value = data;
        AppDialogs.success('settings_saved_success'.tr);
      },
      onFailure: (failure) => AppDialogs.error(failure.message),
    );
  }

  /// 12.0 → "12", 7.5 → "7.5" — ช่องกรอกไม่ต้องมีศูนย์ท้ายรก ๆ
  static String _trimZeros(double value) => value == value.roundToDouble()
      ? value.toStringAsFixed(0)
      : value.toString();
}
