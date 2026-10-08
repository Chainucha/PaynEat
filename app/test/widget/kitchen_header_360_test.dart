// Copyright 2026 Suruch Chakrapeesirisuk
// SPDX-License-Identifier: Apache-2.0

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:payneat_pos/core/constants/app_constants.dart';
import 'package:payneat_pos/core/localization/app_translations.dart';
import 'package:payneat_pos/core/localization/locale_service.dart';
import 'package:payneat_pos/core/network/socket_client.dart';
import 'package:payneat_pos/core/services/session_service.dart';
import 'package:payneat_pos/core/services/storage_service.dart';
import 'package:payneat_pos/core/usecases/result.dart';
import 'package:payneat_pos/core/utils/app_clock.dart';
import 'package:payneat_pos/features/auth/domain/entities/user.dart';
import 'package:payneat_pos/features/kitchen/presentation/controllers/kitchen_controller.dart';
import 'package:payneat_pos/features/kitchen/presentation/controllers/station_status_controller.dart';
import 'package:payneat_pos/features/kitchen/presentation/pages/kitchen_page.dart';
import 'package:payneat_pos/features/menu/domain/entities/kitchen_station.dart';
import 'package:payneat_pos/features/menu/domain/entities/station_status.dart';
import 'package:payneat_pos/features/menu/domain/repositories/menu_repository.dart';
import 'package:payneat_pos/features/menu/domain/usecases/menu_usecases.dart';
import 'package:payneat_pos/features/order/domain/entities/order_item.dart';
import 'package:payneat_pos/features/order/domain/repositories/order_repository.dart';
import 'package:payneat_pos/features/order/domain/usecases/order_usecases.dart';

class _FakeOrderRepository implements OrderRepository {
  @override
  Future<Result<List<OrderItem>>> getKitchenQueue({
    List<String>? statuses,
  }) async => const Result.success([]);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeMenuRepository implements MenuRepository {
  @override
  Future<Result<List<KitchenStation>>> getKitchenStations({
    bool activeOnly = false,
  }) async => const Result.success([]);

  @override
  Future<Result<List<StationStatus>>> getStationStatuses() async =>
      const Result.success([]);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  tearDown(() {
    AppClock.unfreeze();
    Get.reset();
  });

  testWidgets(
    'หัวจอครัว 360px ภาษาอังกฤษ + ป้ายเกินเวลา + ปุ่มสถานี → ไม่ล้น (ticket 36)',
    (tester) async {
      final now = DateTime.utc(2026, 10, 8, 12);
      AppClock.freeze(now);
      final orders = _FakeOrderRepository();
      final menu = _FakeMenuRepository();
      final session =
          SessionService(
            storage: StorageService.memory(),
            socket: SocketClient(),
          )..updateUser(
            const User(
              id: 1,
              name: 'ครัว',
              username: 'kitchen',
              role: 'kitchen',
              isActive: true,
              branchId: 1,
            ),
          );
      Get.put<SessionService>(session);
      final kitchen = KitchenController(
        getQueue: GetKitchenQueueUseCase(orders),
        updateItemStatus: UpdateOrderItemStatusUseCase(orders),
        session: session,
        getStations: GetKitchenStationsUseCase(menu),
        storage: StorageService.memory(),
      );
      Get.put<KitchenController>(kitchen);
      Get.put<StationStatusController>(
        StationStatusController(
          getStatuses: GetStationStatusesUseCase(menu),
          setClosed: SetStationClosedUseCase(menu),
          session: session,
        ),
      );
      // ตั้งค่าตรง ๆ แทน onInit (Timer.periodic ทำให้ pumpAndSettle ไม่จบ)
      kitchen.queue.assignAll([
        for (var i = 1; i <= 3; i++)
          OrderItem(
            id: i,
            orderId: 1,
            name: 'ผัดกะเพรา',
            unitPrice: 75,
            quantity: 1,
            lineTotal: 75,
            status: OrderItemStatus.pending,
            createdAt: now
                .subtract(const Duration(minutes: 30))
                .toIso8601String(),
          ),
      ]);
      expect(kitchen.lateCount, 3);

      tester.view.physicalSize = const Size(360, 640);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        GetMaterialApp(
          translations: AppTranslations(),
          locale: LocaleService.english,
          home: const Scaffold(body: KitchenPage()),
        ),
      );
      await tester.pump();

      expect(find.byIcon(Icons.storefront_outlined), findsOneWidget);
      expect(find.byIcon(Icons.refresh_rounded), findsOneWidget);
      expect(find.byIcon(Icons.volume_up_rounded), findsOneWidget);
      expect(tester.takeException(), isNull);
      // หยุด Timer.periodic ที่ onInit เปิดไว้ ก่อนจบเทสต์
      kitchen.onClose();
    },
  );
}
