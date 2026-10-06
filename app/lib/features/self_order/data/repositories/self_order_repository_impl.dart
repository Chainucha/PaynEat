// Copyright 2026 Suruch Chakrapeesirisuk
// SPDX-License-Identifier: Apache-2.0

import '../../../../core/errors/failure_mapper.dart';
import '../../../../core/usecases/result.dart';
import '../../../menu/domain/entities/category.dart';
import '../../../menu/domain/entities/menu_item.dart';
import '../../../order/domain/entities/order.dart';
import '../../../order/domain/entities/order_item_payload.dart';
import '../../domain/entities/self_order_table.dart';
import '../../domain/repositories/self_order_repository.dart';
import '../datasources/self_order_remote_data_source.dart';

class SelfOrderRepositoryImpl implements SelfOrderRepository {
  const SelfOrderRepositoryImpl(this._remote);

  final SelfOrderRemoteDataSource _remote;

  @override
  Future<Result<({SelfOrderTable table, Order? order})>> getTable(
    String qrToken,
  ) => guard(() async {
    final result = await _remote.getTable(qrToken);
    return (
      table: result.table as SelfOrderTable,
      order: result.order as Order?,
    );
  });

  @override
  Future<Result<SelfOrderMenu>> getMenu(String qrToken) => guard(() async {
    final result = await _remote.getMenu(qrToken);
    return (
      categories: result.categories.cast<Category>(),
      items: result.items.cast<MenuItem>(),
      staffOnlyCount: result.staffOnlyCount,
      maxQuantityPerLine: result.maxQuantityPerLine,
    );
  });

  @override
  Future<Result<Order>> addItems(
    String qrToken,
    List<OrderItemPayload> items,
  ) => guard(() => _remote.addItems(qrToken, items));
}
