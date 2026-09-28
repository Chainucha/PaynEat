// Copyright 2026 Suruch Chakrapeesirisuk
// SPDX-License-Identifier: Apache-2.0

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../../app/routes/app_routes.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/services/session_service.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/widgets/app_dialogs.dart';
import '../../../customer/domain/entities/customer.dart';
import '../../../customer/domain/usecases/customer_usecases.dart';
import '../../../order/domain/entities/order.dart';
import '../../../order/domain/usecases/order_usecases.dart';
import '../../../settings/domain/entities/store_settings.dart';
import '../../../settings/domain/usecases/settings_usecases.dart';
import '../../../shift/domain/usecases/shift_usecases.dart';
import '../../domain/entities/payment.dart';
import '../../domain/usecases/payment_usecases.dart';

/// หน้าจอเก็บเงิน — รองรับจ่ายครบทีเดียวและแยกจ่ายหลายช่องทาง
class CheckoutController extends GetxController {
  CheckoutController({
    required GetOrderUseCase getOrder,
    required GetPaymentSummaryUseCase getSummary,
    required PayOrderUseCase pay,
    required GetCurrentShiftUseCase getCurrentShift,
    required GetCustomerUseCase getCustomer,
    required GetSettingsUseCase getSettings,
    required GetPromptPayQrUseCase getPromptPayQr,
    RefundPaymentUseCase? refundPayment,
    SessionService? session,
  }) : _getOrder = getOrder,
       _getSummary = getSummary,
       _pay = pay,
       _getCurrentShift = getCurrentShift,
       _getCustomer = getCustomer,
       _getSettings = getSettings,
       _getPromptPayQr = getPromptPayQr,
       _refundPayment = refundPayment,
       _session = session;

  final GetOrderUseCase _getOrder;
  final GetPaymentSummaryUseCase _getSummary;
  final PayOrderUseCase _pay;
  final GetCurrentShiftUseCase _getCurrentShift;
  final GetCustomerUseCase _getCustomer;
  final GetSettingsUseCase _getSettings;
  final GetPromptPayQrUseCase _getPromptPayQr;
  final RefundPaymentUseCase? _refundPayment;
  final SessionService? _session;

  final Rxn<Order> order = Rxn<Order>();
  final Rxn<PaymentSummary> summary = Rxn<PaymentSummary>();
  final Rxn<Customer> customer = Rxn<Customer>();
  final Rx<StoreSettings> settings = StoreSettings.fallback.obs;
  final RxBool hasOpenShift = true.obs;
  final RxBool isLoading = true.obs;
  final RxBool isPaying = false.obs;
  final RxBool isRefunding = false.obs;
  final RxnString errorMessage = RxnString();
  final RxString method = PaymentMethod.cash.obs;
  final RxDouble amount = 0.0.obs;
  final RxDouble received = 0.0.obs;
  final RxInt pointsToRedeem = 0.obs;

  // QR พร้อมเพย์ (ดู docs/tickets/16-promptpay-qr.md) — โหลดใหม่ทุกครั้งที่ยอด/แต้มที่แลก
  // เปลี่ยนตอนเลือกช่องทาง "qr" อยู่ debounce ไว้กันยิง request รัวตอนพิมพ์ยอดเอง
  final Rxn<PromptPayQr> promptPayQr = Rxn<PromptPayQr>();
  final RxnString promptPayQrError = RxnString();
  final RxBool isLoadingQr = false.obs;
  Timer? _qrDebounce;

  final TextEditingController amountController = TextEditingController();
  final TextEditingController receivedController = TextEditingController();
  final TextEditingController referenceController = TextEditingController();

  late final int orderId;

  /// ปุ่มลัดธนบัตรที่ใช้บ่อยในร้าน
  static const List<double> quickCashOptions = [100, 500, 1000];

  @override
  void onInit() {
    super.onInit();
    final args = Get.arguments;
    orderId = (args is Map ? args['orderId'] as int? : null) ?? 0;
    load();
  }

  @override
  void onClose() {
    _qrDebounce?.cancel();
    amountController.dispose();
    receivedController.dispose();
    referenceController.dispose();
    super.onClose();
  }

  double get remaining => summary.value?.remaining ?? 0;

  /// คืนเงินบนบิลที่ยังเปิดได้ (DECISIONS #77 D1) สิทธิ์เดียวกับหน้าใบเสร็จ — ผู้จัดการขึ้นไป
  bool get canRefund =>
      _refundPayment != null && (_session?.currentUser?.isManagement ?? false);

