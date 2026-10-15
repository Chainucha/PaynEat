// Copyright 2026 Suruch Chakrapeesirisuk
// SPDX-License-Identifier: Apache-2.0

import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../core/utils/formatters.dart';
import '../controllers/station_status_controller.dart';

/// แถบเฉพาะพนักงาน: สถานีไหนปิดอยู่ ตั้งแต่เมื่อไหร่ ใครปิด (ticket 36)
/// ไม่มีการเปิดคืนอัตโนมัติ แถบนี้จึงเป็นตัวกันลืม — ลูกค้า QR ไม่เห็น
class StationClosedBanner extends GetView<StationStatusController> {
  const StationClosedBanner({super.key, this.onTap});

  /// แตะแถบเพื่อเปิดชีตสถานะ — null สำหรับบทบาทที่เปิด/ปิดไม่ได้
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final closed = controller.closed;
      if (closed.isEmpty) return const SizedBox.shrink();
      return Material(
        color: AppColors.warning.withValues(alpha: 0.14),
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  Icons.do_not_disturb_on_rounded,
                  size: 18,
                  color: AppColors.warningInk,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      for (final station in closed)
                        Text(
                          'station_closed_banner'.trParams({
                            'station': station.displayName,
                            'time': Formatters.dateTime(station.closedAt),
                            'name': station.closedByName ?? '-',
                          }),
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: AppColors.warningInk,
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    });
  }
}
