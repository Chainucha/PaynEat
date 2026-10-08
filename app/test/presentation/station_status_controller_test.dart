// Copyright 2026 Suruch Chakrapeesirisuk
// SPDX-License-Identifier: Apache-2.0

import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:payneat_pos/core/errors/failures.dart';
import 'package:payneat_pos/core/network/socket_client.dart';
import 'package:payneat_pos/core/services/session_service.dart';
import 'package:payneat_pos/core/services/storage_service.dart';
import 'package:payneat_pos/core/usecases/result.dart';
import 'package:payneat_pos/features/auth/domain/entities/user.dart';
import 'package:payneat_pos/features/kitchen/presentation/controllers/station_status_controller.dart';
import 'package:payneat_pos/features/menu/domain/entities/station_status.dart';
import 'package:payneat_pos/features/menu/domain/repositories/menu_repository.dart';
import 'package:payneat_pos/features/menu/domain/usecases/menu_usecases.dart';

class _FakeMenuRepository implements MenuRepository {
  List<StationStatus> statuses = [];
  Failure? nextFailure;
  int loads = 0;
  Completer<Result<List<StationStatus>>>? pendingLoad;
  Completer<void>? gate;
  final calls = <String>[];

  @override
  Future<Result<List<StationStatus>>> getStationStatuses() async {
    loads++;
    final pending = pendingLoad;
    if (pending != null) {
      pendingLoad = null;
      return pending.future;
    }
    return Result.success(List.of(statuses));
  }

  @override
  Future<Result<StationStatus>> setStationClosed(
    int stationId, {
    required bool closed,
  }) async {
    calls.add('$stationId:$closed');
    await gate?.future;
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
  late SessionService session;
  late StationStatusController controller;

  setUp(() {
    repository = _FakeMenuRepository()
      ..statuses = [_status(1, 'hot'), _status(3, 'bar', pending: 2)];
    socket = SocketClient();
    session = SessionService(storage: StorageService.memory(), socket: socket);
    controller = StationStatusController(
      getStatuses: GetStationStatusesUseCase(repository),
      setClosed: SetStationClosedUseCase(repository),
      session: session,
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
    expect(controller.errorMessage.value, 'สิทธิ์ไม่เพียงพอ');
  });

  test(
    'admin โหมดทุกสาขา (ไม่มี branchId) → canUse เป็น false และ load ไม่เรียก API',
    () async {
      final session =
          SessionService(storage: StorageService.memory(), socket: socket)
            ..updateUser(
              const User(
                id: 1,
                name: 'admin',
                username: 'admin',
                role: 'admin',
                isActive: true,
              ),
            );
      final adminController = StationStatusController(
        getStatuses: GetStationStatusesUseCase(repository),
        setClosed: SetStationClosedUseCase(repository),
        session: session,
      );
      expect(adminController.canUse, isFalse);
      await adminController.load();
      expect(repository.loads, 0);
      expect(adminController.statuses, isEmpty);
    },
  );

  test('load เก่าที่ตอบช้ากว่า setClosed ไม่เขียนทับผลใหม่', () async {
    await controller.load();
    final slow = Completer<Result<List<StationStatus>>>();
    repository.pendingLoad = slow;
    final stale = controller.load();
    await controller.setClosed(controller.statuses.last, true);
    slow.complete(Result.success([_status(1, 'hot'), _status(3, 'bar')]));
    await stale;
    expect(controller.closed.single.code, 'bar');
  });

  test('กำลังสลับสถานีเดิมอยู่ → คำขอซ้ำถูกปฏิเสธ', () async {
    await controller.load();
    final gate = Completer<void>();
    repository.gate = gate;
    final first = controller.setClosed(controller.statuses.last, true);
    expect(controller.busyIds, {3});
    expect(await controller.setClosed(controller.statuses.last, true), isFalse);
    gate.complete();
    expect(await first, isTrue);
    expect(controller.busyIds, isEmpty);
    expect(repository.calls, ['3:true']);
  });

  test('socket ต่อใหม่ (false→true) → โหลดสถานะใหม่หนึ่งครั้ง', () async {
    controller.onInit();
    await Future<void>.delayed(Duration.zero);
    final before = repository.loads;

    socket.connected.value = true;
    await Future<void>.delayed(Duration.zero);
    expect(repository.loads, before + 1);

    // true→true ไม่ใช่การต่อใหม่ และ false ไม่โหลด
    socket.connected.value = false;
    await Future<void>.delayed(Duration.zero);
    expect(repository.loads, before + 1);
  });

  test('canUse เปลี่ยนเป็น false หลังมีข้อมูล → ล้าง statuses', () async {
    repository.statuses = [_status(1, 'hot'), _status(3, 'bar', closed: true)];
    await controller.load();
    expect(controller.statuses, isNotEmpty);

    session.updateUser(
      const User(
        id: 1,
        name: 'admin',
        username: 'admin',
        role: 'admin',
        isActive: true,
      ),
    );
    await controller.load();
    expect(controller.canUse, isFalse);
    expect(controller.statuses, isEmpty);
    expect(controller.closed, isEmpty);
  });

  test(
    'หลังล้างเพราะ canUse false แล้วกลับมาใช้ได้ ไม่นับเป็นการเปลี่ยนชุดสถานีปิด',
    () async {
      repository.statuses = [
        _status(1, 'hot'),
        _status(3, 'bar', closed: true),
      ];
      await controller.load();
      session.updateUser(
        const User(
          id: 1,
          name: 'admin',
          username: 'admin',
          role: 'admin',
          isActive: true,
        ),
      );
      await controller.load();
      session.updateUser(
        const User(
          id: 2,
          name: 'admin2',
          username: 'admin2',
          role: 'admin',
          isActive: true,
          branchId: 2,
        ),
      );
      await controller.load();
      expect(controller.closed.single.code, 'bar');
      expect(controller.closedVersion.value, 0);
    },
  );

  test(
    'setClosed สำเร็จระหว่างมี load ค้างอยู่ → ยังโหลดใหม่ตามหลัง ไม่ทิ้งการเปลี่ยนจากเครื่องอื่น',
    () async {
      await controller.load();
      final slow = Completer<Result<List<StationStatus>>>();
      repository.pendingLoad = slow;
      final inFlight = controller.load();
      // เครื่องอื่นปิด hot ไปแล้ว ขณะที่เครื่องนี้ปิด bar
      repository.statuses = [
        _status(1, 'hot', closed: true),
        _status(3, 'bar'),
      ];
      await controller.setClosed(controller.statuses.last, true);
      slow.complete(Result.success([_status(1, 'hot'), _status(3, 'bar')]));
      await inFlight;
      await Future<void>.delayed(Duration.zero);

      expect(
        controller.closed.map((s) => s.code),
        unorderedEquals(['hot', 'bar']),
      );
    },
  );
}
