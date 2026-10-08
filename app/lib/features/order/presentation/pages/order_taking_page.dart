// Copyright 2026 Suruch Chakrapeesirisuk
// SPDX-License-Identifier: Apache-2.0

import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/services/session_service.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/utils/responsive.dart';
import '../../../../core/widgets/app_dialogs.dart';
import '../../../../core/widgets/state_views.dart';
import '../../../kitchen/presentation/widgets/station_closed_banner.dart';
import '../../../kitchen/presentation/widgets/station_status_sheet.dart';
import '../../../menu/domain/entities/menu_item.dart';
import '../../../menu/presentation/controllers/menu_controller.dart';
import '../../../menu/presentation/widgets/category_filter_bar.dart';
import '../../../menu/presentation/widgets/menu_item_card.dart';
import '../../domain/services/barcode_resolver.dart';
import '../controllers/cart_controller.dart';
import '../widgets/cart_panel.dart';
import '../widgets/barcode_scan_field.dart';
import '../widgets/option_selection_sheet.dart';
import '../widgets/weight_entry_dialog.dart';

/// หน้าจอรับออเดอร์ — ด้านซ้ายเลือกเมนู ด้านขวาคือตะกร้า
///
/// บนแท็บเล็ต/เว็บจะแสดงสองคอลัมน์คู่กัน ส่วนบนมือถือตะกร้าจะยุบเป็นแถบล่างที่กดเปิดได้
class OrderTakingPage extends GetView<MenuBrowseController> {
  const OrderTakingPage({super.key});

  CartController get cart => Get.find<CartController>();

  /// เปิด/ปิดสถานีได้จากหน้านี้เฉพาะผู้จัดการ/แอดมิน (ครัวไม่ได้ใช้หน้านี้) — ticket 36
  bool get canToggleStations => UserRole.canToggleStations(
    Get.find<SessionService>().currentUser?.role ?? '',
  );

  @override
  Widget build(BuildContext context) {
    final isWide = Responsive.isWide(context);

    // กดย้อนกลับ (ปุ่มลูกศร/ปัดขอบจอ/ปุ่ม back ของ Android) ตอนตะกร้ายังมีของ → ถามก่อนทิ้ง
    // เดิมหายเงียบ ๆ ทั้งตะกร้า ลูกค้า UAT กดลองแล้วของหายโดยไม่รู้ตัว (DECISIONS #62)
    return Obx(
      () => PopScope(
        canPop: cart.isEmpty,
        onPopInvokedWithResult: (didPop, _) async {
          if (didPop) return;
          final discard = await AppDialogs.confirm(
            title: 'order_discard_cart_title'.tr,
            message: 'order_discard_cart_message'.trParams({
              'count': '${cart.totalQuantity}',
            }),
            confirmLabel: 'order_discard_cart_button'.tr,
            cancelLabel: 'order_keep_cart_button'.tr,
            destructive: true,
          );
          if (discard) {
            cart.clear();
            Get.back<void>();
          }
        },
        child: _buildScaffold(context, isWide),
      ),
    );
  }

