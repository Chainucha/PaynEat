// Copyright 2026 Suruch Chakrapeesirisuk
// SPDX-License-Identifier: Apache-2.0

part of 'demo_data_sources.dart';

/// โหมดสาธิตจำลองสถานะการสำรองข้อมูลของร้านที่ตั้งไว้ครบ (ticket 33) ให้เห็นหน้าตาของส่วน "สำรองข้อมูล"
/// ข้อมูลสาธิตอยู่ในเบราว์เซอร์ ไม่มีไฟล์ถูกสร้างจริง — การ์ดบอกไว้ด้วย `backup_demo_note`
class DemoBackupDataSource implements BackupRemoteDataSource {
  DemoBackupDataSource();

  static const _dir = 'data/backups';
  static const _copyDir = '/mnt/usb-backup/payneat';
  static const _sizeBytes = 4718592;

  int _files = 14;
  DateTime? _manualAt;

  DateTime get _shiftCloseAt {
    final now = AppClock.now();
    final today = DateTime(now.year, now.month, now.day, 22, 15);
    return today.isAfter(now) ? today.subtract(const Duration(days: 1)) : today;
  }

  BackupStatus _status() {
    final manual = _manualAt;
    final last = BackupRecord(
      at: manual ?? _shiftCloseAt,
      file: manual == null
          ? 'payneat-demo-shift-close.sqlite'
          : 'payneat-demo-manual.sqlite',
      reason: manual == null ? 'shift-close' : 'manual',
      sizeBytes: _sizeBytes,
    );
    return BackupStatus(
      enabled: true,
      running: false,
      warning: null,
      staleAfterHours: 26,
      lowDiskSpace: false,
      primary: BackupDestination(
        configured: true,
        dir: _dir,
        fileCount: _files,
        lastSuccess: last,
      ),
      copy: BackupDestination(
        configured: true,
        dir: _copyDir,
        fileCount: _files,
        lastSuccess: last,
      ),
    );
  }

  @override
  Future<BackupStatus> getStatus() => _delayed(_status);

  @override
  Future<BackupNowOutcome> backupNow() => _delayed(() {
    _manualAt = AppClock.now();
    _files++;
    return BackupNowOutcome(
      result: const BackupRunResult(
        ok: true,
        file: 'payneat-demo-manual.sqlite',
        sizeBytes: _sizeBytes,
      ),
      status: _status(),
    );
  });
}
