// Copyright 2026 Suruch Chakrapeesirisuk
// SPDX-License-Identifier: Apache-2.0

import '../../../../core/widgets/language_menu_button.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/utils/responsive.dart';
import '../../../../core/widgets/app_card.dart';
import '../../../../core/widgets/quantity_stepper.dart';
import '../../../../core/widgets/sheet_handle.dart';
import '../../../../core/widgets/state_views.dart';
import '../../../menu/presentation/widgets/category_filter_bar.dart';
import '../../../menu/presentation/widgets/menu_item_card.dart';
import '../../../order/domain/entities/cart_line.dart';
import '../../../order/presentation/widgets/bill_summary.dart';
import '../../../order/presentation/widgets/order_item_tile.dart';
import '../controllers/self_order_controller.dart';

/// หน้าลูกค้าสั่งอาหารเองผ่าน QR ที่โต๊ะ (ดู docs/tickets/17-qr-self-order.md) — ไม่มี login เลย
/// เข้าได้ตรงจากลิงก์ QR ทันที ต่างจากทุกหน้าอื่นในแอปที่ต้องผ่าน AuthController ก่อนเสมอ
class SelfOrderPage extends GetView<SelfOrderController> {
  const SelfOrderPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        // ลูกค้าเปิดหน้านี้เป็นหน้าแรกจากการสแกน QR ไม่มีหน้าก่อนหน้าให้ย้อนกลับไป — ปุ่มย้อนกลับ
        // จึงมีแต่จะพาหลุดออกไปหน้าเข้าสู่ระบบของพนักงาน ซึ่งไม่ใช่ที่ของลูกค้าเลย
        automaticallyImplyLeading: false,
        title: Obx(() {
          final table = controller.table.value;
          return Text(
            table == null
                ? 'self_order_title'.tr
                : 'table_number_label'.trParams({'name': table.name}),
          );
        }),
        actions: [
          // ลูกค้าไม่มีหน้าตั้งค่าให้เปลี่ยนภาษา ปุ่มนี้คือทางเดียว (docs/DECISIONS.md #62)
          const LanguageMenuButton(),
          Obx(() {
            final order = controller.currentOrder.value;
            final count =
                order?.items.where((item) => !item.isCancelled).length ?? 0;
            if (count == 0) return const SizedBox.shrink();
            return IconButton(
              tooltip: 'self_order_current_order_title'.tr,
              onPressed: () => _showCurrentOrder(context),
              icon: Badge(
                label: Text('$count'),
                child: const Icon(Icons.receipt_long_rounded),
              ),
            );
          }),
        ],
      ),
      body: Obx(() {
        if (controller.isLoading.value) {
          return LoadingView(message: 'self_order_loading'.tr);
        }
        final error = controller.errorMessage.value;
        if (error != null) {
          final linkProblem = controller.isLinkProblem.value;
          return ErrorView(
            message: error,
            icon: linkProblem
                ? Icons.qr_code_scanner_rounded
                : Icons.wifi_off_rounded,
            onRetry: linkProblem ? null : controller.load,
          );
        }

        return Column(
          children: [
            _TableHeader(),
            const SizedBox(height: 8),
            CategoryFilterBar(
              categories: controller.categories,
              selectedId: controller.selectedCategoryId.value,
              onSelected: controller.selectCategory,
            ),
            const SizedBox(height: 8),
            Expanded(
              child: controller.filteredItems.isEmpty
                  ? EmptyView(
                      message: 'self_order_menu_empty'.tr,
                      icon: Icons.restaurant_menu_rounded,
                    )
                  : LayoutBuilder(
                      builder: (context, constraints) {
                        final columns = Responsive.gridColumns(
                          constraints.maxWidth - 32,
                          minTileWidth: 165,
                        );
                        return GridView.builder(
                          padding: const EdgeInsets.fromLTRB(16, 0, 16, 100),
                          itemCount: controller.filteredItems.length,
                          gridDelegate:
                              SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: columns,
                                mainAxisSpacing: 12,
                                crossAxisSpacing: 12,
                                childAspectRatio: 0.86,
                              ),
                          itemBuilder: (context, index) {
                            final item = controller.filteredItems[index];
                            return MenuItemCard(
                              item: item,
                              showAvailabilityBadge: true,
                              onTap: () => controller.addToCart(item),
                            );
                          },
                        );
                      },
                    ),
            ),
          ],
        );
      }),
      bottomNavigationBar: Obx(() {
        if (controller.cart.isEmpty) return const SizedBox.shrink();
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
            child: FilledButton(
              onPressed: () => _showCart(context),
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(52),
              ),
              child: Text(
                'self_order_view_cart_button'.trParams({
                  'count': '${controller.cartItemCount}',
                  'total': Formatters.baht(controller.cartSubtotalPreview),
                }),
              ),
            ),
          ),
        );
      }),
    );
  }

  Future<void> _showCurrentOrder(BuildContext context) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (sheetContext) => Obx(() {
        final order = controller.currentOrder.value;
        if (order == null) return const SizedBox.shrink();
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SheetHandle(),
                Text(
                  'self_order_current_order_title'.tr,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 12),
                Flexible(
                  child: ListView.separated(
                    shrinkWrap: true,
                    itemCount: order.items.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 8),
                    itemBuilder: (context, index) => OrderItemTile(
                      item: order.items[index],
                      showActions: false,
                    ),
                  ),
                ),
                const Divider(height: 24),
                BillSummary(order: order, dense: true),
              ],
            ),
          ),
        );
      }),
    );
  }

  Future<void> _showCart(BuildContext context) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
          child: Obx(() {
            if (controller.cart.isEmpty) {
              // ตะกร้าว่างระหว่างเปิดชีทอยู่ (เช่นกดส่งสำเร็จแล้ว หรือลดจำนวนจนหมด) — ปิดชีทเองแทน
              // โชว์ว่างเปล่า
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (Navigator.of(sheetContext).canPop()) {
                  Navigator.of(sheetContext).pop();
                }
              });
              return const SizedBox.shrink();
            }
            // อ่านที่ scope บนสุดของ Obx (CODING_STANDARDS 3.2) แล้วส่งต่อเข้า itemBuilder
            final maxPerLine = controller.maxQuantityPerLine.value;
            return Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SheetHandle(),
                Text(
                  'self_order_cart_title'.tr,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 12),
                Flexible(
                  child: ListView.separated(
                    shrinkWrap: true,
                    itemCount: controller.cart.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 8),
                    itemBuilder: (context, index) => _CartLineTile(
                      line: controller.cart[index],
                      index: index,
                      maxQuantity: maxPerLine,
                    ),
                  ),
                ),
                const Divider(height: 24),
                Row(
                  children: [
                    Text(
                      'order_subtotal_label'.tr,
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                    const Spacer(),
                    Text(
                      Formatters.baht(controller.cartSubtotalPreview),
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 16,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  'self_order_cart_footnote'.tr,
                  style: TextStyle(
                    fontSize: 11.5,
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 12),
                Obx(
                  () => FilledButton(
                    onPressed: controller.isSubmitting.value
                        ? null
                        : () async {
                            await controller.submitCart();
                            if (sheetContext.mounted &&
                                Navigator.of(sheetContext).canPop()) {
                              Navigator.of(sheetContext).pop();
                            }
                          },
                    style: FilledButton.styleFrom(
                      minimumSize: const Size.fromHeight(52),
                    ),
                    child: controller.isSubmitting.value
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2.2,
                              color: Colors.white,
                            ),
                          )
                        : Text('self_order_send_to_kitchen'.tr),
                  ),
                ),
              ],
            );
          }),
        ),
      ),
    );
  }
}

