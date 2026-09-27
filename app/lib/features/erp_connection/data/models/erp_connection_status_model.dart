// Copyright 2026 Suruch Chakrapeesirisuk
// SPDX-License-Identifier: Apache-2.0

import '../../domain/entities/erp_connection_status.dart';

/// แปลงคำตอบของ `GET/PUT/DELETE /erp/connection` — ไม่มีฟิลด์ credential ในคำตอบ (backend ไม่ส่งกลับ)
class ErpConnectionStatusModel {
  const ErpConnectionStatusModel._();

  static ErpConnectionStatus fromJson(Map<String, dynamic> json) {
    final connection = json['connection'] as Map<String, dynamic>?;
    return ErpConnectionStatus(
      mode: ErpMode.parse(json['mode'] as String?),
      connection: connection == null ? null : _connection(connection),
      branches: [
        for (final row in json['branches'] as List? ?? const [])
          _branch((row as Map).cast<String, dynamic>()),
      ],
      servedBranches: [
        for (final row in json['servedBranches'] as List? ?? const [])
          _served((row as Map).cast<String, dynamic>()),
      ],
    );
  }

  static ErpConnectionInfo _connection(Map<String, dynamic> json) {
    final error = json['lastError'] as Map<String, dynamic>?;
    return ErpConnectionInfo(
      erpUrl: json['erpUrl'] as String? ?? '',
      instanceCode: json['instanceCode'] as String? ?? '',
      instanceName: json['instanceName'] as String? ?? '',
      contractVersion: json['contractVersion'] as String? ?? '',
      appliedVersion: (json['appliedVersion'] as num?)?.toInt() ?? 0,
      latestVersion: (json['latestVersion'] as num?)?.toInt(),
      connectedAt: json['connectedAt'] as String?,
      lastPullAt: json['lastPullAt'] as String?,
      lastError: error == null
          ? null
          : ErpPullError(
              kind: error['kind'] as String? ?? 'internal',
              status: (error['status'] as num?)?.toInt(),
              reason: error['reason'] as String?,
              at: error['at'] as String?,
            ),
      credentialRejected: json['credentialRejected'] as bool? ?? false,
      pullStopped: json['pullStopped'] as bool? ?? false,
      retryAfter: json['retryAfter'] as String?,
    );
  }

  static ErpBranchCheck _branch(Map<String, dynamic> json) => ErpBranchCheck(
    id: (json['id'] as num).toInt(),
    name: json['name'] as String? ?? '',
    code: json['code'] as String?,
    isActive: json['isActive'] as bool? ?? true,
    codeProblem: BranchCodeProblem.parse(json['codeProblem'] as String?),
    servedByErp: json['servedByErp'] as bool?,
    supersededBy: json['supersededBy'] as String?,
  );

  static ErpServedBranch _served(Map<String, dynamic> json) => ErpServedBranch(
    code: json['code'] as String? ?? '',
    nameTh: json['nameTh'] as String? ?? '',
    nameEn: json['nameEn'] as String? ?? '',
    isActive: json['isActive'] as bool? ?? true,
    localBranchId: (json['localBranchId'] as num?)?.toInt(),
  );

  static ErpPullOutcome pullFromJson(Map<String, dynamic> json) {
    final result = (json['result'] as Map?)?.cast<String, dynamic>() ?? {};
    return ErpPullOutcome(
      applied: (result['applied'] as num?)?.toInt() ?? 0,
      skipped: (result['skipped'] as num?)?.toInt() ?? 0,
      status: fromJson(
        (json['status'] as Map?)?.cast<String, dynamic>() ?? const {},
      ),
    );
  }
}
