// Copyright 2026 Suruch Chakrapeesirisuk
// SPDX-License-Identifier: Apache-2.0

part of 'demo_store.dart';

// ----------------------------------------------------------- orders -----
extension DemoStoreOrders on DemoStore {
  Map<String, dynamic> findOrder(int id) => orders.firstWhere(
    (row) => row['id'] == id,
    orElse: () => throw ApiException(
      message: 'order_error_not_found'.tr,
      statusCode: 404,
    ),
  );

  List<Map<String, dynamic>> orderList({
    String? status,
    bool? activeOnly,
    String? dateFrom,
    int? customerId,
  }) {
    final result = orders.where((order) {
      if (status != null && order['status'] != status) return false;
      if (activeOnly == true &&
          !OrderStatus.isActive(order['status'] as String)) {
        return false;
      }
      if (customerId != null && order['customerId'] != customerId) {
        return false;
      }
      return true;
    }).toList()..sort((a, b) => (b['id'] as int).compareTo(a['id'] as int));
    return result;
  }

  Map<String, dynamic>? openOrderByTable(int tableId) {
    for (final order in orders) {
      if (order['tableId'] == tableId &&
          OrderStatus.isActive(order['status'] as String)) {
        return order;
      }
    }
    return null;
  }

  /// เลขคิวรับอาหาร รันต่อวันเฉพาะออเดอร์ type=takeaway — mirror ของ
  /// order.repository.js#nextQueueNumber (ดู docs/tickets/10-takeaway-delivery-flow.md)
  int _nextQueueNumber(DateTime now) {
    final sameDayTakeawayCount = orders.where((order) {
      if (order['type'] != OrderType.takeaway) return false;
      final createdAt = DateTime.tryParse(order['createdAt'] as String? ?? '');
      if (createdAt == null) return false;
      return createdAt.year == now.year &&
          createdAt.month == now.month &&
          createdAt.day == now.day;
    }).length;
    return sameDayTakeawayCount + 1;
  }

  Map<String, dynamic> createOrder({
    required String type,
    int? tableId,
    int? customerId,
    required int guestCount,
    required List<Map<String, dynamic>> items,
    int? waiterId,
  }) {
    if (tableId != null && openOrderByTable(tableId) != null) {
      throw ApiException(
        message: 'order_error_table_has_open_order'.tr,
        statusCode: 409,
      );
    }
    // ผูกลูกค้าแบบ optional (ดู docs/tickets/09-customer-loyalty.md)
    final customer = customerId == null ? null : findCustomer(customerId);

    final table = tableId == null ? null : _findTable(tableId);
    final now = AppClock.now();
    final code =
        'ORD-${now.year}'
        '${now.month.toString().padLeft(2, '0')}'
        '${now.day.toString().padLeft(2, '0')}'
        '-${(++_orderSequence).toString().padLeft(4, '0')}';

    final order = <String, dynamic>{
      'id': _nextId(),
      'code': code,
      'type': type,
      'tableId': tableId,
      'tableName': table?['name'],
      'tableZone': table == null ? null : DemoNames.of(table, key: 'zone'),
      'queueNumber': type == OrderType.takeaway ? _nextQueueNumber(now) : null,
      'waiterId': waiterId,
      'waiterName': waiterId == null ? null : DemoNames.of(_findUser(waiterId)),
      'customerId': customerId,
      'customerName': customer?['name'],
      'customerPhone': customer?['phone'],
      'pointsEarned': 0,
      'guestCount': guestCount,
      'status': OrderStatus.open,
      'note': null,
      'subtotal': 0.0,
      'discountType': DiscountType.none,
      'discountValue': 0.0,
      'discountAmount': 0.0,
      'promotionId': null,
      'promotionName': null,
      'promotionCode': null,
      'promotionDiscountAmount': 0.0,
      'serviceCharge': 0.0,
      'vat': 0.0,
      'total': 0.0,
      'cancelledReason': null,
      'createdAt': _now(),
      'updatedAt': _now(),
      'closedAt': null,
      'items': <Map<String, dynamic>>[],
    };

    orders.add(order);
    _appendItems(order, items);
    if (table != null) table['status'] = TableStatus.occupied;

    // mirror ของ order.service.js#create — log ทุกครั้งที่เปิดออเดอร์ใหม่ ดู
    // docs/tickets/13-order-audit-trail.md
    _logAudit(
      actorId: waiterId,
      action: 'order.create',
      summaryArgs: {'code': order['code'], 'count': items.length},
      entityType: 'order',
      entityId: order['id'] as int,
      summary: 'เปิดออเดอร์ใหม่ #${order['code']} (${items.length} รายการ)',
      metadata: {
        'orderCode': order['code'],
        'type': type,
        'tableId': tableId,
        'itemCount': items.length,
      },
    );

    return _recalculate(order);
  }