  /// ยอดที่ยังคืนได้ของ payment นี้ (หักที่คืนไปแล้วก่อนหน้า)
  double refundableAmount(Payment payment) {
    final left = payment.amount - (summary.value?.refundedFor(payment.id) ?? 0);
    return left > 0 ? double.parse(left.toStringAsFixed(2)) : 0;
  }

  /// คืนเงินของ payment ที่รับไว้แล้วบนบิลที่ยังเปิด — ยอดคงเหลือเพิ่มขึ้นตามยอดที่คืน และถ้าคืน payment ที่แยกจ่าย
  /// ตามรายการครบ รายการเหล่านั้นกลับไปเลือกจ่ายใหม่ได้ โหลดยอดจาก backend ใหม่เสมอ ไม่คำนวณเอง
  /// (T06 #82, docs/DECISIONS.md #87)
  Future<void> refundPayment({
    required Payment payment,
    required double amount,
    required String reason,
  }) async {
    final refund = _refundPayment;
    if (refund == null) return;
    isRefunding.value = true;
    final result = await refund(
      RefundParams(paymentId: payment.id, amount: amount, reason: reason),
    );
    isRefunding.value = false;
    await result.fold(
      onSuccess: (_) async {
        AppDialogs.success('payment_refund_success'.tr);
        await load();
      },
      onFailure: (failure) async => AppDialogs.error(failure.message),
    );
  }

  bool get isCash => method.value == PaymentMethod.cash;
  bool get isCredit => method.value == PaymentMethod.credit;

  /// ขายเชื่อได้เมื่อออเดอร์ผูกลูกค้าที่มีวงเงิน และผู้ใช้ไม่ใช่พนักงานเสิร์ฟ — ตรงกับเงื่อนไขใน
  /// payment.service.js (ดู docs/tickets/20-b2b-credit.md)
  bool get canSellOnCredit =>
      (customer.value?.hasCreditAccount ?? false) &&
      (_session?.currentUser?.canHandleCredit ?? false);

  /// ช่องทางที่โชว์ให้เลือก — "ขายเชื่อ" โผล่เฉพาะตอนใช้ได้จริง ไม่งั้นแคชเชียร์กดแล้วโดนปฏิเสธเปล่า ๆ
  List<String> get availableMethods => [
    ...PaymentMethod.all,
    if (canSellOnCredit) PaymentMethod.credit,
  ];

  /// วงเงินที่ยังเหลือของลูกค้า ณ ตอนโหลดหน้า
  double get creditAvailable => customer.value?.creditAvailable ?? 0;

  /// มูลค่าแต้มที่ใช้แลกรอบนี้ (บาท) — ลดแค่ยอดที่ต้องเก็บจริง (chargedAmount) เท่านั้น
  /// ไม่แตะยอด amount ที่นับเข้าบัญชีจ่ายของออเดอร์ (ดู docs/tickets/09-customer-loyalty.md)
  double get pointsRedeemedValue =>
      pointsToRedeem.value * settings.value.pointsRedeemValueBaht;

  /// ยอดที่ต้องเก็บจริงผ่านช่องทางที่เลือกรอบนี้ หลังหักมูลค่าแต้มที่แลก
  double get chargedAmount {
    final value = amount.value - pointsRedeemedValue;
    return value > 0 ? double.parse(value.toStringAsFixed(2)) : 0;
  }

  /// แต้มสูงสุดที่แลกได้รอบนี้ — ไม่เกินแต้มคงเหลือของลูกค้า และมูลค่าต้องไม่เกินยอดจ่ายรอบนี้
  int get maxRedeemablePoints {
    final loyaltyCustomer = customer.value;
    // ขายเชื่อใช้แต้มร่วมไม่ได้ — หนี้ต้องเท่ากับยอดในบิลพอดี (backend ปฏิเสธเหมือนกัน)
    if (loyaltyCustomer == null || isCredit) return 0;
    final rate = settings.value.pointsRedeemValueBaht;
    if (rate <= 0) return 0;
    final byAmount = (amount.value / rate).floor();
    return loyaltyCustomer.pointsBalance < byAmount
        ? loyaltyCustomer.pointsBalance
        : byAmount;
  }