/// โซน/สาขาของโต๊ะ + บอกวิธีสั่งสั้น ๆ — ลูกค้าไม่เคยผ่านการอบรมเหมือนพนักงาน จึงต้องมีประโยคเดียว
/// บอกว่ากดการ์ดเมนูแล้วเกิดอะไรขึ้น
class _TableHeader extends GetView<SelfOrderController> {
  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final table = controller.table.value;
      if (table == null) return const SizedBox.shrink();
      final branch = table.branchName;

      return Padding(
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              branch == null
                  ? table.displayZone
                  : '${table.displayZone} · $branch',
              style: TextStyle(fontSize: 12.5, color: AppColors.textSecondary),
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                Icon(
                  Icons.touch_app_rounded,
                  size: 15,
                  color: AppColors.brandInk,
                ),
                const SizedBox(width: 5),
                Expanded(
                  child: Text(
                    'self_order_hint'.tr,
                    style: TextStyle(fontSize: 12.5, color: AppColors.brandInk),
                  ),
                ),
              ],
            ),
            // เนื้อสดชั่งน้ำหนักถูกซ่อนจากเมนูลูกค้า (ราคาขึ้นกับน้ำหนักจริง) — บอกไว้ให้รู้ว่า
            // ไม่ได้หมด แค่ต้องสั่งกับพนักงาน (DECISIONS #64)
            if (controller.staffOnlyCount.value > 0) ...[
              const SizedBox(height: 4),
              Row(
                key: const ValueKey('self-order-staff-only'),
                children: [
                  Icon(
                    Icons.scale_rounded,
                    size: 15,
                    color: AppColors.textSecondary,
                  ),
                  const SizedBox(width: 5),
                  Expanded(
                    child: Text(
                      'self_order_staff_only_hint'.tr,
                      style: TextStyle(
                        fontSize: 12.5,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      );
    });
  }
}

class _CartLineTile extends GetView<SelfOrderController> {
  const _CartLineTile({
    required this.line,
    required this.index,
    required this.maxQuantity,
  });

  final CartLine line;
  final int index;

  /// เพดานต่อรายการของ QR (DECISIONS #99) — ปุ่ม + หยุดที่ค่านี้ และบอกให้เรียกพนักงานถ้าต้องการมากกว่า
  final int maxQuantity;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.all(10),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  line.menuItem.displayName,
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 13.5,
                  ),
                ),
                if (line.selectedOptions.isNotEmpty)
                  Text(
                    line.optionsSummary,
                    style: TextStyle(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                    ),
                  ),
                if (line.note != null && line.note!.isNotEmpty)
                  Text(
                    line.note!,
                    style: TextStyle(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                    ),
                  ),
                const SizedBox(height: 6),
                Text(
                  Formatters.baht(line.lineTotal),
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 13.5,
                  ),
                ),
                if (line.quantity >= maxQuantity)
                  Text(
                    'self_order_line_limit_hint'.trParams({
                      'max': '$maxQuantity',
                    }),
                    key: const ValueKey('self-order-line-limit'),
                    style: TextStyle(
                      fontSize: 11.5,
                      color: AppColors.textSecondary,
                    ),
                  ),
              ],
            ),
          ),
          // จำนวน 1 แล้วกด − = เอาออกจากตะกร้า จึงไม่ต้องมีปุ่มถังขยะแยกอีกปุ่ม
          QuantityStepper(
            value: line.quantity,
            min: 0,
            max: maxQuantity,
            onChanged: (quantity) =>
                controller.updateCartQuantity(index, quantity),
          ),
        ],
      ),
    );
  }
}
