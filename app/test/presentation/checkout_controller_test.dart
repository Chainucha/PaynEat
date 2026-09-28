// Copyright 2026 Suruch Chakrapeesirisuk
// SPDX-License-Identifier: Apache-2.0

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:payneat_pos/core/constants/app_constants.dart';
import 'package:payneat_pos/core/errors/failures.dart';
import 'package:payneat_pos/core/network/socket_client.dart';
import 'package:payneat_pos/core/services/session_service.dart';
import 'package:payneat_pos/core/services/storage_service.dart';
import 'package:payneat_pos/features/auth/domain/entities/user.dart';
import 'package:payneat_pos/core/usecases/result.dart';
import 'package:payneat_pos/features/customer/domain/entities/customer.dart';
import 'package:payneat_pos/features/customer/domain/repositories/customer_repository.dart';
import 'package:payneat_pos/features/customer/domain/usecases/customer_usecases.dart';
import 'package:payneat_pos/features/order/domain/entities/order.dart';
import 'package:payneat_pos/features/order/domain/repositories/order_repository.dart';
import 'package:payneat_pos/features/order/domain/usecases/order_usecases.dart';
import 'package:payneat_pos/features/payment/domain/entities/payment.dart';
import 'package:payneat_pos/features/payment/domain/repositories/payment_repository.dart';
import 'package:payneat_pos/features/payment/domain/usecases/payment_usecases.dart';
import 'package:payneat_pos/features/payment/presentation/controllers/checkout_controller.dart';
import 'package:payneat_pos/features/settings/domain/entities/store_settings.dart';
import 'package:payneat_pos/features/settings/domain/repositories/settings_repository.dart';
import 'package:payneat_pos/features/settings/domain/usecases/settings_usecases.dart';
import 'package:payneat_pos/features/shift/domain/entities/shift.dart';
import 'package:payneat_pos/features/shift/domain/repositories/shift_repository.dart';
import 'package:payneat_pos/features/shift/domain/usecases/shift_usecases.dart';

class _FakeOrderRepository implements OrderRepository {
  Result<Order> nextOrderResult = Result.success(_order());

