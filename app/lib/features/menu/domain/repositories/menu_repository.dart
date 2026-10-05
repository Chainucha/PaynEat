// Copyright 2026 Suruch Chakrapeesirisuk
// SPDX-License-Identifier: Apache-2.0

import '../../../../core/usecases/result.dart';
import '../entities/menu_item_payload.dart';
import '../entities/category.dart';
import '../entities/kitchen_station.dart';
import '../entities/menu_item.dart';

abstract class MenuRepository {
  Future<Result<List<Category>>> getCategories({bool activeOnly});
  Future<Result<Category>> createCategory({
    required String name,
    String? nameEn,
    String? icon,
    int? stationId,
  });
  Future<Result<Category>> updateCategory(int id, Map<String, dynamic> changes);
  Future<Result<void>> deleteCategory(int id);

  Future<Result<List<KitchenStation>>> getKitchenStations({bool activeOnly});
  Future<Result<KitchenStation>> saveKitchenStation({
    int? id,
    required String name,
    String? code,
    String? nameEn,
    String? nameKo,
    String? icon,
    bool? isActive,
    bool? isDefault,
  });
  Future<Result<void>> deleteKitchenStation(int id);

  Future<Result<List<MenuItem>>> getMenuItems({
    int? categoryId,
    String? search,
    bool? availableOnly,
  });
  Future<Result<MenuItem>> getMenuItem(int id);
  Future<Result<MenuItem>> createMenuItem(MenuItemPayload payload);
  Future<Result<MenuItem>> updateMenuItem(int id, MenuItemPayload payload);
  Future<Result<MenuItem>> setAvailability(int id, bool isAvailable);
  Future<Result<void>> deleteMenuItem(int id);
}