  Map<String, dynamic> sendToKitchen(int orderId) {
    final order = findOrder(orderId);
    _assertMutable(order);

    final active = (order['items'] as List)
        .where((row) => row['status'] != OrderItemStatus.cancelled)
        .cast<Map<String, dynamic>>()
        .toList();
    if (active.isEmpty) {
      throw ApiException(message: 'order_error_no_items'.tr, statusCode: 400);
    }

    if (order['status'] == OrderStatus.open) {
      order['status'] = OrderStatus.inKitchen;
    }

    // ตัดสต๊อกให้ทุกรายการที่ยังไม่เคยตัด (idempotent — กดส่งครัวซ้ำไม่ตัดซ้ำ)
    for (final item in active) {
      if (item['stockDeducted'] != true) {
        deductForOrderItem(item);
        item['stockDeducted'] = true;
      }
    }

    return _recalculate(order);
  }

  Map<String, dynamic> applyDiscount(
    int orderId,
    String type,
    double value, {
    int? actorId,
  }) {
    final order = findOrder(orderId);
    _assertMutable(order);
    final previousType = order['discountType'];
    final previousValue = order['discountValue'];
    order['discountType'] = type;
    order['discountValue'] = type == DiscountType.none ? 0.0 : value;

    // mirror ของ order.service.js#applyDiscount — log ทุกครั้งที่แก้ส่วนลด
    // รวมถึงตอนยกเลิกส่วนลด (type == none) ดู docs/tickets/08-audit-log.md
    _logAudit(
      actorId: actorId,
      action: 'order.discount',
      summaryArgs: {'code': order['code'], 'type': type, 'value': value},
      entityType: 'order',
      entityId: order['id'] as int,
      summary: type == DiscountType.none
          ? 'ยกเลิกส่วนลดออเดอร์ #${order['code']}'
          : 'ให้ส่วนลดออเดอร์ #${order['code']} เป็น ${_jsNumber(value)}'
                '${type == DiscountType.percent ? '%' : ' บาท'}',
      metadata: {
        'orderCode': order['code'],
        'previousType': previousType,
        'previousValue': previousValue,
        'newType': type,
        'newValue': order['discountValue'],
      },
    );

    return _recalculate(order);
  }

  /// ย้ายออเดอร์ (ที่ยังไม่ปิดบิล) ไปโต๊ะอื่น เช่น ลูกค้าขอย้ายที่นั่ง
  Map<String, dynamic> moveOrderTable(
    int orderId,
    int tableId, {
    int? actorId,
  }) {
    final order = findOrder(orderId);
    _assertMutable(order);
    final oldTableId = order['tableId'];
    if (oldTableId == null) {
      throw ApiException(message: 'order_error_no_table'.tr, statusCode: 400);
    }
    if (oldTableId == tableId) {
      throw ApiException(message: 'order_error_same_table'.tr, statusCode: 400);
    }
    if (openOrderByTable(tableId) != null) {
      throw ApiException(
        message: 'order_error_destination_table_occupied'.tr,
        statusCode: 409,
      );
    }

    final oldTableName = order['tableName'];
    final table = _findTable(tableId);
    order['tableId'] = tableId;
    order['tableName'] = table['name'];
    order['tableZone'] = DemoNames.of(table, key: 'zone');
    table['status'] = TableStatus.occupied;
    _findTable(oldTableId as int)['status'] = TableStatus.available;
    order['updatedAt'] = _now();

    for (final item in (order['items'] as List).cast<Map<String, dynamic>>()) {
      item['tableName'] = table['name'];
    }

    // mirror ของ order.service.js#moveTable — ดู docs/tickets/13-order-audit-trail.md
    _logAudit(
      actorId: actorId,
      action: 'order.move_table',
      summaryArgs: {
        'code': order['code'],
        'fromTable': oldTableName,
        'toTable': table['name'],
      },
      entityType: 'order',
      entityId: orderId,
      summary:
          'ย้ายออเดอร์ #${order['code']} จากโต๊ะ "$oldTableName" '
          'ไปโต๊ะ "${table['name']}"',
      metadata: {
        'orderCode': order['code'],
        'fromTableId': oldTableId,
        'toTableId': tableId,
      },
    );

    return order;
  }

