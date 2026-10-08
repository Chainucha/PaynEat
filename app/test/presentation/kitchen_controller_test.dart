// Copyright 2026 Suruch Chakrapeesirisuk
// SPDX-License-Identifier: Apache-2.0

import 'package:fake_async/fake_async.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:payneat_pos/core/constants/app_constants.dart';
import 'package:payneat_pos/core/errors/failures.dart';
import 'package:payneat_pos/core/utils/app_clock.dart';
import 'package:payneat_pos/core/network/socket_client.dart';
import 'package:payneat_pos/core/services/chime_player.dart';
import 'package:payneat_pos/core/services/session_service.dart';
import 'package:payneat_pos/core/services/storage_service.dart';
import 'package:payneat_pos/core/usecases/result.dart';
import 'package:payneat_pos/features/auth/domain/entities/user.dart';
import 'package:payneat_pos/features/order/domain/entities/order.dart';
import 'package:payneat_pos/features/order/domain/entities/order_item.dart';
import 'package:payneat_pos/features/order/domain/repositories/order_repository.dart';
import 'package:payneat_pos/features/order/domain/usecases/order_usecases.dart';
import 'package:payneat_pos/features/menu/domain/entities/kitchen_station.dart';
import 'package:payneat_pos/features/menu/domain/repositories/menu_repository.dart';
import 'package:payneat_pos/features/menu/domain/usecases/menu_usecases.dart';
import 'package:payneat_pos/features/kitchen/presentation/controllers/kitchen_controller.dart';

class _FakeOrderRepository implements OrderRepository {
  Result<List<OrderItem>> nextQueueResult = const Result.success([]);
  Result<Order> nextUpdateItemStatusResult = Result.success(_order());
  final statusCalls = <String>[];

  @override
  Future<Result<List<OrderItem>>> getKitchenQueue({
    List<String>? statuses,
  }) async => nextQueueResult;

