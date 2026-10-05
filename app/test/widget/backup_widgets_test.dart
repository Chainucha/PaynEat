// Copyright 2026 Suruch Chakrapeesirisuk
// SPDX-License-Identifier: Apache-2.0

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:payneat_pos/core/localization/app_translations.dart';
import 'package:payneat_pos/core/localization/locale_service.dart';
import 'package:payneat_pos/core/usecases/result.dart';
import 'package:payneat_pos/features/backup/domain/entities/backup_status.dart';
import 'package:payneat_pos/features/backup/domain/repositories/backup_repository.dart';
import 'package:payneat_pos/features/backup/domain/usecases/backup_usecases.dart';
import 'package:payneat_pos/features/backup/presentation/controllers/backup_controller.dart';
import 'package:payneat_pos/features/backup/presentation/controllers/backup_warning_controller.dart';
import 'package:payneat_pos/features/backup/presentation/widgets/backup_card.dart';
import 'package:payneat_pos/features/backup/presentation/widgets/backup_warning_banner.dart';

/// ส่วน "สำรองข้อมูล" ในหน้าตั้งค่า และแถบเตือนบนหน้าหลัก (ticket 33)
class _StatusRepository implements BackupRepository {
  _StatusRepository(this.status);

  final BackupStatus status;

  @override
  Future<Result<BackupStatus>> getStatus() async => Result.success(status);

  @override
  Future<Result<BackupNowOutcome>> backupNow() async => Result.success(
    BackupNowOutcome(
      result: const BackupRunResult(ok: true, file: 'payneat-x-manual.sqlite'),
      status: status,
    ),
  );
}

final _lastShiftClose = BackupRecord(
  at: DateTime(2026, 10, 4, 22, 15),
  file: 'payneat-2026-10-04T221500+0700-shift-close.sqlite',
  reason: 'shift-close',
  sizeBytes: 4718592,
);

BackupStatus _status({
  BackupWarning? warning,
  BackupDestination? copy,
  bool lowDiskSpace = false,
}) => BackupStatus(
  enabled: true,
  running: false,
  warning: warning,
  staleAfterHours: 26,
  lowDiskSpace: lowDiskSpace,
  primary: BackupDestination(
    configured: true,
    dir: '/srv/payneat/data/backups',
    fileCount: 12,
    lastSuccess: _lastShiftClose,
    lastFailure: warning == BackupWarning.failed
        ? BackupFailureRecord(
            at: DateTime(2026, 10, 5, 10),
            reason: 'scheduled',
            code: 'EACCES',
            message: 'permission denied',
          )
        : null,
  ),
  copy: copy ?? const BackupDestination(configured: false),
);