  /// รวมออเดอร์ต้นทางเข้ากับออเดอร์ปลายทาง — ใช้ตอนลูกค้าขอรวมโต๊ะ/รวมบิล
  Map<String, dynamic> mergeOrders(
    int targetOrderId,
    int sourceOrderId, {
    int? actorId,
  }) {
    if (targetOrderId == sourceOrderId) {
      throw ApiException(
        message: 'order_error_merge_same_order'.tr,
        statusCode: 400,
      );
    }
    final target = findOrder(targetOrderId);
    final source = findOrder(sourceOrderId);
    _assertMutable(target);
    _assertMutable(source);

    final sourceItems = (source['items'] as List).cast<Map<String, dynamic>>();
    final targetItems = target['items'] as List;
    for (final item in sourceItems) {
      item['orderId'] = target['id'];
      item['orderCode'] = target['code'];
      item['tableName'] = target['tableName'];
      item['orderType'] = target['type'];
      targetItems.add(item);
    }
    sourceItems.clear();

    source['status'] = OrderStatus.cancelled;
    source['cancelledReason'] = 'order_merged_into_reason'.trParams({
      'code': target['code'] as String,
    });
    source['closedAt'] = _now();
    _freeTable(source);

    // mirror ของ order.service.js#mergeOrders — ดู docs/tickets/13-order-audit-trail.md
    _logAudit(
      actorId: actorId,
      action: 'order.merge',
      summaryArgs: {'source': source['code'], 'target': target['code']},
      entityType: 'order',
      entityId: target['id'] as int,
      summary: 'รวมบิล #${source['code']} เข้ากับ #${target['code']}',
      metadata: {
        'targetOrderCode': target['code'],
        'sourceOrderCode': source['code'],
      },
    );

    return _recalculate(target);
  }

  Map<String, dynamic> cancelOrder(int orderId, String reason, {int? actorId}) {
    final order = findOrder(orderId);
    if (order['status'] == OrderStatus.paid) {
      throw ApiException(
        message: 'order_error_already_paid_cannot_cancel'.tr,
        statusCode: 409,
      );
    }

    // ยกเลิกทั้งบิล คืนสต๊อกให้ทุกรายการที่เคยตัดไปแล้วและยังไม่ถูกยกเลิก
    // (รวมรายการที่เสิร์ฟไปแล้วด้วย — mirror ของ order.service.js#cancel)
    for (final item in (order['items'] as List).cast<Map<String, dynamic>>()) {
      if (item['status'] != OrderItemStatus.cancelled &&
          item['stockDeducted'] == true) {
        restoreForOrderItem(item);
      }
    }

    for (final item in (order['items'] as List)) {
      if (item['status'] != OrderItemStatus.served) {
        item['status'] = OrderItemStatus.cancelled;
      }
    }
    order['status'] = OrderStatus.cancelled;
    order['cancelledReason'] = reason;
    order['closedAt'] = _now();
    _freeTable(order);

    _logAudit(
      actorId: actorId,
      action: 'order.cancel',
      summaryArgs: {'code': order['code']},
      entityType: 'order',
      entityId: order['id'] as int,
      summary: 'ยกเลิกออเดอร์ #${order['code']}',
      reason: reason,
      metadata: {'orderCode': order['code']},
    );

    return _recalculate(order);
  }

  List<Map<String, dynamic>> kitchenQueue(List<String> statuses) {
    final result = <Map<String, dynamic>>[];
    for (final order in orders) {
      final status = order['status'] as String;
      if (status != OrderStatus.inKitchen && status != OrderStatus.served) {
        continue;
      }
      for (final item
          in (order['items'] as List).cast<Map<String, dynamic>>()) {
        if (statuses.contains(item['status'])) {
          result.add({
            ...item,
            'tableName': order['tableName'],
            'orderCode': order['code'],
          });
        }
      }
    }
    result.sort(
      (a, b) => (a['createdAt'] as String).compareTo(b['createdAt'] as String),
    );
    return result;
  }

  void _assertMutable(Map<String, dynamic> order) {
    if (!OrderStatus.isActive(order['status'] as String)) {
      throw ApiException(
        message: 'order_error_closed_cannot_edit'.tr,
        statusCode: 409,
      );
    }
  }

  void _freeTable(Map<String, dynamic> order) {
    final tableId = order['tableId'];
    if (tableId is int) {
      _findTable(tableId)['status'] = TableStatus.available;
    }
  }

  /// คิดยอดใหม่ทั้งบิลด้วยกฎเดียวกับ backend
  Map<String, dynamic> _recalculate(Map<String, dynamic> order) {
    final items = (order['items'] as List).cast<Map<String, dynamic>>();
    final subtotal = items
        .where((item) => item['status'] != OrderItemStatus.cancelled)
        .fold<double>(
          0,
          (sum, item) => sum + (item['lineTotal'] as num).toDouble(),
        );

    final type = order['discountType'] as String;
    final value = (order['discountValue'] as num).toDouble();
    final promo = _resolvePromotionForOrder(order, items);

    final bill = _calculator.fromSubtotal(
      subtotal,
      discountAmount: type == DiscountType.amount ? value : 0,
      discountPercent: type == DiscountType.percent ? value : 0,
      promotionDiscountAmount: promo['discountAmount'] as double,
    );

    order['subtotal'] = bill.subtotal;
    order['discountAmount'] = bill.discount;
    order['promotionId'] = promo['promotionId'];
    order['promotionName'] = promo['name'];
    order['promotionCode'] = promo['code'];
    order['promotionDiscountAmount'] = bill.promotionDiscount;
    order['serviceCharge'] = bill.serviceCharge;
    order['vat'] = bill.vat;
    order['total'] = bill.total;
    order['updatedAt'] = _now();

    return order;
  }
}
