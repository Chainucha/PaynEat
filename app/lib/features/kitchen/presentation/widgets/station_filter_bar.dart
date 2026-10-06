// Copyright 2026 Suruch Chakrapeesirisuk
// SPDX-License-Identifier: Apache-2.0

import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../core/widgets/horizontal_fade.dart';
import '../controllers/kitchen_controller.dart';

/// แถบชิปเลือกสถานีครัวบนจอครัว (ticket 34)
///
/// อยู่เป็นแถวของตัวเองใต้หัวจอ ไม่ยัดเข้าไปใน `Wrap` ของหัวจอ ซึ่งเคยล้นที่ความกว้าง 360px
/// มาแล้ว (docs/DECISIONS.md #62) ร้านที่มีสถานีเดียวไม่เห็นแถบนี้เลย
class StationFilterBar extends GetView<KitchenController> {
  const StationFilterBar({super.key});

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final stations = controller.stations;
      if (stations.length < 2) return const SizedBox.shrink();

      final selected = controller.selectedStationCode.value;
      return Padding(
        padding: const EdgeInsets.only(bottom: 4),
        child: SizedBox(
          height: 44,
          child: HorizontalFade(
            builder: (context, scrollController) => ListView.separated(
              controller: scrollController,
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: stations.length + 1,
              separatorBuilder: (_, _) => const SizedBox(width: 8),
              itemBuilder: (context, index) {
                if (index == 0) {
                  return _StationChip(
                    label: 'kitchen_station_filter_all'.tr,
                    selected: selected == null,
                    onTap: () => controller.selectStation(null),
                  );
                }
                final station = stations[index - 1];
                return _StationChip(
                  label: station.labelWithIcon,
                  selected: selected == station.code,
                  onTap: () => controller.selectStation(station.code),
                );
              },
            ),
          ),
        ),
      );
    });
  }
}

class _StationChip extends StatelessWidget {
  const _StationChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Material(
        color: selected ? AppColors.primary : AppColors.surface,
        borderRadius: BorderRadius.circular(10),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(10),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: selected ? AppColors.primary : AppColors.border,
              ),
            ),
            child: Text(
              label,
              style: TextStyle(
                fontSize: 13.5,
                fontWeight: FontWeight.w700,
                color: selected ? Colors.white : AppColors.textSecondary,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
