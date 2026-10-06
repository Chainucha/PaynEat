// Copyright 2026 Suruch Chakrapeesirisuk
// SPDX-License-Identifier: Apache-2.0

import '../../../../core/errors/failure_mapper.dart';
import '../../../../core/usecases/result.dart';
import '../../domain/entities/category.dart';
import '../../domain/entities/kitchen_station.dart';
import '../../domain/entities/menu_item.dart';
import '../../domain/repositories/menu_repository.dart';
import '../datasources/menu_remote_data_source.dart';
import '../models/category_model.dart';
import '../models/kitchen_station_model.dart';
import '../../domain/entities/menu_item_payload.dart';

class MenuRepositoryImpl implements MenuRepository {
  const MenuRepositoryImpl(this._remote);

  final MenuRemoteDataSource _remote;

  @override
  Future<Result<List<Category>>> getCategories({bool activeOnly = false}) =>
      guard(() async => await _remote.getCategories(activeOnly: activeOnly));

  @override
  Future<Result<Category>> createCategory({
    required String name,
    String? nameEn,
    String? icon,
    int? stationId,
  }) => guard(
    () async => await _remote.createCategory({
      ...CategoryModel.toCreateJson(name: name, nameEn: nameEn, icon: icon),
      'stationId': ?stationId,
    }),
  );

  @override
  Future<Result<Category>> updateCategory(
    int id,
    Map<String, dynamic> changes,
  ) => guard(() async => await _remote.updateCategory(id, changes));

  @override
  Future<Result<void>> deleteCategory(int id) =>
      guard(() => _remote.deleteCategory(id));

  @override
  Future<Result<List<KitchenStation>>> getKitchenStations({
    bool activeOnly = false,
  }) => guard(
    () async => await _remote.getKitchenStations(activeOnly: activeOnly),
  );

  /// สร้างเมื่อไม่ส่ง [id] มา — ตอนสร้างต้องมี [code] ตอนแก้ไขส่ง code ไปก็ไม่มีผล
  @override
  Future<Result<KitchenStation>> saveKitchenStation({
    int? id,
    required String name,
    String? code,
    String? nameEn,
    String? nameKo,
    String? icon,
    bool? isActive,
    bool? isDefault,
  }) => guard(() async {
    if (id == null) {
      return await _remote.createKitchenStation(
        KitchenStationModel.toCreateJson(
          code: code ?? '',
          name: name,
          nameEn: nameEn,
          nameKo: nameKo,
          icon: icon,
        ),
      );
    }
    return await _remote.updateKitchenStation(
      id,
      KitchenStationModel.toUpdateJson(
        name: name,
        nameEn: nameEn,
        nameKo: nameKo,
        icon: icon,
        isActive: isActive,
        isDefault: isDefault,
      ),
    );
  });

  @override
  Future<Result<void>> deleteKitchenStation(int id) =>
      guard(() => _remote.deleteKitchenStation(id));

  @override
  Future<Result<List<MenuItem>>> getMenuItems({
    int? categoryId,
    String? search,
    bool? availableOnly,
  }) => guard(
    () async => await _remote.getMenuItems(
      categoryId: categoryId,
      search: search,
      availableOnly: availableOnly,
    ),
  );

  @override
  Future<Result<MenuItem>> getMenuItem(int id) =>
      guard(() async => await _remote.getMenuItem(id));

  @override
  Future<Result<MenuItem>> createMenuItem(MenuItemPayload payload) =>
      guard(() async => await _remote.createMenuItem(payload));

  @override
  Future<Result<MenuItem>> updateMenuItem(int id, MenuItemPayload payload) =>
      guard(() async => await _remote.updateMenuItem(id, payload));

  @override
  Future<Result<MenuItem>> setAvailability(int id, bool isAvailable) =>
      guard(() async => await _remote.setAvailability(id, isAvailable));

  @override
  Future<Result<void>> deleteMenuItem(int id) =>
      guard(() => _remote.deleteMenuItem(id));
}
