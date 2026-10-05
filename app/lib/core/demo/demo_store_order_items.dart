// Copyright 2026 Suruch Chakrapeesirisuk
// SPDX-License-Identifier: Apache-2.0

part of 'demo_store.dart';

// ------------------------------------------------------ order items -----
extension DemoStoreOrderItems on DemoStore {
  Map<String, dynamic> addItems(
    int orderId,
    List<Map<String, dynamic>> items, {
    int? actorId,
  }) {
    final order = findOrder(orderId);
    _assertMutable(order);
    final before = (order['items'] as List).length;
    _appendItems(order, items);
    final added = (order['items'] as List).cast<Map<String, dynamic>>().sublist(
      before,
    );

    // mirror ของ order.service.js#addItems — ดู docs/tickets/13-order-audit-trail.md
    _logAudit(
      actorId: actorId,
      action: 'order.item.add',
      summaryArgs: {
        'code': order['code'],
        'count': added.length,
        'items': [
          for (final row in added)
            {
              'name': row['name'],
              'quantity': row['quantity'],
              'weightGrams': row['weightGrams'],
            },
        ],
      },
      entityType: 'order',
      entityId: order['id'] as int,
      summary:
          'เพิ่ม ${added.length} รายการเข้าออเดอร์ #${order['code']}: '
          '${added.map(_describeLine).join(', ')}',
      metadata: {
        'orderCode': order['code'],
        'items': added
            .map(
              (row) => {
                'name': row['name'],
                'quantity': row['quantity'],
                if (row['weightGrams'] != null)
                  'weightGrams': row['weightGrams'],
              },
            )
            .toList(),
      },
    );

    return _recalculate(order);
  }

  void _appendItems(
    Map<String, dynamic> order,
    List<Map<String, dynamic>> inputs,
  ) {
    final items = order['items'] as List;
    // ถ้าออเดอร์ถูกส่งครัวไปแล้ว รายการที่เพิ่งสั่งเพิ่มต้องตัดสต๊อกทันที
    // (ไม่ต้องรอกดส่งครัวซ้ำ) — ดู docs/tickets/06-inventory-stock.md
    final alreadySentToKitchen = order['status'] != OrderStatus.open;

    for (final input in inputs) {
      final menu = menuItem(input['menuItemId'] as int);
      if (menu['isAvailable'] != true) {
        throw ApiException(
          message: 'order_error_menu_item_unavailable'.trParams({
            'name': menu['name'] as String,
          }),
          statusCode: 409,
        );
      }

      final selected = <Map<String, dynamic>>[];
      for (final optionId in (input['optionIds'] as List? ?? const [])) {
        for (final group in (menu['optionGroups'] as List)) {
          for (final option in (group['options'] as List)) {
            if (option['id'] == optionId) {
              selected.add({
                'id': option['id'],
                // ประทับชื่อตามภาษาที่คนกดสั่งเห็นอยู่ตอนนั้น ไม่ใช่ภาษาไทยเสมอ
                // (ตั๋วครัวและใบเสร็จต้องตรงกับที่พนักงานเห็นบนจอตอนสั่ง)
                'groupName': DemoNames.of(group.cast<String, dynamic>()),
                'name': DemoNames.of(option.cast<String, dynamic>()),
                'priceDelta': option['priceDelta'],
              });
            }
          }
        }
      }

      final optionsPrice = selected.fold<double>(
        0,
        (sum, option) => sum + (option['priceDelta'] as num).toDouble(),
      );
      final unitPrice = (menu['price'] as num).toDouble();
      final quantity = input['quantity'] as int;

      // ขายตามน้ำหนัก — mirror ของ order.service.js#buildItemRow (docs/tickets/18-sell-by-weight.md)
      final soldByWeight = menu['soldByWeight'] == true;
      final weightGrams = (input['weightGrams'] as num?)?.toInt();
      if (soldByWeight && weightGrams == null) {
        throw ApiException(
          message: 'order_error_weight_required'.trParams({
            'name': DemoNames.of(menu),
          }),
          statusCode: 400,
        );
      }
      if (!soldByWeight && weightGrams != null) {
        throw ApiException(
          message: 'order_error_not_sold_by_weight'.trParams({
            'name': DemoNames.of(menu),
          }),
          statusCode: 400,
        );
      }
      if (soldByWeight && quantity != 1) {
        throw ApiException(
          message: 'order_error_weighed_one_per_line'.tr,
          statusCode: 400,
        );
      }
      if (weightGrams != null && (weightGrams < 1 || weightGrams > 99999)) {
        throw ApiException(message: 'order_weigh_invalid'.tr, statusCode: 422);
      }

      final station = resolveStationFor(menu);
      final item = {
        'id': _nextId(),
        'orderId': order['id'],
        'menuItemId': menu['id'],
        'categoryId': menu['categoryId'],
        // ประทับสถานีครัวตอนบันทึก (ticket 34) ย้ายเมนูไปสถานีอื่นทีหลังจึงไม่ดึงตั๋วข้ามจอ
        'stationId': station['id'],
        'stationCode': station['code'],
        'stationName': station['name'],
        'name': DemoNames.of(menu),
        'unitPrice': unitPrice,
        'quantity': quantity,
        'weightGrams': weightGrams,
        'options': selected,
        'optionsPrice': optionsPrice,
        'lineTotal': weightGrams == null
            ? (unitPrice + optionsPrice) * quantity
            : _weighedLineTotal(unitPrice, selected, weightGrams),
        'note': input['note'],
        'status': OrderItemStatus.pending,
        'stockDeducted': false,
        'isPaid': false,
        'createdAt': _now(),
        'updatedAt': _now(),
        'orderCode': order['code'],
        'tableName': order['tableName'],
        'orderType': order['type'],
      };
      items.add(item);
      if (alreadySentToKitchen) {
        deductForOrderItem(item);
        item['stockDeducted'] = true;
      }
    }
  }