  Widget _buildScaffold(BuildContext context, bool isWide) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          cart.isAddingToExistingOrder
              ? 'order_taking_title_add'.tr
              : cart.tableName != null
              ? 'order_taking_title_table'.trParams({'table': cart.tableName!})
              : 'order_taking_title_takeaway'.tr,
        ),
        actions: [
          if (canToggleStations)
            IconButton(
              tooltip: 'station_status_button'.tr,
              onPressed: StationStatusSheet.show,
              icon: const Icon(Icons.storefront_outlined),
            ),
          if (!isWide)
            Obx(
              () => cart.isEmpty
                  ? const SizedBox.shrink()
                  : IconButton(
                      tooltip: 'order_open_cart_tooltip'.tr,
                      onPressed: () => _openCartSheet(context),
                      icon: Badge(
                        label: Text('${cart.totalQuantity}'),
                        child: const Icon(Icons.shopping_basket_outlined),
                      ),
                    ),
            ),
        ],
      ),
      body: Column(
        children: [
          // แบนเนอร์เฉพาะพนักงาน (ticket 36) — ลูกค้า QR ไม่เห็น; ผู้จัดการแตะเพื่อเปิดชีต
          StationClosedBanner(
            onTap: canToggleStations ? StationStatusSheet.show : null,
          ),
          Expanded(
            child: isWide
                ? Row(
                    children: [
                      const Expanded(child: _MenuSection()),
                      Container(
                        width: 380,
                        decoration: BoxDecoration(
                          color: AppColors.surface,
                          border: Border(
                            left: BorderSide(color: AppColors.border),
                          ),
                        ),
                        child: const CartPanel(),
                      ),
                    ],
                  )
                : const _MenuSection(),
          ),
        ],
      ),
      bottomNavigationBar: isWide
          ? null
          : _MobileCartBar(onTap: () => _openCartSheet(context)),
    );
  }

  void _openCartSheet(BuildContext context) {
    Get.bottomSheet<void>(
      Container(
        height: MediaQuery.sizeOf(context).height * 0.85,
        decoration: const BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
        ),
        clipBehavior: Clip.antiAlias,
        child: const CartPanel(),
      ),
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
    );
  }
}

