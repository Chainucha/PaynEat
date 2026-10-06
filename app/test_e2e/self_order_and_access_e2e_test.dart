// Copyright 2026 Suruch Chakrapeesirisuk
// SPDX-License-Identifier: Apache-2.0

@Timeout(Duration(minutes: 3))
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:payneat_pos/core/errors/failures.dart';
import 'package:payneat_pos/core/usecases/result.dart';
import 'package:payneat_pos/features/auth/domain/entities/login_result.dart';
import 'package:payneat_pos/features/menu/domain/entities/menu_item.dart';
import 'package:payneat_pos/features/order/domain/entities/order.dart';
import 'package:payneat_pos/features/order/domain/entities/order_item_payload.dart';
import 'package:payneat_pos/features/self_order/domain/self_order_limits.dart';
import 'package:payneat_pos/features/self_order/domain/self_order_link.dart';
import 'package:payneat_pos/features/table/domain/entities/dining_table.dart';

import 'support/backend_process.dart';
import 'support/pos_device.dart';
import 'support/scenario.dart';

/// ลูกค้าสแกน QR สั่งเองจากมือถือตัวเอง (ticket 17) และขอบเขตการเข้าถึง: ล็อกอิน สาขา สิทธิ์ตามบทบาท
/// session หมดอายุ และพนักงานที่ถูกปิดบัญชี — ทั้งหมดยิงผ่านโค้ดชั้น data/domain ตัวจริงของแอปไปหา
/// backend ตัวจริง แบบเดียวกับ `restaurant_day_e2e_test.dart`
void main() {
  late BackendProcess backend;

  setUpAll(() async => backend = await BackendProcess.start());
  tearDownAll(() async => backend.stop());

  PosDevice device() => PosDevice(backend.apiBaseUrl);

  group('ลูกค้าสแกน QR ที่โต๊ะแล้วสั่งเอง — ไม่ต้องล็อกอิน', () {
    final flow = Scenario();
    late PosDevice waiter;
    late PosDevice kitchen;
    late PosDevice manager;
    late PosDevice customer;
    late DiningTable table;
    late String qrToken;
    late List<MenuItem> customerMenu;
    late Order order;

    setUpAll(() async {
      waiter = device();
      kitchen = device();
      manager = device();
      customer = device(); // ไม่เคยล็อกอิน — มือถือลูกค้า
      await waiter.signIn('waiter1', 'waiter123');
      await kitchen.signIn('kitchen', 'kitchen123');
      await manager.signIn('manager', 'manager123');
    });

    tearDownAll(() {
      // ignore: avoid_print
      if (flow.hasFailed) print('──── backend log ────\n${backend.log}');
    });

    flow.step(
      'ลูกค้าเปิดลิงก์จาก QR เห็นชื่อโต๊ะ/โซน/สาขาถูกต้อง โดยไม่มี token ใด ๆ',
      () async {
        table = expectOk(
          await waiter.tables.getTables(status: 'available'),
          'โต๊ะว่าง',
        ).last;
        qrToken = table.qrToken!;

        final opened = expectOk(
          await customer.selfOrder.getTable(qrToken),
          'เปิดลิงก์',
        );
        expect(customer.storage.token, isNull);
        expect(opened.table.id, table.id);
        expect(opened.table.name, table.name);
        expect(opened.table.zone, table.zone);
        expect(opened.table.branchName, isNotEmpty);
        expect(opened.order, isNull, reason: 'โต๊ะว่างยังไม่มีออเดอร์');
      },
    );

    flow.step(
      'ลูกค้าเห็นเฉพาะเมนูที่ขายอยู่ เมนูที่ผู้จัดการปิดขายหายไปทันที',
      () async {
        final before = expectOk(
          await customer.selfOrder.getMenu(qrToken),
          'เมนูลูกค้า',
        );
        expect(before.items, isNotEmpty);
        expect(before.categories, isNotEmpty);
        expect(before.items.every((m) => m.isAvailable), isTrue);

        final soldOut = before.items.first;
        expectOk(
          await manager.menu.setAvailability(soldOut.id, false),
          'ปิดขาย',
        );
        final after = expectOk(
          await customer.selfOrder.getMenu(qrToken),
          'เมนูหลังปิดขาย',
        );
        expect(after.items.map((m) => m.id), isNot(contains(soldOut.id)));

        expectOk(
          await manager.menu.setAvailability(soldOut.id, true),
          'เปิดขายคืน',
        );
        customerMenu =
            expectOk(await customer.selfOrder.getMenu(qrToken), 'เมนู').items
                .where((m) => m.optionGroups.every((g) => !g.isRequired))
                .toList();
        expect(customerMenu.length, greaterThanOrEqualTo(2));
      },
    );

    flow.step(
      'ลูกค้ากด "ส่งเข้าครัว" แล้วครัวเห็นรายการจริง ตามที่หน้าจอบอกลูกค้า',
      () async {
        order = expectOk(
          await customer.selfOrder.addItems(qrToken, [
            OrderItemPayload(
              menuItemId: customerMenu[0].id,
              quantity: 2,
              note: 'เผ็ดน้อย',
            ),
          ]),
          'ลูกค้าสั่งรอบแรก',
        );
        expect(order.items, hasLength(1));
        expect(order.items.single.quantity, 2);

        // หน้าลูกค้าขึ้น "ส่งออเดอร์เข้าครัวเรียบร้อยแล้ว" (self_order_submit_success) — ถ้าครัวไม่เห็น
        // ลูกค้าจะนั่งรออาหารที่ไม่มีใครทำ (ticket 17 AC: "กด 'ส่งเข้าครัว' แล้วออเดอร์ขึ้นที่ฝั่ง
        // พนักงาน (ผังโต๊ะ/ครัว)" และ DECISIONS #37: "ขึ้นที่ผังโต๊ะ/ครัวเหมือนออเดอร์ปกติทุกประการ")
        final queue = expectOk(
          await kitchen.orders.getKitchenQueue(),
          'คิวครัว',
        );
        final mine = queue.where((i) => i.orderId == order.id).toList();
        expect(mine, hasLength(1), reason: 'ครัวต้องเห็นรายการที่ลูกค้าสั่ง');
        expect(mine.single.tableName, table.name);
        expect(mine.single.note, 'เผ็ดน้อย');
      },
    );

    flow.step(
      'พนักงานเห็นออเดอร์ของลูกค้าที่ผังโต๊ะ โต๊ะไม่ว่างแล้ว',
      () async {
        final open = expectOk(
          await waiter.orders.getOpenOrderByTable(table.id),
          'ออเดอร์ของโต๊ะ',
        );
        expect(open?.id, order.id);
        final now = expectOk(
          await waiter.tables.getTables(),
          'ผังโต๊ะ',
        ).singleWhere((t) => t.id == table.id);
        expect(now.status, 'occupied');
      },
    );

    flow.step(
      'ลูกค้าสั่งรอบสองเข้าบิลเดิม ไม่เปิดบิลใหม่ และครัวเห็นรอบสองทันที',
      () async {
        final second = expectOk(
          await customer.selfOrder.addItems(qrToken, [
            OrderItemPayload(menuItemId: customerMenu[1].id, quantity: 1),
          ]),
          'ลูกค้าสั่งรอบสอง',
        );
        expect(second.id, order.id);
        expect(second.items, hasLength(2));

        final queue = expectOk(
          await kitchen.orders.getKitchenQueue(),
          'คิวครัว',
        );
        expect(queue.where((i) => i.orderId == order.id), hasLength(2));

        final view = expectOk(
          await customer.selfOrder.getTable(qrToken),
          'ลูกค้าดูออเดอร์',
        );
        expect(view.order?.items, hasLength(2));
        order = second;
      },
    );

    flow.step(
      'สั่งผ่าน QR เกิน 10 ที่ต่อรายการ ร้านปฏิเสธทั้งคำขอและบอกให้เรียกพนักงาน (DECISIONS #99)',
      () async {
        final menu = expectOk(
          await customer.selfOrder.getMenu(qrToken),
          'เมนูลูกค้า',
        );
        expect(menu.maxQuantityPerLine, 10);

        final result = await customer.selfOrder.addItems(qrToken, [
          OrderItemPayload(menuItemId: customerMenu[0].id, quantity: 11),
        ]);
        final failure = result.failureOrNull;
        expect(failure, isNotNull);
        expect(isSelfOrderLimit(failure!), isTrue);
        expect(failure.message, contains('10'));

        final view = expectOk(
          await customer.selfOrder.getTable(qrToken),
          'ลูกค้าดูออเดอร์',
        );
        expect(
          view.order?.items,
          hasLength(2),
          reason: 'ไม่มีรายการใหม่เข้าบิล',
        );
      },
    );

    flow.step(
      'ข้อมูลส่วนตัวของพนักงาน/ลูกค้าไม่หลุดไปถึงหน้าเว็บสาธารณะ',
      () async {
        final view = expectOk(
          await customer.selfOrder.getTable(qrToken),
          'ลูกค้าดูออเดอร์',
        );
        expect(view.order?.waiterName, isNull);
        expect(view.order?.customerName, isNull);
        expect(view.order?.customerPhone, isNull);
      },
    );

    flow.step(
      'ลิงก์เสียทุกแบบถูกจัดเป็น "ลิงก์ใช้ไม่ได้" ไม่ใช่ "เน็ตหลุด" (ซ่อนปุ่มลองใหม่)',
      () async {
        // token รูปแบบถูกแต่ไม่มีโต๊ะนี้ → backend 404
        final unknown = expectFailure(
          await customer.selfOrder.getTable(
            '00000000-0000-4000-8000-000000000000',
          ),
          'token ที่ไม่มีจริง',
        );
        expect(
          unknown,
          isA<ServerFailure>().having((f) => f.statusCode, 'status', 404),
        );
        expect(isBrokenSelfOrderLink(unknown), isTrue);

        // ลิงก์ถูกตัดท้ายตอนส่งต่อ (ไม่ใช่ UUID แล้ว) → backend 400 ตั้งแต่ชั้น validate
        final truncated = expectFailure(
          await customer.selfOrder.getTable(qrToken.substring(0, 16)),
          'ลิงก์ถูกตัดท้าย',
        );
        expect(truncated, isA<ValidationFailure>());
        expect(isBrokenSelfOrderLink(truncated), isTrue);
      },
    );

    flow.step(
      'ผู้จัดการสร้าง QR ใหม่ ลิงก์เก่าที่หลุดออกไปใช้ไม่ได้ทันที',
      () async {
        final regenerated = expectOk(
          await manager.tables.regenerateQrToken(table.id),
          'สร้าง QR ใหม่',
        );
        final newToken = regenerated.qrToken!;
        expect(newToken, isNot(qrToken));

        final old = expectFailure(
          await customer.selfOrder.getTable(qrToken),
          'ลิงก์เก่า',
        );
        expect(
          old,
          isA<ServerFailure>().having((f) => f.statusCode, 'status', 404),
        );
        final blocked = expectFailure(
          await customer.selfOrder.addItems(qrToken, [
            OrderItemPayload(menuItemId: customerMenu[0].id, quantity: 1),
          ]),
          'สั่งผ่านลิงก์เก่า',
        );
        expect(
          blocked,
          isA<ServerFailure>().having((f) => f.statusCode, 'status', 404),
        );

        final fresh = expectOk(
          await customer.selfOrder.getTable(newToken),
          'ลิงก์ใหม่',
        );
        expect(
          fresh.order?.id,
          order.id,
          reason: 'ลิงก์ใหม่ยังเห็นบิลเดิมของโต๊ะ',
        );
      },
    );

    flow.step('มือถือลูกค้าเรียก API ของพนักงานไม่ได้', () async {
      final denied = expectFailure(
        await customer.orders.getOrders(),
        'ลูกค้าดูออเดอร์ทั้งร้าน',
      );
      expect(denied, isA<UnauthorizedFailure>());
      expect(customer.unauthorizedCount, greaterThanOrEqualTo(1));
    });
  });

  group('ล็อกอิน สาขา และสิทธิ์ตามบทบาท', () {
    test('รหัสผ่านผิดถูกปฏิเสธ และไม่มี token ค้างอยู่ในเครื่อง', () async {
      final phone = device();
      final failure = expectFailure(
        await phone.auth.login(username: 'cashier', password: 'ผิดแน่นอน'),
        'รหัสผิด',
      );
      expect(failure, isA<UnauthorizedFailure>());
      expect(phone.storage.token, isNull);
    });

    // แอปส่งภาษาที่ผู้ใช้เลือกไปกับทุก request แล้ว backend แปลข้อความ error ให้ (DECISIONS #64)
    // — เดิมพนักงานเกาหลีที่ต่อ backend จริงเห็นข้อความปฏิเสธเป็นภาษาไทยทุกครั้ง
    test(
      'เครื่องที่ตั้งเป็นภาษาเกาหลี/อังกฤษได้ข้อความ error ภาษานั้นจาก backend จริง',
      () async {
        for (final (language, expected) in [
          ('ko', '아이디 또는 비밀번호가 올바르지 않습니다'),
          ('en', 'Incorrect username or password'),
        ]) {
          final phone = PosDevice(backend.apiBaseUrl, language: language);
          final failure = expectFailure(
            await phone.auth.login(username: 'cashier', password: 'ผิดแน่นอน'),
            'รหัสผิด ($language)',
          );
          expect(failure.message, expected);
        }
      },
    );

    test(
      'พนักงานหลายสาขาต้องเลือกสาขาก่อน และ pendingToken ไม่ถูกเก็บเป็น session',
      () async {
        final phone = device();
        final login = expectOk(
          await phone.auth.login(username: 'waiter2', password: 'waiter123'),
          'login waiter2',
        );
        expect(login, isA<LoginNeedsBranchSelection>());
        final pick = login as LoginNeedsBranchSelection;
        expect(
          pick.branches.map((b) => b.code),
          containsAll(['SUKHUMVIT', 'THONGLOR']),
        );
        expect(
          phone.storage.token,
          isNull,
          reason: 'pendingToken ต้องไม่ถูกแนบไปกับ request อื่น (ticket 11)',
        );

        // pendingToken ใช้ได้แค่เลือกสาขา — เอาไปเรียก API อื่นตรง ๆ ต้องไม่ผ่าน (403 ไม่ใช่ 401 เพราะ
        // ตัว token ถูกต้อง แค่ยังไม่มีสิทธิ์ทำอะไรนอกจากเลือกสาขา)
        await phone.storage.saveSession(
          token: pick.pendingToken,
          user: const {},
        );
        final misuse = expectFailure(
          await phone.tables.getTables(),
          'ใช้ pendingToken ผิดที่',
        );
        expect(misuse, isA<ForbiddenFailure>());
        expect(misuse.message, contains('เลือกสาขา'));
        await phone.auth.logout();

        final thonglor = pick.branches.singleWhere((b) => b.code == 'THONGLOR');
        final session = expectOk(
          await phone.auth.selectBranch(
            token: pick.pendingToken,
            branchId: thonglor.id,
          ),
          'เลือกทองหล่อ',
        );
        expect(session.user.branchId, thonglor.id);
        expect(phone.storage.token, session.token);
      },
    );

    test(
      'แต่ละสาขาเห็นเมนูและโต๊ะของตัวเองเท่านั้น และสลับสาขาได้โดยไม่ต้องล็อกอินใหม่',
      () async {
        final sukhumvit = device();
        await sukhumvit.signIn('waiter1', 'waiter123');
        final thonglor = device();
        await thonglor.signIn('waiter2', 'waiter123', branchCode: 'THONGLOR');

        Future<Set<String>> menuNames(PosDevice d) async => expectOk(
          await d.menu.getMenuItems(),
          'เมนู',
        ).map((m) => m.nameEn ?? m.name).toSet();
        Future<Set<int>> tableIds(PosDevice d) async => expectOk(
          await d.tables.getTables(),
          'โต๊ะ',
        ).map((t) => t.id).toSet();

        expect(await menuNames(thonglor), contains('Crab Fried Rice'));
        expect(await menuNames(sukhumvit), isNot(contains('Crab Fried Rice')));
        final thonglorTables = await tableIds(thonglor);
        expect(thonglorTables, isNotEmpty);
        expect(thonglorTables.intersection(await tableIds(sukhumvit)), isEmpty);

        final branches = expectOk(
          await thonglor.auth.listMyBranches(),
          'สาขาของฉัน',
        );
        expect(branches, hasLength(2));
        final home = branches.singleWhere((b) => b.code == 'SUKHUMVIT');
        expectOk(
          await thonglor.auth.selectBranch(
            token: thonglor.storage.token!,
            branchId: home.id,
          ),
          'สลับไปสุขุมวิท',
        );
        expect(await menuNames(thonglor), isNot(contains('Crab Fried Rice')));
      },
    );

    test(
      'บทบาทที่ไม่มีสิทธิ์ถูกปฏิเสธด้วย 403 ทุกจุดที่เกี่ยวกับเงินและข้อมูลร้าน',
      () async {
        final waiter = device();
        await waiter.signIn('waiter1', 'waiter123');
        final kitchen = device();
        await kitchen.signIn('kitchen', 'kitchen123');
        final cashier = device();
        await cashier.signIn('cashier', 'cashier123');

        final cases = <String, Future<Result<Object?>>>{
          'พนักงานเสิร์ฟดูรายงานยอดขาย': waiter.reports.getSummary(),
          'พนักงานเสิร์ฟแก้ตั้งค่าร้าน': waiter.settings.update(
            storeName: 'ร้านปลอม',
          ),
          'ครัวรับชำระเงิน': kitchen.payments.pay(
            orderId: 1,
            method: 'cash',
            amount: 1,
            received: 1,
          ),
          'แคชเชียร์เปิด audit log': cashier.auditLogs.list(),
          'แคชเชียร์เพิ่มพนักงาน': cashier.staff.create(
            name: 'ผี',
            username: 'ghost',
            password: 'ghost123',
            role: 'admin',
          ),
        };
        for (final MapEntry(key: label, value: call) in cases.entries) {
          expect(
            (await call).failureOrNull,
            isA<ForbiddenFailure>(),
            reason: label,
          );
        }
      },
    );

    test(
      'token เสีย/หมดอายุ: ได้ UnauthorizedFailure และแอปได้สัญญาณให้กลับหน้า login',
      () async {
        final phone = device();
        await phone.storage.saveSession(
          token: 'not-a-real-jwt',
          user: const {},
        );
        final failure = expectFailure(
          await phone.tables.getTables(),
          'token เสีย',
        );
        expect(failure, isA<UnauthorizedFailure>());
        expect(phone.unauthorizedCount, 1);
      },
    );

    test(
      'ปิดบัญชีพนักงานที่ลาออก เครื่องที่ยังล็อกอินค้างไว้ใช้ต่อไม่ได้ทันที',
      () async {
        final admin = device();
        await admin.signIn('admin', 'admin123');
        final created = expectOk(
          await admin.staff.create(
            name: 'พนักงานชั่วคราว',
            username: 'temp_e2e',
            password: 'temp1234',
            role: 'waiter',
          ),
          'เพิ่มพนักงาน',
        );

        final phone = device();
        await phone.signIn('temp_e2e', 'temp1234');
        expectOk(await phone.tables.getTables(), 'ใช้งานได้ก่อนถูกปิด');

        expectOk(
          await admin.staff.update(created.id, isActive: false),
          'ปิดบัญชี',
        );
        final after = expectFailure(
          await phone.tables.getTables(),
          'หลังถูกปิดบัญชี',
        );
        expect(after, isA<UnauthorizedFailure>());
        expect(phone.unauthorizedCount, 1);

        // ล็อกอินใหม่ไม่ได้ และได้ข้อความบอกตรง ๆ ว่าบัญชีถูกปิด (403) ไม่ใช่ "รหัสผิด" (401) —
        // พนักงานจะได้รู้ว่าต้องติดต่อผู้ดูแล ไม่ใช่ลองรหัสซ้ำไปเรื่อย ๆ
        final relogin = expectFailure(
          await device().auth.login(username: 'temp_e2e', password: 'temp1234'),
          'ล็อกอินใหม่หลังถูกปิด',
        );
        expect(relogin, isA<ForbiddenFailure>());
        expect(relogin.message, contains('ถูกปิดการใช้งาน'));
      },
    );
  });
}
