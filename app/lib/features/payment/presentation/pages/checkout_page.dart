// Copyright 2026 Suruch Chakrapeesirisuk
// SPDX-License-Identifier: Apache-2.0

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';

import '../../../../app/routes/app_routes.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_theme.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/utils/responsive.dart';
import '../../../../core/widgets/app_card.dart';
import '../../../../core/widgets/state_views.dart';
import '../../../order/presentation/widgets/bill_summary.dart';
import '../../domain/entities/payment.dart';
import '../controllers/checkout_controller.dart';
import '../widgets/promptpay_qr_view.dart';
import '../widgets/refund_dialog.dart';
import '../../../../core/localization/order_display.dart';

/// หน้าชำระเงิน
class CheckoutPage extends GetView<CheckoutController> {
  const CheckoutPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('payment_checkout_title'.tr)),
      body: Obx(() {
        if (controller.isLoading.value) {
          return const LoadingView();
        }
        final error = controller.errorMessage.value;
        if (error != null) {
          return ErrorView(message: error, onRetry: controller.load);
        }
        final order = controller.order.value;
        if (order == null) {
          return EmptyView(message: 'payment_order_not_found'.tr);
        }

        final billCard = AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Text(
                    order.displayTarget,
                    style: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    order.code,
                    style: TextStyle(
                      fontSize: 12.5,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              BillSummary(order: order, dense: true),
              const SizedBox(height: 12),
              const _PaidHistory(),
            ],
          ),
        );

        final shiftBanner = controller.hasOpenShift.value
            ? const <Widget>[]
            : const <Widget>[_NoShiftBanner(), SizedBox(height: 12)];

        return Responsive.isWide(context)
            ? Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [...shiftBanner, billCard],
                      ),
                    ),
                  ),
                  SizedBox(
                    width: 420,
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.fromLTRB(0, 16, 16, 16),
                      child: const _PaymentForm(),
                    ),
                  ),
                ],
              )
            : ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  ...shiftBanner,
                  billCard,
                  const SizedBox(height: 12),
                  const _PaymentForm(),
                ],
              );
      }),
    );
  }
}

class _NoShiftBanner extends GetView<CheckoutController> {
  const _NoShiftBanner();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.danger.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.danger.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Icon(Icons.warning_amber_rounded, color: AppColors.dangerInk),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'payment_no_shift_banner'.tr,
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
            ),
          ),
          TextButton(
            onPressed: () async {
              await Get.toNamed<void>(AppRoutes.shift);
              controller.load();
            },
            child: Text('payment_go_open_shift'.tr),
          ),
        ],
      ),
    );
  }
}

class _PaidHistory extends GetView<CheckoutController> {
  const _PaidHistory();

  Future<void> _refund(Payment payment) async {
    final result = await RefundDialog.show(
      maxAmount: controller.refundableAmount(payment),
    );
    if (result == null) return;
    await controller.refundPayment(
      payment: payment,
      amount: result.amount,
      reason: result.reason,
    );
  }

