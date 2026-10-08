// Copyright 2026 Suruch Chakrapeesirisuk
// SPDX-License-Identifier: Apache-2.0

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:payneat_pos/core/errors/failures.dart';
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
  Failure? nextFailure;
  Failure? loadFailure;

  // onInit ของ controller โหลดสถานะทันที — ตอบว่างไว้ ให้ test ตั้งค่า statuses เอง
  @override
  Future<Result<List<StationStatus>>> getStationStatuses() async =>
      loadFailure != null
      ? Result.failure(loadFailure!)
      : Result.success(const <StationStatus>[]);

  @override
  Future<Result<StationStatus>> setStationClosed(
    int stationId, {
    required bool closed,
  }) async {
    calls.add('$stationId:$closed');
    if (nextFailure != null) return Result.failure(nextFailure!);
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

  Future<void> pump(
    WidgetTester tester,
    Widget child, {
    double height = 720,
  }) async {
    tester.view.physicalSize = Size(360, height);
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

  const pendingStation = [
    StationStatus(stationId: 3, code: 'bar', name: 'บาร์', pendingCount: 2),
  ];

  testWidgets('ชีต: ปิดสถานีที่มีรายการค้าง → ถามก่อน แล้วยืนยัน → ปิด', (
    tester,
  ) async {
    controller.statuses.assignAll(pendingStation);
    await pump(tester, const StationStatusSheet());

    await tester.tap(find.byType(Switch));
    await tester.pumpAndSettle();
    expect(find.textContaining('ยังมี 2 รายการค้าง'), findsOneWidget);
    expect(repository.calls, isEmpty);

    await tester.tap(find.text('ปิดสถานี'));
    await tester.pumpAndSettle();

    expect(repository.calls, ['3:true']);
    expect(controller.closed.single.stationId, 3);
  });

  testWidgets('ชีต: มีรายการค้างแล้วกดยกเลิก → ไม่เรียก API สถานียังเปิด', (
    tester,
  ) async {
    controller.statuses.assignAll(pendingStation);
    await pump(tester, const StationStatusSheet());

    await tester.tap(find.byType(Switch));
    await tester.pumpAndSettle();
    await tester.tap(find.text('ยกเลิก'));
    await tester.pumpAndSettle();

    expect(repository.calls, isEmpty);
    expect(controller.closed, isEmpty);
    expect(tester.widget<Switch>(find.byType(Switch)).value, isTrue);
  });

  testWidgets('ชีต: ปิดไม่สำเร็จ → ขึ้น error และสถานียังเปิด', (tester) async {
    repository.nextFailure = const ServerFailure('สิทธิ์ไม่เพียงพอ');
    controller.statuses.assignAll(const [
      StationStatus(stationId: 1, code: 'hot', name: 'ครัวร้อน'),
    ]);
    await pump(tester, const StationStatusSheet());

    await tester.tap(find.byType(Switch));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    expect(repository.calls, ['1:true']);
    expect(find.text('สิทธิ์ไม่เพียงพอ'), findsOneWidget);
    expect(controller.closed, isEmpty);
    expect(tester.widget<Switch>(find.byType(Switch)).value, isTrue);
    await tester.pumpAndSettle(const Duration(seconds: 5));
  });

  testWidgets('ชีต: โหลดไม่สำเร็จและไม่มีแถว → ขึ้น error กับปุ่มลองใหม่', (
    tester,
  ) async {
    repository.loadFailure = const ServerFailure('เชื่อมต่อไม่ได้');
    await pump(tester, const StationStatusSheet());
    await controller.load();
    await tester.pump();

    expect(find.text('เชื่อมต่อไม่ได้'), findsOneWidget);
    expect(find.byType(Switch), findsNothing);

    repository.loadFailure = null;
    await tester.tap(find.text('ลองใหม่อีกครั้ง'));
    await tester.pump();
    expect(find.text('เชื่อมต่อไม่ได้'), findsNothing);
  });

  testWidgets('ชีต: สถานีเยอะบนจอเตี้ย 360x480 → เลื่อนได้ ไม่ล้น', (
    tester,
  ) async {
    controller.statuses.assignAll([
      for (var i = 1; i <= 8; i++)
        StationStatus(stationId: i, code: 's$i', name: 'สถานี $i'),
    ]);
    await pump(tester, const StationStatusSheet(), height: 480);
    expect(tester.takeException(), isNull);
  });
}
