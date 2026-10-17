// Copyright 2026 Suruch Chakrapeesirisuk
// SPDX-License-Identifier: Apache-2.0

import 'dart:async';

import 'package:get/get.dart';

import '../../../kitchen/presentation/controllers/station_status_controller.dart';
import '../../domain/entities/category.dart';
import '../../domain/entities/menu_item.dart';
import '../../domain/usecases/menu_usecases.dart';

/// โหลดเมนู + หมวดหมู่ แล้วกรอง/ค้นหาในเครื่อง
///
/// โหลดทั้งหมดครั้งเดียวเพราะเมนูร้านอาหารมีไม่กี่สิบรายการ
/// การกรองในเครื่องทำให้กดสลับหมวดหมู่ลื่นไม่ต้องรอเน็ตทุกครั้ง
class MenuBrowseController extends GetxController {
  MenuBrowseController({
    required GetMenuItemsUseCase getMenuItems,
    required GetCategoriesUseCase getCategories,
    this.availableOnly = true,
    StationStatusController? stationStatus,
  }) : _getMenuItems = getMenuItems,
       _getCategories = getCategories,
       _stationStatus = stationStatus;

  final GetMenuItemsUseCase _getMenuItems;
  final GetCategoriesUseCase _getCategories;

  /// หน้าสั่งอาหารจะเห็นเฉพาะเมนูที่เปิดขาย ส่วนหน้าจัดการเมนูเห็นทั้งหมด
  final bool availableOnly;

  final RxList<MenuItem> items = <MenuItem>[].obs;
  final RxList<Category> categories = <Category>[].obs;
  final RxBool isLoading = true.obs;
  final RxnString errorMessage = RxnString();
  final RxnInt selectedCategoryId = RxnInt();
  final RxString searchQuery = ''.obs;

  final StationStatusController? _stationStatus;
  Worker? _stationWorker;
  Timer? _debounce;

  @override
  void onInit() {
    super.onInit();
    load();
    // สถานีปิด/เปิดระหว่างที่หน้าสั่งอาหารเปิดอยู่ (ticket 36) — โหลดเมนูใหม่เงียบ ๆ ให้การ์ดเทา/หายเทา
    final status = _stationStatus;
    if (status != null) {
      _stationWorker = ever<int>(
        status.closedVersion,
        (_) => load(showLoader: false),
      );
    }
  }

  @override
  void onClose() {
    _debounce?.cancel();
    _stationWorker?.dispose();
    super.onClose();
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
          return item.name.toLowerCase().contains(query) ||
              (item.nameEn?.toLowerCase().contains(query) ?? false);
        })
        .toList(growable: false);
  }

  List<MenuItem> get recommendedItems =>
      items.where((item) => item.isRecommended).toList(growable: false);

  int countByCategory(int categoryId) =>
      items.where((item) => item.categoryId == categoryId).length;

  Future<void> load({bool showLoader = true}) async {
    if (showLoader) isLoading.value = true;
    errorMessage.value = null;

    final results = await Future.wait([
      _getCategories(availableOnly),
      _getMenuItems(MenuFilter(availableOnly: availableOnly ? true : null)),
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
  }

  void selectCategory(int? categoryId) => selectedCategoryId.value = categoryId;

  /// หน่วงการค้นหาเล็กน้อยเพื่อไม่ให้ rebuild ทุกตัวอักษร
  void search(String query) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 250), () {
      searchQuery.value = query;
    });
  }

  void clearSearch() {
    _debounce?.cancel();
    searchQuery.value = '';
  }

  /// อัปเดตเมนูในหน่วยความจำหลังแก้ไข เพื่อไม่ต้องโหลดใหม่ทั้งก้อน
  void replaceItem(MenuItem updated) {
    final index = items.indexWhere((item) => item.id == updated.id);
    if (index >= 0) {
      items[index] = updated;
    } else {
      items.add(updated);
    }
  }

  void removeItem(int id) => items.removeWhere((item) => item.id == id);
}
