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
import 'package:payneat_pos/features/kitchen/presentation/controllers/station_status_controller.dart';
import 'package:payneat_pos/features/kitchen/presentation/widgets/station_closed_banner.dart';
import 'package:payneat_pos/features/kitchen/presentation/widgets/station_status_sheet.dart';
import 'package:payneat_pos/features/menu/domain/entities/station_status.dart';
import 'package:payneat_pos/features/menu/domain/repositories/menu_repository.dart';
import 'package:payneat_pos/features/menu/domain/usecases/menu_usecases.dart';

class _FakeMenuRepository implements MenuRepository {
  final calls = <String>[];

  // onInit ของ controller โหลดสถานะทันที — ตอบว่างไว้ ให้ test ตั้งค่า statuses เอง
  @override
  Future<Result<List<StationStatus>>> getStationStatuses() async =>
      Result.success(const <StationStatus>[]);

  @override
  Future<Result<StationStatus>> setStationClosed(
    int stationId, {
    required bool closed,
  }) async {
    calls.add('$stationId:$closed');
    return Result.success(
      StationStatus(
        stationId: stationId,
        code: 'hot',
        name: 'ครัวร้อน',
        isClosed: closed,
      ),
    );
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  late _FakeMenuRepository repository;
  late StationStatusController controller;

  setUp(() {
    repository = _FakeMenuRepository();
    controller = StationStatusController(
      getStatuses: GetStationStatusesUseCase(repository),
      setClosed: SetStationClosedUseCase(repository),
      session: SessionService(
        storage: StorageService.memory(),
        socket: SocketClient(),
      ),
    );
    Get.put<StationStatusController>(controller);
  });

  tearDown(Get.reset);

  Future<void> pump(WidgetTester tester, Widget child) async {
    tester.view.physicalSize = const Size(360, 720);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      GetMaterialApp(
        translations: AppTranslations(),
        locale: LocaleService.thai,
        home: Scaffold(body: child),
      ),
    );
    await tester.pump();
  }

  testWidgets(
    'แบนเนอร์ว่างเมื่อไม่มีสถานีปิด และขึ้นชื่อสถานี/คนปิดเมื่อมี — ไม่ล้นที่ 360px',
    (tester) async {
      await pump(tester, const StationClosedBanner());
      expect(find.byType(Text), findsNothing);

      controller.statuses.assignAll(const [
        StationStatus(
          stationId: 3,
          code: 'bar',
          name: 'บาร์เครื่องดื่มและของหวานชื่อยาวมาก',
          isClosed: true,
          closedAt: '2026-10-08 14:03:00',
          closedByName: 'สมชาย (ผู้จัดการ)',
        ),
      ]);
      await tester.pump();
      expect(find.textContaining('บาร์เครื่องดื่ม'), findsOneWidget);
      expect(find.textContaining('สมชาย'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('ชีต: สวิตช์ปิดสถานีที่ไม่มีรายการค้าง → ปิดทันทีโดยไม่ถาม', (
    tester,
  ) async {
    controller.statuses.assignAll(const [
      StationStatus(stationId: 1, code: 'hot', name: 'ครัวร้อน'),
    ]);
    await pump(tester, const StationStatusSheet());

    await tester.tap(find.byType(Switch));
    await tester.pumpAndSettle();

    expect(repository.calls, ['1:true']);
    expect(controller.closed.single.stationId, 1);
    expect(tester.takeException(), isNull);
  });
}
