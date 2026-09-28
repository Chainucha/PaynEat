// Copyright 2026 Suruch Chakrapeesirisuk
// SPDX-License-Identifier: Apache-2.0

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_theme.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/widgets/app_card.dart';
import '../../../../core/widgets/state_views.dart';
import '../../domain/entities/payment.dart';
import '../controllers/split_bill_controller.dart';
import '../../../../core/localization/order_display.dart';

/// หน้าแยกบิลรายการอาหาร — เลือกเมนูที่จะจ่ายรอบนี้ ดูยอดล่วงหน้า แล้วชำระทีละก้อน
///
/// ทุกอย่างในหน้านี้อยู่ใน Obx เดียวกันโดยตั้งใจ (ไม่แยกเป็น GetView ย่อยที่อ่าน
/// ค่าของตัวเอง) เพื่อกันบั๊กแบบที่เคยเจอใน orders_page.dart (ดู
/// docs/CODING_STANDARDS.md หัวข้อ 3.2) — การเลือก/ยกเลิกรายการต้องอัปเดต
/// ยอดพรีวิวและปุ่มชำระเงินพร้อมกันเสมอ
class SplitBillPage extends GetView<SplitBillController> {
  const SplitBillPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('payment_split_bill_title'.tr)),
      body: Obx(() {
        if (controller.isLoading.value) return const LoadingView();
        final error = controller.errorMessage.value;
        if (error != null) {
          return ErrorView(message: error, onRetry: controller.load);
        }
        final order = controller.order.value;
        if (order == null) {
          return EmptyView(message: 'payment_order_not_found'.tr);
        }
        if (order.isPaid) {
          return EmptyView(
            message: 'payment_order_already_paid'.tr,
            icon: Icons.check_circle_rounded,
          );
        }

        final preview = controller.preview.value;

        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            AppCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    order.displayTarget,
                    style: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'payment_split_bill_instructions'.tr,
                    style: TextStyle(
                      fontSize: 12.5,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            AppCard(
              padding: EdgeInsets.zero,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (final item in order.activeItems)
                    CheckboxListTile(
                      value:
                          item.isPaid ||
                          controller.selectedItemIds.contains(item.id),
                      onChanged: item.isPaid
                          ? null
                          : (_) => controller.toggleItem(item.id),
                      controlAffinity: ListTileControlAffinity.leading,
                      title: Text(item.name),
                      subtitle: Text(
                        item.isPaid
                            ? 'payment_item_paid_label'.tr
                            : item.isWeighed
                            ? Formatters.weight(item.weightGrams!)
                            : 'payment_item_quantity_label'.trParams({
                                'count': item.quantity.toString(),
                              }),
                        style: TextStyle(
                          color: item.isPaid
                              ? AppColors.successInk
                              : AppColors.textSecondary,
                        ),
                      ),
                      secondary: Text(
                        Formatters.baht(item.lineTotal),
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            AppCard(
              child: preview == null
                  ? Text('payment_select_items_hint'.tr)
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _AmountRow(
                          label: 'payment_selected_subtotal_label'.tr,
                          value: preview.subtotal,
                        ),
                        if (preview.discountAmount > 0)
                          _AmountRow(
                            label: 'payment_discount_label'.tr,
                            value: -preview.discountAmount,
                          ),
                        _AmountRow(
                          label: 'payment_service_charge_label'.tr,
                          value: preview.serviceCharge,
                        ),
                        // โหมด VAT รวมในราคา VAT อยู่ในยอดแล้ว บอกไว้ให้รู้ว่าไม่ได้บวกเพิ่ม (T10 #83)
                        _AmountRow(
                          label: preview.vatIncluded
                              ? 'payment_vat_included_label'.tr
                              : 'payment_vat_label'.tr,
                          value: preview.vat,
                        ),
                        if (preview.adjustment.abs() >= 0.005)
                          _AmountRow(
                            key: const ValueKey('split-adjustment'),
                            label: 'payment_split_adjustment_label'.tr,
                            value: preview.adjustment,
                          ),
                        const Divider(height: 20),
                        _AmountRow(
                          label: 'payment_amount_due_this_round_label'.tr,
                          value: preview.total,
                          bold: true,
                        ),
                      ],
                    ),
            ),
            if (preview != null) ...[
              const SizedBox(height: 12),
              _PaymentForm(preview: preview),
            ],
          ],
        );
      }),
    );
  }
}

class _AmountRow extends StatelessWidget {
  const _AmountRow({
    super.key,
    required this.label,
    required this.value,
    this.bold = false,
  });

  final String label;
  final double value;
  final bool bold;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: bold ? 15 : 13.5,
              fontWeight: bold ? FontWeight.w800 : FontWeight.w500,
            ),
          ),
          const Spacer(),
          Text(
            Formatters.baht(value),
            style: TextStyle(
              fontSize: bold ? 18 : 13.5,
              fontWeight: bold ? FontWeight.w900 : FontWeight.w600,
              color: bold ? AppColors.brandInk : null,
            ),
          ),
        ],
      ),
    );
  }
}

class _PaymentForm extends GetView<SplitBillController> {
  const _PaymentForm({required this.preview});

  final SplitPreview preview;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'payment_method_section_title'.tr,
            style: const TextStyle(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 10),
          Obx(
            () => Wrap(
              spacing: 8,
              runSpacing: 8,
              children: PaymentMethod.all
                  .map((method) {
                    final selected = controller.method.value == method;
                    return ChoiceChip(
                      label: Text(PaymentMethod.label(method)),
                      selected: selected,
                      showCheckmark: false,
                      onSelected: (_) => controller.selectMethod(method),
                      selectedColor: AppColors.fillOf(AppColors.primary),
                      backgroundColor: AppColors.surfaceAlt,
                      labelStyle: TextStyle(
                        color: selected
                            ? AppColors.onColor(
                                AppColors.fillOf(AppColors.primary),
                              )
                            : AppColors.textSecondary,
                        fontWeight: FontWeight.w600,
                      ),
                    );
                  })
                  .toList(growable: false),
            ),
          ),
          Obx(
            () => controller.isCash
                ? Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const SizedBox(height: 16),
                      TextField(
                        controller: controller.receivedController,
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        inputFormatters: [
                          FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
                        ],
                        onChanged: controller.onReceivedChanged,
                        decoration: InputDecoration(
                          labelText: 'payment_received_label'.tr,
                          suffixText: 'common_baht'.tr,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Wrap(
                        spacing: 8,
                        children: [
                          ActionChip(
                            label: Text('payment_exact_amount_label'.tr),
                            onPressed: () =>
                                controller.setReceived(preview.total),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: AppColors.secondarySoft,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          children: [
                            Text(
                              'payment_change_due_label'.tr,
                              style: const TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const Spacer(),
                            Text(
                              Formatters.baht(controller.change),
                              style: AppTheme.moneyLarge.copyWith(
                                color: AppColors.secondaryInk,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  )
                : const SizedBox.shrink(),
          ),
          const SizedBox(height: 16),
          Obx(
            () => FilledButton.icon(
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.fillOf(AppColors.success),
                foregroundColor: AppColors.onColor(
                  AppColors.fillOf(AppColors.success),
                ),
                minimumSize: const Size(0, 52),
              ),
              onPressed: controller.canPay && !controller.isPaying.value
                  ? controller.submit
                  : null,
              icon: controller.isPaying.value
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: AppColors.surface,
                      ),
                    )
                  : const Icon(Icons.check_circle_rounded),
              label: Text(
                'payment_submit_button'.trParams({
                  'amount': Formatters.baht(preview.total),
                }),
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
