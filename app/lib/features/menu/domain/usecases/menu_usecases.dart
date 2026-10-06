// Copyright 2026 Suruch Chakrapeesirisuk
// SPDX-License-Identifier: Apache-2.0

import '../../../../core/usecases/result.dart';
import '../../../../core/usecases/usecase.dart';
import '../entities/menu_item_payload.dart';
import '../entities/category.dart';
import '../entities/kitchen_station.dart';
import '../entities/menu_item.dart';
import '../repositories/menu_repository.dart';

/// พารามิเตอร์สำหรับกรองเมนู
class MenuFilter {
  const MenuFilter({this.categoryId, this.search, this.availableOnly});

  final int? categoryId;
  final String? search;
  final bool? availableOnly;
}

/// ดึงรายการเมนู (ใช้ทั้งหน้าสั่งอาหารและหน้าจัดการเมนู)
class GetMenuItemsUseCase implements UseCase<List<MenuItem>, MenuFilter> {
  const GetMenuItemsUseCase(this._repository);

  final MenuRepository _repository;

  @override
  Future<Result<List<MenuItem>>> call(MenuFilter params) =>
      _repository.getMenuItems(
        categoryId: params.categoryId,
        search: params.search,
        availableOnly: params.availableOnly,
      );
}

/// ดึงหมวดหมู่ทั้งหมด
class GetCategoriesUseCase implements UseCase<List<Category>, bool> {
  const GetCategoriesUseCase(this._repository);

  final MenuRepository _repository;

  @override
  Future<Result<List<Category>>> call(bool activeOnly) =>
      _repository.getCategories(activeOnly: activeOnly);
}

/// เพิ่มเมนูใหม่ (ผู้จัดการ)
class CreateMenuItemUseCase implements UseCase<MenuItem, MenuItemPayload> {
  const CreateMenuItemUseCase(this._repository);

  final MenuRepository _repository;

  @override
  Future<Result<MenuItem>> call(MenuItemPayload params) =>
      _repository.createMenuItem(params);
}

class UpdateMenuItemParams {
  const UpdateMenuItemParams({required this.id, required this.payload});

  final int id;
  final MenuItemPayload payload;
}

/// แก้ไขเมนู (ผู้จัดการ)
class UpdateMenuItemUseCase implements UseCase<MenuItem, UpdateMenuItemParams> {
  const UpdateMenuItemUseCase(this._repository);

  final MenuRepository _repository;

  @override
  Future<Result<MenuItem>> call(UpdateMenuItemParams params) =>
      _repository.updateMenuItem(params.id, params.payload);
}

class ToggleAvailabilityParams {
  const ToggleAvailabilityParams({required this.id, required this.isAvailable});

  final int id;
  final bool isAvailable;
}

/// เปิด/ปิดการขายเมนู — ใช้ตอนของหมดกลางวัน
class ToggleMenuAvailabilityUseCase
    implements UseCase<MenuItem, ToggleAvailabilityParams> {
  const ToggleMenuAvailabilityUseCase(this._repository);

  final MenuRepository _repository;

  @override
  Future<Result<MenuItem>> call(ToggleAvailabilityParams params) =>
      _repository.setAvailability(params.id, params.isAvailable);
}

/// ลบเมนู
class DeleteMenuItemUseCase implements UseCase<void, int> {
  const DeleteMenuItemUseCase(this._repository);

  final MenuRepository _repository;

  @override
  Future<Result<void>> call(int params) => _repository.deleteMenuItem(params);
}

/// จัดการหมวดหมู่
class SaveCategoryParams {
  const SaveCategoryParams({
    this.id,
    required this.name,
    this.nameEn,
    this.icon,
    this.stationId,
    this.stationChanged = false,
  });

  final int? id;
  final String name;
  final String? nameEn;
  final String? icon;

  /// สถานีครัวตั้งต้นของหมวดหมู่ (ticket 34) — null = ใช้สถานีค่าเริ่มต้นของร้าน
  final int? stationId;

  /// true = ผู้ใช้แตะช่องสถานีจริง จึงส่ง `stationId` ไปแม้เป็น null (= ล้างค่า)
  /// ถ้าไม่แยกไว้ การแก้แค่ชื่อหมวดหมู่จะล้างสถานีทิ้งทุกครั้ง
  final bool stationChanged;
}

class SaveCategoryUseCase implements UseCase<Category, SaveCategoryParams> {
  const SaveCategoryUseCase(this._repository);

  final MenuRepository _repository;

  @override
  Future<Result<Category>> call(SaveCategoryParams params) {
    if (params.id == null) {
      return _repository.createCategory(
        name: params.name,
        nameEn: params.nameEn,
        icon: params.icon,
        stationId: params.stationId,
      );
    }
    return _repository.updateCategory(params.id!, {
      'name': params.name,
      if (params.nameEn != null) 'nameEn': params.nameEn,
      if (params.icon != null) 'icon': params.icon,
      if (params.stationChanged) 'stationId': params.stationId,
    });
  }
}

class DeleteCategoryUseCase implements UseCase<void, int> {
  const DeleteCategoryUseCase(this._repository);

  final MenuRepository _repository;

  @override
  Future<Result<void>> call(int params) => _repository.deleteCategory(params);
}

/// จัดการสถานีครัว (ticket 34)
class GetKitchenStationsUseCase implements UseCase<List<KitchenStation>, bool> {
  const GetKitchenStationsUseCase(this._repository);

  final MenuRepository _repository;

  @override
  Future<Result<List<KitchenStation>>> call(bool activeOnly) =>
      _repository.getKitchenStations(activeOnly: activeOnly);
}

class SaveKitchenStationParams {
  const SaveKitchenStationParams({
    this.id,
    required this.name,
    this.code,
    this.nameEn,
    this.nameKo,
    this.icon,
    this.isActive,
    this.isDefault,
  });

  final int? id;
  final String name;

  /// ต้องมีเฉพาะตอนสร้าง — รหัสของสถานีที่มีอยู่แล้วแก้ไม่ได้
  final String? code;
  final String? nameEn;
  final String? nameKo;
  final String? icon;
  final bool? isActive;
  final bool? isDefault;
}

class SaveKitchenStationUseCase
    implements UseCase<KitchenStation, SaveKitchenStationParams> {
  const SaveKitchenStationUseCase(this._repository);

  final MenuRepository _repository;

  @override
  Future<Result<KitchenStation>> call(SaveKitchenStationParams params) =>
      _repository.saveKitchenStation(
        id: params.id,
        name: params.name,
        code: params.code,
        nameEn: params.nameEn,
        nameKo: params.nameKo,
        icon: params.icon,
        isActive: params.isActive,
        isDefault: params.isDefault,
      );
}

class DeleteKitchenStationUseCase implements UseCase<void, int> {
  const DeleteKitchenStationUseCase(this._repository);

  final MenuRepository _repository;

  @override
  Future<Result<void>> call(int params) =>
      _repository.deleteKitchenStation(params);
}
