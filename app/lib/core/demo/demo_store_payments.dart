// Copyright 2026 Suruch Chakrapeesirisuk
// SPDX-License-Identifier: Apache-2.0

part of 'demo_store.dart';

// --------------------------------------------------------- payments -----
extension DemoStorePayments on DemoStore {
  /// เงินที่ร้านถือไว้สำหรับออเดอร์นี้ = ยอดชำระ − ยอดคืนเงิน — mirror ของ payment.repository.js#netPaid
  /// (T06 #82, docs/DECISIONS.md #87)
  double paidAmount(int orderId) =>
      payments
          .where((row) => row['orderId'] == orderId)
          .fold<double>(
            0,
            (sum, row) => sum + (row['amount'] as num).toDouble(),
          ) -
      _refundedTotalByOrder(orderId);

  double _refundedTotalByOrder(int orderId) => refundsByOrder(
    orderId,
  ).fold<double>(0, (sum, row) => sum + (row['amount'] as num).toDouble());

  Map<String, dynamic> paymentSummary(int orderId) {
    final order = findOrder(orderId);
    final paid = paidAmount(orderId);
    final total = (order['total'] as num).toDouble();
    return {
      'orderId': orderId,
      'total': total,
      'paid': paid,
      'refunded': _refundedTotalByOrder(orderId),
      // บิลที่จ่ายครบแล้วปิดไปแล้ว คืนเงินหลังปิดบิลไม่เปิดยอดค้างใหม่ — mirror ของ payment.service.js#summary
      'remaining': order['status'] == OrderStatus.paid
          ? 0.0
          : max(0, total - paid),
      'payments': payments
          .where((row) => row['orderId'] == orderId)
          .toList(growable: false),
      'refunds': refundsByOrder(orderId),
    };
  }

  /// ตรวจว่ารายการที่เลือกแยกบิลถูกต้อง — อยู่ในออเดอร์จริง ยังไม่ถูกยกเลิก และยังไม่ถูกจ่ายไปก่อนหน้า
  void _assertItemsSelectable(Map<String, dynamic> order, List<int> itemIds) {
    final items = (order['items'] as List).cast<Map<String, dynamic>>();
    for (final id in itemIds) {
      if (!items.any((item) => item['id'] == id)) {
        throw ApiException(
          message: 'payment_error_items_not_in_order'.tr,
          statusCode: 400,
        );
      }
    }
    for (final item in items.where((item) => itemIds.contains(item['id']))) {
      if (item['isPaid'] == true) {
        throw ApiException(
          message: 'payment_error_item_already_paid'.trParams({
            'name': '${item['name']}',
          }),
          statusCode: 409,
        );
      }
      if (item['status'] == OrderItemStatus.cancelled) {
        throw ApiException(
          message: 'payment_error_item_cancelled'.trParams({
            'name': '${item['name']}',
          }),
          statusCode: 400,
        );
      }
    }
  }

  /// คำนวณส่วนแบ่งบิลของรายการที่เลือก — คิดสัดส่วนตาม subtotal เทียบกับทั้งบิล
  /// แล้วเฉลี่ยส่วนลด/Service Charge/VAT ตามสัดส่วนนั้น (ดูสูตรเดียวกันที่
  /// backend/src/modules/orders/order.calculator.js#calculateItemsShare)
  Map<String, dynamic> _itemsShare(
    Map<String, dynamic> order,
    List<int> itemIds,
  ) {
    final items = (order['items'] as List).cast<Map<String, dynamic>>();
    final active = items
        .where((item) => item['status'] != OrderItemStatus.cancelled)
        .toList();
    final unpaidActive = active
        .where((item) => item['isPaid'] != true)
        .toList();
    final selected = active.where((item) => itemIds.contains(item['id']));

    final fullSubtotal = active.fold<double>(
      0,
      (sum, item) => sum + (item['lineTotal'] as num).toDouble(),
    );
    final selectedSubtotal = selected.fold<double>(
      0,
      (sum, item) => sum + (item['lineTotal'] as num).toDouble(),
    );
    final share = fullSubtotal > 0 ? selectedSubtotal / fullSubtotal : 0.0;

    final discountAmount = _roundMoney(
      (order['discountAmount'] as num).toDouble() * share,
    );
    final serviceCharge = _roundMoney(
      (order['serviceCharge'] as num).toDouble() * share,
    );
    final vat = _roundMoney((order['vat'] as num).toDouble() * share);
    final total = selectedSubtotal - discountAmount + serviceCharge + vat;

    final isLastBatch =
        unpaidActive.isNotEmpty &&
        unpaidActive.every((item) => itemIds.contains(item['id']));

    return {
      'subtotal': selectedSubtotal,
      'discountAmount': discountAmount,
      'serviceCharge': serviceCharge,
      'vat': vat,
      'total': total,
      'isLastBatch': isLastBatch,
    };
  }

