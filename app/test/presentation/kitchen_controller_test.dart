// Copyright 2026 Suruch Chakrapeesirisuk
// SPDX-License-Identifier: Apache-2.0

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:payneat_pos/core/constants/app_constants.dart';
import 'package:payneat_pos/core/errors/failures.dart';
import 'package:payneat_pos/core/network/socket_client.dart';
import 'package:payneat_pos/core/services/session_service.dart';
import 'package:payneat_pos/core/services/storage_service.dart';
import 'package:payneat_pos/core/usecases/result.dart';
import 'package:payneat_pos/features/order/domain/entities/order.dart';
import 'package:payneat_pos/features/order/domain/entities/order_item.dart';
import 'package:payneat_pos/features/order/domain/repositories/order_repository.dart';
import 'package:payneat_pos/features/order/domain/usecases/order_usecases.dart';
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
}) => OrderItem(
  id: id,
  orderId: orderId,
  name: 'ข้าวผัด',
  unitPrice: 50,
  quantity: 1,
  lineTotal: 50,
  status: status,
  createdAt: createdAt,
);

void main() {
  late _FakeOrderRepository repository;
  late SessionService session;
  late KitchenController controller;

  setUp(() {
    repository = _FakeOrderRepository();
    session = SessionService(
      storage: StorageService.memory(),
      socket: SocketClient(),
    );
    controller = KitchenController(
      getQueue: GetKitchenQueueUseCase(repository),
      updateItemStatus: UpdateOrderItemStatusUseCase(repository),
      session: session,
    );
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
}
