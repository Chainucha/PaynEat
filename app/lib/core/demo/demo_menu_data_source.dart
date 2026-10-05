// Copyright 2026 Suruch Chakrapeesirisuk
// SPDX-License-Identifier: Apache-2.0

part of 'demo_data_sources.dart';

class DemoMenuDataSource implements MenuRemoteDataSource {
  const DemoMenuDataSource(this._store, this._auth);

  final DemoStore _store;
  final DemoAuthDataSource _auth;

  @override
  Future<List<CategoryModel>> getCategories({bool activeOnly = false}) =>
      _delayed(
        () => _store
            .categoryList()
            .map(CategoryModel.fromJson)
            .toList(growable: false),
      );

  @override
  Future<CategoryModel> createCategory(Map<String, dynamic> body) =>
      _delayed(() => CategoryModel.fromJson(_store.saveCategory(body)));

  @override
  Future<CategoryModel> updateCategory(int id, Map<String, dynamic> body) =>
      _delayed(() => CategoryModel.fromJson(_store.saveCategory(body, id: id)));

  @override
  Future<void> deleteCategory(int id) =>
      _delayed(() => _store.deleteCategory(id));

  @override
  Future<List<KitchenStationModel>> getKitchenStations({
    bool activeOnly = false,
  }) => _delayed(
    () => _store
        .kitchenStationList(activeOnly: activeOnly)
        .map(KitchenStationModel.fromJson)
        .toList(growable: false),
  );

  @override
  Future<KitchenStationModel> createKitchenStation(Map<String, dynamic> body) =>
      _delayed(
        () => KitchenStationModel.fromJson(_store.saveKitchenStation(body)),
      );

  @override
  Future<KitchenStationModel> updateKitchenStation(
    int id,
    Map<String, dynamic> body,
  ) => _delayed(
    () => KitchenStationModel.fromJson(_store.saveKitchenStation(body, id: id)),
  );

  @override
  Future<void> deleteKitchenStation(int id) =>
      _delayed(() => _store.deleteKitchenStation(id));

  @override
  Future<List<MenuItemModel>> getMenuItems({
    int? categoryId,
    String? search,
    bool? availableOnly,
    int page = 1,
    int limit = 200,
  }) => _delayed(
    () => _store
        .menuList(
          categoryId: categoryId,
          search: search,
          availableOnly: availableOnly,
        )
        .map(_store.presentMenuItem)
        .map(MenuItemModel.fromJson)
        .toList(growable: false),
  );

  @override
  Future<MenuItemModel> getMenuItem(int id) => _delayed(
    () => MenuItemModel.fromJson(_store.presentMenuItem(_store.menuItem(id))),
  );

  @override
  Future<MenuItemModel> createMenuItem(MenuItemPayload payload) => _delayed(
    () => MenuItemModel.fromJson(
      _store.presentMenuItem(_store.saveMenuItem(payload.toJson())),
    ),
  );

  @override
  Future<MenuItemModel> updateMenuItem(int id, MenuItemPayload payload) =>
      _delayed(
        () => MenuItemModel.fromJson(
          _store.presentMenuItem(
            _store.saveMenuItem(
              payload.toJson(),
              id: id,
              actorId: _auth.currentUserId,
            ),
          ),
        ),
      );

  @override
  Future<MenuItemModel> setAvailability(int id, bool isAvailable) => _delayed(
    () => MenuItemModel.fromJson(
      _store.presentMenuItem(_store.setAvailability(id, isAvailable)),
    ),
  );

  @override
  Future<void> deleteMenuItem(int id) =>
      _delayed(() => _store.deleteMenuItem(id));
}
