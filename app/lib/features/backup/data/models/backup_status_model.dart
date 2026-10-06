// Copyright 2026 Suruch Chakrapeesirisuk
// SPDX-License-Identifier: Apache-2.0

import '../../domain/entities/backup_status.dart';

/// แปลงคำตอบของ `GET /backups/status`, `POST /backups` และฟิลด์ `backup` ในคำตอบของการปิดกะ
class BackupStatusModel {
  const BackupStatusModel._();

  static BackupStatus fromJson(Map<String, dynamic> json) {
    final primary = _map(json['primary']) ?? const {};
    final copy = _map(json['copy']) ?? const {};
    return BackupStatus(
      enabled: json['enabled'] as bool? ?? true,
      running: json['running'] as bool? ?? false,
      warning: BackupWarning.parse(json['warning'] as String?),
      staleAfterHours: (json['staleAfterHours'] as num?)?.toInt() ?? 26,
      lowDiskSpace: json['lowDiskSpace'] as bool? ?? false,
      primary: _destination(primary, configured: true),
      copy: _destination(
        copy,
        configured: copy['configured'] as bool? ?? false,
      ),
    );
  }

  static BackupRunResult resultFromJson(Map<String, dynamic> json) {
    final copy = _map(json['copy']);
    return BackupRunResult(
      ok: json['ok'] as bool? ?? false,
      file: json['file'] as String?,
      sizeBytes: (json['sizeBytes'] as num?)?.toInt(),
      code: json['code'] as String?,
      message: json['message'] as String?,
      copyFailed: copy != null && copy['ok'] == false,
    );
  }

  static BackupNowOutcome outcomeFromJson(Map<String, dynamic> json) =>
      BackupNowOutcome(
        result: resultFromJson(_map(json['result']) ?? const {}),
        status: fromJson(_map(json['status']) ?? const {}),
      );

  static Map<String, dynamic>? _map(Object? value) =>
      value is Map ? value.cast<String, dynamic>() : null;

  static DateTime? _time(Object? value) =>
      value is String ? DateTime.tryParse(value)?.toLocal() : null;

  static BackupDestination _destination(
    Map<String, dynamic> json, {
    required bool configured,
  }) => BackupDestination(
    configured: configured,
    dir: json['dir'] as String?,
    fileCount: (json['fileCount'] as num?)?.toInt() ?? 0,
    lastSuccess: _record(_map(json['lastSuccess'])),
    lastFailure: _failure(_map(json['lastFailure'])),
    failing: json['failing'] as bool? ?? false,
  );

  static BackupRecord? _record(Map<String, dynamic>? json) {
    final at = _time(json?['at']);
    if (json == null || at == null) return null;
    return BackupRecord(
      at: at,
      file: json['file'] as String? ?? '',
      reason: json['reason'] as String? ?? '',
      sizeBytes: (json['sizeBytes'] as num?)?.toInt(),
    );
  }

  static BackupFailureRecord? _failure(Map<String, dynamic>? json) {
    final at = _time(json?['at']);
    if (json == null || at == null) return null;
    return BackupFailureRecord(
      at: at,
      reason: json['reason'] as String? ?? '',
      code: json['code'] as String? ?? 'BACKUP_FAILED',
      message: json['message'] as String? ?? '',
    );
  }
}
