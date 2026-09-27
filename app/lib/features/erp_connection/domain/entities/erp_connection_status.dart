// Copyright 2026 Suruch Chakrapeesirisuk
// SPDX-License-Identifier: Apache-2.0

/// โหมดของเครื่อง (ดู docs/tickets/25-erp-connected-mode.md) — ค่าเริ่มต้นคือใช้งานเดี่ยว
enum ErpMode {
  standalone,
  connected;

  static ErpMode parse(String? value) =>
      value == 'connected' ? ErpMode.connected : ErpMode.standalone;
}

/// ปัญหาของรหัสสาขาที่ต้องแก้ก่อนเชื่อมต่อ ERP
enum BranchCodeProblem {
  missing,
  invalid;

  static BranchCodeProblem? parse(String? value) => switch (value) {
    'missing' => BranchCodeProblem.missing,
    'invalid' => BranchCodeProblem.invalid,
    _ => null,
  };
}

/// รหัสกลางของระบบนิเวศ PaynEat (รหัสสาขา รหัสสินค้า) — รูปแบบเดียวกับสัญญา POS v1 และ backend
class EcosystemCode {
  const EcosystemCode._();

  static final RegExp pattern = RegExp(r'^[A-Z0-9][A-Z0-9-]{1,31}$');

  static bool isValid(String? code) => code != null && pattern.hasMatch(code);
}

/// การดึงครั้งล่าสุดที่ล้มเหลว — `kind` ตามที่ backend จัดประเภทไว้ (credential_rejected, network …)
class ErpPullError {
  const ErpPullError({required this.kind, this.status, this.reason, this.at});

  final String kind;
  final int? status;
  final String? reason;
  final String? at;
}

/// การเชื่อมต่อที่บันทึกไว้ — ไม่มี credential: backend ไม่ส่งกลับมาหลังบันทึก
class ErpConnectionInfo {
  const ErpConnectionInfo({
    required this.erpUrl,
    required this.instanceCode,
    required this.instanceName,
    required this.contractVersion,
    required this.appliedVersion,
    this.latestVersion,
    this.connectedAt,
    this.lastPullAt,
    this.lastError,
    this.credentialRejected = false,
    this.pullStopped = false,
    this.retryAfter,
  });

  final String erpUrl;
  final String instanceCode;
  final String instanceName;
  final String contractVersion;
  final int appliedVersion;
  final int? latestVersion;
  final String? connectedAt;
  final String? lastPullAt;
  final ErpPullError? lastError;
  final bool credentialRejected;

  /// ดึงตามรอบเวลาหยุดไว้จนกว่าจะมีคนแก้ต้นเหตุ (ERP ตอบผิดสัญญา, สัญญา major อื่น, credential ใช้ไม่ได้)
  /// — กด "ดึงทันที" ได้ ถ้าสำเร็จ backend กลับมาดึงตามรอบเอง
  final bool pullStopped;
  final String? retryAfter;
}

/// สาขาในเครื่องพร้อมผลตรวจรหัส และว่า ERP ให้เครื่องนี้ดูแลไหม (null = ใช้งานเดี่ยว)
class ErpBranchCheck {
  const ErpBranchCheck({
    required this.id,
    required this.name,
    required this.isActive,
    this.code,
    this.codeProblem,
    this.servedByErp,
    this.supersededBy,
  });

  final int id;
  final String name;
  final String? code;
  final bool isActive;
  final BranchCodeProblem? codeProblem;
  final bool? servedByErp;
  final String? supersededBy;
}

/// สาขาที่ ERP ให้เครื่องนี้ดูแล — `localBranchId` null = ยังไม่มีสาขานี้ในเครื่อง
class ErpServedBranch {
  const ErpServedBranch({
    required this.code,
    required this.nameTh,
    required this.nameEn,
    required this.isActive,
    this.localBranchId,
  });

  final String code;
  final String nameTh;
  final String nameEn;
  final bool isActive;
  final int? localBranchId;
}

class ErpConnectionStatus {
  const ErpConnectionStatus({
    required this.mode,
    this.connection,
    this.branches = const [],
    this.servedBranches = const [],
  });

  static const standalone = ErpConnectionStatus(mode: ErpMode.standalone);

  final ErpMode mode;
  final ErpConnectionInfo? connection;
  final List<ErpBranchCheck> branches;
  final List<ErpServedBranch> servedBranches;

  bool get isConnected => mode == ErpMode.connected;

  /// สาขาที่เปิดใช้อยู่แต่รหัสยังใช้เชื่อมต่อไม่ได้ — ต้องแก้ก่อนกดเชื่อมต่อ
  List<ErpBranchCheck> get branchesToFix => branches
      .where((branch) => branch.isActive && branch.codeProblem != null)
      .toList(growable: false);

  /// สาขาในเครื่องที่ ERP ไม่ได้ให้เครื่องนี้ดูแล (โหมดเชื่อมต่อเท่านั้น)
  List<ErpBranchCheck> get branchesNotServed => branches
      .where((branch) => branch.isActive && branch.servedByErp == false)
      .toList(growable: false);

  /// สาขาที่ ERP ให้ดูแลแต่ในเครื่องยังไม่มี
  List<ErpServedBranch> get servedButMissing => servedBranches
      .where((branch) => branch.localBranchId == null)
      .toList(growable: false);
}

/// ผลของการกด "ดึงทันที"
class ErpPullOutcome {
  const ErpPullOutcome({
    required this.applied,
    required this.skipped,
    required this.status,
  });

  final int applied;
  final int skipped;
  final ErpConnectionStatus status;
}
