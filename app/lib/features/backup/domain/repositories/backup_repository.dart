// Copyright 2026 Suruch Chakrapeesirisuk
// SPDX-License-Identifier: Apache-2.0

import '../../../../core/usecases/result.dart';
import '../entities/backup_status.dart';

/// การสำรองข้อมูลของเซิร์ฟเวอร์ร้าน (ดู docs/tickets/33-automatic-backup.md)
///
/// ไม่มีเมธอดกู้คืนหรือดาวน์โหลด: กู้คืนเป็นคำสั่งบนเครื่องเซิร์ฟเวอร์เท่านั้น (`npm run db:restore`)
abstract class BackupRepository {
  /// สถานะสำหรับหน้าตั้งค่า (admin) และแถบเตือน (admin, manager)
  Future<Result<BackupStatus>> getStatus();

  /// "สำรองข้อมูลตอนนี้" (admin) — สำรองไม่สำเร็จยังเป็น success โดยบอกใน [BackupNowOutcome.result]
  Future<Result<BackupNowOutcome>> backupNow();
}
