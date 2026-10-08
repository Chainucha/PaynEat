// Copyright 2026 Suruch Chakrapeesirisuk
// SPDX-License-Identifier: Apache-2.0

import 'package:flutter_test/flutter_test.dart';
import 'package:payneat_pos/core/errors/failures.dart';
import 'package:payneat_pos/core/network/socket_client.dart';
import 'package:payneat_pos/core/services/session_service.dart';
import 'package:payneat_pos/core/services/storage_service.dart';
import 'package:payneat_pos/core/usecases/result.dart';
import 'package:payneat_pos/features/kitchen/presentation/controllers/station_status_controller.dart';
import 'package:payneat_pos/features/menu/domain/entities/station_status.dart';
import 'package:payneat_pos/features/menu/domain/repositories/menu_repository.dart';
import 'package:payneat_pos/features/menu/domain/usecases/menu_usecases.dart';

class _FakeMenuRepository implements MenuRepository {
  List<StationStatus> statuses = [];
  Failure? nextFailure;
  int loads = 0;
  final calls = <String>[];

  @override
  Future<Result<List<StationStatus>>> getStationStatuses() async {
    loads++;
    return Result.success(List.of(statuses));
  }

  @override
  Future<Result<StationStatus>> setStationClosed(
    int stationId, {
    required bool closed,
  }) async {
    calls.add('$stationId:$closed');
    if (nextFailure != null) return Result.failure(nextFailure!);
    statuses = [
      for (final s in statuses)
        s.stationId == stationId
            ? _status(s.stationId, s.code, closed: closed)
            : s,
    ];
    return Result.success(statuses.firstWhere((s) => s.stationId == stationId));
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

StationStatus _status(
  int id,
  String code, {
  bool closed = false,
  int pending = 0,
}) => StationStatus(
  stationId: id,
  code: code,
  name: code,
  isClosed: closed,
  closedByName: closed ? 'เชฟต้น' : null,
  pendingCount: pending,
);

void main() {
  late _FakeMenuRepository repository;
  late SocketClient socket;
  late StationStatusController controller;

  setUp(() {
    repository = _FakeMenuRepository()
      ..statuses = [_status(1, 'hot'), _status(3, 'bar', pending: 2)];
    socket = SocketClient();
    controller = StationStatusController(
      getStatuses: GetStationStatusesUseCase(repository),
      setClosed: SetStationClosedUseCase(repository),
      session: SessionService(storage: StorageService.memory(), socket: socket),
    );
  });

  tearDown(() => controller.onClose());

  test('load เติมสถานะ และ closed คืนเฉพาะสถานีที่ปิด', () async {
    repository.statuses = [_status(1, 'hot'), _status(3, 'bar', closed: true)];
    await controller.load();
    expect(controller.statuses.length, 2);
    expect(controller.closed.single.code, 'bar');
  });

  test(
    'closedVersion ไม่ขยับตอนโหลดแรก ขยับเมื่อชุดสถานีที่ปิดเปลี่ยนเท่านั้น',
    () async {
      await controller.load();
      expect(controller.closedVersion.value, 0);

      await controller.load();
      expect(controller.closedVersion.value, 0, reason: 'โหลดซ้ำ ชุดเดิม');

      await controller.setClosed(controller.statuses.last, true);
      expect(repository.calls, ['3:true']);
      expect(controller.closed.single.code, 'bar');
      expect(controller.closedVersion.value, 1);
    },
  );

  test('event station:status → โหลดสถานะใหม่จากเซิร์ฟเวอร์', () async {
    controller.onInit();
    await Future<void>.delayed(Duration.zero);
    final before = repository.loads;

    socket.dispatchLocal(SocketEvents.stationStatus, {'branchId': 1});
    await Future<void>.delayed(Duration.zero);

    expect(repository.loads, before + 1);
  });

  test('ปิดไม่สำเร็จ → คืน false และสถานะเดิมไม่เปลี่ยน', () async {
    await controller.load();
    repository.nextFailure = const ServerFailure('สิทธิ์ไม่เพียงพอ');
    final ok = await controller.setClosed(controller.statuses.last, true);
    expect(ok, isFalse);
    expect(controller.closed, isEmpty);
  });
}