void main() {
  tearDown(Get.reset);

  Future<void> pumpApp(WidgetTester tester, Widget child) async {
    await tester.pumpWidget(
      GetMaterialApp(
        translations: AppTranslations(),
        locale: LocaleService.english,
        home: Scaffold(body: SingleChildScrollView(child: child)),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> pumpCard(WidgetTester tester, BackupStatus status) async {
    final repository = _StatusRepository(status);
    Get.put(
      BackupController(
        getStatus: GetBackupStatusUseCase(repository),
        backupNow: BackupNowUseCase(repository),
      ),
    );
    await pumpApp(tester, const BackupCard());
  }

  group('การ์ดสำรองข้อมูลในหน้าตั้งค่า', () {
    testWidgets('แสดงเวลาล่าสุด ขนาด จำนวนไฟล์ และแนะนำที่เก็บชุดที่สอง', (
      tester,
    ) async {
      await pumpCard(tester, _status());

      expect(find.text('OK'), findsOneWidget);
      expect(find.textContaining('after shift close'), findsOneWidget);
      expect(find.text('4.5 MB'), findsOneWidget);
      expect(find.text('12 files'), findsOneWidget);
      expect(find.text('/srv/payneat/data/backups'), findsOneWidget);
      expect(
        find.byKey(const Key('backup-copy-not-configured')),
        findsOneWidget,
      );
      expect(find.byKey(const Key('backup-warning')), findsNothing);
      // ไม่มีปุ่มกู้คืนหรือดาวน์โหลด มีแค่คำอธิบายว่ากู้คืนบนเครื่องเซิร์ฟเวอร์
      expect(find.textContaining('npm run db:restore'), findsOneWidget);
      expect(find.textContaining('Download'), findsNothing);
    });

    testWidgets('ชุดที่สองล้มเหลว แสดงแยกจากชุดแรกที่ยังสำเร็จ', (
      tester,
    ) async {
      await pumpCard(
        tester,
        _status(
          copy: BackupDestination(
            configured: true,
            dir: '/mnt/usb/payneat',
            fileCount: 3,
            lastFailure: BackupFailureRecord(
              at: DateTime(2026, 10, 4, 22, 15),
              reason: 'shift-close',
              code: 'ENOENT',
              message: 'no such file or directory',
            ),
            failing: true,
          ),
        ),
      );

      expect(find.byKey(const Key('backup-warning')), findsNothing);
      expect(find.text('/mnt/usb/payneat'), findsOneWidget);
      expect(find.textContaining('no such file or directory'), findsOneWidget);
    });

    testWidgets('ครั้งล่าสุดล้มเหลว เตือนพร้อมเหตุผล และเตือนดิสก์ใกล้เต็ม', (
      tester,
    ) async {
      await pumpCard(
        tester,
        _status(warning: BackupWarning.failed, lowDiskSpace: true),
      );

      expect(find.text('Needs attention'), findsOneWidget);
      expect(find.byKey(const Key('backup-warning')), findsOneWidget);
      expect(find.textContaining('The last backup failed'), findsOneWidget);
      expect(find.text('permission denied'), findsOneWidget);
      expect(find.byKey(const Key('backup-low-disk')), findsOneWidget);
    });

    testWidgets('กดสำรองตอนนี้ แสดงชื่อไฟล์ในการ์ด', (tester) async {
      await pumpCard(tester, _status());

      await tester.ensureVisible(find.byKey(const Key('backup-now')));
      await tester.tap(find.byKey(const Key('backup-now')));
      await tester.pumpAndSettle();

      expect(find.text('Backed up: payneat-x-manual.sqlite'), findsOneWidget);
    });
  });

  group('แถบเตือนบนหน้าหลัก', () {
    Future<void> pumpBanner(
      WidgetTester tester,
      BackupStatus status, {
      VoidCallback? onOpenSettings,
    }) async {
      Get.put(
        BackupWarningController(
          getStatus: GetBackupStatusUseCase(_StatusRepository(status)),
        ),
      );
      await pumpApp(
        tester,
        BackupWarningBanner(onOpenSettings: onOpenSettings),
      );
    }

    final banner = find.byKey(const Key('backup-warning-banner'));

    // ตัวเตือนโหลดสถานะใหม่ทุก 15 นาที — หยุดตัวจับเวลาก่อนจบเทสต์
    void stopRefresh() => Get.delete<BackupWarningController>();

    testWidgets('บทบาทที่ไม่ได้ลงทะเบียนตัวเตือน (cashier ฯลฯ) ไม่เห็นอะไร', (
      tester,
    ) async {
      await pumpApp(tester, const BackupWarningBanner());
      expect(banner, findsNothing);
    });

    testWidgets('สำรองสำเร็จล่าสุดยังไม่เกินเวลา ไม่เตือน', (tester) async {
      await pumpBanner(tester, _status());
      expect(banner, findsNothing);
      stopRefresh();
    });

    testWidgets('admin: เกิน 26 ชั่วโมง เตือนพร้อมปุ่มไปหน้าตั้งค่า', (
      tester,
    ) async {
      var opened = 0;
      await pumpBanner(
        tester,
        _status(warning: BackupWarning.stale),
        onOpenSettings: () => opened++,
      );

      expect(banner, findsOneWidget);
      expect(find.textContaining('more than 26 hours'), findsOneWidget);
      await tester.tap(find.text('View backups'));
      expect(opened, 1);
      stopRefresh();
    });

    testWidgets('manager: ไม่มีปุ่มตั้งค่า บอกให้แจ้งเจ้าของร้านแทน', (
      tester,
    ) async {
      await pumpBanner(tester, _status(warning: BackupWarning.never));

      expect(banner, findsOneWidget);
      expect(
        find.text('No backup has succeeded yet Tell the shop owner.'),
        findsOneWidget,
      );
      expect(find.text('View backups'), findsNothing);
      stopRefresh();
    });
  });
}
