// Copyright 2026 Suruch Chakrapeesirisuk
// SPDX-License-Identifier: Apache-2.0

part of 'demo_data_sources.dart';

/// mirror ของ public-order.service.js ฝั่ง backend (ดู docs/tickets/17-qr-self-order.md) — ไม่มี
/// currentUserId/actorId ผูกอยู่เลยตลอดทั้งไฟล์นี้โดยตั้งใจ เพราะลูกค้าไม่ได้ login เหมือนกันทั้งคู่
class DemoSelfOrderDataSource implements SelfOrderRemoteDataSource {
  const DemoSelfOrderDataSource(this._store);

  final DemoStore _store;

  @override
  Future<({SelfOrderTableModel table, OrderModel? order})> getTable(
    String qrToken,
  ) => _delayed(() {
    final table = _store.resolveTableByQrToken(qrToken);
    final order = _store.openOrderByTable(table['id'] as int);
    return (
      // โหมดสาธิตมีสาขาเดียวเสมอ (ดู docs/DECISIONS.md #36) จึงไม่มี branchName ให้โชว์
      table: SelfOrderTableModel.fromJson(table),
      order: order == null ? null : OrderModel.fromJson(order),
    );
  });

  @override
  Future<SelfOrderMenuModel> getMenu(String qrToken) => _delayed(() {
    _store.resolveTableByQrToken(qrToken);
    final available = _store.menuList(availableOnly: true);
    return (
      categories: _store
          .categoryList()
          .map(CategoryModel.fromJson)
          .toList(growable: false),
      // สินค้าขายตามน้ำหนักต้องให้พนักงานชั่ง ลูกค้าสั่งเองไม่ได้ — mirror ของ
      // public-order.service.js#getMenu (docs/tickets/18-sell-by-weight.md)
      items: available
          .where((item) => item['soldByWeight'] != true)
          .map(_store.presentMenuItem)
          .map(MenuItemModel.fromJson)
          .toList(growable: false),
      staffOnlyCount: available
          .where((item) => item['soldByWeight'] == true)
          .length,
      maxQuantityPerLine: defaultSelfOrderMaxQuantityPerLine,
    );
  });

  @override
  Future<OrderModel> addItems(
    String qrToken,
    List<OrderItemPayload> items,
  ) => _delayed(() {
    final table = _store.resolveTableByQrToken(qrToken);
    final tableId = table['id'] as int;
    for (final item in items) {
      final menu = _store.menuItem(item.menuItemId);
      if (menu['soldByWeight'] == true) {
        throw ApiException(
          message: 'self_order_error_weighed_item'.trParams({
            'name': DemoNames.of(menu),
          }),
          statusCode: 409,
        );
      }
    }
    final existing = _store.openOrderByTable(tableId);
    _assertWithinSelfOrderLimits(items, existing);
    final itemsJson = items
        .map((item) => item.toJson())
        .toList(growable: false);

    final order = existing == null
        ? _store.createOrder(
            type: OrderType.dineIn,
            tableId: tableId,
            guestCount: 1,
            items: itemsJson,
          )
        : _store.addItems(existing['id'] as int, itemsJson);
    // mirror ของ public-order.service.js#addItems — ลูกค้ากด "ส่งเข้าครัว" ร่างออเดอร์จึงต้อง
    // เข้าครัวจริง ไม่งั้นครัวไม่เห็น (DECISIONS #46)
    final sent = order['status'] == OrderStatus.open
        ? _store.sendToKitchen(order['id'] as int)
        : order;
    return OrderModel.fromJson(sent);
  });

  /// mirror ของ public-order.service.js#assertWithinSelfOrderLimits (DECISIONS #99) — โหมดสาธิตใช้
  /// ค่าเริ่มต้นของ backend เสมอ เพราะไม่มี env ให้ร้านตั้ง
  void _assertWithinSelfOrderLimits(
    List<OrderItemPayload> items,
    Map<String, dynamic>? existing,
  ) {
    if (items.any(
      (item) => item.quantity > defaultSelfOrderMaxQuantityPerLine,
    )) {
      throw ApiException(
        message: 'self_order_error_line_limit'.trParams({
          'max': '$defaultSelfOrderMaxQuantityPerLine',
        }),
        statusCode: 409,
        code: selfOrderLimitErrorCode,
      );
    }
    final current = ((existing?['items'] as List?) ?? const [])
        .cast<Map<String, dynamic>>()
        .where((row) => row['status'] != OrderItemStatus.cancelled)
        .fold<int>(0, (sum, row) => sum + (row['quantity'] as num).toInt());
    final requested = items.fold<int>(0, (sum, item) => sum + item.quantity);
    if (current + requested > defaultSelfOrderMaxOrderQuantity) {
      throw ApiException(
        message: 'self_order_error_order_limit'.trParams({
          'max': '$defaultSelfOrderMaxOrderQuantity',
          'current': '$current',
        }),
        statusCode: 409,
        code: selfOrderLimitErrorCode,
      );
    }
  }
}
