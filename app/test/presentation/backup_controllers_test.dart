// Copyright 2026 Suruch Chakrapeesirisuk
// SPDX-License-Identifier: Apache-2.0

import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:payneat_pos/core/constants/app_constants.dart';
import 'package:payneat_pos/core/errors/failures.dart';
import 'package:payneat_pos/core/localization/app_translations.dart';
import 'package:payneat_pos/core/localization/locale_service.dart';
import 'package:payneat_pos/core/usecases/result.dart';
import 'package:payneat_pos/features/backup/data/models/backup_status_model.dart';
import 'package:payneat_pos/features/backup/domain/entities/backup_status.dart';
import 'package:payneat_pos/features/backup/domain/repositories/backup_repository.dart';
import 'package:payneat_pos/features/backup/domain/usecases/backup_usecases.dart';
import 'package:payneat_pos/features/backup/presentation/controllers/backup_controller.dart';
import 'package:payneat_pos/features/backup/presentation/controllers/backup_warning_controller.dart';
import 'package:payneat_pos/features/home/presentation/bindings/home_binding.dart';
import 'package:payneat_pos/features/shift/data/models/shift_model.dart';

/// ส่วน "สำรองข้อมูล" ในหน้าตั้งค่าและแถบเตือนบนหน้าหลัก (ticket 33)
class _FakeBackupRepository implements BackupRepository {
  final statusResults = <Result<BackupStatus>>[];
  Result<BackupNowOutcome>? backupNowResult;
  int statusCalls = 0;
  int backupNowCalls = 0;

  @override
  Future<Result<BackupStatus>> getStatus() async {
    statusCalls += 1;
    return statusResults.isEmpty
        ? Result.success(_status())
        : statusResults.removeAt(0);
  }

  @override
  Future<Result<BackupNowOutcome>> backupNow() async {
    backupNowCalls += 1;
    return backupNowResult!;
  }
}

/// คำตอบจริงของ `GET /backups/status` (backup.service.js status())
Map<String, dynamic> _statusJson({
  String? warning,
  bool enabled = true,
  bool copyConfigured = true,
  bool copyFailing = false,
}) => {
  'enabled': enabled,
  'running': false,
  'warning': warning,
  'staleAfterHours': 26,
  'lowDiskSpace': false,
  'primary': {
    'dir': '/srv/payneat/data/backups',
    'fileCount': 12,
    'lastSuccess': {
      'at': '2026-10-04T15:15:30.000Z',
      'file': 'payneat-2026-10-04T221530+0700-shift-close.sqlite',
      'sizeBytes': 4718592,
      'reason': 'shift-close',
    },
    'lastFailure': warning == 'failed'
        ? {
            'at': '2026-10-05T03:00:00.000Z',
            'reason': 'scheduled',
            'code': 'EACCES',
            'message': 'permission denied',
          }
        : null,
  },
  'copy': {
    'configured': copyConfigured,
    'dir': copyConfigured ? '/mnt/usb/payneat' : null,
    'fileCount': copyConfigured ? 11 : 0,
    'lastSuccess': copyConfigured
        ? {
            'at': '2026-10-03T15:15:30.000Z',
            'file': 'payneat-2026-10-03T221530+0700-shift-close.sqlite',
            'reason': 'shift-close',
          }
        : null,
    'lastFailure': copyFailing
        ? {
            'at': '2026-10-04T15:15:31.000Z',
            'reason': 'shift-close',
            'code': 'ENOENT',
            'message': 'no such file or directory',
          }
        : null,
    'failing': copyFailing,
  },
};

BackupStatus _status({String? warning, bool enabled = true}) =>
    BackupStatusModel.fromJson(_statusJson(warning: warning, enabled: enabled));

BackupController _controller(
  _FakeBackupRepository repository, {
  void Function(BackupStatus)? onStatus,
}) => BackupController(
  getStatus: GetBackupStatusUseCase(repository),
  backupNow: BackupNowUseCase(repository),
  onStatus: onStatus,
);