  static double _roundMoney(double value) => (value * 100).round() / 100;

  /// ดูยอดที่ต้องจ่ายล่วงหน้าก่อนแยกบิล โดยยังไม่ตัดจ่ายจริง
  Map<String, dynamic> splitPreview(int orderId, List<int> itemIds) {
    final order = findOrder(orderId);
    if (order['status'] == OrderStatus.cancelled) {
      throw ApiException(
        message: 'payment_error_order_cancelled'.tr,
        statusCode: 409,
      );
    }
    if (order['status'] == OrderStatus.paid) {
      throw ApiException(
        message: 'payment_order_already_paid'.tr,
        statusCode: 409,
      );
    }
    _assertItemsSelectable(order, itemIds);

    final total = (order['total'] as num).toDouble();
    final alreadyPaid = paidAmount(orderId);
    final remaining = max<double>(0, total - alreadyPaid);
    final share = _itemsShare(order, itemIds);
    final amount = (share['isLastBatch'] as bool)
        ? remaining
        : min(share['total'] as double, remaining);

    return {
      'orderId': orderId,
      'itemIds': itemIds,
      'subtotal': share['subtotal'],
      'discountAmount': share['discountAmount'],
      'serviceCharge': share['serviceCharge'],
      'vat': share['vat'],
      'total': amount,
      'remaining': remaining,
      'isLastBatch': share['isLastBatch'],
    };
  }

