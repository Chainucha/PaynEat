// Copyright 2026 Suruch Chakrapeesirisuk
// SPDX-License-Identifier: Apache-2.0

import '../../../../core/network/api_client.dart';
import '../../../../core/network/api_endpoints.dart';
import '../../../menu/data/models/category_model.dart';
import '../../../menu/data/models/menu_item_model.dart';
import '../../../order/data/models/order_model.dart';
import '../../../order/domain/entities/order_item_payload.dart';
import '../../domain/self_order_limits.dart';
import '../models/self_order_table_model.dart';

/// คุยกับ endpoint สาธารณะ `/public/tables/:qrToken/*` (ดู docs/tickets/17-qr-self-order.md) —
/// ไม่แนบ Authorization header เลย เพราะไม่มี session ให้แนบ (ApiClient จะแนบให้อัตโนมัติถ้ามี
/// token ค้างอยู่ในเครื่องจากการ login ก่อนหน้า แต่ backend ฝั่งนี้ไม่สนใจ header นี้อยู่แล้ว)
/// เมนูฝั่งลูกค้าระดับ model — คู่กับ [SelfOrderMenu] ในชั้น domain
typedef SelfOrderMenuModel = ({
  List<CategoryModel> categories,
  List<MenuItemModel> items,
  int staffOnlyCount,
  int maxQuantityPerLine,
});

abstract class SelfOrderRemoteDataSource {
  Future<({SelfOrderTableModel table, OrderModel? order})> getTable(
    String qrToken,
  );

  Future<SelfOrderMenuModel> getMenu(String qrToken);

  Future<OrderModel> addItems(String qrToken, List<OrderItemPayload> items);
}

class SelfOrderRemoteDataSourceImpl implements SelfOrderRemoteDataSource {
  const SelfOrderRemoteDataSourceImpl(this._client);

  final ApiClient _client;

  @override
  Future<({SelfOrderTableModel table, OrderModel? order})> getTable(
    String qrToken,
  ) async {
    final result = await _client.get(ApiEndpoints.publicTable(qrToken));
    final data = result.asMap;
    final branchName = data['branchName'] as String?;
    final orderJson = data['order'] as Map<String, dynamic>?;
    return (
      table: SelfOrderTableModel.fromJson(
        data['table'] as Map<String, dynamic>? ?? const {},
        branchName: branchName,
      ),
      order: orderJson == null ? null : OrderModel.fromJson(orderJson),
    );
  }

  @override
  Future<SelfOrderMenuModel> getMenu(String qrToken) async {
    final result = await _client.get(ApiEndpoints.publicTableMenu(qrToken));
    final data = result.asMap;
    final categories = (data['categories'] as List? ?? const [])
        .whereType<Map<String, dynamic>>()
        .map(CategoryModel.fromJson)
        .toList(growable: false);
    final items = (data['items'] as List? ?? const [])
        .whereType<Map<String, dynamic>>()
        .map(MenuItemModel.fromJson)
        .toList(growable: false);
    return (
      categories: categories,
      items: items,
      // เมนูชั่งน้ำหนักที่ซ่อนจากลูกค้า — หน้า QR บอกให้สั่งกับพนักงาน (DECISIONS #64)
      staffOnlyCount: (data['staffOnlyCount'] as num?)?.toInt() ?? 0,
      // เพดานต่อรายการที่ร้านตั้งไว้ (DECISIONS #99) — ปุ่มเพิ่มจำนวนในหน้า QR หยุดที่ค่านี้
      maxQuantityPerLine:
          ((data['limits'] as Map<String, dynamic>?)?['maxQuantityPerLine']
                  as num?)
              ?.toInt() ??
          defaultSelfOrderMaxQuantityPerLine,
    );
  }

  @override
  Future<OrderModel> addItems(
    String qrToken,
    List<OrderItemPayload> items,
  ) async {
    final result = await _client.post(
      ApiEndpoints.publicTableItems(qrToken),
      body: {
        'items': items.map((item) => item.toJson()).toList(growable: false),
      },
    );
    return OrderModel.fromJson(result.asMap);
  }
}
