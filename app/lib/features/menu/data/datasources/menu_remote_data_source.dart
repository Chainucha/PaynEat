// Copyright 2026 Suruch Chakrapeesirisuk
// SPDX-License-Identifier: Apache-2.0

import '../../../../core/network/api_client.dart';
import '../../../../core/network/api_endpoints.dart';
import '../models/category_model.dart';
import '../models/kitchen_station_model.dart';
import '../../domain/entities/menu_item_payload.dart';
import '../models/menu_item_model.dart';

abstract class MenuRemoteDataSource {
  Future<List<CategoryModel>> getCategories({bool activeOnly});
  Future<CategoryModel> createCategory(Map<String, dynamic> body);
  Future<CategoryModel> updateCategory(int id, Map<String, dynamic> body);
  Future<void> deleteCategory(int id);

  Future<List<KitchenStationModel>> getKitchenStations({bool activeOnly});
  Future<KitchenStationModel> createKitchenStation(Map<String, dynamic> body);
  Future<KitchenStationModel> updateKitchenStation(
    int id,
    Map<String, dynamic> body,
  );
  Future<void> deleteKitchenStation(int id);

  Future<List<MenuItemModel>> getMenuItems({
    int? categoryId,
    String? search,
    bool? availableOnly,
    int page,
    int limit,
  });
  Future<MenuItemModel> getMenuItem(int id);
  Future<MenuItemModel> createMenuItem(MenuItemPayload payload);
  Future<MenuItemModel> updateMenuItem(int id, MenuItemPayload payload);
  Future<MenuItemModel> setAvailability(int id, bool isAvailable);
  Future<void> deleteMenuItem(int id);
}

class MenuRemoteDataSourceImpl implements MenuRemoteDataSource {
  const MenuRemoteDataSourceImpl(this._client);

  final ApiClient _client;

  @override
  Future<List<CategoryModel>> getCategories({bool activeOnly = false}) async {
    final result = await _client.get(
      ApiEndpoints.categories,
      query: {if (activeOnly) 'activeOnly': 'true'},
    );
    return result.asList.map(CategoryModel.fromJson).toList(growable: false);
  }

  @override
  Future<CategoryModel> createCategory(Map<String, dynamic> body) async {
    final result = await _client.post(ApiEndpoints.categories, body: body);
    return CategoryModel.fromJson(result.asMap);
  }

  @override
  Future<CategoryModel> updateCategory(
    int id,
    Map<String, dynamic> body,
  ) async {
    final result = await _client.patch(ApiEndpoints.category(id), body: body);
    return CategoryModel.fromJson(result.asMap);
  }

  @override
  Future<void> deleteCategory(int id) =>
      _client.delete(ApiEndpoints.category(id));

  @override
  Future<List<KitchenStationModel>> getKitchenStations({
    bool activeOnly = false,
  }) async {
    final result = await _client.get(
      ApiEndpoints.kitchenStations,
      query: {if (activeOnly) 'activeOnly': 'true'},
    );
    return result.asList
        .map(KitchenStationModel.fromJson)
        .toList(growable: false);
  }

  @override
  Future<KitchenStationModel> createKitchenStation(
    Map<String, dynamic> body,
  ) async {
    final result = await _client.post(ApiEndpoints.kitchenStations, body: body);
    return KitchenStationModel.fromJson(result.asMap);
  }

  @override
  Future<KitchenStationModel> updateKitchenStation(
    int id,
    Map<String, dynamic> body,
  ) async {
    final result = await _client.patch(
      ApiEndpoints.kitchenStation(id),
      body: body,
    );
    return KitchenStationModel.fromJson(result.asMap);
  }

  @override
  Future<void> deleteKitchenStation(int id) =>
      _client.delete(ApiEndpoints.kitchenStation(id));

  @override
  Future<List<MenuItemModel>> getMenuItems({
    int? categoryId,
    String? search,
    bool? availableOnly,
    int page = 1,
    int limit = 200,
  }) async {
    final result = await _client.get(
      ApiEndpoints.menuItems,
      query: {
        'page': page,
        'limit': limit,
        'categoryId': ?categoryId,
        if (search != null && search.isNotEmpty) 'search': search,
        if (availableOnly == true) 'availableOnly': 'true',
      },
    );
    return result.asList.map(MenuItemModel.fromJson).toList(growable: false);
  }

  @override
  Future<MenuItemModel> getMenuItem(int id) async {
    final result = await _client.get(ApiEndpoints.menuItem(id));
    return MenuItemModel.fromJson(result.asMap);
  }

  @override
  Future<MenuItemModel> createMenuItem(MenuItemPayload payload) async {
    final result = await _client.post(
      ApiEndpoints.menuItems,
      body: payload.toJson(),
    );
    return MenuItemModel.fromJson(result.asMap);
  }

  @override
  Future<MenuItemModel> updateMenuItem(int id, MenuItemPayload payload) async {
    final result = await _client.patch(
      ApiEndpoints.menuItem(id),
      body: payload.toJson(),
    );
    return MenuItemModel.fromJson(result.asMap);
  }

  @override
  Future<MenuItemModel> setAvailability(int id, bool isAvailable) async {
    final result = await _client.patch(
      ApiEndpoints.menuAvailability(id),
      body: {'isAvailable': isAvailable},
    );
    return MenuItemModel.fromJson(result.asMap);
  }

  @override
  Future<void> deleteMenuItem(int id) =>
      _client.delete(ApiEndpoints.menuItem(id));
}
