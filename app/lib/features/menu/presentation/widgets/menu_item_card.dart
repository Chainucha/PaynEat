// Copyright 2026 Suruch Chakrapeesirisuk
// SPDX-License-Identifier: Apache-2.0

import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_theme.dart';
import '../../../../core/utils/formatters.dart';
import '../../domain/entities/menu_item.dart';
import 'menu_item_thumbnail.dart';
import 'menu_placeholder.dart';

/// การ์ดเมนู 1 รายการ
///
/// ถ้าไม่มีรูปจะใช้ [MenuPlaceholder] แทน (ดูเหตุผลที่ไม่ใช้อักษรตัวแรกในไฟล์นั้น)
class MenuItemCard extends StatelessWidget {
  const MenuItemCard({
    super.key,
    required this.item,
    this.onTap,
    this.trailing,
    this.showAvailabilityBadge = false,
  });

  final MenuItem item;
  final VoidCallback? onTap;
  final Widget? trailing;
  final bool showAvailabilityBadge;

  @override
  Widget build(BuildContext context) {
    // จานที่สั่งไม่ได้ตอนนี้: ปิดขาย หรือสถานีของจานปิดอยู่ (ticket 36)
    final disabled = !item.isOrderable;
    final badge = item.closedStation != null
        ? 'menu_station_closed_badge'.trParams({
            'station': item.closedStation!.displayName,
          })
        : 'menu_sold_out_badge'.tr;

    return Opacity(
      opacity: disabled ? 0.55 : 1,
      child: Material(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppTheme.radiusLg),
        child: InkWell(
          onTap: disabled ? null : onTap,
          borderRadius: BorderRadius.circular(AppTheme.radiusLg),
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(AppTheme.radiusLg),
              border: Border.all(color: AppColors.border),
            ),
            clipBehavior: Clip.antiAlias,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  flex: 5,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      MenuItemThumbnail(
                        imageUrl: item.imageUrl,
                        placeholder: MenuPlaceholder(seed: item.id),
                      ),
                      if (item.isRecommended)
                        Positioned(
                          top: 8,
                          left: 8,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 7,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.surface,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.star_rounded,
                                  size: 12,
                                  color: AppColors.warningInk,
                                ),
                                const SizedBox(width: 3),
                                Text(
                                  'menu_recommended_badge'.tr,
                                  style: const TextStyle(
                                    fontSize: 10.5,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      if (showAvailabilityBadge && disabled)
                        Container(
                          color: Colors.black.withValues(alpha: 0.45),
                          alignment: Alignment.center,
                          child: Text(
                            badge,
                            textAlign: TextAlign.center,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w800,
                              fontSize: 14,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                Expanded(
                  flex: 4,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          item.displayName,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 13.5,
                            fontWeight: FontWeight.w700,
                            height: 1.25,
                          ),
                        ),
                        const Spacer(),
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                // ขายตามน้ำหนักโชว์ราคาต่อกก. ให้ชัด ไม่งั้นพนักงานเข้าใจว่า
                                // 280 บาทคือราคาต่อถุง (ดู docs/tickets/18-sell-by-weight.md)
                                item.soldByWeight
                                    ? Formatters.bahtPerKg(item.price)
                                    : Formatters.baht(item.price),
                                style: TextStyle(
                                  fontSize: 14.5,
                                  fontWeight: FontWeight.w800,
                                  color: AppColors.brandInk,
                                ),
                              ),
                            ),
                            if (trailing != null)
                              trailing!
                            else if (item.hasOptions)
                              Icon(
                                Icons.tune_rounded,
                                size: 15,
                                color: AppColors.textDisabled,
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
