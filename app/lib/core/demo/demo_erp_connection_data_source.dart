// Copyright 2026 Suruch Chakrapeesirisuk
// SPDX-License-Identifier: Apache-2.0

part of 'demo_data_sources.dart';

/// โหมดสาธิตแสดงสถานะ "ใช้งานเดี่ยว" เสมอ (ดู docs/tickets/25-erp-connected-mode.md) — ไม่มี PaynEat ERP
/// ให้เชื่อมต่อ และไม่ปลอมการเชื่อมต่อขึ้นมาเอง ปุ่มเชื่อมต่อจึงได้เหตุผลกลับไปแบบเดียวกับ error จาก backend
class DemoErpConnectionDataSource implements ErpConnectionRemoteDataSource {
  const DemoErpConnectionDataSource();

  static const _status = ErpConnectionStatus(
    mode: ErpMode.standalone,
    branches: [
      ErpBranchCheck(
        id: 1,
        name: 'สาขาสุขุมวิท',
        code: 'SUKHUMVIT',
        isActive: true,
      ),
    ],
  );

  Never _notInDemo() => throw ApiException(
    message: 'erp_error_demo_mode'.tr,
    statusCode: 409,
    code: 'ERP_NOT_IN_DEMO',
  );

  @override
  Future<ErpMode> getMode() => _delayed(() => ErpMode.standalone);

  @override
  Future<ErpConnectionStatus> getStatus() => _delayed(() => _status);

  @override
  Future<ErpConnectionStatus> connect({
    required String erpUrl,
    required String credential,
  }) => _delayed(_notInDemo);

  @override
  Future<ErpConnectionStatus> disconnect() => _delayed(() => _status);

  @override
  Future<ErpPullOutcome> pullNow() => _delayed(_notInDemo);

  @override
  Future<ErpConnectionStatus> createServedBranch(String code) =>
      _delayed(_notInDemo);

  @override
  Future<void> updateBranchCode(int branchId, String code) =>
      _delayed(_notInDemo);
}
