// Copyright 2026 Suruch Chakrapeesirisuk
// SPDX-License-Identifier: Apache-2.0

import 'package:get/get.dart';

import '../../../core/utils/formatters.dart';
import '../domain/entities/backup_status.dart';

/// ประโยคเตือนเรื่องการสำรองข้อมูล ใช้ทั้งแถบเตือนบนหน้าหลักและการ์ดในหน้าตั้งค่า ให้พูดตรงกัน
class BackupWarningText {
  const BackupWarningText._();

  /// null = ไม่มีอะไรต้องเตือน
  static String? of(BackupStatus status) {
    if (!status.enabled) return null;
    final last = status.primary.lastSuccess;
    final failedAt = status.primary.lastFailure?.at;
    return switch (status.warning) {
      BackupWarning.failed => 'backup_warning_failed'.trParams({
        'time': failedAt == null ? '-' : Formatters.dateTimeOf(failedAt),
      }),
      BackupWarning.never => 'backup_warning_never'.tr,
      BackupWarning.stale => 'backup_warning_stale'.trParams({
        'hours': '${status.staleAfterHours}',
        'time': last == null ? '-' : Formatters.dateTimeOf(last.at),
      }),
      null => null,
    };
  }

  /// ชื่อจังหวะที่สำรอง (ปิดกะ, ตามรอบเวลา, ก่อนอัปเดต, กดเอง, ก่อนกู้คืน)
  static String reason(String reason) {
    final key = 'backup_reason_${reason.replaceAll('-', '_')}';
    final text = key.tr;
    return text == key ? reason : text;
  }
}
