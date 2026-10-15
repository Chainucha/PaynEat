// Copyright 2026 Suruch Chakrapeesirisuk
// SPDX-License-Identifier: Apache-2.0

import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../../app/theme/app_colors.dart';
import '../controllers/kitchen_controller.dart';

/// ปุ่มลำโพงบนหัวจอครัว (ticket 37) — ค่าที่เลือกจำต่อเครื่อง
/// สไตล์เดียวกับปุ่มอื่นในหัวจอ (กว้าง 36) เพื่อให้พอดี 360px
class ChimeMuteButton extends GetView<KitchenController> {
  const ChimeMuteButton({super.key});

  @override
  Widget build(BuildContext context) {
    return Obx(
      () => IconButton(
        visualDensity: VisualDensity.compact,
        padding: EdgeInsets.zero,
        constraints: const BoxConstraints.tightFor(width: 36, height: 40),
        tooltip: controller.muted.value
            ? 'kitchen_unmute_tooltip'.tr
            : 'kitchen_mute_tooltip'.tr,
        onPressed: controller.toggleMute,
        icon: Icon(
          controller.muted.value
              ? Icons.volume_off_rounded
              : Icons.volume_up_rounded,
        ),
      ),
    );
  }
}

/// แถบ "แตะเพื่อเปิดเสียง" — เบราว์เซอร์ไม่ยอมเล่นเสียงจนกว่าผู้ใช้จะแตะหน้าจอ (ticket 37)
/// ขึ้นเฉพาะตอนเสียงยังล็อกและไม่ได้ปิดเสียงไว้ ไม่บังการใช้งานจอ แตะครั้งเดียวแล้วหาย
class SoundUnlockBar extends GetView<KitchenController> {
  const SoundUnlockBar({super.key});

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      if (!controller.soundLocked.value || controller.muted.value) {
        return const SizedBox.shrink();
      }
      return Material(
        color: AppColors.primarySoft,
        child: InkWell(
          onTap: controller.unlockSound,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            child: Row(
              children: [
                Icon(
                  Icons.volume_up_rounded,
                  size: 18,
                  color: AppColors.brandInk,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'kitchen_sound_unlock'.tr,
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      color: AppColors.brandInk,
                    ),
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