class _MenuSection extends GetView<MenuBrowseController> {
  const _MenuSection();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 10),
          // ช่องสแกนโผล่เฉพาะร้านที่มีสินค้าติดบาร์โค้ด/รหัสตาชั่งจริง — ร้านอาหารทั่วไปที่ไม่มีเครื่องสแกน
          // ไม่ควรเสียช่องค้นหาไปครึ่งหนึ่ง บนมือถือช่องค้นหากว้างกว่า (3:2) และคำใบ้ช่องสแกนสั้นลง
          // เดิมแบ่งครึ่ง คำใบ้ทั้งสองช่องถูกตัดเป็น "Search men..." / "Scan barcod..." ทุกภาษา
          child: Obx(() {
            final canScan = controller.items.any(
              (item) => item.barcode != null || item.scalePlu != null,
            );
            final compact = !Responsive.isWide(context);
            return Row(
              children: [
                Expanded(
                  flex: 3,
                  child: TextField(
                    onChanged: controller.search,
                    decoration: InputDecoration(
                      hintText: 'order_search_menu_hint'.tr,
                      prefixIcon: const Icon(Icons.search_rounded),
                      isDense: true,
                    ),
                  ),
                ),
                if (canScan) ...[
                  const SizedBox(width: 10),
                  Expanded(
                    flex: compact ? 2 : 3,
                    child: BarcodeScanField(
                      onScanned: _handleScan,
                      compact: compact,
                    ),
                  ),
                ],
              ],
            );
          }),
        ),
        Obx(
          () => CategoryFilterBar(
            categories: controller.categories,
            selectedId: controller.selectedCategoryId.value,
            onSelected: controller.selectCategory,
          ),
        ),
        const SizedBox(height: 8),
        Expanded(
          child: Obx(() {
            if (controller.isLoading.value) {
              return LoadingView(message: 'order_menu_loading'.tr);
            }
            final error = controller.errorMessage.value;
            if (error != null && controller.items.isEmpty) {
              return ErrorView(message: error, onRetry: controller.load);
            }

            final items = controller.filteredItems;
            if (items.isEmpty) {
              return EmptyView(
                message: 'order_menu_search_empty'.tr,
                icon: Icons.search_off_rounded,
              );
            }

            return LayoutBuilder(
              builder: (context, constraints) {
                final columns = Responsive.gridColumns(
                  constraints.maxWidth - 32,
                  minTileWidth: 165,
                );
                return GridView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 20),
                  itemCount: items.length,
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: columns,
                    mainAxisSpacing: 12,
                    crossAxisSpacing: 12,
                    childAspectRatio: 0.86,
                  ),
                  itemBuilder: (context, index) {
                    final item = items[index];
                    return MenuItemCard(
                      item: item,
                      showAvailabilityBadge: true,
                      onTap: () => _addToCart(item),
                    );
                  },
                );
              },
            );
          }),
        ),
      ],
    );
  }

  /// มีตัวเลือกให้เลือก → เปิดแผ่นเลือกก่อน, ไม่มี → ใส่ตะกร้าเลย 1 ที่
  ///
  /// สินค้าขายตามน้ำหนักต้องได้น้ำหนักก่อนเสมอ — จากฉลากตาชั่งที่สแกน ([scannedGrams]) หรือให้
  /// พนักงานกรอกตามหน้าจอตาชั่ง (ดู docs/tickets/18-sell-by-weight.md)
  Future<void> _addToCart(MenuItem item, {int? scannedGrams}) async {
    final cart = Get.find<CartController>();

    var result = const OptionSelectionResult(quantity: 1, options: []);
    if (item.requiresSelection) {
      final picked = await OptionSelectionSheet.show(item);
      if (picked == null) return;
      result = picked;
    }

    if (!item.soldByWeight) {
      cart.addItem(
        item,
        quantity: result.quantity,
        options: result.options,
        note: result.note,
      );
      return;
    }

    final grams =
        scannedGrams ??
        await WeightEntryDialog.show(item, options: result.options);
    if (grams == null) return;
    cart.addWeighedItem(
      item,
      grams,
      options: result.options,
      note: result.note,
    );
  }

  /// รหัสจากเครื่องสแกน (ดู docs/tickets/19-barcode-scale.md) — กรณีที่ใส่ตะกร้าได้เลย
  /// [CartController.applyScan] จัดการให้แล้ว ที่เหลือ (ต้องเลือกตัวเลือก/ต้องชั่ง/อ่านไม่ออก) ทำต่อที่นี่
  Future<void> _handleScan(String code) async {
    final result = Get.find<CartController>().applyScan(code, controller.items);
    switch (result) {
      case ScannedUnitItem(:final item):
        if (item.requiresSelection) {
          await _addToCart(item);
        } else {
          AppDialogs.success(
            'order_scan_added'.trParams({'name': item.displayName}),
          );
        }
      case ScannedWeighedItem(:final item, :final weightGrams):
        if (item.requiresSelection) {
          await _addToCart(item, scannedGrams: weightGrams);
        } else {
          AppDialogs.success(
            'order_scan_added_weight'.trParams({
              'name': item.displayName,
              'weight': Formatters.weight(weightGrams),
            }),
          );
        }
      case ScannedNeedsWeighing(:final item):
        await _addToCart(item);
      case ScanBadCheckDigit():
        AppDialogs.error('order_scan_bad_label'.tr);
      case ScanNotFound(:final code):
        AppDialogs.error('order_scan_not_found'.trParams({'code': code}));
    }
  }
}

/// แถบตะกร้าด้านล่างสำหรับมือถือ
class _MobileCartBar extends StatelessWidget {
  const _MobileCartBar({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final cart = Get.find<CartController>();

    return Obx(() {
      if (cart.isEmpty) return const SizedBox.shrink();

      return SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
          child: Material(
            color: AppColors.primary,
            borderRadius: BorderRadius.circular(14),
            child: InkWell(
              onTap: onTap,
              borderRadius: BorderRadius.circular(14),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 18,
                  vertical: 14,
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 9,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.25),
                        borderRadius: BorderRadius.circular(7),
                      ),
                      child: Text(
                        '${cart.totalQuantity}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w800,
                          fontSize: 13,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      'order_view_cart'.tr,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                        fontSize: 15,
                      ),
                    ),
                    const Spacer(),
                    Text(
                      Formatters.baht(cart.preview.total),
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w900,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(width: 6),
                    const Icon(
                      Icons.arrow_forward_ios_rounded,
                      color: Colors.white,
                      size: 14,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
    });
  }
}