  Map<String, dynamic> updateItem(
    int orderId,
    int itemId, {
    int? quantity,
    String? note,
    int? actorId,
  }) {
    final order = findOrder(orderId);
    _assertMutable(order);
    final item = _findItem(order, itemId);

    if (_kitchenStarted(item)) {
      throw ApiException(
        message: 'order_error_item_locked_edit'.tr,
        statusCode: 409,
      );
    }

    if (quantity != null && item['weightGrams'] != null && quantity != 1) {
      throw ApiException(
        message: 'order_error_weighed_quantity_locked'.tr,
        statusCode: 400,
      );
    }

    if (quantity != null) {
      final oldQuantity = item['quantity'] as int;
      item['quantity'] = quantity;
      item['lineTotal'] =
          ((item['unitPrice'] as num) + (item['optionsPrice'] as num))
              .toDouble() *
          quantity;
      if (item['stockDeducted'] == true) {
        adjustIngredientsForQuantityChange(item, oldQuantity, quantity);
      }
      if (quantity != oldQuantity) {
        // mirror ของ order.service.js#updateItem — ดู docs/tickets/13-order-audit-trail.md
        _logAudit(
          actorId: actorId,
          action: 'order.item.edit',
          summaryArgs: {
            'code': order['code'],
            'name': item['name'],
            'from': oldQuantity,
            'to': quantity,
          },
          entityType: 'order_item',
          entityId: itemId,
          summary:
              'แก้ไขจำนวน "${item['name']}" ในออเดอร์ #${order['code']} '
              'จาก $oldQuantity เป็น $quantity',
          metadata: {
            'orderId': orderId,
            'orderCode': order['code'],
            'previousQuantity': oldQuantity,
            'newQuantity': quantity,
          },
        );
      }
    }
    if (note != null) item['note'] = note;

    return _recalculate(order);
  }

