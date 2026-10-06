// Copyright 2026 Suruch Chakrapeesirisuk
// SPDX-License-Identifier: Apache-2.0

import 'package:get/get.dart';

import '../../../../app/routes/app_routes.dart';
import '../../../../core/widgets/app_dialogs.dart';
import '../../domain/entities/menu_item_payload.dart';
import '../../domain/entities/category.dart';
import '../../domain/entities/kitchen_station.dart';
import '../../domain/entities/menu_item.dart';
import '../../domain/usecases/menu_usecases.dart';

/// จัดการเมนู (สำหรับผู้จัดการ/แอดมิน) — เพิ่ม แก้ไข ลบ และเปิด-ปิดการขาย
class MenuManagementController extends GetxController {
  MenuManagementController({
    required GetMenuItemsUseCase getMenuItems,
    required GetCategoriesUseCase getCategories,
    required CreateMenuItemUseCase createMenuItem,
    required UpdateMenuItemUseCase updateMenuItem,
    required DeleteMenuItemUseCase deleteMenuItem,
    required ToggleMenuAvailabilityUseCase toggleAvailability,
    required SaveCategoryUseCase saveCategory,
    required DeleteCategoryUseCase deleteCategory,
    required GetKitchenStationsUseCase getStations,
    required SaveKitchenStationUseCase saveStationUseCase,
    required DeleteKitchenStationUseCase deleteStationUseCase,
  }) : _getMenuItems = getMenuItems,
       _getCategories = getCategories,
       _createMenuItem = createMenuItem,
       _updateMenuItem = updateMenuItem,
       _deleteMenuItem = deleteMenuItem,
       _toggleAvailability = toggleAvailability,
       _saveCategory = saveCategory,
       _deleteCategory = deleteCategory,
       _getStations = getStations,
       _saveStation = saveStationUseCase,
       _deleteStation = deleteStationUseCase;

  final GetMenuItemsUseCase _getMenuItems;
  final GetCategoriesUseCase _getCategories;
  final CreateMenuItemUseCase _createMenuItem;
  final UpdateMenuItemUseCase _updateMenuItem;
  final DeleteMenuItemUseCase _deleteMenuItem;
  final ToggleMenuAvailabilityUseCase _toggleAvailability;
  final SaveCategoryUseCase _saveCategory;
  final DeleteCategoryUseCase _deleteCategory;
  final GetKitchenStationsUseCase _getStations;
  final SaveKitchenStationUseCase _saveStation;
  final DeleteKitchenStationUseCase _deleteStation;

  final RxList<MenuItem> items = <MenuItem>[].obs;
  final RxList<Category> categories = <Category>[].obs;
  final RxList<KitchenStation> stations = <KitchenStation>[].obs;
  final RxBool isLoading = true.obs;
  final RxBool isSaving = false.obs;
  final RxnString errorMessage = RxnString();
  final RxnInt selectedCategoryId = RxnInt();
  final RxString searchQuery = ''.obs;

  @override
  void onInit() {
    super.onInit();
    load();
  }

  List<MenuItem> get filteredItems {
    final query = searchQuery.value.trim().toLowerCase();
    return items
        .where((item) {
          final categoryMatched =
              selectedCategoryId.value == null ||
              item.categoryId == selectedCategoryId.value;
          if (!categoryMatched) return false;
          if (query.isEmpty) return true;
          return item.name.toLowerCase().contains(query);
        })
        .toList(growable: false);
  }

  int get unavailableCount => items.where((item) => !item.isAvailable).length;

  Future<void> load() async {
    isLoading.value = true;
    errorMessage.value = null;

    final results = await Future.wait([
      _getCategories(false),
      _getMenuItems(const MenuFilter()),
      _getStations(false),
    ]);

    isLoading.value = false;
    results[0].fold(
      onSuccess: (data) => categories.assignAll(data as List<Category>),
      onFailure: (failure) => errorMessage.value = failure.message,
    );
    results[1].fold(
      onSuccess: (data) => items.assignAll(data as List<MenuItem>),
      onFailure: (failure) => errorMessage.value = failure.message,
    );
    results[2].fold(
      onSuccess: (data) => stations.assignAll(data as List<KitchenStation>),
      onFailure: (failure) => errorMessage.value = failure.message,
    );
  }

  void selectCategory(int? id) => selectedCategoryId.value = id;
  void search(String query) => searchQuery.value = query;