  Map<String, dynamic> pay({
    required int orderId,
    required String method,
    double? amount,
    List<int>? itemIds,
    double? received,
    String? reference,
    int? cashierId,
    int pointsToRedeem = 0,
  }) {
    final shift = _openShift;
    if (shift == null) {
      throw ApiException(
        message: 'payment_error_shift_required'.tr,
        statusCode: 409,
      );
    }

    final order = findOrder(orderId);
    if (order['status'] == OrderStatus.cancelled) {
      throw ApiException(
        message: 'payment_error_order_cancelled'.tr,
        statusCode: 409,
      );
    }
    if (order['status'] == OrderStatus.paid) {
      throw ApiException(
        message: 'payment_order_already_paid'.tr,
        statusCode: 409,
      );
    }

    final total = (order['total'] as num).toDouble();
    final alreadyPaid = paidAmount(orderId);
    final remaining = total - alreadyPaid;

    double resolvedAmount;
    if (itemIds != null && itemIds.isNotEmpty) {
      _assertItemsSelectable(order, itemIds);
      final share = _itemsShare(order, itemIds);
      resolvedAmount = (share['isLastBatch'] as bool)
          ? remaining
          : min(share['total'] as double, remaining);
    } else {
      resolvedAmount = amount ?? 0;
    }

    if (resolvedAmount > remaining + 0.001) {
      throw ApiException(
        message: 'payment_error_amount_exceeds_remaining'.trParams({
          'remaining': remaining.toStringAsFixed(2),
        }),
        statusCode: 400,
      );
    }

    // ใช้แต้มสะสมแลกส่วนลดรอบจ่ายนี้ (ดู docs/tickets/09-customer-loyalty.md) — resolvedAmount
    // (ยอดที่นับเข้ายอดจ่ายของออเดอร์) ไม่เปลี่ยน มีแค่ยอดที่ต้องเก็บจริง (chargedAmount) ที่ลดลง
    var pointsRedeemedValue = 0.0;
    final customerId = order['customerId'] as int?;
    if (pointsToRedeem > 0) {
      if (customerId == null) {
        throw ApiException(
          message: 'payment_error_points_requires_customer'.tr,
          statusCode: 400,
        );
      }
      final customer = findCustomer(customerId);
      if (pointsToRedeem > (customer['pointsBalance'] as int)) {
        throw ApiException(
          message: 'payment_error_points_insufficient'.tr,
          statusCode: 400,
        );
      }
      pointsRedeemedValue = _roundMoney(
        pointsToRedeem * (settings['pointsRedeemValueBaht'] as num).toDouble(),
      );
      if (pointsRedeemedValue > resolvedAmount + 0.001) {
        throw ApiException(
          message: 'payment_error_points_value_exceeds_amount'.tr,
          statusCode: 400,
        );
      }
    }

    // ขายเชื่อ — mirror ของ payment.service.js#pay (ดู docs/tickets/20-b2b-credit.md)
    String? dueDate;
    if (method == PaymentMethod.credit) {
      if (cashierId != null &&
          _findUser(cashierId)['role'] == UserRole.waiter) {
        throw ApiException(
          message: 'payment_error_credit_role'.tr,
          statusCode: 403,
        );
      }
      if (customerId == null) {
        throw ApiException(
          message: 'payment_error_credit_requires_customer'.tr,
          statusCode: 400,
        );
      }
      if (pointsToRedeem > 0) {
        throw ApiException(
          message: 'payment_error_credit_no_points'.tr,
          statusCode: 400,
        );
      }
      dueDate = assertCanChargeCredit(customerId, resolvedAmount);
    }
    final chargedAmount = resolvedAmount - pointsRedeemedValue;

    final actualReceived = method == PaymentMethod.cash
        ? (received ?? chargedAmount)
        : chargedAmount;
    if (method == PaymentMethod.cash &&
        actualReceived + 0.001 < chargedAmount) {
      throw ApiException(
        message: 'payment_error_received_less_than_amount'.tr,
        statusCode: 400,
      );
    }

    final payment = {
      'id': _nextId(),
      'orderId': orderId,
      'shiftId': shift['id'],
      'method': method,
      'amount': resolvedAmount,
      'received': actualReceived,
      'change': method == PaymentMethod.cash
          ? max(0, actualReceived - chargedAmount)
          : 0.0,
      'reference': reference,
      'cashierId': cashierId,
      'cashierName': cashierId == null
          ? null
          : DemoNames.of(_findUser(cashierId)),
      'pointsRedeemed': pointsToRedeem,
      'pointsRedeemedValue': pointsRedeemedValue,
      'dueDate': dueDate,
      'createdAt': _now(),
    };
    payments.add(payment);

    if (pointsToRedeem > 0) {
      adjustCustomerPoints(customerId!, -pointsToRedeem);
    }

    if (itemIds != null && itemIds.isNotEmpty) {
      for (final item
          in (order['items'] as List).cast<Map<String, dynamic>>()) {
        if (itemIds.contains(item['id'])) {
          item['isPaid'] = true;
          item['paidByPaymentId'] = payment['id'];
        }
      }
    }

    final isFullyPaid = alreadyPaid + resolvedAmount >= total - 0.001;
    if (isFullyPaid) {
      // ของที่ขายไปต้องออกจากสต๊อกเสมอ แม้บิลนี้ไม่เคยกด "ส่งเข้าครัว" — mirror ของ
      // payment.service.js#pay (docs/DECISIONS.md #51)
      for (final item
          in (order['items'] as List).cast<Map<String, dynamic>>()) {
        if (item['status'] != OrderItemStatus.cancelled &&
            item['stockDeducted'] != true) {
          deductForOrderItem(item);
          item['stockDeducted'] = true;
        }
      }
      order['status'] = OrderStatus.paid;
      order['closedAt'] = _now();
      _freeTable(order);
      // สะสมแต้มให้ลูกค้าที่ผูกไว้ครั้งเดียวตอนออเดอร์นี้จ่ายครบ (ไม่ผูกลูกค้า = ไม่ได้แต้ม)
      // ออเดอร์ที่มีส่วนขายเชื่อ แต้มรอไปให้ตอนรับชำระหนี้ครบ (DECISIONS #59)
      if (customerId != null && _hasCreditPayment(orderId)) {
        _syncCreditPoints(orderId);
      } else if (customerId != null) {
        final earnRate = (settings['pointsEarnRateBaht'] as num).toDouble();
        final pointsEarned = (total / earnRate).floor();
        if (pointsEarned > 0) {
          order['pointsEarned'] = pointsEarned;
          adjustCustomerPoints(customerId, pointsEarned);
        }
      }
    }

    return {
      'payment': payment,
      'order': order,
      'isFullyPaid': isFullyPaid,
      'remaining': max(0, total - (alreadyPaid + resolvedAmount)),
    };
  }

  Map<String, dynamic> receipt(int orderId) {
    final order = findOrder(orderId);
    return {
      'store': {
        'name': DemoNames.of(settings, key: 'storeName'),
        'currency': settings['currency'],
        'vatRate': settings['vatRate'],
        'serviceChargeRate': settings['serviceChargeRate'],
      },
      'order': order,
      'payments': payments
          .where((row) => row['orderId'] == orderId)
          .toList(growable: false),
      'refunds': refundsByOrder(orderId),
      'refundedTotal': refundsByOrder(
        orderId,
      ).fold<double>(0, (sum, row) => sum + (row['amount'] as num).toDouble()),
      'paidAt': order['closedAt'],
      'changeTotal': payments
          .where((row) => row['orderId'] == orderId)
          .fold<double>(
            0,
            (sum, row) => sum + (row['change'] as num).toDouble(),
          ),
    };
  }
}
