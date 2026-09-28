// Copyright 2026 Suruch Chakrapeesirisuk
// SPDX-License-Identifier: Apache-2.0

@Timeout(Duration(minutes: 3))
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:payneat_pos/core/errors/failures.dart';
import 'package:payneat_pos/core/utils/promptpay.dart';
import 'package:payneat_pos/features/menu/domain/entities/menu_item.dart';
import 'package:payneat_pos/features/menu/domain/entities/menu_option.dart';
import 'package:payneat_pos/features/order/domain/entities/cart_line.dart';
import 'package:payneat_pos/features/order/domain/entities/order.dart';
import 'package:payneat_pos/features/order/domain/services/bill_calculator.dart';
import 'package:payneat_pos/features/order/domain/usecases/order_usecases.dart';
import 'package:payneat_pos/features/payment/domain/entities/payment.dart';
import 'package:payneat_pos/features/report/domain/entities/report.dart';
import 'package:payneat_pos/features/settings/domain/entities/store_settings.dart';
import 'package:payneat_pos/features/shift/domain/entities/shift.dart';

import 'support/backend_process.dart';
import 'support/pos_device.dart';
import 'support/scenario.dart';

/// หนึ่งวันทำงานเต็มของร้าน — ทุกบทบาทถือเครื่องของตัวเอง ยิงผ่านโค้ดชั้น data/domain ตัวจริงของแอป
/// ไปหา backend ตัวจริง (ไม่ใช่โหมดสาธิต) ตั้งแต่เปิดกะจนปิดกะและออกรายงาน
///
/// จุดที่ชุดนี้จับได้แต่เทสต์เดิมทั้งหมดจับไม่ได้:
/// - ชื่อ/ชนิดฟิลด์ใน JSON ที่ backend ส่งจริง กับที่ model ฝั่งแอป parse ไม่ตรงกัน
/// - ยอดเงินที่แอปโชว์ในตะกร้า (`BillCalculator`) ไม่ตรงกับที่ backend เรียกเก็บจริง
/// - QR พร้อมเพย์ที่ backend สร้างไม่ตรงกับอัลกอริทึมฝั่ง Dart (โหมดสาธิตใช้ตัว Dart)
/// - กฎธุรกิจที่ข้ามหลาย module: ตัดสต๊อกตอนส่งครัว, ต้องเปิดกะก่อนรับเงิน, เงินในลิ้นชักตอนปิดกะ
void main() {
  late BackendProcess backend;
  late PosDevice admin;
  late PosDevice manager;
  late PosDevice cashier;
  late PosDevice waiter;
  late PosDevice kitchen;

  final day = Scenario();

  // สถานะที่ส่งต่อระหว่างขั้น
  late StoreSettings settings;
  late SalesSummary summaryBefore;
  late int tableId;
  late MenuItem stockItem;
  late MenuItem optionItem;
  late List<CartLine> cart;
  late Map<int, double> stockBefore;
  late Map<int, double> expectedDeduction;
  late Order order;
  late Shift shift;
  late Payment payment;
  const openingCash = 1000.0;
  const refundAmount = 50.0;
  const promptPayId = '0812345678';

  setUpAll(() async {
    backend = await BackendProcess.start();
    admin = PosDevice(backend.apiBaseUrl);
    manager = PosDevice(backend.apiBaseUrl);
    cashier = PosDevice(backend.apiBaseUrl);
    waiter = PosDevice(backend.apiBaseUrl);
    kitchen = PosDevice(backend.apiBaseUrl);
  });

  tearDownAll(() async {
    // เทสต์ล้ม = อยากเห็นว่า backend พูดอะไรไว้บ้าง (stack trace ฝั่ง Node, SQL error ฯลฯ)
    // ignore: avoid_print
    if (day.hasFailed) print('──── backend log ────\n${backend.log}');
    await backend.stop();
  });

  day.step('ทุกบทบาทล็อกอินผ่าน repository จริง ได้ role ตรงกับบัญชี', () async {
    final roles = {
      'admin': await admin.signIn('admin', 'admin123'),
      'manager': await manager.signIn('manager', 'manager123'),
      'cashier': await cashier.signIn('cashier', 'cashier123'),
      'waiter': await waiter.signIn('waiter1', 'waiter123'),
      'kitchen': await kitchen.signIn('kitchen', 'kitchen123'),
    };
    for (final MapEntry(key: role, value: user) in roles.entries) {
      expect(user.role, role, reason: 'บัญชี $role');
      expect(user.branchName, isNotNull, reason: '$role ต้องถูกผูกกับสาขา');
    }
    // token ต้องถูกเก็บลง storage ของ "เครื่อง" นั้น ๆ — ApiClient หยิบไปแนบเองจากตรงนี้
    expect(cashier.storage.token, isNotEmpty);
    expect(cashier.storage.token, isNot(waiter.storage.token));
  });

  day.step(
    'ผู้จัดการตั้งเลขพร้อมเพย์ของร้าน และจดยอดขายวันนี้ไว้เทียบตอนท้าย',
    () async {
      settings = expectOk(
        await manager.settings.update(promptPayId: promptPayId),
        'ตั้งเลขพร้อมเพย์',
      );
      expect(settings.promptPayId, promptPayId);
      summaryBefore = expectOk(
        await manager.reports.getSummary(),
        'ยอดขายก่อนเริ่ม',
      );
    },
  );

  day.step(
    'พนักงานเสิร์ฟเลือกโต๊ะว่าง และหาเมนูที่ผูกสต๊อก/มีตัวเลือกเสริม',
    () async {
      final tables = expectOk(
        await waiter.tables.getTables(status: 'available'),
        'โต๊ะว่าง',
      );
      expect(tables, isNotEmpty);
      tableId = tables.first.id;
      expect(
        tables.first.qrToken,
        isNotEmpty,
        reason: 'ทุกโต๊ะต้องมี QR token',
      );

      final list = expectOk(
        await waiter.menu.getMenuItems(availableOnly: true),
        'เมนูที่ขายอยู่',
      );
      expect(list, isNotEmpty);

      // รายการเมนูไม่รวมตัวเลือก/วัตถุดิบ ต้องเปิดรายละเอียดทีละตัวแบบเดียวกับหน้าจอเลือกเมนู
      final details = <MenuItem>[];
      for (final item in list) {
        details.add(
          expectOk(await waiter.menu.getMenuItem(item.id), 'เมนู ${item.id}'),
        );
      }
      // สินค้าขายตามน้ำหนักมีชุดเทสต์ของตัวเอง (meat_shop_b2b_e2e_test.dart) — ตรงนี้ต้องเป็นจาน
      stockItem = details.firstWhere(
        (m) =>
            !m.soldByWeight &&
            m.ingredients.isNotEmpty &&
            m.optionGroups.every((g) => !g.isRequired),
        orElse: () =>
            fail('seed ไม่มีเมนูที่ผูกวัตถุดิบและไม่มีตัวเลือกบังคับ'),
      );
      optionItem = details.firstWhere(
        (m) =>
            m.id != stockItem.id &&
            m.optionGroups.any((g) => g.options.any((o) => o.priceDelta > 0)),
        orElse: () => fail('seed ไม่มีเมนูที่มีตัวเลือกเสริมแบบบวกราคา'),
      );
    },
  );

  day.step(
    'ออเดอร์ที่ backend สร้าง ราคาตรงกับตะกร้าที่แอปคำนวณโชว์พนักงานทุกสตางค์',
    () async {
      cart = [
        CartLine(menuItem: stockItem, quantity: 2),
        CartLine(
          menuItem: optionItem,
          selectedOptions: _pickOptions(optionItem),
          note: 'ไม่เผ็ด',
        ),
      ];
      // เหมือน CartController — แอปโชว์ยอดนี้ให้พนักงานดูก่อนกดส่ง
      final calculator = BillCalculator(
        vatRate: settings.vatRate,
        serviceChargeRate: settings.serviceChargeRate,
        vatIncluded: settings.vatIncluded,
      );
      final shownToWaiter = calculator.fromCart(cart);

      order = expectOk(
        await waiter.orders.createOrder(
          type: 'dine_in',
          tableId: tableId,
          guestCount: 3,
          items: cartToPayload(cart),
        ),
        'เปิดออเดอร์',
      );

      expect(order.status, 'open');
      expect(order.tableId, tableId);
      expect(order.items, hasLength(2));
      for (final line in cart) {
        final item = order.items.singleWhere(
          (i) => i.menuItemId == line.menuItem.id,
        );
        expect(item.quantity, line.quantity);
        expect(
          item.lineTotal,
          baht(line.lineTotal),
          reason: 'ราคาต่อบรรทัด ${item.name}',
        );
        expect(
          item.options.map((o) => o.id).toSet(),
          line.optionIds.toSet(),
          reason: 'ตัวเลือกที่ส่งไปต้องกลับมาครบ',
        );
      }
      expect(
        order.items.singleWhere((i) => i.menuItemId == optionItem.id).note,
        'ไม่เผ็ด',
      );

      expect(
        order.subtotal,
        baht(shownToWaiter.subtotal),
        reason: 'ยอดก่อนภาษี',
      );
      expect(
        order.serviceCharge,
        baht(shownToWaiter.serviceCharge),
        reason: 'ค่าบริการ',
      );
      expect(order.vat, baht(shownToWaiter.vat), reason: 'VAT');
      expect(
        order.total,
        baht(shownToWaiter.total),
        reason: 'ยอดสุทธิที่ลูกค้าเห็น',
      );

      final table = expectOk(
        await waiter.tables.getTables(),
        'ผังโต๊ะ',
      ).singleWhere((t) => t.id == tableId);
      expect(table.status, 'occupied');
      final open = expectOk(
        await waiter.orders.getOpenOrderByTable(tableId),
        'ออเดอร์ของโต๊ะ',
      );
      expect(open?.id, order.id);
    },
  );

  day.step(
    'ร่างออเดอร์ยังไม่ถึงครัวและยังไม่ตัดสต๊อก จนกว่าจะกด "ส่งเข้าครัว"',
    () async {
      expectedDeduction = {};
      for (final line in cart) {
        for (final usage in line.menuItem.ingredients) {
          expectedDeduction.update(
            usage.ingredientId,
            (sum) => sum + usage.qtyPerUnit * line.quantity,
            ifAbsent: () => usage.qtyPerUnit * line.quantity,
          );
        }
      }
      expect(expectedDeduction, isNotEmpty);

      Future<Map<int, double>> readStock() async => {
        for (final id in expectedDeduction.keys)
          id: expectOk(
            await manager.ingredients.getIngredient(id),
            'วัตถุดิบ $id',
          ).currentStock,
      };
      stockBefore = await readStock();

      final queue = expectOk(await kitchen.orders.getKitchenQueue(), 'คิวครัว');
      expect(
        queue.where((i) => i.orderId == order.id),
        isEmpty,
        reason: 'ครัวต้องไม่เห็นออเดอร์ที่พนักงานยังแก้อยู่',
      );

      order = expectOk(
        await waiter.orders.sendToKitchen(order.id),
        'ส่งเข้าครัว',
      );
      expect(order.status, 'in_kitchen');

      final stockAfter = await readStock();
      for (final MapEntry(key: id, value: used) in expectedDeduction.entries) {
        expect(
          stockAfter[id],
          baht(stockBefore[id]! - used),
          reason: 'สต๊อกวัตถุดิบ $id',
        );
      }
    },
  );

  day.step('ครัวรับรายการ ทำจนพร้อมเสิร์ฟ แล้วพนักงานยกไปเสิร์ฟ', () async {
    final queue = expectOk(await kitchen.orders.getKitchenQueue(), 'คิวครัว');
    final mine = queue.where((i) => i.orderId == order.id).toList();
    expect(mine, hasLength(2));
    for (final item in mine) {
      expect(item.status, 'pending');
      expect(item.tableName, isNotNull, reason: 'ครัวต้องรู้ว่าส่งโต๊ะไหน');
      expect(item.orderCode, order.code);
    }

    for (final item in mine) {
      expectOk(
        await kitchen.orders.updateItemStatus(order.id, item.id, 'cooking'),
        'เริ่มทำ ${item.name}',
      );
      expectOk(
        await kitchen.orders.updateItemStatus(order.id, item.id, 'ready'),
        'ทำเสร็จ ${item.name}',
      );
      order = expectOk(
        await waiter.orders.updateItemStatus(order.id, item.id, 'served'),
        'เสิร์ฟ ${item.name}',
      );
    }
    expect(order.items.map((i) => i.status), everyElement('served'));

    final after = expectOk(
      await kitchen.orders.getKitchenQueue(),
      'คิวครัวหลังเสิร์ฟ',
    );
    expect(after.where((i) => i.orderId == order.id), isEmpty);
  });

  day.step(
    'กะเมื่อวานยังค้างเปิด — ต้องปิดก่อน แล้วรับเงินไม่ได้จนกว่าจะเปิดกะใหม่',
    () async {
      final leftover = expectOk(
        await cashier.shifts.getCurrent(),
        'กะปัจจุบัน',
      );
      if (leftover != null) {
        final closed = expectOk(
          await cashier.shifts.close(
            leftover.id,
            countedCash: leftover.openingCash,
          ),
          'ปิดกะที่ค้าง',
        );
        expect(closed.status, 'closed');
      }
      expect(expectOk(await cashier.shifts.getCurrent(), 'กะหลังปิด'), isNull);

      // ส่ง received มาด้วยเสมอเหมือนหน้าเก็บเงินจริง — ถ้าไม่ส่ง backend จะตีกลับตั้งแต่ขั้น validate
      // (เงินสดต้องรับมาไม่น้อยกว่ายอด) ไม่ถึงกฎเรื่องกะที่ขั้นนี้ตั้งใจทดสอบ
      final refused = expectFailure(
        await cashier.payments.pay(
          orderId: order.id,
          method: 'cash',
          amount: order.total,
          received: order.total,
        ),
        'รับเงินตอนไม่มีกะ',
      );
      expect(
        refused,
        isA<ServerFailure>().having((f) => f.statusCode, 'status', 409),
      );

      shift = expectOk(await cashier.shifts.open(openingCash), 'เปิดกะ');
      expect(shift.status, 'open');
      expect(shift.openingCash, baht(openingCash));
      expect(
        expectOk(await cashier.shifts.getCurrent(), 'กะปัจจุบัน')?.id,
        shift.id,
      );
    },
  );

  day.step(
    'QR พร้อมเพย์จาก backend ตรงกับที่แอปสร้างเองทุกตัวอักษร (รวม CRC)',
    () async {
      final qr = expectOk(
        await cashier.payments.getPromptPayQr(order.total),
        'QR พร้อมเพย์',
      );
      expect(qr.promptPayId, promptPayId);
      expect(qr.amount, baht(order.total));
      expect(
        qr.payload,
        buildPromptPayPayload(promptPayId: promptPayId, amount: order.total),
        reason:
            'โหมดสาธิตใช้ตัว Dart — ถ้าไม่ตรงกัน ลูกค้าสแกนได้ยอดไม่เท่ากันแล้วแต่ว่าเปิดโหมดไหน',
      );

      final summary = expectOk(
        await cashier.payments.getSummary(order.id),
        'ยอดค้างจ่าย',
      );
      expect(summary.total, baht(order.total));
      expect(summary.paid, baht(0));
      expect(summary.remaining, baht(order.total));
    },
  );

  day.step('รับเงินสด ทอนถูก ปิดบิล โต๊ะว่าง ใบเสร็จตรง', () async {
    final received = ((order.total ~/ 100) + 1) * 100.0;
    final paid = expectOk(
      await cashier.payments.pay(
        orderId: order.id,
        method: 'cash',
        amount: order.total,
        received: received,
      ),
      'รับเงินสด',
    );
    payment = paid.result.payment;
    expect(paid.result.isFullyPaid, isTrue);
    expect(paid.result.remaining, baht(0));
    expect(payment.amount, baht(order.total));
    expect(payment.received, baht(received));
    expect(payment.change, baht(received - order.total));
    expect(paid.order.status, 'paid');
    expect(paid.order.closedAt, isNotNull);

    final table = expectOk(
      await cashier.tables.getTables(),
      'ผังโต๊ะ',
    ).singleWhere((t) => t.id == tableId);
    expect(
      table.status,
      'available',
      reason: 'จ่ายครบแล้วโต๊ะต้องว่างให้ลูกค้าคนถัดไป',
    );

    final receipt = expectOk(
      await cashier.payments.getReceipt(order.id),
      'ใบเสร็จ',
    );
    expect(receipt.receipt.payments, hasLength(1));
    expect(receipt.receipt.changeTotal, baht(received - order.total));
    expect(receipt.receipt.vatRate, settings.vatRate);
    expect(receipt.order.total, baht(order.total));
  });

  day.step('ออกใบกำกับภาษีเต็มรูป ข้อมูลลูกค้าภาษาไทยไปกลับครบ', () async {
    final invoice = expectOk(
      await cashier.taxInvoices.issue(order.id, {
        'invoiceType': 'full',
        'customerName': 'บริษัท มีท365 จำกัด',
        'customerTaxId': '0105561234567',
        'customerAddress': 'โรงงานสาขาบางนา กรุงเทพมหานคร',
      }),
      'ออกใบกำกับภาษี',
    );
    expect(invoice.runningNumber, isNotEmpty);
    expect(invoice.invoiceType, 'full');
    expect(invoice.customerName, 'บริษัท มีท365 จำกัด');
    expect(invoice.customerAddress, 'โรงงานสาขาบางนา กรุงเทพมหานคร');
    expect(invoice.total, baht(order.total));
    expect(invoice.subtotal + invoice.vat, baht(invoice.total));
    expect(invoice.isVoid, isFalse);

    final again = expectOk(
      await cashier.taxInvoices.getByOrder(order.id),
      'เปิดดูซ้ำ',
    );
    expect(again.runningNumber, invoice.runningNumber);
  });

  day.step(
    'แคชเชียร์คืนเงินเองไม่ได้ ผู้จัดการคืนได้ ใบเสร็จแสดงยอดคืน',
    () async {
      final denied = expectFailure(
        await cashier.payments.refund(
          paymentId: payment.id,
          amount: refundAmount,
          reason: 'ลองคืนเอง',
        ),
        'แคชเชียร์คืนเงิน',
      );
      expect(denied, isA<ForbiddenFailure>());

      final refund = expectOk(
        await manager.payments.refund(
          paymentId: payment.id,
          amount: refundAmount,
          reason: 'เนื้อย่างสุกเกินไป ลูกค้าขอคืนบางส่วน',
        ),
        'ผู้จัดการคืนเงิน',
      );
      expect(refund.amount, baht(refundAmount));
      expect(refund.orderId, order.id);
      expect(refund.refundedByName, isNotEmpty);

      final receipt = expectOk(
        await cashier.payments.getReceipt(order.id),
        'ใบเสร็จหลังคืน',
      );
      expect(receipt.receipt.refunds, hasLength(1));
      expect(receipt.receipt.refundedTotal, baht(refundAmount));

      // ยอด "จ่ายแล้ว" หักยอดคืน (T06 #82) แต่บิลที่ปิดแล้วไม่มียอดค้างขึ้นมาใหม่ — แอปอ่านยอดคืนจาก backend จริงได้
      final summary = expectOk(
        await cashier.payments.getSummary(order.id),
        'ยอดชำระหลังคืน',
      );
      expect(summary.paid, baht(order.total - refundAmount));
      expect(summary.refunded, baht(refundAmount));
      expect(summary.remaining, baht(0));
      expect(summary.refundedFor(payment.id), baht(refundAmount));
    },
  );

  day.step('ปิดกะ: นับเงินในลิ้นชักตรงตามจริง ส่วนต่างต้องเป็นศูนย์', () async {
    // เงินที่อยู่ในลิ้นชักจริง = เงินทอนตั้งต้น + เงินสดที่รับ − เงินสดที่คืนลูกค้าไปจากลิ้นชัก
    final inDrawer = openingCash + order.total - refundAmount;
    shift = expectOk(
      await cashier.shifts.close(
        shift.id,
        countedCash: inDrawer,
        note: 'ปิดกะเย็น',
      ),
      'ปิดกะ',
    );
    expect(shift.status, 'closed');
    expect(shift.countedCash, baht(inDrawer));
    expect(
      shift.expectedCash,
      baht(inDrawer),
      reason:
          'ระบบต้องหักเงินสดที่คืนลูกค้าออกจากยอดที่คาดว่าควรอยู่ในลิ้นชัก '
          'ไม่งั้นแคชเชียร์ที่นับเงินถูกต้องจะถูกบันทึกว่าเงินขาด',
    );
    expect(shift.variance, baht(0));
  });

  day.step(
    'Z-report ของกะตรงกับบิลจริง และ export CSV เปิดกับ Excel ได้',
    () async {
      final z = expectOk(
        await manager.reports.getZReportByShift(shift.id),
        'Z-report กะ',
      );
      expect(z.isShiftReport, isTrue);
      expect(z.shiftId, shift.id);
      expect(z.orderCount, 1);
      expect(z.guestCount, 3);
      expect(z.vat, baht(order.vat));
      expect(z.serviceCharge, baht(order.serviceCharge));
      expect(z.refundTotal, baht(refundAmount));
      final cash = z.paymentMethods.singleWhere((m) => m.method == 'cash');
      expect(cash.amount, baht(order.total));
      expect(cash.count, 1);
      expect(z.openingCash, baht(openingCash));
      expect(z.countedCash, baht(shift.countedCash!));
      expect(z.expectedCash, baht(shift.expectedCash!));
      expect(z.variance, baht(shift.variance!));

      final csv = expectOk(
        await manager.reports.exportZReportByShiftCsv(shift.id),
        'Z-report CSV',
      );
      expect(
        csv.startsWith('\uFEFF'),
        isTrue,
        reason: 'ไม่มี BOM = Excel เปิดแล้วภาษาไทยเพี้ยน',
      );
      expect(csv.split('\n').length, greaterThan(5));
    },
  );

  day.step(
    'รายงานยอดขายวันนี้นับบิลนี้เพิ่มเข้าไปพอดี และ export CSV ได้',
    () async {
      final after = expectOk(
        await manager.reports.getSummary(),
        'ยอดขายหลังปิดกะ',
      );
      expect(after.orderCount, summaryBefore.orderCount + 1);
      expect(after.guestCount, summaryBefore.guestCount + 3);

      double cashOf(SalesSummary s) => s.paymentMethods
          .where((m) => m.method == 'cash')
          .fold(0.0, (sum, m) => sum + m.amount);
      expect(cashOf(after), baht(cashOf(summaryBefore) + order.total));

      final csv = expectOk(
        await manager.reports.exportSummaryCsv(),
        'สรุปยอดขาย CSV',
      );
      expect(csv.startsWith('\uFEFF'), isTrue);
    },
  );

  day.step(
    'audit log บันทึกทุกเหตุการณ์ที่เกี่ยวกับเงิน พร้อมชื่อคนทำ',
    () async {
      Future<void> expectLogged(String action, String actor) async {
        final logs = expectOk(
          await admin.auditLogs.list(action: action, limit: 5),
          'audit $action',
        ).logs;
        expect(logs, isNotEmpty, reason: 'ต้องมี $action');
        expect(logs.first.actorName, contains(actor), reason: 'คนทำ $action');
      }

      await expectLogged('shift.open', 'แอน');
      await expectLogged('payment.pay', 'แอน');
      await expectLogged('payment.refund', 'สมชาย');
      await expectLogged('shift.close', 'แอน');

      final denied = expectFailure(
        await manager.auditLogs.list(action: 'payment.pay'),
        'ผู้จัดการเปิด audit log',
      );
      expect(
        denied,
        isA<ForbiddenFailure>(),
        reason: 'audit log เปิดได้เฉพาะ admin',
      );
    },
  );
}

/// เลือกตัวเลือกแบบที่คนกดจริง: กลุ่มบังคับเลือกให้ครบขั้นต่ำ (เอาตัวที่บวกราคาก่อน) และกลุ่มไม่บังคับ
/// เลือกตัวบวกราคาไว้ 1 ตัว — ตั้งใจให้มีทั้งราคาเพิ่มจากตัวเลือกไปคำนวณจริงเสมอ
List<MenuOption> _pickOptions(MenuItem item) {
  final picked = <MenuOption>[];
  for (final group in item.optionGroups) {
    final byPrice = [...group.options]
      ..sort((a, b) => b.priceDelta.compareTo(a.priceDelta));
    final count = group.isRequired
        ? (group.minSelect < 1 ? 1 : group.minSelect)
        : (byPrice.first.priceDelta > 0 ? 1 : 0);
    picked.addAll(byPrice.take(count.clamp(0, group.maxSelect)));
  }
  return picked;
}