  @override
  Widget build(BuildContext context) {
    final summary = controller.summary.value;
    if (summary == null || summary.payments.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Divider(),
        const SizedBox(height: 4),
        Text(
          'payment_already_paid_section_title'.tr,
          style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 6),
        for (final payment in summary.payments)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 3),
            child: Row(
              children: [
                Icon(
                  Icons.check_circle_rounded,
                  size: 15,
                  color: AppColors.successInk,
                ),
                const SizedBox(width: 8),
                Text(
                  payment.methodLabel,
                  style: TextStyle(
                    fontSize: 13,
                    color: AppColors.textSecondary,
                  ),
                ),
                const Spacer(),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      Formatters.money(payment.amount),
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    // คืนเงินบนบิลที่ยังเปิด ยอดคงเหลือด้านล่างเพิ่มขึ้นเท่ายอดที่คืน (T06 #82)
                    if (summary.refundedFor(payment.id) > 0)
                      Text(
                        'payment_refunded_from_payment'.trParams({
                          'amount': Formatters.money(
                            summary.refundedFor(payment.id),
                          ),
                        }),
                        key: ValueKey('checkout-refunded-${payment.id}'),
                        style: TextStyle(
                          fontSize: 12,
                          color: AppColors.dangerInk,
                        ),
                      ),
                  ],
                ),
                if (controller.canRefund)
                  IconButton(
                    key: ValueKey('checkout-refund-${payment.id}'),
                    tooltip: 'payment_refund_dialog_title'.tr,
                    visualDensity: VisualDensity.compact,
                    icon: const Icon(Icons.undo_rounded, size: 18),
                    onPressed: controller.refundableAmount(payment) > 0
                        ? () => _refund(payment)
                        : null,
                  ),
              ],
            ),
          ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: AppColors.warning.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Row(
            children: [
              Text(
                'payment_remaining_due_label'.tr,
                style: const TextStyle(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const Spacer(),
              Text(
                Formatters.baht(summary.remaining),
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w900,
                  color: AppColors.warningInk,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _PaymentForm extends GetView<CheckoutController> {
  const _PaymentForm();

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
              children: controller.availableMethods
                  .map((method) {
                    final selected = controller.method.value == method;
                    return ChoiceChip(
                      avatar: Icon(
                        _iconFor(method),
                        size: 16,
                        color: selected
                            ? AppColors.onColor(
                                AppColors.fillOf(AppColors.primary),
                              )
                            : AppColors.textSecondary,
                      ),
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
          const SizedBox(height: 18),
          TextField(
            controller: controller.amountController,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
            ],
            onChanged: controller.onAmountChanged,
            decoration: InputDecoration(
              labelText: 'payment_amount_this_round_label'.tr,
              helperText: 'payment_amount_this_round_helper'.tr,
              suffixText: 'common_baht'.tr,
            ),
          ),
          const _LoyaltySection(),
          Obx(
            () => controller.isCash
                ? Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const SizedBox(height: 12),
                      TextField(
                        controller: controller.receivedController,
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        inputFormatters: [
                          FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
                        ],
                        onChanged: controller.onReceivedChanged,
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                        ),
                        decoration: InputDecoration(
                          labelText: 'payment_received_label'.tr,
                          helperText: 'payment_received_helper'.tr,
                          suffixText: 'common_baht'.tr,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Wrap(
                        spacing: 8,
                        children: [
                          ActionChip(
                            label: Text('payment_exact_amount_label'.tr),
                            onPressed: () => controller.setReceived(
                              controller.chargedAmount,
                            ),
                          ),
                          if (controller.roundUpShortcut != null)
                            ActionChip(
                              label: Text(
                                Formatters.compact(controller.roundUpShortcut!),
                              ),
                              onPressed: () => controller.setReceived(
                                controller.roundUpShortcut!,
                              ),
                            ),
                          ...controller.cashShortcuts.map(
                            (value) => ActionChip(
                              label: Text(Formatters.compact(value)),
                              onPressed: () => controller.setReceived(value),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),
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
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (controller.method.value == PaymentMethod.qr)
                        const PromptPayQrView(),
                      if (controller.isCredit) const _CreditInfo(),
                      Padding(
                        padding: const EdgeInsets.only(top: 12),
                        child: TextField(
                          controller: controller.referenceController,
                          decoration: InputDecoration(
                            labelText: 'payment_reference_label'.tr,
                            hintText: 'payment_reference_hint'.tr,
                          ),
                        ),
                      ),
                    ],
                  ),
          ),
          const SizedBox(height: 18),
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
                  'amount': Formatters.baht(controller.chargedAmount),
                }),
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ),
          Obx(() {
            final hint = controller.isPaying.value
                ? null
                : controller.payBlockedHint;
            if (hint == null) return const SizedBox.shrink();
            return Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    Icons.info_outline_rounded,
                    size: 16,
                    color: AppColors.warningInk,
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      hint,
                      key: const ValueKey('checkout-pay-blocked-hint'),
                      style: TextStyle(
                        fontSize: 13,
                        color: AppColors.warningInk,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  IconData _iconFor(String method) => switch (method) {
    PaymentMethod.cash => Icons.payments_rounded,
    PaymentMethod.qr => Icons.qr_code_2_rounded,
    PaymentMethod.card => Icons.credit_card_rounded,
    PaymentMethod.transfer => Icons.account_balance_rounded,
    PaymentMethod.credit => Icons.request_quote_rounded,
    _ => Icons.payment_rounded,
  };
}

/// วงเงินคงเหลือ/เครดิตเทอมตอนเลือก "ขายเชื่อ" (ดู docs/tickets/20-b2b-credit.md) — ยอดเกินวงเงิน
/// ปุ่มจ่ายจะกดไม่ได้พร้อมบอกเหตุผลตรงนี้ แทนที่จะปล่อยให้กดแล้วค่อยโดน backend ปฏิเสธ
class _CreditInfo extends GetView<CheckoutController> {
  const _CreditInfo();

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final customer = controller.customer.value;
      if (customer == null) return const SizedBox.shrink();
      final overLimit =
          controller.amount.value > controller.creditAvailable + 0.001;
      final ink = overLimit ? AppColors.dangerInk : AppColors.brandInk;
      return Container(
        key: const ValueKey('checkout-credit-info'),
        margin: const EdgeInsets.only(top: 12),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: overLimit
              ? AppColors.danger.withValues(alpha: 0.08)
              : AppColors.primarySoft,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'payment_credit_available'.trParams({
                'amount': Formatters.baht(controller.creditAvailable),
              }),
              style: TextStyle(fontWeight: FontWeight.w800, color: ink),
            ),
            const SizedBox(height: 2),
            Text(
              overLimit
                  ? 'payment_credit_over_limit'.tr
                  : 'payment_credit_due_in'.trParams({
                      'days': '${customer.creditTermDays}',
                    }),
              style: TextStyle(fontSize: 12.5, color: ink),
            ),
          ],
        ),
      );
    });
  }
}

/// แสดงข้อมูลลูกค้าที่ผูกกับออเดอร์นี้ + ให้เลือกใช้แต้มสะสมแลกส่วนลดรอบจ่ายนี้
///
/// ไม่แสดงอะไรเลยถ้าออเดอร์นี้ไม่ได้ผูกลูกค้าไว้ (ลูกค้าทั่วไปที่ไม่ได้เป็นสมาชิก)
class _LoyaltySection extends GetView<CheckoutController> {
  const _LoyaltySection();

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final customer = controller.customer.value;
      if (customer == null) return const SizedBox.shrink();

      final maxPoints = controller.maxRedeemablePoints;
      final redeemed = controller.pointsToRedeem.value;

      return Container(
        margin: const EdgeInsets.only(top: 12),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppColors.primarySoft,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Icon(
                  Icons.card_giftcard_rounded,
                  size: 16,
                  color: AppColors.brandInk,
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    'payment_loyalty_customer_label'.trParams({
                      'name': customer.name,
                    }),
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                // ขายเชื่อใช้แต้มไม่ได้ (บอกไว้บรรทัดล่าง) ยอดแต้มจึงไม่ต้องโชว์ — ให้ชื่อบริษัทยาว ๆ
                // มีที่พอ เดิมชื่อถูกตัดแล้วชนกับ "0 points left" ติดกันไม่มีช่องว่าง
                if (!controller.isCredit) ...[
                  const SizedBox(width: 8),
                  Text(
                    'payment_loyalty_points_balance'.trParams({
                      'points': '${customer.pointsBalance}',
                    }),
                    style: TextStyle(
                      fontSize: 12.5,
                      color: AppColors.brandInk,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ],
            ),
            if (controller.isCredit)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  'payment_credit_no_points'.tr,
                  style: TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                  ),
                ),
              )
            else if (maxPoints > 0) ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'payment_loyalty_redeem_label'.tr,
                      style: const TextStyle(fontSize: 12.5),
                    ),
                  ),
                  IconButton(
                    tooltip: 'common_decrease'.tr,
                    onPressed: redeemed > 0
                        ? () => controller.setPointsToRedeem(redeemed - 1)
                        : null,
                    icon: const Icon(Icons.remove_circle_outline_rounded),
                    visualDensity: VisualDensity.compact,
                  ),
                  SizedBox(
                    width: 32,
                    child: Text(
                      '$redeemed',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: 'common_increase'.tr,
                    onPressed: redeemed < maxPoints
                        ? () => controller.setPointsToRedeem(redeemed + 1)
                        : null,
                    icon: const Icon(Icons.add_circle_outline_rounded),
                    visualDensity: VisualDensity.compact,
                  ),
                  TextButton(
                    onPressed: redeemed == maxPoints
                        ? null
                        : () => controller.setPointsToRedeem(maxPoints),
                    child: Text('payment_loyalty_redeem_max_button'.tr),
                  ),
                ],
              ),
              if (redeemed > 0)
                Text(
                  'payment_loyalty_redeem_value'.trParams({
                    'value': Formatters.money(controller.pointsRedeemedValue),
                  }),
                  style: TextStyle(
                    fontSize: 12,
                    color: AppColors.successInk,
                    fontWeight: FontWeight.w700,
                  ),
                ),
            ] else
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  'payment_loyalty_no_points_available'.tr,
                  style: TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                  ),
                ),
              ),
          ],
        ),
      );
    });
  }
}
