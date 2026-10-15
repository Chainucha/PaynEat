// Copyright 2026 Suruch Chakrapeesirisuk
// SPDX-License-Identifier: Apache-2.0

import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/widgets/app_dialogs.dart';
import '../../../menu/domain/entities/station_status.dart';
import '../controllers/station_status_controller.dart';

/// ชีตเปิด/ปิดสถานีครัวของสาขานี้ (ticket 36) — ใช้ทั้งจอครัวและหน้าสั่งอาหาร (ผู้จัดการ)
/// ชิปสถานีบนจอครัวใช้กรองอย่างเดียว ไม่ใช่สวิตช์ — แยกมาไว้ที่นี่กันแตะผิด
class StationStatusSheet extends GetView<StationStatusController> {
  const StationStatusSheet({super.key});

  static Future<void> show() {
    Get.find<StationStatusController>().load();
    return Get.bottomSheet<void>(
      const StationStatusSheet(),
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
        child: Obx(
          () => Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'station_status_title'.tr,
                style: const TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'station_status_subtitle'.tr,
                style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
              ),
              const SizedBox(height: 8),
              Flexible(child: _body()),
            ],
          ),
        ),
      ),
    );
  }

  Widget _body() {
    if (controller.statuses.isEmpty) {
      if (controller.isLoading.value) {
        return const Padding(
          padding: EdgeInsets.symmetric(vertical: 24),
          child: Center(child: CircularProgressIndicator()),
        );
      }
      final error = controller.errorMessage.value;
      if (error != null) {
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 16),
          child: Column(
            children: [
              Text(error, textAlign: TextAlign.center),
              TextButton(
                onPressed: controller.load,
                child: Text('common_retry'.tr),
              ),
            ],
          ),
        );
      }
    }
    // เลื่อนได้ กันล้นเมื่อสถานีเยอะหรือจอเตี้ย (DECISIONS #62)
    return SingleChildScrollView(
      child: Column(
        children: [
          for (final station in controller.statuses)
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(station.labelWithIcon),
              subtitle: Text(
                station.isClosed
                    ? 'station_status_closed_by'.trParams({
                        'time': Formatters.dateTime(station.closedAt),
                        'name': station.closedByName ?? '-',
                      })
                    : 'station_status_open'.tr,
              ),
              // สวิตช์ "เปิด" = สถานีเปิดรับออเดอร์ — ปิดสวิตช์ระหว่างรอผล กันกดซ้ำ
              value: !station.isClosed,
              onChanged: controller.busyIds.contains(station.stationId)
                  ? null
                  : (open) => _toggle(station, open),
            ),
        ],
      ),
    );
  }

  Future<void> _toggle(StationStatus station, bool open) async {
    if (!open && station.pendingCount > 0) {
      final confirmed = await AppDialogs.confirm(
        title: 'station_status_confirm_title'.trParams({
          'station': station.displayName,
        }),
        message: 'station_status_confirm_pending'.trParams({
          'count': '${station.pendingCount}',
        }),
        confirmLabel: 'station_status_confirm_button'.tr,
        destructive: true,
      );
      if (!confirmed) return;
    }
    final ok = await controller.setClosed(station, !open);
    if (!ok) AppDialogs.error(controller.errorMessage.value ?? '');
  }
}