  Map<String, dynamic> removeItem(int orderId, int itemId, {int? actorId}) {
    final order = findOrder(orderId);
    _assertMutable(order);
    final item = _findItem(order, itemId);

    if (_kitchenStarted(item)) {
      throw ApiException(
        message: 'order_error_item_locked_remove'.tr,
        statusCode: 409,
      );
    }

    if (item['stockDeducted'] == true) {
      restoreForOrderItem(item);
    }

    (order['items'] as List).removeWhere((row) => row['id'] == itemId);

    // mirror ของ order.service.js#removeItem — ดู docs/tickets/13-order-audit-trail.md
    _logAudit(
      actorId: actorId,
      action: 'order.item.remove',
      summaryArgs: {
        'code': order['code'],
        'name': item['name'],
        'quantity': item['quantity'],
        'weightGrams': item['weightGrams'],
      },
      entityType: 'order',
      entityId: orderId,
      summary:
          'ลบรายการ "${_describeLine(item)}" '
          'ออกจากออเดอร์ #${order['code']}',
      metadata: {
        'orderCode': order['code'],
        'itemName': item['name'],
        'quantity': item['quantity'],
        if (item['weightGrams'] != null) 'weightGrams': item['weightGrams'],
      },
    );

    return _recalculate(order);
  }

  Map<String, dynamic> updateItemStatus(
    int orderId,
    int itemId,
    String status, {
    int? actorId,
  }) {
    final order = findOrder(orderId);
    final item = _findItem(order, itemId);
    final previousItemStatus = item['status'] as String;

    // บิลที่ปิดแล้วและรายการที่รับเงินไปแล้วยกเลิกไม่ได้ — mirror ของ order.service.js#updateItemStatus (T04 #95)
    if (status == OrderItemStatus.cancelled) {
      _assertMutable(order);
      if (item['isPaid'] == true) {
        throw ApiException(
          message: 'order_error_item_paid_cannot_cancel'.tr,
          statusCode: 409,
        );
      }
    }

    const transitions = {
      OrderItemStatus.pending: [
        OrderItemStatus.cooking,
        OrderItemStatus.ready,
        OrderItemStatus.cancelled,
      ],
      // ย้อนได้หนึ่งขั้นสำหรับกดผิดในจอครัว — mirror ของ ITEM_TRANSITIONS ใน backend (#64)
      OrderItemStatus.cooking: [
        OrderItemStatus.pending,
        OrderItemStatus.ready,
        OrderItemStatus.cancelled,
      ],
      OrderItemStatus.ready: [
        OrderItemStatus.cooking,
        OrderItemStatus.served,
        OrderItemStatus.cancelled,
      ],
      OrderItemStatus.served: <String>[],
      OrderItemStatus.cancelled: <String>[],
    };

    final allowed = transitions[item['status']] ?? const <String>[];
    if (!allowed.contains(status)) {
      throw ApiException(
        message: 'order_error_invalid_status_transition'.trParams({
          'from': item['status'] as String,
          'to': status,
        }),
        statusCode: 409,
      );
    }

    // void รายการที่ครัวเคยลงมือทำแล้ว (นับรวมรายการที่ถูกเลิกทำถอยกลับไปรอทำ) ต้องเป็นผู้จัดการขึ้นไป และ log ทุกครั้ง
    // — mirror ของ order.service.js#updateItemStatus (T05 #104, docs/DECISIONS.md #86)
    final isRiskyVoid =
        status == OrderItemStatus.cancelled && _kitchenStarted(item);
    if (isRiskyVoid && !_isManagement(actorId)) {
      throw ApiException(
        message: 'order_error_void_needs_manager'.tr,
        statusCode: 403,
      );
    }
    // รายการใน seed ไม่มีค่านี้ ถือว่าเคยถึงสถานะปัจจุบัน เหมือน migration 0003 ที่เติมค่าให้รายการเดิม
    final previousReached =
        item['kitchenReached'] as String? ??
        _furthestKitchenStage(null, previousItemStatus);

    if (status == OrderItemStatus.cancelled && item['stockDeducted'] == true) {
      restoreForOrderItem(item);
    }

    item['status'] = status;
    item['kitchenReached'] = _furthestKitchenStage(previousReached, status);
    item['updatedAt'] = _now();

    if (isRiskyVoid) {
      // ถ้าครัวเคยทำไปไกลกว่าสถานะตอนยกเลิก (ถูกเลิกทำถอยกลับมา) ให้ผู้ตรวจเห็นขั้นที่เคยไปถึงด้วย
      final reached = previousReached ?? previousItemStatus;
      final undone = reached != previousItemStatus;
      _logAudit(
        actorId: actorId,
        action: 'order_item.void',
        summaryArgs: {
          'code': order['code'],
          'name': item['name'],
          'status': previousItemStatus,
          if (undone) 'reached': reached,
        },
        entityType: 'order_item',
        entityId: itemId,
        summary: undone
            ? 'ยกเลิกรายการ "${item['name']}" ในออเดอร์ #${order['code']} '
                  '(สถานะก่อนยกเลิก: $previousItemStatus, ครัวเคยทำถึง: $reached)'
            : 'ยกเลิกรายการ "${item['name']}" ในออเดอร์ #${order['code']} '
                  '(สถานะก่อนยกเลิก: $previousItemStatus)',
        metadata: {
          'orderId': orderId,
          'orderCode': order['code'],
          'previousStatus': previousItemStatus,
          'kitchenReached': reached,
        },
      );
    }

    final active = (order['items'] as List)
        .where((row) => row['status'] != OrderItemStatus.cancelled)
        .toList();
    if (active.isNotEmpty &&
        active.every((row) => row['status'] == OrderItemStatus.served) &&
        order['status'] == OrderStatus.inKitchen) {
      order['status'] = OrderStatus.served;
    }

    return _recalculate(order);
  }

