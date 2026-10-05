// Copyright 2026 Suruch Chakrapeesirisuk
// SPDX-License-Identifier: Apache-2.0

import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../../app/theme/app_colors.dart';
import '../backup_warning_text.dart';
import '../controllers/backup_warning_controller.dart';

/// แถบเตือนบนหน้าหลักเมื่อไม่ได้สำรองข้อมูลสำเร็จเกิน 26 ชั่วโมง หรือครั้งล่าสุดล้มเหลว (ticket 33)
///
/// แสดงเฉพาะเมื่อมี [BackupWarningController] — หน้าหลักลงทะเบียนให้ admin และ manager เท่านั้น
/// [onOpenSettings] = ปุ่มไปหน้าตั้งค่า (admin) ส่วน manager ไม่มีส่วนสำรองข้อมูลในหน้าตั้งค่า
/// จึงได้ประโยคบอกให้แจ้งเจ้าของร้านแทน
class BackupWarningBanner extends StatelessWidget {
  const BackupWarningBanner({super.key, this.onOpenSettings});

  final VoidCallback? onOpenSettings;

  @override
  Widget build(BuildContext context) {
    if (!Get.isRegistered<BackupWarningController>()) {
      return const SizedBox.shrink();
    }
    final controller = Get.find<BackupWarningController>();
    return Obx(() {
      final status = controller.attention;
      final text = status == null ? null : BackupWarningText.of(status);
      if (text == null) return const SizedBox.shrink();
      final open = onOpenSettings;
      return Material(
        key: const Key('backup-warning-banner'),
        color: AppColors.warning.withValues(alpha: 0.14),
        child: SafeArea(
          top: false,
          bottom: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 8, 10),
            child: Row(
              children: [
                Icon(Icons.backup_outlined, color: AppColors.warningInk),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    open == null
                        ? '$text ${'backup_banner_tell_owner'.tr}'
                        : text,
                    style: const TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                if (open != null)
                  TextButton(
                    onPressed: open,
                    child: Text('backup_banner_open_settings'.tr),
                  ),
              ],
            ),
          ),
        ),
      );
    });
  }
}
