// Copyright 2026 Suruch Chakrapeesirisuk
// SPDX-License-Identifier: Apache-2.0

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:payneat_pos/core/constants/app_constants.dart';
import 'package:payneat_pos/core/localization/app_translations.dart';
import 'package:payneat_pos/core/localization/locale_service.dart';
import 'package:payneat_pos/core/network/socket_client.dart';
import 'package:payneat_pos/core/services/chime_player.dart';
import 'package:payneat_pos/core/services/session_service.dart';
import 'package:payneat_pos/core/services/storage_service.dart';
import 'package:payneat_pos/core/usecases/result.dart';
import 'package:payneat_pos/features/kitchen/presentation/controllers/kitchen_controller.dart';
import 'package:payneat_pos/features/kitchen/presentation/widgets/chime_controls.dart';
import 'package:payneat_pos/features/kitchen/presentation/widgets/kitchen_ticket_card.dart';
import 'package:payneat_pos/features/menu/domain/entities/kitchen_station.dart';
import 'package:payneat_pos/features/menu/domain/repositories/menu_repository.dart';
import 'package:payneat_pos/features/menu/domain/usecases/menu_usecases.dart';
import 'package:payneat_pos/features/order/domain/entities/order_item.dart';
import 'package:payneat_pos/features/order/domain/repositories/order_repository.dart';
import 'package:payneat_pos/features/order/domain/usecases/order_usecases.dart';

/// เสียงเตือนตั๋วเข้า (ticket 37) — ป้าย "ใหม่", ปุ่มปิดเสียง, แถบปลดล็อกเสียงบนเว็บ ที่ 360px
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
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _LockedChime implements ChimePlayer {
  int unlocks = 0;

  @override
  bool get startsLocked => true;

  @override
  Future<bool> play() async => false;

  @override
  Future<bool> unlock() async {
    unlocks++;
    return true;
  }
}

const _ticket = OrderItem(
  id: 7,
  orderId: 1,
  name: 'ผัดกะเพราหมูกรอบไข่ดาวไม่สุกพิเศษ',
  unitPrice: 75,
  quantity: 1,
  lineTotal: 75,
  status: OrderItemStatus.pending,
  tableName: 'VIP2',
);

/// ชื่อโต๊ะยาว — ให้ Flexible/ellipsis ในหัวการ์ดทำงานจริงที่ 360px
const _longTicket = OrderItem(
  id: 8,
  orderId: 2,
  name: 'ผัดกะเพรา',
  unitPrice: 75,
  quantity: 1,
  lineTotal: 75,
  status: OrderItemStatus.pending,
  tableName: 'ห้องจัดเลี้ยงชั้นสองฝั่งริมแม่น้ำ VIP',
);

void main() {
  late _LockedChime chime;
  late StorageService storage;
  late KitchenController controller;

  setUp(() {
    chime = _LockedChime();
    storage = StorageService.memory();
    controller = KitchenController(
      getQueue: GetKitchenQueueUseCase(_FakeOrderRepository()),
      updateItemStatus: UpdateOrderItemStatusUseCase(_FakeOrderRepository()),
      session: SessionService(storage: storage, socket: SocketClient()),
      getStations: GetKitchenStationsUseCase(_FakeMenuRepository()),
      storage: storage,
      chime: chime,
    );
    Get.put<KitchenController>(controller);
  });

  tearDown(() {
    controller.onClose();
    Get.reset();
  });

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
    'การ์ดตั๋วเข้าใหม่มีป้าย "ใหม่" แตะแล้วเรียก onTap — ไม่ล้นที่ 360px',
    (tester) async {
      var taps = 0;
      await pump(
        tester,
        KitchenTicketCard(
          item: _longTicket,
          isLate: false,
          isNew: true,
          onAdvance: () {},
          onTap: () => taps++,
        ),
      );

      expect(find.text('ใหม่'), findsOneWidget);
      await tester.tap(find.text('ใหม่'));
      expect(taps, 1);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'แถบ "แตะเพื่อเปิดเสียง" ขึ้นตอนล็อก แตะแล้วหาย; ปิดเสียงอยู่ไม่ขึ้นแถบ',
    (tester) async {
      await pump(tester, const Column(children: [SoundUnlockBar()]));
      expect(find.text('แตะเพื่อเปิดเสียงแจ้งเตือนตั๋วใหม่'), findsOneWidget);

      await tester.tap(find.text('แตะเพื่อเปิดเสียงแจ้งเตือนตั๋วใหม่'));
      await tester.pump();
      expect(chime.unlocks, 1);
      expect(find.text('แตะเพื่อเปิดเสียงแจ้งเตือนตั๋วใหม่'), findsNothing);

      // ล็อกอยู่และไม่ได้ปิดเสียง → แถบต้องขึ้น (กันเทสต์ผ่านเพราะแถบไม่เคยขึ้น)
      controller.soundLocked.value = true;
      await tester.pump();
      expect(find.text('แตะเพื่อเปิดเสียงแจ้งเตือนตั๋วใหม่'), findsOneWidget);

      await controller.toggleMute();
      await tester.pump();
      expect(controller.muted.value, isTrue);
      expect(find.text('แตะเพื่อเปิดเสียงแจ้งเตือนตั๋วใหม่'), findsNothing);
    },
  );

  testWidgets('ป้าย "ใหม่" ไม่ทำให้การ์ดสูงขึ้น (ชื่อโต๊ะยาว 360px)', (
    tester,
  ) async {
    Future<double> heightOf(bool isNew) async {
      await pump(
        tester,
        SingleChildScrollView(
          child: KitchenTicketCard(
            item: _longTicket,
            isLate: false,
            isNew: isNew,
            onAdvance: () {},
          ),
        ),
      );
      return tester.getSize(find.byType(KitchenTicketCard)).height;
    }

    final plain = await heightOf(false);
    final badged = await heightOf(true);
    expect(badged, plain);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'กดปุ่มเดินสถานะ เรียก onAdvance อย่างเดียว ไม่เรียก onTap ของการ์ด',
    (tester) async {
      var advances = 0;
      var taps = 0;
      await pump(
        tester,
        SingleChildScrollView(
          child: KitchenTicketCard(
            item: _ticket,
            isLate: false,
            isNew: true,
            onAdvance: () => advances++,
            onTap: () => taps++,
          ),
        ),
      );

      await tester.tap(find.byType(FilledButton));
      expect(advances, 1);
      expect(taps, 0);
    },
  );

  testWidgets('ปุ่มลำโพงสลับปิด/เปิดเสียงและจำไว้ในเครื่อง', (tester) async {
    await pump(tester, const ChimeMuteButton());
    expect(find.byIcon(Icons.volume_up_rounded), findsOneWidget);

    await tester.tap(find.byType(ChimeMuteButton));
    await tester.pump();
    expect(find.byIcon(Icons.volume_off_rounded), findsOneWidget);
    expect(storage.kitchenChimeMuted, isTrue);
  });
}
