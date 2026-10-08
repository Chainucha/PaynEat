// Copyright 2026 Suruch Chakrapeesirisuk
// SPDX-License-Identifier: Apache-2.0

import 'package:flutter_test/flutter_test.dart';
import 'package:payneat_pos/core/network/socket_client.dart';
import 'package:payneat_pos/core/services/session_service.dart';
import 'package:payneat_pos/core/services/storage_service.dart';
import 'package:payneat_pos/features/kitchen/presentation/controllers/station_status_controller.dart';
import 'package:payneat_pos/features/menu/domain/entities/station_status.dart';
import 'package:payneat_pos/core/errors/failures.dart';
import 'package:payneat_pos/core/usecases/result.dart';
import 'package:payneat_pos/features/menu/domain/entities/category.dart';
import 'package:payneat_pos/features/menu/domain/entities/menu_item.dart';
import 'package:payneat_pos/features/menu/domain/repositories/menu_repository.dart';
import 'package:payneat_pos/features/menu/domain/usecases/menu_usecases.dart';
import 'package:payneat_pos/features/menu/presentation/controllers/menu_controller.dart';

class _FakeMenuRepository implements MenuRepository {
  Result<List<Category>> nextCategoriesResult = const Result.success([]);
  Result<List<MenuItem>> nextMenuItemsResult = const Result.success([]);
  int menuLoads = 0;

  @override
  Future<Result<List<StationStatus>>> getStationStatuses() async =>
      const Result.success([]);

  @override
  Future<Result<List<Category>>> getCategories({
    bool activeOnly = true,
  }) async => nextCategoriesResult;

  @override
  Future<Result<List<MenuItem>>> getMenuItems({
    int? categoryId,
    String? search,
    bool? availableOnly,
  }) async {
    menuLoads++;
    return nextMenuItemsResult;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

MenuItem _item(
  int id, {
  int categoryId = 1,
  String name = 'ข้าวผัด',
  bool isRecommended = false,
}) => MenuItem(
  id: id,
  categoryId: categoryId,
  name: name,
  price: 50,
  isRecommended: isRecommended,
);

void main() {
  late _FakeMenuRepository repository;
  late MenuBrowseController controller;

  setUp(() {
    repository = _FakeMenuRepository();
    controller = MenuBrowseController(
      getMenuItems: GetMenuItemsUseCase(repository),
      getCategories: GetCategoriesUseCase(repository),
    );
  });

  tearDown(() => controller.onClose());

  group('MenuBrowseController', () {
    test('load สำเร็จ → เติมทั้งเมนูและหมวดหมู่ ปิด loading', () async {
      repository.nextCategoriesResult = const Result.success([
        Category(id: 1, name: 'จานเดียว'),
      ]);
      repository.nextMenuItemsResult = Result.success([_item(1), _item(2)]);

      await controller.load();

      expect(controller.items.length, 2);
      expect(controller.categories.length, 1);
      expect(controller.isLoading.value, isFalse);
      expect(controller.errorMessage.value, isNull);
    });

    test('load ล้มเหลว (เมนู) → ตั้ง errorMessage', () async {
      repository.nextCategoriesResult = const Result.success([]);
      repository.nextMenuItemsResult = Result.failure(
        NetworkFailure('ต่อเซิร์ฟเวอร์ไม่ได้'),
      );

      await controller.load();

      expect(controller.errorMessage.value, 'ต่อเซิร์ฟเวอร์ไม่ได้');
    });

    test('filteredItems กรองตามหมวดหมู่และคำค้นหาพร้อมกัน', () async {
      repository.nextMenuItemsResult = Result.success([
        _item(1, categoryId: 1, name: 'ข้าวผัดหมู'),
        _item(2, categoryId: 1, name: 'ต้มยำกุ้ง'),
        _item(3, categoryId: 2, name: 'ข้าวผัดปู'),
      ]);
      await controller.load();

      controller.selectCategory(1);
      expect(controller.filteredItems.map((i) => i.id), [1, 2]);

      controller.searchQuery.value = 'ข้าวผัด';
      expect(controller.filteredItems.map((i) => i.id), [1]);

      controller.selectCategory(null);
      expect(controller.filteredItems.map((i) => i.id), [1, 3]);
    });

    test(
      'search มีการหน่วงเวลา (debounce) ก่อนอัปเดต searchQuery จริง',
      () async {
        controller.search('ผัด');
        expect(controller.searchQuery.value, isEmpty);

        await Future<void>.delayed(const Duration(milliseconds: 300));

        expect(controller.searchQuery.value, 'ผัด');
      },
    );

    test('clearSearch ล้างคำค้นหาทันทีโดยไม่รอ debounce', () async {
      controller.search('ผัด');
      controller.clearSearch();

      await Future<void>.delayed(const Duration(milliseconds: 300));

      expect(controller.searchQuery.value, isEmpty);
    });

    test('recommendedItems กรองเฉพาะเมนูแนะนำ', () async {
      repository.nextMenuItemsResult = Result.success([
        _item(1, isRecommended: true),
        _item(2, isRecommended: false),
      ]);
      await controller.load();

      expect(controller.recommendedItems.map((i) => i.id), [1]);
    });

    test('countByCategory นับเฉพาะเมนูในหมวดหมู่นั้น', () async {
      repository.nextMenuItemsResult = Result.success([
        _item(1, categoryId: 1),
        _item(2, categoryId: 1),
        _item(3, categoryId: 2),
      ]);
      await controller.load();

      expect(controller.countByCategory(1), 2);
      expect(controller.countByCategory(2), 1);
      expect(controller.countByCategory(99), 0);
    });

    test(
      'replaceItem อัปเดตของเดิมถ้ามี id ซ้ำ หรือเพิ่มใหม่ถ้าไม่มี',
      () async {
        repository.nextMenuItemsResult = Result.success([
          _item(1, name: 'เดิม'),
        ]);
        await controller.load();

        controller.replaceItem(_item(1, name: 'แก้ไขแล้ว'));
        expect(controller.items.single.name, 'แก้ไขแล้ว');

        controller.replaceItem(_item(2, name: 'ใหม่'));
        expect(controller.items.length, 2);
      },
    );

    test('removeItem ลบเมนูออกจากรายการตาม id', () async {
      repository.nextMenuItemsResult = Result.success([_item(1), _item(2)]);
      await controller.load();

      controller.removeItem(1);

      expect(controller.items.map((i) => i.id), [2]);
    });
  });

  test(
    'ชุดสถานีที่ปิดเปลี่ยน → โหลดเมนูใหม่แบบไม่ขึ้น loader (ticket 36)',
    () async {
      final status = StationStatusController(
        getStatuses: GetStationStatusesUseCase(repository),
        setClosed: SetStationClosedUseCase(repository),
        session: SessionService(
          storage: StorageService.memory(),
          socket: SocketClient(),
        ),
      );
      final browse = MenuBrowseController(
        getMenuItems: GetMenuItemsUseCase(repository),
        getCategories: GetCategoriesUseCase(repository),
        stationStatus: status,
      )..onInit();
      await Future<void>.delayed(Duration.zero);
      final loadsBefore = repository.menuLoads;

      status.closedVersion.value++;
      await Future<void>.delayed(Duration.zero);

      expect(repository.menuLoads, loadsBefore + 1);
      expect(browse.isLoading.value, isFalse);
      browse.onClose();
    },
  );
}