  /// ขั้นที่ครัวทำรายการไปถึง เรียงจากน้อยไปมาก — `kitchenReached` เก็บขั้นที่ไกลที่สุด ไม่ถอยลงแม้เลิกทำ
  /// (mirror ของ KITCHEN_STAGES ใน order.service.js, T05 #104)
  static const _kitchenStages = [
    OrderItemStatus.cooking,
    OrderItemStatus.ready,
    OrderItemStatus.served,
  ];

  String? _furthestKitchenStage(String? reached, String status) =>
      _kitchenStages.indexOf(status) > _kitchenStages.indexOf(reached ?? '')
      ? status
      : reached;

  /// ครัวเคยลงมือทำรายการนี้แล้วหรือยัง — นับรวมรายการที่ถูกเลิกทำถอยกลับไปรอทำด้วย
  bool _kitchenStarted(Map<String, dynamic> item) =>
      item['status'] != OrderItemStatus.pending ||
      item['kitchenReached'] != null;

  /// ไม่รู้ผู้ทำ (เรียกจากโค้ดภายใน) ถือว่าผ่าน เหมือนเส้นทางอื่นของ demo store ที่ไม่ได้ตรวจสิทธิ์ซ้ำ
  bool _isManagement(int? actorId) {
    if (actorId == null) return true;
    final role = users.firstWhereOrNull(
      (user) => user['id'] == actorId,
    )?['role'];
    return role == 'admin' || role == 'manager';
  }

  Map<String, dynamic> _findItem(Map<String, dynamic> order, int itemId) =>
      (order['items'] as List).cast<Map<String, dynamic>>().firstWhere(
        (row) => row['id'] == itemId,
        orElse: () => throw ApiException(
          message: 'order_error_item_not_found'.tr,
          statusCode: 404,
        ),
      );

  /// "ข้าวผัด x2" หรือ "หมูสามชั้น 0.485 กก." — mirror ของ core/weight.js#describeLine
  String _describeLine(Map<String, dynamic> row) {
    final grams = row['weightGrams'] as int?;
    return grams == null
        ? '${row['name']} x${row['quantity']}'
        : '${row['name']} ${(grams / 1000).toStringAsFixed(3)} กก.';
  }

  /// ราคาบรรทัดชั่งน้ำหนัก — คิดเป็นสตางค์เต็มก่อนแล้วค่อยปัด เหมือน CartLine.lineTotal และ
  /// order.calculator.js#lineTotalFor (ดู docs/DECISIONS.md #48)
  double _weighedLineTotal(
    double unitPrice,
    List<Map<String, dynamic>> options,
    int weightGrams,
  ) {
    final perKgSatang =
        (unitPrice * 100).round() +
        options.fold<int>(
          0,
          (sum, option) =>
              sum + ((option['priceDelta'] as num).toDouble() * 100).round(),
        );
    return (perKgSatang * weightGrams / 1000).round() / 100;
  }
}
