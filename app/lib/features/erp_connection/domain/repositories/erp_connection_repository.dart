// Copyright 2026 Suruch Chakrapeesirisuk
// SPDX-License-Identifier: Apache-2.0

import '../../../../core/usecases/result.dart';
import '../entities/erp_connection_status.dart';

/// การเชื่อมต่อ PaynEat ERP ของเครื่องนี้ (ดู docs/tickets/25-erp-connected-mode.md)
abstract class ErpConnectionRepository {
  /// โหมดของเครื่อง — ทุกบทบาทอ่านได้
  Future<Result<ErpMode>> getMode();

  /// สถานะเต็มสำหรับหน้าตั้งค่า (admin)
  Future<Result<ErpConnectionStatus>> getStatus();

  Future<Result<ErpConnectionStatus>> connect({
    required String erpUrl,
    required String credential,
  });

  Future<Result<ErpConnectionStatus>> disconnect();

  Future<Result<ErpPullOutcome>> pullNow();

  /// "สร้างสาขานี้ในเครื่อง" สำหรับสาขาที่ ERP ให้ดูแลแต่ในเครื่องยังไม่มี (admin) — backend ดึงข้อมูลก่อนเสมอ
  /// และตอบ 409 ถ้ามีรหัสนี้ในเครื่องแล้ว (เช่น ERP เพิ่งย้ายสาขาเดิมมาใช้รหัสนี้) คืนสถานะหลังสร้าง
  Future<Result<ErpConnectionStatus>> createServedBranch(String code);

  /// แก้รหัสสาขาในเครื่อง (ใช้งานเดี่ยวเท่านั้น — โหมดเชื่อมต่อ backend ตอบ 409)
  Future<Result<void>> updateBranchCode(int branchId, String code);
}
