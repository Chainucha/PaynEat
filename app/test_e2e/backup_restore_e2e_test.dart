// Copyright 2026 Suruch Chakrapeesirisuk
// SPDX-License-Identifier: Apache-2.0

@Timeout(Duration(minutes: 3))
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:payneat_pos/features/backup/data/datasources/backup_remote_data_source.dart';
import 'package:payneat_pos/features/backup/data/repositories/backup_repository_impl.dart';
import 'package:payneat_pos/features/backup/domain/entities/backup_status.dart';
import 'package:payneat_pos/features/menu/domain/entities/menu_item.dart';
import 'package:payneat_pos/features/order/domain/entities/cart_line.dart';
import 'package:payneat_pos/features/order/domain/usecases/order_usecases.dart';
import 'package:payneat_pos/features/report/domain/entities/report.dart';
import 'package:payneat_pos/features/shift/domain/entities/shift.dart';

import 'support/backend_process.dart';
import 'support/pos_device.dart';
import 'support/scenario.dart';

/// สำรองและกู้คืนข้อมูลจริงทั้งเส้น (ticket 33): ปิดกะ → backend สำรองเอง → กู้ไฟล์นั้นลงฐานข้อมูลใหม่ด้วย
/// คำสั่ง `db:restore` ตัวจริง → เปิด backend บนฐานข้อมูลที่กู้แล้ว → ยอดของกะตรงกับก่อนกู้ทุกบาท
///
/// เทสต์ backend (`backend/tests/backups.test.js`) ตรวจแต่ละส่วนแยกกัน ชุดนี้ตรวจว่าทั้งเส้นต่อกันได้จริง
/// และว่าแอปอ่านสถานะการสำรองจาก JSON ที่ backend ส่งมาจริงได้
void main() {
  late BackendProcess shop;
  BackendProcess? restored;
  late Directory restoreDir;
  late PosDevice admin;
  late PosDevice cashier;
  late BackupRepositoryImpl backups;

  final flow = Scenario();

  late Shift closed;
  late ZReport zBefore;
  late String backupFile;

  setUpAll(() async {
    shop = await BackendProcess.start();
    admin = PosDevice(shop.apiBaseUrl);
    cashier = PosDevice(shop.apiBaseUrl);
    backups = BackupRepositoryImpl(BackupRemoteDataSourceImpl(admin.client));
    restoreDir = await Directory.systemTemp.createTemp('payneat-restore-');
  });

  tearDownAll(() async {
    if (flow.hasFailed) {
      // ignore: avoid_print
      print('──── backend log ────\n${shop.log}\n${restored?.log ?? ''}');
    }
    await shop.stop();
    await restored?.stop();
    if (restoreDir.existsSync()) await restoreDir.delete(recursive: true);
  });

  flow.step(
    'ขายหนึ่งบิลในกะใหม่ แล้วปิดกะ — การปิดกะบอกว่าสำรองสำเร็จ',
    () async {
      await admin.signIn('admin', 'admin123');
      await cashier.signIn('cashier', 'cashier123');

      // seed มีกะค้างเปิดไว้ — ปิดก่อนเหมือนเช้าวันใหม่ของร้าน
      final leftover = expectOk(await cashier.shifts.getCurrent(), 'กะค้าง');
      if (leftover != null) {
        expectOk(
          await cashier.shifts.close(
            leftover.id,
            countedCash: leftover.openingCash,
          ),
          'ปิดกะค้าง',
        );
      }
      final shift = expectOk(await cashier.shifts.open(500), 'เปิดกะ');

      final menu = expectOk(
        await cashier.menu.getMenuItems(availableOnly: true),
        'เมนู',
      );
      final dish = menu.firstWhere(
        (MenuItem m) => !m.soldByWeight && !m.requiresSelection,
      );
      final order = expectOk(
        await cashier.orders.createOrder(
          type: 'takeaway',
          guestCount: 1,
          items: cartToPayload([CartLine(menuItem: dish, quantity: 2)]),
        ),
        'เปิดบิล',
      );
      expectOk(
        await cashier.payments.pay(
          orderId: order.id,
          method: 'cash',
          amount: order.total,
          received: order.total,
        ),
        'รับเงินสด',
      );

      closed = expectOk(
        await cashier.shifts.close(shift.id, countedCash: 500 + order.total),
        'ปิดกะ',
      );
      expect(closed.status, 'closed');
      expect(closed.backupFailed, isFalse);

      zBefore = expectOk(
        await admin.reports.getZReportByShift(closed.id),
        'Z-report ก่อนกู้คืน',
      );
      expect(zBefore.netSales, baht(order.total));
    },
  );

  flow.step('มีไฟล์สำรองหลังปิดกะ และแอปอ่านสถานะจาก backend จริงได้', () async {
    final status = expectOk(await backups.getStatus(), 'สถานะสำรองข้อมูล');
    expect(status.enabled, isTrue);
    expect(status.warning, isNull);
    expect(status.copy.configured, isFalse);
    final last = status.primary.lastSuccess!;
    expect(last.reason, 'shift-close');

    // ไฟล์ล่าสุดตามสถานะคือของการปิดกะครั้งหลัง (ปิดสองครั้งในวินาทีเดียวได้ชื่อลงท้าย -2)
    backupFile = '${shop.backupDir}/${last.file}';
    expect(File(backupFile).existsSync(), isTrue);
    final files = Directory(
      shop.backupDir,
    ).listSync().whereType<File>().where((f) => f.path.endsWith('.sqlite'));
    expect(status.primary.fileCount, files.length);

    // แคชเชียร์ดูสถานะไม่ได้ (admin และ manager เท่านั้น)
    final denied = BackupRepositoryImpl(
      BackupRemoteDataSourceImpl(cashier.client),
    );
    expect(expectFailure(await denied.getStatus(), 'แคชเชียร์'), isNotNull);
  });

  flow.step('กดสำรองตอนนี้ (admin) ได้ไฟล์ใหม่ และสถานะอัปเดตทันที', () async {
    final outcome = expectOk(await backups.backupNow(), 'สำรองตอนนี้');
    expect(outcome.result.ok, isTrue);
    expect(outcome.result.file, endsWith('-manual.sqlite'));
    expect(outcome.status.primary.lastSuccess?.reason, 'manual');
    expect(outcome.status.warning, isNull);
    expect(outcome.status, isA<BackupStatus>());
  });

  flow.step(
    'กู้ไฟล์หลังปิดกะลงฐานข้อมูลใหม่ แล้วยอดของกะตรงกับก่อนกู้',
    () async {
      final target = '${restoreDir.path}/restored.sqlite';
      final output = await BackendProcess.restore(
        backupFile: backupFile,
        databaseFile: target,
      );
      expect(output, contains('Restored'));

      restored = await BackendProcess.start(databaseFile: target);
      final owner = PosDevice(restored!.apiBaseUrl);
      await owner.signIn('admin', 'admin123');

      final zAfter = expectOk(
        await owner.reports.getZReportByShift(closed.id),
        'Z-report หลังกู้คืน',
      );
      expect(zAfter.orderCount, zBefore.orderCount);
      expect(zAfter.subtotal, baht(zBefore.subtotal));
      expect(zAfter.vat, baht(zBefore.vat));
      expect(zAfter.serviceCharge, baht(zBefore.serviceCharge));
      expect(zAfter.netSales, baht(zBefore.netSales));
      expect(zAfter.countedCash, baht(zBefore.countedCash!));
      expect(zAfter.expectedCash, baht(zBefore.expectedCash!));

      final logs = expectOk(
        await owner.auditLogs.list(action: 'system.restore', limit: 5),
        'audit system.restore',
      ).logs;
      expect(logs, hasLength(1));
      expect(logs.single.summary, contains(backupFile.split('/').last));
    },
  );
}