  Future<void> toggleAvailability(MenuItem item) async {
    final result = await _toggleAvailability(
      ToggleAvailabilityParams(id: item.id, isAvailable: !item.isAvailable),
    );

    result.fold(
      onSuccess: (updated) {
        final index = items.indexWhere((row) => row.id == updated.id);
        if (index >= 0) items[index] = updated;
        AppDialogs.success(
          updated.isAvailable
              ? 'menu_mark_available_success'.trParams({'name': updated.name})
              : 'menu_mark_unavailable_success'.trParams({
                  'name': updated.name,
                }),
        );
      },
      onFailure: (failure) => AppDialogs.error(failure.message),
    );
  }

  Future<void> save({int? id, required MenuItemPayload payload}) async {
    isSaving.value = true;
    final result = id == null
        ? await _createMenuItem(payload)
        : await _updateMenuItem(UpdateMenuItemParams(id: id, payload: payload));
    isSaving.value = false;

    result.fold(
      onSuccess: (_) {
        AppDialogs.success(
          id == null
              ? 'menu_item_created_success'.tr
              : 'menu_item_updated_success'.tr,
        );
        Get.back<void>();
        load();
      },
      onFailure: (failure) => AppDialogs.error(failure.message),
    );
  }

  Future<void> delete(MenuItem item) async {
    final confirmed = await AppDialogs.confirm(
      title: 'menu_delete_item_title'.tr,
      message: 'menu_delete_item_confirm'.trParams({'name': item.name}),
      confirmLabel: 'menu_delete_item_title'.tr,
      destructive: true,
    );
    if (!confirmed) return;

    final result = await _deleteMenuItem(item.id);
    result.fold(
      onSuccess: (_) {
        items.removeWhere((row) => row.id == item.id);
        AppDialogs.success('menu_item_deleted_success'.tr);
      },
      onFailure: (failure) => AppDialogs.error(failure.message),
    );
  }

  Future<void> openForm({MenuItem? item}) async {
    await Get.toNamed<void>(AppRoutes.menuForm, arguments: {'item': item});
  }

  Future<void> saveCategory({
    int? id,
    required String name,
    String? icon,
    int? stationId,
    bool stationChanged = false,
  }) async {
    final result = await _saveCategory(
      SaveCategoryParams(
        id: id,
        name: name,
        icon: icon,
        stationId: stationId,
        stationChanged: stationChanged,
      ),
    );
    result.fold(
      onSuccess: (_) {
        AppDialogs.success(
          id == null
              ? 'menu_category_created_success'.tr
              : 'menu_category_updated_success'.tr,
        );
        load();
      },
      onFailure: (failure) => AppDialogs.error(failure.message),
    );
  }

  Future<void> deleteCategory(Category category) async {
    final confirmed = await AppDialogs.confirm(
      title: 'menu_delete_category_title'.tr,
      message: 'menu_delete_category_confirm'.trParams({'name': category.name}),
      confirmLabel: 'common_delete'.tr,
      destructive: true,
    );
    if (!confirmed) return;

    final result = await _deleteCategory(category.id);
    result.fold(
      onSuccess: (_) {
        AppDialogs.success('menu_category_deleted_success'.tr);
        load();
      },
      onFailure: (failure) => AppDialogs.error(failure.message),
    );
  }

  /// สถานีครัว (ticket 34) — ไม่ส่ง [id] = สร้างใหม่ ซึ่งต้องมี [code] ด้วย
  Future<void> saveStation({
    int? id,
    required String name,
    String? code,
    String? nameEn,
    String? nameKo,
    String? icon,
    bool? isActive,
    bool? isDefault,
  }) async {
    final result = await _saveStation(
      SaveKitchenStationParams(
        id: id,
        name: name,
        code: code,
        nameEn: nameEn,
        nameKo: nameKo,
        icon: icon,
        isActive: isActive,
        isDefault: isDefault,
      ),
    );
    result.fold(
      onSuccess: (_) {
        AppDialogs.success(
          id == null
              ? 'menu_station_created_success'.tr
              : 'menu_station_updated_success'.tr,
        );
        load();
      },
      onFailure: (failure) => AppDialogs.error(failure.message),
    );
  }

  Future<void> deleteStation(KitchenStation station) async {
    final confirmed = await AppDialogs.confirm(
      title: 'menu_delete_station_title'.tr,
      message: 'menu_delete_station_confirm'.trParams({
        'name': station.displayName,
      }),
      confirmLabel: 'common_delete'.tr,
      destructive: true,
    );
    if (!confirmed) return;

    final result = await _deleteStation(station.id);
    result.fold(
      onSuccess: (_) {
        AppDialogs.success('menu_station_deleted_success'.tr);
        load();
      },
      onFailure: (failure) => AppDialogs.error(failure.message),
    );
  }
}
