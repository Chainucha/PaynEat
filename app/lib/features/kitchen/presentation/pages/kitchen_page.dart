// Copyright 2026 Suruch Chakrapeesirisuk
// SPDX-License-Identifier: Apache-2.0

import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/utils/responsive.dart';
import '../../../../core/widgets/state_views.dart';
import '../../../order/domain/entities/order_item.dart';
import '../controllers/kitchen_controller.dart';
import '../widgets/kitchen_ticket_card.dart';
import '../widgets/station_filter_bar.dart';

/// จอครัว — แบ่งเป็น 3 คอลัมน์ตามสถานะ เห็นภาพรวมงานทั้งครัวในจอเดียว
class KitchenPage extends GetView<KitchenController> {
  const KitchenPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const _KitchenHeader(),
        const StationFilterBar(),
        const _OfflineBanner(),
        Expanded(
          child: Obx(() {
            if (controller.isLoading.value && controller.queue.isEmpty) {
              return LoadingView(message: 'kitchen_loading_queue'.tr);
            }
            final error = controller.errorMessage.value;
            if (error != null && controller.queue.isEmpty) {
              return ErrorView(message: error, onRetry: controller.load);
            }
            if (controller.queue.isEmpty) {
              return EmptyView(
                message: 'kitchen_empty_queue_message'.tr,
                icon: Icons.restaurant_rounded,
              );
            }
            // มีตั๋วอยู่ แต่ไม่ใช่ของสถานีที่เลือก — บอกตรง ๆ ว่ากรองอยู่ ไม่ปล่อยให้เห็นสามคอลัมน์
            // ว่างเปล่าแล้วเดาเอาเองว่าครัวว่างหรือจอค้าง (ticket 34)
            if (controller.visibleQueue.isEmpty) {
              return EmptyView(
                message: 'kitchen_station_empty_queue_message'.tr,
                icon: Icons.filter_alt_off_rounded,
              );
            }

            // อ่านค่า tick เพื่อให้ "เวลารอ" อัปเดตทุก 30 วินาที
            controller.tick.value;

            final columns = [
              (
                title: OrderItemStatus.label(OrderItemStatus.pending),
                status: OrderItemStatus.pending,
                items: controller.pending,
                color: AppColors.warning,
              ),
              (
                title: OrderItemStatus.label(OrderItemStatus.cooking),
                status: OrderItemStatus.cooking,
                items: controller.cooking,
                color: AppColors.primary,
              ),
              (
                title: OrderItemStatus.label(OrderItemStatus.ready),
                status: OrderItemStatus.ready,
                items: controller.ready,
                color: AppColors.success,
              ),
            ];

            if (Responsive.isMobile(context)) {
              return DefaultTabController(
                length: columns.length,
                child: Column(
                  children: [
                    TabBar(
                      labelColor: AppColors.primary,
                      unselectedLabelColor: AppColors.textSecondary,
                      indicatorColor: AppColors.primary,
                      tabs: columns
                          .map(
                            (column) => Tab(
                              text: 'kitchen_column_count_label'.trParams({
                                'title': column.title,
                                'count': column.items.length.toString(),
                              }),
                            ),
                          )
                          .toList(growable: false),
                    ),
                    Expanded(
                      child: TabBarView(
                        children: columns
                            .map(
                              (column) => _TicketList(
                                items: column.items,
                                emptyMessage: 'kitchen_column_empty'.trParams({
                                  'title': column.title,
                                }),
                              ),
                            )
                            .toList(growable: false),
                      ),
                    ),
                  ],
                ),
              );
            }

            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: columns
                  .map(
                    (column) => Expanded(
                      child: _KitchenColumn(
                        title: column.title,
                        color: column.color,
                        items: column.items,
                      ),
                    ),
                  )
                  .toList(growable: false),
            );
          }),
        ),
        const _UndoBar(),
      ],
    );
  }
}

/// แถบเตือนตอนขาดการเชื่อมต่อเรียลไทม์
///
/// จอครัวมักถูกตั้งทิ้งไว้โดยไม่มีคนคอยดูแล ถ้าเน็ตหลุดแล้วไม่บอกอะไรเลย
/// ครัวจะเข้าใจว่าไม่มีออเดอร์เข้า ทั้งที่จริงคือตั๋วส่งมาไม่ถึง
class _OfflineBanner extends GetView<KitchenController> {
  const _OfflineBanner();

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      if (!controller.isOffline.value) return const SizedBox.shrink();

      return Container(
        width: double.infinity,
        color: AppColors.danger,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: Row(
          children: [
            const Icon(Icons.cloud_off_rounded, color: Colors.white, size: 18),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'kitchen_offline_banner'.tr,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            TextButton(
              onPressed: controller.load,
              style: TextButton.styleFrom(
                foregroundColor: Colors.white,
                minimumSize: const Size(0, 40),
              ),
              child: Text('common_retry'.tr),
            ),
          ],
        ),
      );
    });
  }
}

