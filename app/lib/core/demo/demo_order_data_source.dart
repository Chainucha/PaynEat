// Copyright 2026 Suruch Chakrapeesirisuk
// SPDX-License-Identifier: Apache-2.0

part of 'demo_data_sources.dart';

class DemoOrderDataSource implements OrderRemoteDataSource {
  DemoOrderDataSource(this._store, this._auth);

  final DemoStore _store;
  final DemoAuthDataSource _auth;

  @override
  Future<({List<OrderModel> orders, int total})> getOrders({
    String? status,
    bool? activeOnly,
    String? dateFrom,
    String? dateTo,
    int? customerId,
    int page = 1,
    int limit = 30,
  }) => _delayed(() {
    final rows = _store.orderList(
      status: status,
      activeOnly: activeOnly,
      dateFrom: dateFrom,
      customerId: customerId,
    );
    return (
      orders: rows.take(limit).map(OrderModel.fromJson).toList(growable: false),
      total: rows.length,
    );
  });

  @override
  Future<OrderModel> getOrder(int id) =>
      _delayed(() => OrderModel.fromJson(_store.findOrder(id)));

  @override
  Future<OrderModel?> getOpenOrderByTable(int tableId) => _delayed(() {
    final order = _store.openOrderByTable(tableId);
    return order == null ? null : OrderModel.fromJson(order);
  });

  @override
  Future<OrderModel> createOrder({
    required String type,
    int? tableId,
    int? customerId,
    int guestCount = 1,
    String? note,
    required List<OrderItemPayload> items,
  }) => _delayed(
    () => OrderModel.fromJson(
      _store.atomically(
        () => _store.createOrder(
          type: type,
          tableId: tableId,
          customerId: customerId,
          guestCount: guestCount,
          waiterId: _auth.currentUserId,
          items: items.map((item) => item.toJson()).toList(growable: false),
        ),
      ),
    ),
  );

  @override
  Future<OrderModel> addItems(int orderId, List<OrderItemPayload> items) =>
      _delayed(
        () => OrderModel.fromJson(
          _store.atomically(
            () => _store.addItems(
              orderId,
              items.map((item) => item.toJson()).toList(growable: false),
              actorId: _auth.currentUserId,
            ),
          ),
        ),
      );

  @override
  Future<OrderModel> updateItem(
    int orderId,
    int itemId, {
    int? quantity,
    String? note,
  }) => _delayed(
    () => OrderModel.fromJson(
      _store.atomically(
        () => _store.updateItem(
          orderId,
          itemId,
          quantity: quantity,
          note: note,
          actorId: _auth.currentUserId,
        ),
      ),
    ),
  );

  @override
  Future<OrderModel> removeItem(int orderId, int itemId) => _delayed(
    () => OrderModel.fromJson(
      _store.atomically(
        () => _store.removeItem(orderId, itemId, actorId: _auth.currentUserId),
      ),
    ),
  );

  @override
  Future<OrderModel> updateItemStatus(int orderId, int itemId, String status) =>
      _delayed(
        () => OrderModel.fromJson(
          _store.atomically(
            () => _store.updateItemStatus(
              orderId,
              itemId,
              status,
              actorId: _auth.currentUserId,
            ),
          ),
        ),
      );

  @override
  Future<OrderModel> sendToKitchen(int orderId) =>
      _delayed(() => OrderModel.fromJson(_store.sendToKitchen(orderId)));

  @override
  Future<OrderModel> applyDiscount(int orderId, String type, double value) =>
      _delayed(
        () => OrderModel.fromJson(
          _store.atomically(
            () => _store.applyDiscount(
              orderId,
              type,
              value,
              actorId: _auth.currentUserId,
            ),
          ),
        ),
      );

  @override
  Future<OrderModel> cancelOrder(int orderId, String reason) => _delayed(
    () => OrderModel.fromJson(
      _store.atomically(
        () => _store.cancelOrder(orderId, reason, actorId: _auth.currentUserId),
      ),
    ),
  );

  @override
  Future<OrderModel> moveTable(int orderId, int tableId) => _delayed(
    () => OrderModel.fromJson(
      _store.moveOrderTable(orderId, tableId, actorId: _auth.currentUserId),
    ),
  );

  @override
  Future<OrderModel> mergeOrders(int targetOrderId, int sourceOrderId) =>
      _delayed(
        () => OrderModel.fromJson(
          _store.atomically(
            () => _store.mergeOrders(
              targetOrderId,
              sourceOrderId,
              actorId: _auth.currentUserId,
            ),
          ),
        ),
      );

  @override
  Future<List<OrderItemModel>> getKitchenQueue({List<String>? statuses}) =>
      _delayed(
        () => _store
            .kitchenQueue(
              statuses ??
                  const [
                    OrderItemStatus.pending,
                    OrderItemStatus.cooking,
                    OrderItemStatus.ready,
                  ],
            )
            .map(OrderItemModel.fromJson)
            .toList(growable: false),
      );

  @override
  Future<OrderModel> redeemPromotionCode(int orderId, String code) => _delayed(
    () => OrderModel.fromJson(
      _store.atomically(() => _store.redeemPromotionCode(orderId, code)),
    ),
  );

  @override
  Future<OrderModel> removePromotion(int orderId) => _delayed(
    () => OrderModel.fromJson(
      _store.atomically(() => _store.removePromotion(orderId)),
    ),
  );

  @override
  Future<List<EligiblePromotionModel>> getEligiblePromotions(int orderId) =>
      _delayed(
        () => _store
            .eligiblePromotions(orderId)
            .map(EligiblePromotionModel.fromJson)
            .toList(growable: false),
      );
}