  @override
  Future<Result<Order>> updateItemStatus(
    int orderId,
    int itemId,
    String status,
  ) async {
    statusCalls.add('$itemId:$status');
    return nextUpdateItemStatusResult;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/// repository ของเมนู ใช้เฉพาะดึงรายการสถานีมาทำชิปกรองบนจอครัว (ticket 34)
class _FakeMenuRepository implements MenuRepository {
  Result<List<KitchenStation>> nextStationsResult = const Result.success([]);

  @override
  Future<Result<List<KitchenStation>>> getKitchenStations({
    bool activeOnly = false,
  }) async => nextStationsResult;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeChime implements ChimePlayer {
  _FakeChime({this.startsLocked = false});

  @override
  final bool startsLocked;
  int plays = 0;
  int unlocks = 0;
  bool playResult = true;
  bool playThrows = false;
  bool unlockThrows = false;

  @override
  Future<bool> play() async {
    plays++;
    if (playThrows) throw StateError('play boom');
    return playResult;
  }

  @override
  Future<bool> unlock() async {
    unlocks++;
    if (unlockThrows) throw StateError('unlock boom');
    return true;
  }
}

KitchenStation _station(int id, String code, {bool isDefault = false}) =>
    KitchenStation(id: id, code: code, name: code, isDefault: isDefault);

Order _order({int id = 1}) => Order(
  id: id,
  code: 'A001',
  type: 'dine_in',
  status: 'open',
  subtotal: 100,
  total: 100,
);

OrderItem _item(
  int id, {
  int orderId = 1,
  String status = OrderItemStatus.pending,
  String? createdAt,
  String? stationCode,
}) => OrderItem(
  id: id,
  orderId: orderId,
  name: 'ข้าวผัด',
  unitPrice: 50,
  quantity: 1,
  lineTotal: 50,
  status: status,
  createdAt: createdAt,
  stationCode: stationCode,
);

void main() {
  late _FakeOrderRepository repository;
  late _FakeMenuRepository menuRepository;
  late SessionService session;
  late StorageService storage;
  late KitchenController controller;

  KitchenController buildController() => KitchenController(
    getQueue: GetKitchenQueueUseCase(repository),
    updateItemStatus: UpdateOrderItemStatusUseCase(repository),
    session: session,
    getStations: GetKitchenStationsUseCase(menuRepository),
    storage: storage,
  );

  setUp(() {
    repository = _FakeOrderRepository();
    menuRepository = _FakeMenuRepository();
    storage = StorageService.memory();
    session = SessionService(storage: storage, socket: SocketClient());
    controller = buildController();
  });

  tearDown(() => controller.onClose());

  group('KitchenController', () {
    test('load สำเร็จ → เติมคิวและปิด loading', () async {
      repository.nextQueueResult = Result.success([_item(1), _item(2)]);

      await controller.load();

      expect(controller.queue.length, 2);
      expect(controller.isLoading.value, isFalse);
      expect(controller.errorMessage.value, isNull);
    });

    test('load ล้มเหลว → ตั้ง errorMessage', () async {
      repository.nextQueueResult = Result.failure(
        NetworkFailure('ต่อเซิร์ฟเวอร์ไม่ได้'),
      );

      await controller.load();

      expect(controller.errorMessage.value, 'ต่อเซิร์ฟเวอร์ไม่ได้');
    });

    test('byStatus/pending/cooking/ready แบ่งกลุ่มตามสถานะจริง', () async {
      repository.nextQueueResult = Result.success([
        _item(1, status: OrderItemStatus.pending),
        _item(2, status: OrderItemStatus.cooking),
        _item(3, status: OrderItemStatus.ready),
        _item(4, status: OrderItemStatus.pending),
      ]);
      await controller.load();

      expect(controller.pending.map((i) => i.id), [1, 4]);
      expect(controller.cooking.map((i) => i.id), [2]);
      expect(controller.ready.map((i) => i.id), [3]);
    });

    test(
      'lateCount/isLate นับเฉพาะรายการที่รอเกิน 15 นาทีและยังไม่พร้อมเสิร์ฟ',
      () async {
        final longAgo = DateTime.now()
            .subtract(const Duration(minutes: 20))
            .toIso8601String();
        final justNow = DateTime.now().toIso8601String();
        repository.nextQueueResult = Result.success([
          _item(1, status: OrderItemStatus.pending, createdAt: longAgo),
          _item(2, status: OrderItemStatus.cooking, createdAt: justNow),
          _item(3, status: OrderItemStatus.ready, createdAt: longAgo),
        ]);
        await controller.load();

        expect(controller.lateCount, 1);
        expect(controller.isLate(controller.queue[0]), isTrue);
        expect(controller.isLate(controller.queue[1]), isFalse);
      },
    );

    test(
      'advance สำเร็จ (ยังไม่ served) → โหลดคิวใหม่จากเซิร์ฟเวอร์',
      () async {
        repository.nextQueueResult = Result.success([
          _item(1, status: OrderItemStatus.pending),
        ]);
        await controller.load();

        repository.nextUpdateItemStatusResult = Result.success(_order());
        repository.nextQueueResult = Result.success([
          _item(1, status: OrderItemStatus.cooking),
        ]);

        await controller.advance(controller.queue.first);
        await Future<void>.delayed(Duration.zero);

        expect(controller.queue.single.status, OrderItemStatus.cooking);
      },
    );

    test(
      'advance สำเร็จ (ready → served) → ลบออกจากคิวในเครื่องทันที',
      () async {
        repository.nextQueueResult = Result.success([
          _item(1, status: OrderItemStatus.ready),
        ]);
        await controller.load();

        repository.nextUpdateItemStatusResult = Result.success(_order());

        await controller.advance(controller.queue.first);

        expect(controller.queue, isEmpty);
      },
    );

    test(
      'advance เมื่อไม่มีสถานะถัดไป (served/cancelled) → ไม่ทำอะไร',
      () async {
        repository.nextQueueResult = Result.success([
          _item(1, status: OrderItemStatus.served),
        ]);
        await controller.load();

        await controller.advance(controller.queue.first);

        expect(controller.queue.single.status, OrderItemStatus.served);
      },
    );

    // กดผิดในครัวต้องย้อนได้ (DECISIONS #64) — ส่งสถานะเดิมกลับไปหนึ่งขั้น แล้วแถบเลิกทำหายไป
    test(
      'advance แล้ว undoLast → ส่งสถานะเดิมกลับไปที่เซิร์ฟเวอร์ และแถบเลิกทำหาย',
      () async {
        repository.nextQueueResult = Result.success([
          _item(7, status: OrderItemStatus.cooking),
        ]);
        await controller.load();

        await controller.advance(controller.queue.first);
        expect(controller.lastChange.value?.from, OrderItemStatus.cooking);
        expect(controller.lastChange.value?.to, OrderItemStatus.ready);

        await controller.undoLast();
        expect(repository.statusCalls, ['7:ready', '7:cooking']);
        expect(controller.lastChange.value, isNull);

        // กดซ้ำไม่มีอะไรให้ย้อนแล้ว
        await controller.undoLast();
        expect(repository.statusCalls, hasLength(2));
      },
    );

    test(
      'เสิร์ฟแล้ว (served) ไม่มีแถบเลิกทำ — backend ไม่ยอมย้อนจาก served',
      () async {
        repository.nextQueueResult = Result.success([
          _item(8, status: OrderItemStatus.ready),
        ]);
        await controller.load();

        await controller.advance(controller.queue.first);

        expect(controller.lastChange.value, isNull);
      },
    );

    testWidgets('แถบเลิกทำหายเองหลังหมดเวลา', (tester) async {
      repository.nextQueueResult = Result.success([
        _item(9, status: OrderItemStatus.pending),
      ]);
      await controller.load();
      await controller.advance(controller.queue.first);
      expect(controller.lastChange.value, isNotNull);

      await tester.pump(KitchenController.undoWindow);
      expect(controller.lastChange.value, isNull);
    });

    testWidgets(
      'เดินสถานะไม่สำเร็จ (409 จาก backend เช่นบิลปิดแล้ว) → จอครัวแสดงเหตุผล คิวเดิมอยู่ครบ และไม่มีแถบเลิกทำ',
      (tester) async {
        const message = 'ออเดอร์นี้ปิดแล้ว ไม่สามารถแก้ไขได้';
        await tester.pumpWidget(const GetMaterialApp(home: Scaffold()));
        repository.nextQueueResult = Result.success([
          _item(11, status: OrderItemStatus.cooking),
        ]);
        repository.nextUpdateItemStatusResult = const Result.failure(
          ServerFailure(message, statusCode: 409),
        );
        await controller.load();

        await controller.advance(controller.queue.first);
        await tester.pump();

        expect(find.text(message), findsOneWidget);
        expect(controller.queue.map((item) => item.id), [11]);
        expect(controller.lastChange.value, isNull);

        // ให้ snackbar ปิดเองจนหมดเวลา ไม่ค้าง timer ข้ามเทสต์
        await tester.pump(const Duration(seconds: 5));
        await tester.pumpAndSettle();
      },
    );

    test(
      'onInit แล้ว onClose ต้องไม่โยน exception (unsubscribe/timer ครบ)',
      () {
        expect(() => controller.onInit(), returnsNormally);
        expect(() => controller.onClose(), returnsNormally);
      },
    );
  });

  group('KitchenController — ชิปกรองสถานี (ticket 34)', () {
    final stations = [
      _station(1, KitchenStationFilter.hot, isDefault: true),
      _station(3, KitchenStationFilter.bar),
    ];

    setUp(() {
      menuRepository.nextStationsResult = Result.success(stations);
      repository.nextQueueResult = Result.success([
        _item(1, stationCode: KitchenStationFilter.hot),
        _item(2, stationCode: KitchenStationFilter.bar),
        _item(3, stationCode: KitchenStationFilter.bar),
      ]);
    });

    test('ยังไม่เลือกอะไร → เห็นทุกสถานี', () async {
      await controller.load();

      expect(controller.selectedStationCode.value, isNull);
      expect(controller.visibleQueue.length, 3);
      expect(controller.pending.length, 3);
    });

    test('เลือกสถานี → คอลัมน์และตัวนับจานช้ากรองตามสถานีนั้น', () async {
      // ตรึงนาฬิกาไว้ เพื่อให้ "รอมาแล้ว 40 นาที" เป็นจริงแน่นอนไม่ว่าเครื่องที่รันตั้งโซนเวลาไว้อย่างไร
      final now = DateTime(2026, 10, 4, 12);
      AppClock.freeze(now);
      addTearDown(AppClock.unfreeze);
      // backend เก็บเวลาเป็น UTC และ Formatters.parse ก็อ่านแบบ UTC จึงต้องสร้างค่าเป็น UTC
      // ไม่ใช่เวลาท้องถิ่น ไม่งั้นเครื่องที่ไม่ได้ตั้งโซนเวลาเป็น UTC จะคำนวณเวลารอผิด
      final longAgo = now
          .subtract(const Duration(minutes: 40))
          .toUtc()
          .toIso8601String();

      repository.nextQueueResult = Result.success([
        _item(1, stationCode: KitchenStationFilter.hot, createdAt: longAgo),
        _item(2, stationCode: KitchenStationFilter.bar),
      ]);
      await controller.load();
      expect(controller.lateCount, 1);

      await controller.selectStation(KitchenStationFilter.bar);

      expect(controller.visibleQueue.length, 1);
      expect(controller.pending.single.id, 2);
      // จานช้าของครัวร้อนไม่ใช่งานของบาร์ แท็บเล็ตบาร์จึงต้องไม่ขึ้นเตือน
      expect(controller.lateCount, 0);
    });

    test(
      'สถานีที่เลือกถูกจำไว้ต่อเครื่อง และ controller ตัวใหม่กู้คืนได้',
      () async {
        await controller.selectStation(KitchenStationFilter.bar);
        expect(storage.kitchenStation, KitchenStationFilter.bar);

        final revived = buildController();
        revived.onInit();
        await Future<void>.delayed(Duration.zero);

        expect(revived.selectedStationCode.value, KitchenStationFilter.bar);
        revived.onClose();
      },
    );

    test('สถานีที่จำไว้ไม่มีอยู่แล้ว → กลับไปทุกสถานี', () async {
      await storage.saveKitchenStation('ghost');

      final revived = buildController();
      revived.onInit();
      await Future<void>.delayed(Duration.zero);

      expect(revived.selectedStationCode.value, isNull);
      expect(storage.kitchenStation, KitchenStationFilter.all);
      revived.onClose();
    });

    test(
      'ตั๋วที่ไม่มีสถานี → โผล่ที่ชิปสถานีค่าเริ่มต้น ไม่หายไปจากทุกชิป',
      () async {
        repository.nextQueueResult = Result.success([_item(9)]);
        await controller.load();
        await controller.selectStation(null);
        controller.stations.assignAll(stations);

        await controller.selectStation(KitchenStationFilter.hot);
        expect(controller.visibleQueue.single.id, 9);

        await controller.selectStation(KitchenStationFilter.bar);
        expect(controller.visibleQueue, isEmpty);
      },
    );

    test('บัญชีผูกสถานีไว้ → จอเปิดมาที่สถานีนั้นให้เลย (ticket 35)', () async {
      session.updateUser(
        const User(
          id: 9,
          name: 'เชฟบาร์',
          username: 'barchef',
          role: UserRole.kitchen,
          isActive: true,
          stationIds: [3],
          stationCodes: [KitchenStationFilter.bar],
        ),
      );

      final revived = buildController();
      revived.onInit();
      await Future<void>.delayed(Duration.zero);

      expect(revived.selectedStationCode.value, KitchenStationFilter.bar);
      // แค่เลือกให้ล่วงหน้า ไม่ได้จำลงเครื่อง — เครื่องยังไม่เคยตั้งค่าเอง
      expect(storage.kitchenStation, isNull);
      revived.onClose();
    });

    test(
      'ค่าที่เครื่องเคยเลือกทับค่าของบัญชี รวมถึงตอนเลือก "ทุกสถานี"',
      () async {
        session.updateUser(
          const User(
            id: 9,
            name: 'เชฟบาร์',
            username: 'barchef',
            role: UserRole.kitchen,
            isActive: true,
            stationIds: [3],
            stationCodes: [KitchenStationFilter.bar],
          ),
        );
        await storage.saveKitchenStation(KitchenStationFilter.all);

        final revived = buildController();
        revived.onInit();
        await Future<void>.delayed(Duration.zero);

        expect(revived.selectedStationCode.value, isNull);
        revived.onClose();
      },
    );

    test('ดึงรายการสถานีไม่สำเร็จ → ซ่อนชิป แต่ตั๋วทุกใบยังแสดงอยู่', () async {
      menuRepository.nextStationsResult = Result.failure(ServerFailure('ล่ม'));

      controller.onInit();
      await Future<void>.delayed(Duration.zero);

      expect(controller.stations, isEmpty);
      expect(controller.visibleQueue.length, 3);
    });
  });

  group('KitchenController — ตั๋วเข้า (ticket 37)', () {
    late _FakeChime chime;
    late KitchenController kds;
    final t0 = DateTime(2026, 10, 8, 18);

    KitchenController build({StorageService? store}) => KitchenController(
      getQueue: GetKitchenQueueUseCase(repository),
      updateItemStatus: UpdateOrderItemStatusUseCase(repository),
      session: session,
      getStations: GetKitchenStationsUseCase(menuRepository),
      storage: store ?? storage,
      chime: chime,
    );

    Future<void> loadWith(List<OrderItem> rows) async {
      repository.nextQueueResult = Result.success(rows);
      await kds.load();
    }

    setUp(() {
      AppClock.freeze(t0);
      chime = _FakeChime();
      kds = build();
    });

    tearDown(() {
      kds.onClose();
      AppClock.unfreeze();
    });

    test(
      'โหลดแรกตั้ง baseline ไม่ดัง — รายการ pending ใหม่ในรอบถัดไปดังและขึ้น "ใหม่"',
      () async {
        await loadWith([_item(1), _item(2), _item(3)]);
        expect(chime.plays, 0);
        expect(kds.newItems, isEmpty);

        await loadWith([_item(1), _item(2), _item(3), _item(4)]);
        expect(chime.plays, 1);
        expect(kds.isNew(_item(4)), isTrue);
        expect(kds.isNew(_item(1)), isFalse);
      },
    );

    test('โหลดแรกล้มเหลว → รอบที่สำเร็จรอบแรกเป็น baseline ไม่ดัง', () async {
      repository.nextQueueResult = Result.failure(NetworkFailure('หลุด'));
      await kds.load();
      await loadWith([_item(1), _item(2)]);
      expect(chime.plays, 0);
    });

    test('เปลี่ยนสถานะ และเลิกทำถอยกลับ pending ไม่ใช่ตั๋วเข้า', () async {
      await loadWith([_item(1)]);
      await loadWith([_item(1, status: OrderItemStatus.cooking)]);
      await loadWith([_item(1)]);
      expect(chime.plays, 0);
    });

    test(
      'เลือกชิปบาร์ → รายการของครัวร้อนเข้ามาไม่ดัง และสลับชิปทีหลังก็ไม่ดังย้อน',
      () async {
        kds.stations.assignAll([
          _station(1, 'hot', isDefault: true),
          _station(3, 'bar'),
        ]);
        await kds.selectStation('bar');
        await loadWith([_item(1, stationCode: 'bar')]);

        await loadWith([
          _item(1, stationCode: 'bar'),
          _item(2, stationCode: 'hot'),
        ]);
        expect(chime.plays, 0);

        await kds.selectStation('hot');
        await loadWith([
          _item(1, stationCode: 'bar'),
          _item(2, stationCode: 'hot'),
        ]);
        expect(chime.plays, 0);

        await loadWith([
          _item(1, stationCode: 'bar'),
          _item(2, stationCode: 'hot'),
          _item(5, stationCode: 'hot'),
        ]);
        expect(chime.plays, 1);
      },
    );

    test(
      'ตั๋วเข้าติดกันภายในช่วงพัก → ดังครั้งเดียว ทุกใบขึ้น "ใหม่"; พ้นช่วงพักแล้วดังใหม่',
      () async {
        await loadWith([_item(1)]);
        await loadWith([_item(1), _item(2), _item(3)]);
        AppClock.freeze(t0.add(const Duration(seconds: 1)));
        await loadWith([_item(1), _item(2), _item(3), _item(4)]);
        expect(chime.plays, 1);
        expect(kds.newItems.keys, containsAll([2, 3, 4]));

        AppClock.freeze(t0.add(const Duration(seconds: 5)));
        await loadWith([_item(1), _item(2), _item(3), _item(4), _item(6)]);
        expect(chime.plays, 2);
      },
    );

    test(
      'ตอน socket หลุด ตั๋วที่มาทาง polling ก็ดัง (ทางเดียวกันคือ load)',
      () async {
        kds.isOffline.value = true;
        await loadWith([_item(1)]);
        await loadWith([_item(1), _item(2)]);
        expect(chime.plays, 1);
      },
    );

    test('ป้าย "ใหม่" หายเมื่อแตะ / สถานะเปลี่ยน / ครบ 2 นาที', () async {
      await loadWith([_item(1)]);
      await loadWith([_item(1), _item(2), _item(3), _item(4)]);

      kds.acknowledge(_item(2));
      expect(kds.isNew(_item(2)), isFalse);

      await loadWith([
        _item(1),
        _item(3, status: OrderItemStatus.cooking),
        _item(4),
      ]);
      expect(kds.isNew(_item(3)), isFalse);

      AppClock.freeze(t0.add(KitchenController.highlightWindow));
      expect(kds.isNew(_item(4)), isFalse);
    });

    test(
      'ปิดเสียง → ไม่ดังแต่ยังไฮไลต์ และค่าที่ปิดไว้รอดการสร้าง controller ใหม่',
      () async {
        await kds.toggleMute();
        expect(kds.muted.value, isTrue);

        await loadWith([_item(1)]);
        await loadWith([_item(1), _item(2)]);
        expect(chime.plays, 0);
        expect(kds.isNew(_item(2)), isTrue);

        final revived = build();
        expect(revived.muted.value, isTrue);
        revived.onClose();
      },
    );

    test('เบราว์เซอร์บล็อกเสียง → soundLocked; แตะปลดล็อกแล้วหาย', () async {
      chime.playResult = false;
      await loadWith([_item(1)]);
      await loadWith([_item(1), _item(2)]);
      await Future<void>.delayed(Duration.zero);
      expect(kds.soundLocked.value, isTrue);

      await kds.unlockSound();
      expect(chime.unlocks, 1);
      expect(kds.soundLocked.value, isFalse);
    });

    test('play() โยน error → soundLocked ไม่มี error หลุด', () async {
      chime.playThrows = true;
      await loadWith([_item(1)]);
      await loadWith([_item(1), _item(2)]);
      await Future<void>.delayed(Duration.zero);
      expect(chime.plays, 1);
      expect(kds.soundLocked.value, isTrue);
    });

    test('unlock() โยน error → soundLocked ยังเป็น true', () async {
      chime.playResult = false;
      await loadWith([_item(1)]);
      await loadWith([_item(1), _item(2)]);
      await Future<void>.delayed(Duration.zero);
      chime.unlockThrows = true;
      await kds.unlockSound();
      expect(chime.unlocks, 1);
      expect(kds.soundLocked.value, isTrue);
    });

    test('advance() ตั๋วที่เพิ่งเข้า → ป้าย "ใหม่" หายทันที', () async {
      await loadWith([_item(1)]);
      await loadWith([_item(1), _item(2)]);
      expect(kds.isNew(_item(2)), isTrue);
      await kds.advance(_item(2));
      expect(kds.isNew(_item(2)), isFalse);
    });

    test(
      'timer จริง: socket หลุด → polling ทุก 30 วิ ดังเมื่อมีตั๋วใหม่ และล้างป้ายที่ครบ 2 นาที',
      () {
        fakeAsync((async) {
          repository.nextQueueResult = Result.success([_item(1)]);
          kds.onInit();
          async.flushMicrotasks();
          kds.isOffline.value = true;
          expect(chime.plays, 0);

          repository.nextQueueResult = Result.success([_item(1), _item(2)]);
          async.elapse(const Duration(seconds: 30));
          async.flushMicrotasks();
          expect(chime.plays, 1);
          expect(kds.newItems.keys, contains(2));

          // เลย highlightWindow แล้ว timer ต้องล้างป้ายออกจาก newItems เอง
          AppClock.freeze(t0.add(KitchenController.highlightWindow));
          async.elapse(const Duration(seconds: 30));
          async.flushMicrotasks();
          expect(kds.newItems, isEmpty);
          kds.onClose();
        });
      },
    );

    test('ChimePlayer ที่เริ่มแบบล็อก (เว็บ) → soundLocked ตั้งแต่สร้าง', () {
      chime = _FakeChime(startsLocked: true);
      final web = build();
      expect(web.soundLocked.value, isTrue);
      web.onClose();
    });
  });
}