  /// เงินทอน = เงินที่รับมา - ยอดที่ต้องเก็บจริงรอบนี้ (หลังหักแต้ม)
  double get change {
    if (!isCash) return 0;
    final value = received.value - chargedAmount;
    return value > 0 ? double.parse(value.toStringAsFixed(2)) : 0;
  }

  /// เหตุผลที่ปุ่มรับเงินยังกดไม่ได้ (แปลแล้ว) — โชว์ใต้ปุ่มให้คนไม่เคยใช้รู้ว่าต้องทำอะไรต่อ
  /// กรณีขายเชื่อเกินวงเงินมีข้อความในกล่องวงเงินอยู่แล้ว จึงไม่ซ้ำตรงนี้ (คืน null)
  String? get payBlockedHint {
    if (!hasOpenShift.value) return 'payment_blocked_no_shift'.tr;
    if (amount.value <= 0 || amount.value > remaining + 0.001) {
      return 'payment_blocked_amount'.trParams({
        'amount': Formatters.baht(remaining),
      });
    }
    if (isCash && received.value + 0.001 < chargedAmount) {
      return 'payment_blocked_cash_short'.trParams({
        'amount': Formatters.baht(chargedAmount - received.value),
      });
    }
    return null;
  }

  bool get canPay {
    if (!hasOpenShift.value) return false;
    if (amount.value <= 0 || amount.value > remaining + 0.001) return false;
    if (isCash && received.value + 0.001 < chargedAmount) return false;
    if (isCredit) {
      if (!canSellOnCredit) return false;
      if (amount.value > creditAvailable + 0.001) return false;
    }
    return true;
  }

  Future<void> load() async {
    isLoading.value = true;
    errorMessage.value = null;
    pointsToRedeem.value = 0;
    customer.value = null;

    final shiftResult = await _getCurrentShift();
    hasOpenShift.value = shiftResult.dataOrNull != null;

    final settingsResult = await _getSettings();
    settingsResult.fold(
      onSuccess: (data) => settings.value = data,
      onFailure: (_) {}, // ใช้ค่า fallback ต่อไปได้ ไม่ต้องรบกวนผู้ใช้
    );

    final results = await Future.wait([
      _getOrder(orderId),
      _getSummary(orderId),
    ]);

    isLoading.value = false;
    results[0].fold(
      onSuccess: (data) {
        // Order.== เทียบแค่ id ต้องเคลียร์เป็น null ก่อนเพื่อบังคับให้ Rxn อัปเดตจริง
        // (ดู docs/CODING_STANDARDS.md หัวข้อ 3.5) — โหลดซ้ำหลัง submit() ที่จ่ายไม่ครบ
        // ใช้ order id เดิมเสมอ
        order.value = null;
        order.value = data as Order;
        final customerId = order.value?.customerId;
        if (customerId != null) _loadCustomer(customerId);
      },
      onFailure: (failure) => errorMessage.value = failure.message,
    );
    results[1].fold(
      onSuccess: (data) {
        summary.value = data as PaymentSummary;
        setAmount(summary.value!.remaining);
      },
      onFailure: (failure) => errorMessage.value = failure.message,
    );
  }

  /// โหลดข้อมูลลูกค้า (รวมแต้มคงเหลือ) เพื่อแสดงและให้แลกแต้มได้ — ดึงไม่ได้ก็ไม่บล็อก
  /// การจ่ายเงิน แค่ซ่อนส่วนแลกแต้มไป
  Future<void> _loadCustomer(int customerId) async {
    final result = await _getCustomer(customerId);
    result.fold(onSuccess: (data) => customer.value = data, onFailure: (_) {});
    if (isCredit && !canSellOnCredit) selectMethod(PaymentMethod.cash);
  }

  void selectMethod(String value) {
    method.value = value;
    if (value == PaymentMethod.credit) pointsToRedeem.value = 0;
    if (value != PaymentMethod.cash) {
      setReceived(amount.value);
    }
    if (value == PaymentMethod.qr) {
      _qrDebounce?.cancel();
      _fetchPromptPayQr();
    } else {
      _qrDebounce?.cancel();
    }
  }

  void setAmount(double value) {
    final rounded = double.parse(value.toStringAsFixed(2));
    amount.value = rounded;
    amountController.text = rounded.toStringAsFixed(2);
    if (received.value < rounded) setReceived(rounded);
    if (pointsToRedeem.value > maxRedeemablePoints) {
      pointsToRedeem.value = maxRedeemablePoints;
    }
    _scheduleQrReload();
  }

