// Copyright 2026 Suruch Chakrapeesirisuk
// SPDX-License-Identifier: Apache-2.0

import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../core/widgets/state_views.dart';
import '../../../erp_connection/presentation/erp_unit_label.dart';
import '../../domain/entities/ingredient.dart';
import '../controllers/ingredients_controller.dart';
import '../widgets/adjust_stock_dialog.dart';

/// หน้าจัดการวัตถุดิบ/สต๊อก — สำหรับผู้จัดการ/แอดมิน
class IngredientsPage extends GetView<IngredientsController> {
  const IngredientsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Obx(
      () => Scaffold(
        backgroundColor: Colors.transparent,
        // โหมดเชื่อมต่อ PaynEat ERP: อ่านอย่างเดียว ไม่มีปุ่มเพิ่ม/แก้/ปรับสต๊อก/ลบ (ticket 25)
        floatingActionButton: controller.managedByErp.value
            ? null
            : FloatingActionButton.extended(
                heroTag: 'fab-ingredients',
                onPressed: () => controller.openForm(),
                icon: const Icon(Icons.add_rounded),
                label: Text('ingredient_add_button'.tr),
              ),
        body: _body(),
      ),
    );
  }

  Widget _body() {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
          child: Obx(
            () => controller.managedByErp.value
                ? const _ManagedByErpBanner()
                : Align(
                    alignment: Alignment.centerLeft,
                    child: FilterChip(
                      label: Text('ingredient_low_stock_filter'.tr),
                      avatar: const Icon(Icons.warning_amber_rounded, size: 16),
                      selected: controller.lowStockOnly.value,
                      onSelected: controller.toggleLowStockOnly,
                    ),
                  ),
          ),
        ),
        Expanded(
          child: Obx(() {
            if (controller.isLoading.value) return const LoadingView();

            final error = controller.errorMessage.value;
            if (error != null && controller.ingredients.isEmpty) {
              return ErrorView(message: error, onRetry: controller.load);
            }

            if (controller.ingredients.isEmpty) {
              return EmptyView(
                message: 'ingredient_empty_state'.tr,
                icon: Icons.inventory_2_outlined,
              );
            }

            return ListView.separated(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 90),
              itemCount: controller.ingredients.length,
              separatorBuilder: (_, _) => const SizedBox(height: 8),
              itemBuilder: (context, index) =>
                  _IngredientRow(ingredient: controller.ingredients[index]),
            );
          }),
        ),
      ],
    );
  }
}

class _ManagedByErpBanner extends StatelessWidget {
  const _ManagedByErpBanner();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.info.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.info.withValues(alpha: 0.35)),
      ),
      child: Row(
        children: [
          Icon(Icons.cloud_sync_rounded, color: AppColors.infoInk, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'erp_managed_banner'.tr,
              style: TextStyle(fontSize: 13, color: AppColors.infoInk),
            ),
          ),
        ],
      ),
    );
  }
}

class _IngredientRow extends GetView<IngredientsController> {
  const _IngredientRow({required this.ingredient});

  final Ingredient ingredient;

  @override
  Widget build(BuildContext context) {
    return Obx(() => _row(readOnly: controller.managedByErp.value));
  }

  /// หน่วยของวัตถุดิบจาก ERP เป็นรหัส (kg, piece …) แสดงเป็นชื่อหน่วยตามภาษา — ของร้านเองแสดงตามที่พิมพ์
  String get _unit => ingredient.erpItem == null
      ? ingredient.unit
      : ErpUnitLabel.of(ingredient.unit);

  /// โหมดเชื่อมต่อ: รหัสสินค้าและหน่วย (ไม่แสดงยอด) · ใช้งานเดี่ยว: ยอดคงเหลือ ตามด้วยรหัสสินค้าถ้าตั้งไว้
  String _summary({required bool readOnly, required String? code}) {
    if (readOnly) {
      return code == null
          ? _unit
          : 'erp_item_code_summary'.trParams({'code': code, 'unit': _unit});
    }
    final stock = 'ingredient_stock_summary'.trParams({
      'stock': ingredient.currentStock.toStringAsFixed(1),
      'unit': _unit,
      'threshold': ingredient.lowStockThreshold.toStringAsFixed(1),
    });
    return code == null ? stock : '$stock · $code';
  }

  Widget _row({required bool readOnly}) {
    // โหมดเชื่อมต่อ: ยอดในเครื่องไม่ใช่ความจริง จึงไม่เตือน "ใกล้หมด" และไม่แสดงยอด
    final lowStock = !readOnly && ingredient.isLowStock;
    final code = ingredient.itemCode;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: lowStock ? AppColors.warning : AppColors.border,
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: lowStock
                  ? AppColors.warning.withValues(alpha: 0.12)
                  : AppColors.surfaceAlt,
              borderRadius: BorderRadius.circular(11),
            ),
            child: Icon(
              Icons.inventory_2_rounded,
              color: lowStock ? AppColors.warning : AppColors.textSecondary,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        ingredient.name,
                        style: const TextStyle(
                          fontSize: 14.5,
                          fontWeight: FontWeight.w700,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (ingredient.erpItem?.active == false) ...[
                      const SizedBox(width: 6),
                      _Tag(
                        text: 'erp_item_inactive'.tr,
                        color: AppColors.textSecondary,
                      ),
                    ],
                    if (lowStock) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.warning.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          'ingredient_low_stock_badge'.tr,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: AppColors.warningInk,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  _summary(readOnly: readOnly, code: code),
                  style: TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          if (readOnly)
            _Tag(text: 'erp_managed_badge'.tr, color: AppColors.infoInk)
          else ...[
            IconButton(
              onPressed: () async {
                final result = await AdjustStockDialog.show(ingredient);
                if (result != null) {
                  controller.adjustStock(ingredient, result.delta);
                }
              },
              icon: const Icon(Icons.tune_rounded, size: 19),
              tooltip: 'ingredient_adjust_stock_tooltip'.tr,
            ),
            IconButton(
              onPressed: () => controller.openForm(ingredient: ingredient),
              icon: const Icon(Icons.edit_outlined, size: 19),
              tooltip: 'common_edit'.tr,
            ),
            IconButton(
              onPressed: () => controller.delete(ingredient),
              icon: const Icon(Icons.delete_outline_rounded, size: 19),
              color: AppColors.dangerInk,
              tooltip: 'common_delete'.tr,
            ),
          ],
        ],
      ),
    );
  }
}

class _Tag extends StatelessWidget {
  const _Tag({required this.text, required this.color});

  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: color,
        ),
      ),
    );
  }
}
