// Copyright 2026 Suruch Chakrapeesirisuk
// SPDX-License-Identifier: Apache-2.0

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:payneat_pos/core/localization/app_translations.dart';
import 'package:payneat_pos/core/localization/locale_service.dart';
import 'package:payneat_pos/core/network/socket_client.dart';
import 'package:payneat_pos/core/services/session_service.dart';
import 'package:payneat_pos/core/services/storage_service.dart';
import 'package:payneat_pos/core/usecases/result.dart';
import 'package:payneat_pos/features/auth/domain/entities/user.dart';
import 'package:payneat_pos/features/kitchen/presentation/controllers/kitchen_controller.dart';
import 'package:payneat_pos/features/kitchen/presentation/controllers/station_status_controller.dart';
import 'package:payneat_pos/features/kitchen/presentation/pages/kitchen_page.dart';
import 'package:payneat_pos/features/kitchen/presentation/widgets/station_closed_banner.dart';
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

  // มีสถานีปิดอยู่หนึ่งแห่ง เพื่อให้แบนเนอร์แสดง
  @override
  Future<Result<List<StationStatus>>> getStationStatuses() async =>
      const Result.success([
        StationStatus(
          stationId: 3,
          code: 'bar',
          name: 'บาร์',
          isClosed: true,
          closedByName: 'เชฟต้น',
        ),
      ]);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

User _user(String role, {int? branchId = 1}) => User(
  id: 1,
  name: role,
  username: role,
  role: role,
  isActive: true,
  branchId: branchId,
);

Future<StationStatusController> _pump(WidgetTester tester, User user) async {
  final orders = _FakeOrderRepository();
  final menu = _FakeMenuRepository();
  final session = SessionService(
    storage: StorageService.memory(),
    socket: SocketClient(),
  )..updateUser(user);
  Get.put<SessionService>(session);
  Get.put<KitchenController>(
    KitchenController(
      getQueue: GetKitchenQueueUseCase(orders),
      updateItemStatus: UpdateOrderItemStatusUseCase(orders),
      session: session,
      getStations: GetKitchenStationsUseCase(menu),
      storage: StorageService.memory(),
    ),
  );
  final status = Get.put<StationStatusController>(
    StationStatusController(
      getStatuses: GetStationStatusesUseCase(menu),
      setClosed: SetStationClosedUseCase(menu),
      session: session,
    ),
  );
  await status.load();
  tester.view.physicalSize = const Size(800, 640);
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
  return status;
}

/// หยุด Timer.periodic ที่ onInit เปิดไว้ ก่อนจบเทสต์ (ไม่งั้น test binding ฟ้อง timer ค้าง)
void _stopKitchen() => Get.find<KitchenController>().onClose();

void main() {
  tearDown(Get.reset);

  testWidgets(
    'พนักงานเสิร์ฟ: ไม่มีปุ่มสถานี แบนเนอร์เห็นแต่แตะแล้วไม่เปิดชีต',
    (tester) async {
      await _pump(tester, _user('waiter'));
      expect(find.byIcon(Icons.storefront_outlined), findsNothing);
      expect(find.byType(StationClosedBanner), findsOneWidget);
      expect(find.byIcon(Icons.do_not_disturb_on_rounded), findsOneWidget);

      await tester.tap(find.byType(StationClosedBanner));
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.text('station_status_title'.tr), findsNothing);
      _stopKitchen();
    },
  );

  testWidgets('ครัว: มีปุ่มสถานี และแตะแบนเนอร์เปิดชีต', (tester) async {
    await _pump(tester, _user('kitchen'));
    expect(find.byIcon(Icons.storefront_outlined), findsOneWidget);

    await tester.tap(find.byType(StationClosedBanner));
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('station_status_title'.tr), findsOneWidget);
    Get.back<void>();
    await tester.pumpAndSettle();
    _stopKitchen();
  });

  testWidgets('admin โหมดทุกสาขา (canUse false) → ไม่มีปุ่มสถานี', (
    tester,
  ) async {
    await _pump(tester, _user('admin', branchId: null));
    expect(find.byIcon(Icons.storefront_outlined), findsNothing);
    _stopKitchen();
  });
}