class _KitchenHeader extends GetView<KitchenController> {
  const _KitchenHeader();

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.surface,
      padding: const EdgeInsets.fromLTRB(16, 12, 8, 12),
      child: Obx(
        () => Row(
          children: [
            Icon(Icons.soup_kitchen_rounded, color: AppColors.brandInk),
            const SizedBox(width: 8),
            Text(
              'kitchen_header_title'.tr,
              style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
            ),
            const SizedBox(width: 12),
            // ตัวนับคิว + ป้ายเกินเวลาอยู่ใน Wrap — บนมือถือ 360px ฉบับอังกฤษ ("Queue 5" + "3 late")
            // ยาวเกินจนหัวจอครัวล้นขวา 30px ปุ่มรีเฟรชหลุดจอ — docs/DECISIONS.md #62
            Expanded(
              child: Wrap(
                spacing: 8,
                runSpacing: 4,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.primarySoft,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      'kitchen_queue_count'.trParams({
                        'count': controller.visibleQueue.length.toString(),
                      }),
                      style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w700,
                        color: AppColors.brandInk,
                      ),
                    ),
                  ),
                  if (controller.lateCount > 0)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.danger.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.local_fire_department_rounded,
                            size: 14,
                            color: AppColors.dangerInk,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            'kitchen_late_count'.trParams({
                              'count': controller.lateCount.toString(),
                            }),
                            style: TextStyle(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w700,
                              color: AppColors.dangerInk,
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
            IconButton(
              onPressed: controller.load,
              icon: const Icon(Icons.refresh_rounded),
              tooltip: 'kitchen_refresh_tooltip'.tr,
            ),
          ],
        ),
      ),
    );
  }
}

class _KitchenColumn extends StatelessWidget {
  const _KitchenColumn({
    required this.title,
    required this.color,
    required this.items,
  });

  final String title;
  final Color color;
  final List<OrderItem> items;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // หัวคอลัมน์วางตัวหนังสือบนพื้น tint ของสีตัวเอง สีสดจึงอ่านไม่ออก
        // ("รอทำ" สีเหลืองได้แค่ 1.94:1) ใช้เฉดเข้มกับตัวหนังสือ ส่วนจุดกลม
        // ยังใช้สีสดได้เพราะเป็นของตกแต่ง ไม่ใช่ข้อมูลที่ต้องอ่าน
        Container(
          margin: const EdgeInsets.fromLTRB(12, 12, 12, 8),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Row(
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(color: color, shape: BoxShape.circle),
              ),
              const SizedBox(width: 8),
              Text(
                title,
                style: TextStyle(
                  fontWeight: FontWeight.w800,
                  color: AppColors.inkOf(color),
                  fontSize: 14,
                ),
              ),
              const Spacer(),
              Text(
                '${items.length}',
                style: TextStyle(
                  fontWeight: FontWeight.w900,
                  color: AppColors.inkOf(color),
                  fontSize: 15,
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: _TicketList(
            items: items,
            emptyMessage: 'kitchen_column_empty'.trParams({'title': title}),
          ),
        ),
      ],
    );
  }
}

class _TicketList extends GetView<KitchenController> {
  const _TicketList({required this.items, required this.emptyMessage});

  final List<OrderItem> items;
  final String emptyMessage;

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return Center(
        child: Text(
          emptyMessage,
          style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 16),
      itemCount: items.length,
      itemBuilder: (context, index) {
        final item = items[index];
        return KitchenTicketCard(
          item: item,
          isLate: controller.isLate(item),
          onAdvance: () => controller.advance(item),
          // โชว์ป้ายสถานีเฉพาะตอนดู "ทุกสถานี" — กรองอยู่แล้วป้ายก็ซ้ำซ้อน และหัวตั๋วก็แน่นพอแล้ว
          stationLabel: controller.selectedStationCode.value == null
              ? item.stationName
              : null,
        );
      },
    );
  }
}

/// แถบ "เลิกทำ" หลังกดเดินสถานะ — กดผิด (เช่น "ทำเสร็จแล้ว" ทั้งที่ยังไม่เสร็จ) ย้อนได้ในไม่กี่วินาที
/// โดยไม่ต้องตามผู้จัดการ (DECISIONS #64) อยู่ล่างจอ ไม่บังตั๋ว ปุ่มใหญ่พอกดด้วยมือที่เปียก
class _UndoBar extends GetView<KitchenController> {
  const _UndoBar();

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final change = controller.lastChange.value;
      if (change == null) return const SizedBox.shrink();
      return Material(
        key: const ValueKey('kitchen-undo-bar'),
        color: AppColors.textPrimary,
        child: SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 6, 8, 6),
            child: Row(
              children: [
                Icon(
                  Icons.check_circle_outline_rounded,
                  color: AppColors.surface,
                  size: 20,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'kitchen_undo_message'.trParams({
                      'item': change.item.name,
                      'status': OrderItemStatus.label(change.to),
                    }),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: AppColors.surface,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                TextButton.icon(
                  key: const ValueKey('kitchen-undo'),
                  style: TextButton.styleFrom(
                    foregroundColor: AppColors.surface,
                    minimumSize: const Size(0, 48),
                  ),
                  onPressed: controller.undoLast,
                  icon: const Icon(Icons.undo_rounded),
                  label: Text('kitchen_undo_button'.tr),
                ),
              ],
            ),
          ),
        ),
      );
    });
  }
}