void main() {
  setUp(() {
    Get.testMode = true;
    Get.addTranslations(AppTranslations().keys);
    Get.locale = LocaleService.english;
  });
  tearDown(Get.reset);

  group('BackupStatusModel', () {
    test('อ่านคำตอบของ backend: ที่เก็บสองที่แยกสถานะกัน', () {
      final status = BackupStatusModel.fromJson(
        _statusJson(warning: 'failed', copyFailing: true),
      );

      expect(status.warning, BackupWarning.failed);
      expect(status.needsAttention, isTrue);
      expect(status.primary.fileCount, 12);
      expect(status.primary.lastSuccess!.sizeBytes, 4718592);
      expect(status.primary.lastSuccess!.reason, 'shift-close');
      expect(status.primary.lastFailure!.code, 'EACCES');
      expect(status.copy.configured, isTrue);
      expect(status.copy.failing, isTrue);
      expect(status.copy.lastFailure!.message, 'no such file or directory');
    });

    test('ไม่มีคำเตือน = ไม่ต้องตรวจ, ปิดการสำรอง = ไม่เตือนแม้มีคำเตือน', () {
      expect(_status().needsAttention, isFalse);
      expect(_status(warning: 'never', enabled: false).needsAttention, isFalse);
    });

    test('ผลของ POST /backups แยก "ชุดที่สองล้มเหลว" ออกจากชุดแรก', () {
      final outcome = BackupStatusModel.outcomeFromJson({
        'result': {
          'ok': true,
          'file': 'payneat-x-manual.sqlite',
          'sizeBytes': 10,
          'copy': {'ok': false, 'code': 'ENOENT', 'message': 'missing'},
        },
        'status': _statusJson(copyFailing: true),
      });

      expect(outcome.result.ok, isTrue);
      expect(outcome.result.copyFailed, isTrue);
      expect(outcome.status.copy.failing, isTrue);
    });

    test('คำตอบของการปิดกะบอกว่าสำรองหลังปิดกะล้มเหลว', () {
      final base = {
        'id': 3,
        'status': ShiftStatus.closed,
        'openedBy': 1,
        'openedAt': '2026-10-05T01:00:00Z',
        'openingCash': 1000,
      };
      expect(
        ShiftModel.fromJson({
          ...base,
          'backup': {'ok': false, 'code': 'EACCES', 'message': 'denied'},
        }).backupFailed,
        isTrue,
      );
      expect(
        ShiftModel.fromJson({
          ...base,
          'backup': {'ok': true, 'file': 'a.sqlite'},
        }).backupFailed,
        isFalse,
      );
      // ประวัติกะไม่มีฟิลด์ backup
      expect(ShiftModel.fromJson(base).backupFailed, isFalse);
    });
  });

  group('BackupController', () {
    test('โหลดสถานะตอนเปิดการ์ด', () async {
      final repository = _FakeBackupRepository();
      final controller = _controller(repository)..onInit();
      await Future<void>.delayed(Duration.zero);

      expect(controller.isLoading.value, isFalse);
      expect(controller.status.value!.primary.fileCount, 12);
      expect(controller.errorMessage.value, isNull);
    });

    test('โหลดไม่สำเร็จ แสดงเหตุผล', () async {
      final repository = _FakeBackupRepository()
        ..statusResults.add(Result.failure(ForbiddenFailure('forbidden')));
      final controller = _controller(repository)..onInit();
      await Future<void>.delayed(Duration.zero);

      expect(controller.errorMessage.value, 'forbidden');
      expect(controller.status.value, isNull);
    });

    test('สำรองตอนนี้สำเร็จ: บอกชื่อไฟล์ และส่งสถานะใหม่ให้แถบเตือน', () async {
      final forwarded = <BackupStatus>[];
      final repository = _FakeBackupRepository()
        ..backupNowResult = Result.success(
          BackupNowOutcome(
            result: const BackupRunResult(
              ok: true,
              file: 'payneat-x-manual.sqlite',
            ),
            status: _status(),
          ),
        );
      final controller = _controller(repository, onStatus: forwarded.add);

      await controller.backupNow();

      expect(repository.backupNowCalls, 1);
      expect(controller.actionError.value, isNull);
      expect(controller.actionNotice.value, contains('payneat-x-manual'));
      expect(forwarded.single.needsAttention, isFalse);
    });

    test('ชุดแรกสำเร็จแต่ชุดที่สองล้มเหลว บอกแยกกัน', () async {
      final repository = _FakeBackupRepository()
        ..backupNowResult = Result.success(
          BackupNowOutcome(
            result: const BackupRunResult(
              ok: true,
              file: 'payneat-x-manual.sqlite',
              copyFailed: true,
            ),
            status: _status(),
          ),
        );
      final controller = _controller(repository);

      await controller.backupNow();

      expect(controller.actionError.value, isNull);
      expect(controller.actionNotice.value, contains('second location'));
    });

    test('สำรองไม่สำเร็จ แสดงเหตุผลจากเซิร์ฟเวอร์ค้างไว้ในการ์ด', () async {
      final repository = _FakeBackupRepository()
        ..backupNowResult = Result.success(
          BackupNowOutcome(
            result: const BackupRunResult(
              ok: false,
              code: 'EACCES',
              message: 'permission denied',
            ),
            status: _status(warning: 'failed'),
          ),
        );
      final controller = _controller(repository);

      await controller.backupNow();

      expect(controller.actionError.value, 'Backup failed: permission denied');
      expect(controller.status.value!.warning, BackupWarning.failed);
    });

    test('คำขอล้มเหลว (เช่นหมดเวลา) โหลดสถานะจริงมาแสดงด้วย', () async {
      final repository = _FakeBackupRepository()
        ..backupNowResult = Result.failure(NetworkFailure('timeout'));
      final controller = _controller(repository);

      await controller.backupNow();

      expect(controller.actionError.value, 'timeout');
      expect(repository.statusCalls, 1);
      expect(controller.status.value, isNotNull);
      expect(controller.isBusy.value, isFalse);
    });
  });

  group('แถบเตือนบนหน้าหลัก', () {
    test('admin และ manager เห็น ส่วน cashier, waiter, kitchen ไม่เห็น', () {
      expect(HomeBinding.showsBackupWarning(UserRole.admin), isTrue);
      expect(HomeBinding.showsBackupWarning(UserRole.manager), isTrue);
      expect(HomeBinding.showsBackupWarning(UserRole.cashier), isFalse);
      expect(HomeBinding.showsBackupWarning(UserRole.waiter), isFalse);
      expect(HomeBinding.showsBackupWarning(UserRole.kitchen), isFalse);
      expect(HomeBinding.showsBackupWarning(null), isFalse);
    });

    test('เตือนเมื่อเกินเวลาหรือล้มเหลว และหายเมื่อสำรองสำเร็จ', () async {
      final repository = _FakeBackupRepository()
        ..statusResults.add(Result.success(_status(warning: 'stale')));
      final controller = BackupWarningController(
        getStatus: GetBackupStatusUseCase(repository),
      )..onInit();
      await Future<void>.delayed(Duration.zero);

      expect(controller.attention?.warning, BackupWarning.stale);

      controller.apply(_status());
      expect(controller.attention, isNull);
      controller.onClose();
    });

    // testWidgets ใช้นาฬิกาจำลอง: pump(15 นาที) ยิงตัวจับเวลาได้โดยไม่ต้องรอจริง
    testWidgets('โหลดสถานะใหม่ตามรอบ เพราะหน้าหลักเปิดค้างไว้ทั้งวัน', (
      tester,
    ) async {
      final repository = _FakeBackupRepository()
        ..statusResults.addAll([
          Result.success(_status()),
          Result.success(_status(warning: 'failed')),
          Result.failure(NetworkFailure('offline')),
        ]);
      final controller = BackupWarningController(
        getStatus: GetBackupStatusUseCase(repository),
        refreshEvery: const Duration(minutes: 15),
      )..onInit();
      await tester.pump();
      expect(controller.attention, isNull);

      await tester.pump(const Duration(minutes: 15));
      expect(repository.statusCalls, 2);
      expect(controller.attention?.warning, BackupWarning.failed);

      // โหลดไม่สำเร็จไม่ล้างคำเตือนเดิม
      await tester.pump(const Duration(minutes: 15));
      expect(repository.statusCalls, 3);
      expect(controller.attention?.warning, BackupWarning.failed);
      controller.onClose();
    });
  });
}
