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
import 'package:payneat_pos/features/kitchen/presentation/controllers/kitchen_controller.dart';
import 'package:payneat_pos/features/kitchen/presentation/widgets/station_filter_bar.dart';
import 'package:payneat_pos/features/menu/domain/entities/kitchen_station.dart';
import 'package:payneat_pos/features/menu/domain/repositories/menu_repository.dart';
import 'package:payneat_pos/features/menu/domain/usecases/menu_usecases.dart';
import 'package:payneat_pos/features/order/domain/entities/order_item.dart';
import 'package:payneat_pos/features/order/domain/repositories/order_repository.dart';
import 'package:payneat_pos/features/order/domain/usecases/order_usecases.dart';

/// ชิปกรองสถานีบนจอครัว (ticket 34) — รวมกฎว่าหัวจอต้องไม่ล้นที่ 360px (docs/DECISIONS.md #62)
class _FakeOrderRepository implements OrderRepository {
  Result<List<OrderItem>> nextQueueResult = const Result.success([]);

  @override
  Future<Result<List<OrderItem>>> getKitchenQueue({
    List<String>? statuses,
  }) async => nextQueueResult;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeMenuRepository implements MenuRepository {
  Result<List<KitchenStation>> nextStationsResult = const Result.success([]);

  @override
  Future<Result<List<KitchenStation>>> getKitchenStations({
    bool activeOnly = false,
  }) async => nextStationsResult;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

OrderItem _item(int id, String stationCode) => OrderItem(
  id: id,
  orderId: 1,
  name: 'ผัดกะเพรา',
  unitPrice: 75,
  quantity: 1,
  lineTotal: 75,
  status: OrderItemStatus.pending,
  stationCode: stationCode,
);

void main() {
  late _FakeOrderRepository orders;
  late _FakeMenuRepository menu;
  late KitchenController controller;

  setUp(() {
    orders = _FakeOrderRepository();
    menu = _FakeMenuRepository();
    controller = KitchenController(
      getQueue: GetKitchenQueueUseCase(orders),
      updateItemStatus: UpdateOrderItemStatusUseCase(orders),
      session: SessionService(
        storage: StorageService.memory(),
        socket: SocketClient(),
      ),
      getStations: GetKitchenStationsUseCase(menu),
      storage: StorageService.memory(),
    );
    Get.put<KitchenController>(controller);
  });

  tearDown(() {
    controller.onClose();
    Get.reset();
  });

  /// ตั้งสถานะให้ controller ตรง ๆ แทนการเรียก onInit — onInit เปิด Timer.periodic 30 วินาที
  /// ไว้เดินตัวเลข "รอมาแล้วกี่นาที" ซึ่งทำให้ pumpAndSettle ไม่จบ
  Future<void> pump(
    WidgetTester tester, {
    required List<KitchenStation> stations,
    List<OrderItem> queue = const [],
    Size size = const Size(800, 600),
  }) async {
    controller.stations.assignAll(stations);
    controller.queue.assignAll(queue);
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      GetMaterialApp(
        translations: AppTranslations(),
        locale: LocaleService.thai,
        home: const Scaffold(body: StationFilterBar()),
      ),
    );
    await tester.pump();
  }

  testWidgets('มีสถานีหลายสถานี → ขึ้นชิป "ทุกสถานี" พร้อมชิปของแต่ละสถานี', (
    tester,
  ) async {
    await pump(
      tester,
      stations: const [
        KitchenStation(id: 1, code: 'hot', name: 'ครัวร้อน', isDefault: true),
        KitchenStation(id: 3, code: 'bar', name: 'บาร์', icon: '🥤'),
      ],
    );

    expect(find.text('ทุกสถานี'), findsOneWidget);
    expect(find.text('ครัวร้อน'), findsOneWidget);
    expect(find.text('🥤 บาร์'), findsOneWidget);
  });

  testWidgets('แตะชิป → กรองคิวและจำค่าไว้ในเครื่อง', (tester) async {
    await pump(
      tester,
      stations: const [
        KitchenStation(id: 1, code: 'hot', name: 'ครัวร้อน', isDefault: true),
        KitchenStation(id: 3, code: 'bar', name: 'บาร์'),
      ],
      queue: [_item(1, 'hot'), _item(2, 'bar')],
    );
    expect(controller.visibleQueue.length, 2);

    await tester.tap(find.text('บาร์'));
    await tester.pump();

    expect(controller.selectedStationCode.value, 'bar');
    expect(controller.visibleQueue.single.id, 2);
  });

  testWidgets('ร้านที่มีสถานีเดียว → ไม่ขึ้นแถบชิปเลย', (tester) async {
    await pump(
      tester,
      stations: const [
        KitchenStation(id: 1, code: 'hot', name: 'ครัวร้อน', isDefault: true),
      ],
    );

    expect(find.text('ทุกสถานี'), findsNothing);
  });

  testWidgets(
    'กว้าง 360px — แถบชิปเลื่อนได้ ไม่ล้นจอ (docs/DECISIONS.md #62)',
    (tester) async {
      await pump(
        tester,
        stations: const [
          KitchenStation(id: 1, code: 'hot', name: 'ครัวร้อน', isDefault: true),
          KitchenStation(id: 2, code: 'cold', name: 'ครัวเย็น', icon: '🥗'),
          KitchenStation(id: 3, code: 'bar', name: 'บาร์', icon: '🥤'),
          KitchenStation(
            id: 4,
            code: 'grill',
            name: 'เตาย่างหน้าร้าน',
            icon: '🔥',
          ),
        ],
        size: const Size(360, 640),
      );

      expect(tester.takeException(), isNull);
      expect(find.text('ทุกสถานี'), findsOneWidget);
    },
  );
}