  @override
  Future<Result<Order>> getOrder(int id) async => nextOrderResult;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakePaymentRepository implements PaymentRepository {
  Result<PaymentSummary> nextSummaryResult = Result.success(_summary());
  Result<({PaymentResult result, Order order})>? nextPayResult;
  int payCallCount = 0;
  Result<Refund>? nextRefundResult;
  ({int paymentId, double amount, String reason})? lastRefund;

  @override
  Future<Result<Refund>> refund({
    required int paymentId,
    required double amount,
    required String reason,
  }) async {
    lastRefund = (paymentId: paymentId, amount: amount, reason: reason);
    return nextRefundResult!;
  }

  @override
  Future<Result<PaymentSummary>> getSummary(int orderId) async =>
      nextSummaryResult;

  @override
  Future<Result<({PaymentResult result, Order order})>> pay({
    required int orderId,
    required String method,
    double? amount,
    List<int>? itemIds,
    double? received,
    String? reference,
    int? pointsToRedeem,
  }) async {
    payCallCount++;
    return nextPayResult!;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeShiftRepository implements ShiftRepository {
  Result<Shift?> nextCurrentResult = Result.success(_openShift());

  @override
  Future<Result<Shift?>> getCurrent() async => nextCurrentResult;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeCustomerRepository implements CustomerRepository {
  Result<Customer> nextGetByIdResult = Result.success(_customer());

  @override
  Future<Result<Customer>> getById(int id) async => nextGetByIdResult;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeSettingsRepository implements SettingsRepository {
  @override
  Future<Result<StoreSettings>> get() async =>
      const Result.success(StoreSettings.fallback);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

Customer _customer({int id = 1, int pointsBalance = 20}) => Customer(
  id: id,
  name: 'ลูกค้าทดสอบ',
  phone: '0812345678',
  pointsBalance: pointsBalance,
);

Shift _openShift() => const Shift(
  id: 1,
  status: 'open',
  openedBy: 1,
  openedAt: '2026-01-01T00:00:00Z',
  openingCash: 2000,
);

Order _order({int id = 1, double total = 107}) => Order(
  id: id,
  code: 'A001',
  type: 'dine_in',
  status: 'open',
  subtotal: 100,
  total: total,
);

PaymentSummary _summary({double total = 107, double paid = 0}) =>
    PaymentSummary(
      orderId: 1,
      total: total,
      paid: paid,
      remaining: total - paid,
    );

void main() {
  late _FakeOrderRepository orderRepository;
  late _FakePaymentRepository paymentRepository;
  late _FakeShiftRepository shiftRepository;
  late _FakeCustomerRepository customerRepository;
  late _FakeSettingsRepository settingsRepository;
  late CheckoutController controller;

  setUp(() {
    orderRepository = _FakeOrderRepository();
    paymentRepository = _FakePaymentRepository();
    shiftRepository = _FakeShiftRepository();
    customerRepository = _FakeCustomerRepository();
    settingsRepository = _FakeSettingsRepository();
    controller = CheckoutController(
      getOrder: GetOrderUseCase(orderRepository),
      getSummary: GetPaymentSummaryUseCase(paymentRepository),
      pay: PayOrderUseCase(paymentRepository),
      getCurrentShift: GetCurrentShiftUseCase(shiftRepository),
      getCustomer: GetCustomerUseCase(customerRepository),
      getSettings: GetSettingsUseCase(settingsRepository),
      getPromptPayQr: GetPromptPayQrUseCase(paymentRepository),
    );
  });

  tearDown(() => controller.onClose());

  group('CheckoutController', () {
    // submit() ทั้งสองผลลัพธ์ (สำเร็จ/ล้มเหลว) แตะ AppDialogs หรือ Get.offNamed
    // จึงไม่ครอบคลุมในเทสต์ระดับ unit นี้ ทดสอบเฉพาะ guard `if (!canPay) return;`
    // (ดู docs/CODING_STANDARDS.md)

    test(
      'onInit อ่าน orderId จาก Get.arguments (ไม่มี route จริง → 0) แล้วโหลดข้อมูล',
      () async {
        orderRepository.nextOrderResult = Result.success(_order(id: 9));
        paymentRepository.nextSummaryResult = Result.success(_summary());

        controller.onInit();
        await Future<void>.delayed(Duration.zero);

        expect(controller.orderId, 0);
        expect(controller.order.value?.id, 9);
      },
    );

    test(
      'load สำเร็จ → เติมออเดอร์/สรุปยอด และตั้งยอดจ่ายเริ่มต้นเป็นยอดคงเหลือ',
      () async {
        orderRepository.nextOrderResult = Result.success(_order(total: 107));
        paymentRepository.nextSummaryResult = Result.success(
          _summary(total: 107, paid: 0),
        );

        controller.onInit();
        await Future<void>.delayed(Duration.zero);

        expect(controller.order.value?.total, 107);
        expect(controller.remaining, 107);
        expect(controller.amount.value, 107);
        expect(controller.isLoading.value, isFalse);
      },
    );

    test('load ล้มเหลว → ตั้ง errorMessage', () async {
      orderRepository.nextOrderResult = Result.failure(
        NetworkFailure('ต่อเซิร์ฟเวอร์ไม่ได้'),
      );

      controller.onInit();
      await Future<void>.delayed(Duration.zero);

      expect(controller.errorMessage.value, 'ต่อเซิร์ฟเวอร์ไม่ได้');
    });

    test('isCash / change คำนวณเฉพาะตอนจ่ายเงินสด', () async {
      controller.onInit();
      await Future<void>.delayed(Duration.zero);

      controller.selectMethod(PaymentMethod.cash);
      controller.setAmount(100);
      controller.setReceived(150);
      expect(controller.isCash, isTrue);
      expect(controller.change, 50);

      controller.selectMethod(PaymentMethod.card);
      expect(controller.isCash, isFalse);
      expect(controller.change, 0);
    });

    test('canPay ต้องมากกว่า 0 ไม่เกินยอดคงเหลือ และเงินสดต้องรับพอ', () async {
      orderRepository.nextOrderResult = Result.success(_order(total: 100));
      paymentRepository.nextSummaryResult = Result.success(
        _summary(total: 100, paid: 0),
      );
      controller.onInit();
      await Future<void>.delayed(Duration.zero);

      controller.selectMethod(PaymentMethod.cash);
      controller.setAmount(100);
      controller.setReceived(50);
      expect(controller.canPay, isFalse, reason: 'รับเงินไม่พอ');

      controller.setReceived(100);
      expect(controller.canPay, isTrue);

      controller.setAmount(0);
      expect(controller.canPay, isFalse, reason: 'ยอดจ่ายต้องมากกว่า 0');

      controller.setAmount(200);
      expect(controller.canPay, isFalse, reason: 'ห้ามจ่ายเกินยอดคงเหลือ');
    });

    test('setAmount ปัดทศนิยม 2 ตำแหน่งและอัปเดตข้อความในช่องกรอก', () async {
      controller.onInit();
      await Future<void>.delayed(Duration.zero);

      controller.setAmount(99.999);

      expect(controller.amount.value, 100.0);
      expect(controller.amountController.text, '100.00');
    });

    test(
      'onAmountChanged/onReceivedChanged parse จากข้อความ แปลงไม่ได้ = 0',
      () {
        controller.onAmountChanged('123.45');
        expect(controller.amount.value, 123.45);

        controller.onAmountChanged('ไม่ใช่ตัวเลข');
        expect(controller.amount.value, 0);

        controller.onReceivedChanged('200');
        expect(controller.received.value, 200);
      },
    );

    test('roundedUpSuggestion ปัดยอดคงเหลือขึ้นเป็นหลักร้อยถัดไป', () async {
      orderRepository.nextOrderResult = Result.success(_order(total: 176.55));
      paymentRepository.nextSummaryResult = Result.success(
        _summary(total: 176.55, paid: 0),
      );
      controller.onInit();
      await Future<void>.delayed(Duration.zero);

      expect(controller.roundedUpSuggestion, 200);
    });

    test(
      'ยอดที่ปัดขึ้นแล้วตรงกับปุ่มธนบัตรพอดี → ตัดปุ่มธนบัตรที่ซ้ำออก',
      () async {
        // 476.69 ปัดขึ้นหลักร้อยได้ 500 ซึ่งไปซ้ำกับปุ่มธนบัตร 500
        // ถ้าไม่กรอง แคชเชียร์จะเห็นปุ่ม "500" สองปุ่มติดกันที่ทำงานเหมือนกันเป๊ะ
        orderRepository.nextOrderResult = Result.success(_order(total: 476.69));
        paymentRepository.nextSummaryResult = Result.success(
          _summary(total: 476.69, paid: 0),
        );
        controller.onInit();
        await Future<void>.delayed(Duration.zero);

        expect(controller.roundUpShortcut, 500);
        expect(controller.cashShortcuts, [1000]);
      },
    );

    test('ยอดที่ปัดขึ้นแล้วไม่ซ้ำ → ปุ่มธนบัตรยังอยู่ครบ', () async {
      orderRepository.nextOrderResult = Result.success(_order(total: 176.55));
      paymentRepository.nextSummaryResult = Result.success(
        _summary(total: 176.55, paid: 0),
      );
      controller.onInit();
      await Future<void>.delayed(Duration.zero);

      expect(controller.roundUpShortcut, 200);
      expect(controller.cashShortcuts, [500, 1000]);
    });

    test('ยอดลงตัวหลักร้อยอยู่แล้ว → ไม่เสนอปุ่มปัดขึ้น', () async {
      orderRepository.nextOrderResult = Result.success(_order(total: 500));
      paymentRepository.nextSummaryResult = Result.success(
        _summary(total: 500, paid: 0),
      );
      controller.onInit();
      await Future<void>.delayed(Duration.zero);

      // ปัดขึ้นแล้วได้ 500 เท่าเดิม จึงไม่มีอะไรให้เสนอ
      expect(controller.roundUpShortcut, isNull);
      // ปุ่มธนบัตรต้องมากกว่ายอดจริง ๆ 500 จึงไม่เข้าเงื่อนไข
      expect(controller.cashShortcuts, [1000]);
    });

    test(
      'submit เมื่อ canPay เป็นเท็จ → คืนทันทีโดยไม่เรียก pay use case',
      () async {
        controller.onInit();
        await Future<void>.delayed(Duration.zero);
        controller.setAmount(0);

        await controller.submit();

        expect(paymentRepository.payCallCount, 0);
      },
    );

    test(
      'ไม่มีกะเปิดอยู่ → hasOpenShift เป็นเท็จ และ canPay ถูกบล็อกเสมอ',
      () async {
        shiftRepository.nextCurrentResult = const Result.success(null);
        orderRepository.nextOrderResult = Result.success(_order(total: 100));
        paymentRepository.nextSummaryResult = Result.success(
          _summary(total: 100, paid: 0),
        );

        controller.onInit();
        await Future<void>.delayed(Duration.zero);
        controller.selectMethod(PaymentMethod.cash);
        controller.setAmount(100);
        controller.setReceived(100);

        expect(controller.hasOpenShift.value, isFalse);
        expect(controller.canPay, isFalse);
      },
    );

    // UAT แบบไม่มีคนสอน: ปุ่มรับเงินเทาอยู่ต้องบอกเหตุผลใต้ปุ่มเสมอ (DECISIONS #62)
    test(
      'payBlockedHint บอกเหตุผลทุกกรณีที่ canPay เป็นเท็จ และว่างเมื่อจ่ายได้',
      () async {
        orderRepository.nextOrderResult = Result.success(_order(total: 100));
        paymentRepository.nextSummaryResult = Result.success(
          _summary(total: 100, paid: 0),
        );
        controller.onInit();
        await Future<void>.delayed(Duration.zero);

        controller.selectMethod(PaymentMethod.cash);
        controller.setAmount(100);
        controller.setReceived(40);
        expect(controller.canPay, isFalse);
        expect(controller.payBlockedHint, isNotNull, reason: 'เงินสดไม่พอ');

        controller.setAmount(0);
        expect(controller.payBlockedHint, isNotNull, reason: 'ยอดเป็น 0');

        controller.setAmount(100);
        controller.setReceived(100);
        expect(controller.canPay, isTrue);
        expect(controller.payBlockedHint, isNull);

        controller.hasOpenShift.value = false;
        expect(controller.canPay, isFalse);
        expect(controller.payBlockedHint, 'payment_blocked_no_shift'.tr);
      },
    );

    test('มีกะเปิดอยู่ → hasOpenShift เป็นจริง', () async {
      controller.onInit();
      await Future<void>.delayed(Duration.zero);

      expect(controller.hasOpenShift.value, isTrue);
    });
  });

  // ขายเชื่อ (ดู docs/tickets/20-b2b-credit.md) — ปุ่ม "ขายเชื่อ" โผล่เฉพาะเมื่อใช้ได้จริง
  group('CheckoutController ขายเชื่อ', () {
    late SessionService session;
    late CheckoutController credit;
    var initialized = false;

    Customer b2b({double limit = 5000, double available = 1000}) => Customer(
      id: 900,
      name: 'บริษัท โซลบาร์บีคิว จำกัด',
      phone: '021234567',
      pointsBalance: 40,
      creditLimit: limit,
      creditTermDays: 30,
      creditOutstanding: limit - available,
      creditAvailable: available,
    );

    Future<void> open({required String role, Customer? customer}) async {
      session.updateUser(
        User(
          id: 6,
          name: 'แคชเชียร์',
          username: 'cashier',
          role: role,
          isActive: true,
        ),
      );
      orderRepository.nextOrderResult = Result.success(
        Order(
          id: 1,
          code: 'T001',
          type: 'takeaway',
          status: 'open',
          subtotal: 800,
          total: 856,
          customerId: 900,
        ),
      );
      paymentRepository.nextSummaryResult = Result.success(
        _summary(total: 856),
      );
      customerRepository.nextGetByIdResult = Result.success(customer ?? b2b());
      // เปิดหน้าครั้งแรก = onInit, ครั้งต่อไปในเทสต์เดียวกัน = โหลดซ้ำ (orderId เป็น late final)
      if (initialized) {
        await credit.load();
      } else {
        initialized = true;
        credit.onInit();
      }
      await Future<void>.delayed(Duration.zero);
      await Future<void>.delayed(Duration.zero);
    }

    setUp(() {
      initialized = false;
      session = SessionService(
        storage: StorageService.memory(),
        socket: SocketClient(),
      );
      credit = CheckoutController(
        getOrder: GetOrderUseCase(orderRepository),
        getSummary: GetPaymentSummaryUseCase(paymentRepository),
        pay: PayOrderUseCase(paymentRepository),
        getCurrentShift: GetCurrentShiftUseCase(shiftRepository),
        getCustomer: GetCustomerUseCase(customerRepository),
        getSettings: GetSettingsUseCase(settingsRepository),
        getPromptPayQr: GetPromptPayQrUseCase(paymentRepository),
        session: session,
      );
    });

    tearDown(() => credit.onClose());

    test('ลูกค้ามีวงเงิน + แคชเชียร์ → มีช่องทาง "ขายเชื่อ"', () async {
      await open(role: UserRole.cashier);

      expect(credit.canSellOnCredit, isTrue);
      expect(credit.availableMethods, contains(PaymentMethod.credit));
      expect(credit.creditAvailable, 1000);
    });

    test(
      'พนักงานเสิร์ฟ / ลูกค้าไม่มีวงเงิน → ไม่มีช่องทาง "ขายเชื่อ"',
      () async {
        await open(role: UserRole.waiter);
        expect(credit.availableMethods, isNot(contains(PaymentMethod.credit)));

        await open(
          role: UserRole.cashier,
          customer: b2b(limit: 0, available: 0),
        );
        expect(credit.availableMethods, isNot(contains(PaymentMethod.credit)));
      },
    );

    test('ยอดไม่เกินวงเงินที่เหลือจ่ายได้ เกินแล้วปุ่มจ่ายกดไม่ได้', () async {
      await open(role: UserRole.cashier);
      credit.selectMethod(PaymentMethod.credit);

      credit.setAmount(856);
      expect(credit.canPay, isTrue);

      await open(role: UserRole.cashier, customer: b2b(available: 500));
      credit.selectMethod(PaymentMethod.credit);
      credit.setAmount(856);
      expect(credit.canPay, isFalse);
      credit.setAmount(500);
      expect(credit.canPay, isTrue, reason: 'จ่ายบางส่วนด้วยเครดิตได้');
    });

    test(
      'เลือกขายเชื่อแล้วแต้มที่เลือกไว้ถูกล้าง และแลกแต้มเพิ่มไม่ได้',
      () async {
        await open(role: UserRole.cashier);
        credit.setPointsToRedeem(10);
        expect(credit.pointsToRedeem.value, 10);

        credit.selectMethod(PaymentMethod.credit);

        expect(credit.pointsToRedeem.value, 0);
        expect(credit.maxRedeemablePoints, 0);
        credit.setPointsToRedeem(10);
        expect(credit.pointsToRedeem.value, 0);
      },
    );
  });

  // คืนเงินบนบิลที่ยังเปิด (T06 #82, docs/DECISIONS.md #77 D1, #87) — ยอดคงเหลือมาจาก backend ที่หักยอดคืนแล้วเสมอ
  group('CheckoutController คืนเงินบนบิลที่ยังเปิด (T06)', () {
    late SessionService session;
    late CheckoutController checkout;

    const cash50 = Payment(
      id: 31,
      orderId: 1,
      method: PaymentMethod.cash,
      amount: 50,
      received: 50,
    );

    PaymentSummary summaryAfter({double refunded = 0}) => PaymentSummary(
      orderId: 1,
      total: 100.05,
      paid: 50 - refunded,
      remaining: 100.05 - (50 - refunded),
      refunded: refunded,
      payments: const [cash50],
      refunds: [
        if (refunded > 0)
          Refund(
            id: 7,
            paymentId: cash50.id,
            orderId: 1,
            amount: refunded,
            reason: 'ลูกค้าเปลี่ยนใจ',
          ),
      ],
    );

    Future<void> open({
      required String role,
      Future<void> Function()? settle,
    }) async {
      session.updateUser(
        User(id: 2, name: 'ผู้ใช้', username: role, role: role, isActive: true),
      );
      orderRepository.nextOrderResult = Result.success(_order(total: 100.05));
      paymentRepository.nextSummaryResult = Result.success(summaryAfter());
      checkout.onInit();
      // ใน testWidgets เวลาเดินเมื่อ pump เท่านั้น — ใช้ settle ของ tester แทน Future.delayed
      await (settle ?? () => Future<void>.delayed(Duration.zero))();
    }

    setUp(() {
      session = SessionService(
        storage: StorageService.memory(),
        socket: SocketClient(),
      );
      checkout = CheckoutController(
        getOrder: GetOrderUseCase(orderRepository),
        getSummary: GetPaymentSummaryUseCase(paymentRepository),
        pay: PayOrderUseCase(paymentRepository),
        getCurrentShift: GetCurrentShiftUseCase(shiftRepository),
        getCustomer: GetCustomerUseCase(customerRepository),
        getSettings: GetSettingsUseCase(settingsRepository),
        getPromptPayQr: GetPromptPayQrUseCase(paymentRepository),
        refundPayment: RefundPaymentUseCase(paymentRepository),
        session: session,
      );
    });

    tearDown(() => checkout.onClose());

    test(
      'ผู้จัดการคืนเงินได้ แคชเชียร์ไม่ได้ (สิทธิ์เดียวกับหน้าใบเสร็จ)',
      () async {
        await open(role: UserRole.manager);
        expect(checkout.canRefund, isTrue);

        session.updateUser(
          const User(
            id: 6,
            name: 'แคชเชียร์',
            username: 'cashier',
            role: UserRole.cashier,
            isActive: true,
          ),
        );
        expect(checkout.canRefund, isFalse);
      },
    );

    test('ยอดที่คืนได้หักยอดที่คืนไปแล้วของ payment นั้น', () async {
      await open(role: UserRole.manager);
      expect(checkout.refundableAmount(cash50), 50);

      checkout.summary.value = summaryAfter(refunded: 20);
      expect(checkout.refundableAmount(cash50), 30);
      checkout.summary.value = summaryAfter(refunded: 50);
      expect(checkout.refundableAmount(cash50), 0);
    });

    testWidgets(
      'จ่าย 50 แล้วคืน 50 → โหลดยอดใหม่จาก backend ยอดคงเหลือกลับเป็น 100.05 และตั้งยอดจ่ายตามนั้น',
      (tester) async {
        await tester.pumpWidget(const GetMaterialApp(home: Scaffold()));
        await open(role: UserRole.manager, settle: tester.pump);
        expect(checkout.remaining, closeTo(50.05, 0.001));

        paymentRepository.nextRefundResult = const Result.success(
          Refund(
            id: 7,
            paymentId: 31,
            orderId: 1,
            amount: 50,
            reason: 'ลูกค้าเปลี่ยนใจ',
          ),
        );
        paymentRepository.nextSummaryResult = Result.success(
          summaryAfter(refunded: 50),
        );
        await checkout.refundPayment(
          payment: cash50,
          amount: 50,
          reason: 'ลูกค้าเปลี่ยนใจ',
        );
        await tester.pump();

        expect(paymentRepository.lastRefund?.paymentId, 31);
        expect(paymentRepository.lastRefund?.amount, 50);
        expect(checkout.remaining, 100.05);
        expect(checkout.amount.value, 100.05);
        expect(checkout.summary.value?.refunded, 50);
        expect(checkout.isRefunding.value, isFalse);

        await tester.pump(const Duration(seconds: 5));
        await tester.pumpAndSettle();
      },
    );

    testWidgets(
      'คืนเงินไม่สำเร็จ → แสดงเหตุผลจาก backend และยอดเดิมไม่เปลี่ยน',
      (tester) async {
        const message = 'คืนเงินเกินยอดที่คืนได้ (คืนได้สูงสุด 50 บาท)';
        await tester.pumpWidget(const GetMaterialApp(home: Scaffold()));
        await open(role: UserRole.manager, settle: tester.pump);
        paymentRepository.nextRefundResult = const Result.failure(
          ServerFailure(message, statusCode: 400),
        );

        await checkout.refundPayment(payment: cash50, amount: 60, reason: 'x');
        await tester.pump();

        expect(find.text(message), findsOneWidget);
        expect(checkout.remaining, closeTo(50.05, 0.001));

        await tester.pump(const Duration(seconds: 5));
        await tester.pumpAndSettle();
      },
    );
  });
}