  /// ตั้งจำนวนแต้มที่จะแลกรอบนี้ — ถูกจำกัดไม่ให้เกิน [maxRedeemablePoints] เสมอ
  void setPointsToRedeem(int value) {
    pointsToRedeem.value = value.clamp(0, maxRedeemablePoints);
    _scheduleQrReload();
  }

  void onAmountChanged(String value) {
    amount.value = double.tryParse(value.trim()) ?? 0;
    _scheduleQrReload();
  }

  /// โหลด QR พร้อมเพย์ใหม่ทันที (ตอนเพิ่งเปลี่ยนมาเลือกช่องทาง "qr")
  Future<void> _fetchPromptPayQr() async {
    if (method.value != PaymentMethod.qr) return;
    if (chargedAmount <= 0) {
      promptPayQr.value = null;
      promptPayQrError.value = null;
      return;
    }
    isLoadingQr.value = true;
    promptPayQrError.value = null;
    final result = await _getPromptPayQr(chargedAmount);
    isLoadingQr.value = false;
    result.fold(
      onSuccess: (data) => promptPayQr.value = data,
      onFailure: (failure) {
        promptPayQr.value = null;
        promptPayQrError.value = failure.message;
      },
    );
  }

  /// หน่วงโหลด QR ใหม่ 350ms กันยิง request รัวตอนพิมพ์ยอดเอง — เรียกได้ตลอดแม้ยังไม่ได้
  /// เลือกช่องทาง "qr" เพราะเช็คเงื่อนไขซ้ำใน [_fetchPromptPayQr] อยู่แล้ว
  void _scheduleQrReload() {
    if (method.value != PaymentMethod.qr) return;
    _qrDebounce?.cancel();
    _qrDebounce = Timer(const Duration(milliseconds: 350), _fetchPromptPayQr);
  }

  void setReceived(double value) {
    received.value = value;
    receivedController.text = value.toStringAsFixed(2);
  }

  void onReceivedChanged(String value) {
    received.value = double.tryParse(value.trim()) ?? 0;
  }

  /// ปัดขึ้นเป็นหลักร้อยถัดไป เช่น ยอด 176.55 → เสนอปุ่ม 200
  double get roundedUpSuggestion {
    final target = remaining;
    if (target <= 0) return 0;
    return (target / 100).ceil() * 100;
  }

  /// ปุ่ม "ปัดขึ้นหลักร้อย" ที่ควรโชว์จริง — null เมื่อยอดลงตัวหลักร้อยอยู่แล้ว
  /// (ปัดขึ้นแล้วได้เท่าเดิม จึงไม่มีอะไรให้เสนอ)
  double? get roundUpShortcut {
    final suggestion = roundedUpSuggestion;
    return suggestion > remaining ? suggestion : null;
  }

  /// ปุ่มธนบัตรที่ควรโชว์ — ต้องมากกว่ายอดที่จ่ายรอบนี้ และต้องไม่ซ้ำกับปุ่มปัดขึ้นหลักร้อย
  ///
  /// ยอด 476.69 ทำให้ปัดขึ้นหลักร้อยได้ 500 พอดี ซึ่งไปซ้ำกับปุ่มธนบัตร 500
  /// แคชเชียร์จะเห็นปุ่ม "500" สองปุ่มติดกันที่ทำงานเหมือนกันเป๊ะ
  List<double> get cashShortcuts => quickCashOptions
      .where((value) => value > amount.value && value != roundUpShortcut)
      .toList(growable: false);

  Future<void> submit() async {
    if (!canPay) return;

    isPaying.value = true;
    final result = await _pay(
      PayParams(
        orderId: orderId,
        method: method.value,
        amount: amount.value,
        received: isCash ? received.value : null,
        reference: referenceController.text.trim(),
        pointsToRedeem: pointsToRedeem.value > 0 ? pointsToRedeem.value : null,
      ),
    );
    isPaying.value = false;

    result.fold(
      onSuccess: (data) {
        if (data.result.isFullyPaid) {
          AppDialogs.success('payment_bill_closed_success'.tr);
          Get.offNamed<void>(
            AppRoutes.receipt,
            arguments: {'orderId': orderId},
          );
        } else {
          AppDialogs.success(
            'payment_partial_paid_success'.trParams({
              'amount': data.result.remaining.toStringAsFixed(2),
            }),
          );
          referenceController.clear();
          load();
        }
      },
      onFailure: (failure) => AppDialogs.error(failure.message),
    );
  }
}
