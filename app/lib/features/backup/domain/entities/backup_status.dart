// Copyright 2026 Suruch Chakrapeesirisuk
// SPDX-License-Identifier: Apache-2.0

/// สถานะการสำรองข้อมูลของเซิร์ฟเวอร์ร้าน (ticket 33 — `GET /backups/status`)
///
/// ไม่มีเนื้อหาของไฟล์สำรองและไม่มีทางดาวน์โหลด: ไฟล์สำรองมีเบอร์โทรลูกค้าและ hash รหัสผ่าน
/// เข้าถึงได้เฉพาะคนที่เข้าเครื่องเซิร์ฟเวอร์ได้ แอปแสดงแค่ว่าสำรองครั้งล่าสุดเมื่อไหร่ ที่ไหน และกี่ไฟล์
enum BackupWarning {
  /// ครั้งล่าสุดล้มเหลว
  failed,

  /// ยังไม่เคยสำรองสำเร็จ
  never,

  /// สำรองสำเร็จครั้งล่าสุดนานเกิน [BackupStatus.staleAfterHours] ชั่วโมง
  stale;

  static BackupWarning? parse(String? value) => switch (value) {
    'failed' => BackupWarning.failed,
    'never' => BackupWarning.never,
    'stale' => BackupWarning.stale,
    _ => null,
  };
}

/// ไฟล์สำรองที่เขียนสำเร็จ
class BackupRecord {
  const BackupRecord({
    required this.at,
    required this.file,
    required this.reason,
    this.sizeBytes,
  });

  final DateTime at;
  final String file;

  /// shift-close / scheduled / pre-migration / manual / pre-restore
  final String reason;
  final int? sizeBytes;
}

/// การสำรองที่ล้มเหลว — [message] เป็นเหตุผลจากเครื่องเซิร์ฟเวอร์ (เช่น เขียนโฟลเดอร์ไม่ได้)
class BackupFailureRecord {
  const BackupFailureRecord({
    required this.at,
    required this.reason,
    required this.code,
    required this.message,
  });

  final DateTime at;
  final String reason;
  final String code;
  final String message;
}

/// ที่เก็บหนึ่งที่ — ชุดแรก (`BACKUP_DIR`) หรือชุดที่สอง (`BACKUP_COPY_DIR`) แสดงสถานะแยกกัน
class BackupDestination {
  const BackupDestination({
    required this.configured,
    this.dir,
    this.fileCount = 0,
    this.lastSuccess,
    this.lastFailure,
    this.failing = false,
  });

  final bool configured;
  final String? dir;
  final int fileCount;
  final BackupRecord? lastSuccess;
  final BackupFailureRecord? lastFailure;

  /// ครั้งล่าสุดของที่เก็บนี้ล้มเหลว (ใหม่กว่าครั้งที่สำเร็จ)
  final bool failing;
}

class BackupStatus {
  const BackupStatus({
    required this.enabled,
    required this.running,
    required this.warning,
    required this.staleAfterHours,
    required this.lowDiskSpace,
    required this.primary,
    required this.copy,
  });

  /// false = ฐานข้อมูลอยู่ในหน่วยความจำ (เทสต์) ไม่มีอะไรให้สำรอง
  final bool enabled;
  final bool running;
  final BackupWarning? warning;
  final int staleAfterHours;
  final bool lowDiskSpace;
  final BackupDestination primary;
  final BackupDestination copy;

  /// แถบเตือนบนหน้าหลัก (admin และ manager) — เตือนเมื่อสำรองไม่สำเร็จหรือนานเกินไป
  bool get needsAttention => enabled && warning != null;
}

/// ผลของการสำรองหนึ่งครั้ง (ปุ่ม "สำรองข้อมูลตอนนี้" หรือหลังปิดกะ)
class BackupRunResult {
  const BackupRunResult({
    required this.ok,
    this.file,
    this.sizeBytes,
    this.code,
    this.message,
    this.copyFailed = false,
  });

  final bool ok;
  final String? file;
  final int? sizeBytes;
  final String? code;
  final String? message;

  /// ชุดแรกสำเร็จ แต่คัดลอกไปที่เก็บชุดที่สองไม่สำเร็จ
  final bool copyFailed;
}

/// คำตอบของ `POST /backups` — ผลของครั้งนี้พร้อมสถานะหลังสำรอง
class BackupNowOutcome {
  const BackupNowOutcome({required this.result, required this.status});

  final BackupRunResult result;
  final BackupStatus status;
}
