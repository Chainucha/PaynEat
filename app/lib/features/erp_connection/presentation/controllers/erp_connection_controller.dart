// Copyright 2026 Suruch Chakrapeesirisuk
// SPDX-License-Identifier: Apache-2.0

import 'package:flutter/widgets.dart';
import 'package:get/get.dart';

import '../../../../core/errors/failures.dart';
import '../../domain/entities/erp_connection_status.dart';
import '../../domain/usecases/erp_connection_usecases.dart';

/// ส่วน PaynEat ERP ของหัวข้อ "การเชื่อมต่อ" ในหน้าตั้งค่า (admin — ดู docs/tickets/25-erp-connected-mode.md)
///
/// ผลของแต่ละปุ่มแสดงเป็นข้อความในการ์ด ([actionError]/[actionNotice]) ไม่ใช่ snackbar — เหตุผลอย่าง
/// "สาขาไหนต้องแก้รหัส" หรือ "ERP ไม่รับ credential" ต้องอยู่ให้อ่านจนกว่าจะแก้ ไม่ใช่หายไปในสามวินาที
class ErpConnectionController extends GetxController {
  ErpConnectionController({
    required GetErpStatusUseCase getStatus,
    required ConnectErpUseCase connect,
    required DisconnectErpUseCase disconnect,
    required PullErpNowUseCase pullNow,
    required UpdateBranchCodeUseCase updateBranchCode,
    required CreateServedBranchUseCase createServedBranch,
  }) : _getStatus = getStatus,
       _connect = connect,
       _disconnect = disconnect,
       _pullNow = pullNow,
       _updateBranchCode = updateBranchCode,
       _createServedBranch = createServedBranch;

  final GetErpStatusUseCase _getStatus;
  final ConnectErpUseCase _connect;
  final DisconnectErpUseCase _disconnect;
  final PullErpNowUseCase _pullNow;
  final UpdateBranchCodeUseCase _updateBranchCode;
  final CreateServedBranchUseCase _createServedBranch;

  final Rx<ErpConnectionStatus> status = ErpConnectionStatus.standalone.obs;
  final RxBool isLoading = true.obs;
  final RxBool isBusy = false.obs;
  final RxnString errorMessage = RxnString();
  final RxnString actionError = RxnString();
  final RxnString actionNotice = RxnString();

  /// โหมดเชื่อมต่อ: กด "เปลี่ยน credential" แล้วฟอร์มถึงแสดง
  final RxBool editingCredential = false.obs;

  final urlController = TextEditingController();

  /// credential อยู่ในช่องนี้แค่ระหว่างพิมพ์ — ล้างทันทีหลังบันทึกสำเร็จ และไม่ถูกเก็บในเครื่อง
  final credentialController = TextEditingController();

  static const credentialPrefix = 'pnepos_';

  @override
  void onInit() {
    super.onInit();
    load();
  }

  @override
  void onClose() {
    urlController.dispose();
    credentialController.dispose();
    super.onClose();
  }

  Future<void> load() async {
    isLoading.value = true;
    errorMessage.value = null;
    final result = await _getStatus();
    isLoading.value = false;
    result.fold(
      onSuccess: _apply,
      onFailure: (failure) => errorMessage.value = failure.message,
    );
  }

  void _apply(ErpConnectionStatus next) {
    status.value = next;
    final url = next.connection?.erpUrl;
    if (url != null && urlController.text.isEmpty) urlController.text = url;
  }

  void _clearMessages() {
    actionError.value = null;
    actionNotice.value = null;
  }

  /// ข้อความ error ที่อ่านแล้วรู้ว่าต้องทำอะไร — 422 ของช่องกรอกใช้ข้อความของช่องแรก
  String _messageOf(Failure failure) {
    final detail = failure.details?.firstOrNull?.message;
    return detail != null && detail.isNotEmpty ? detail : failure.message;
  }

  /// เข้าโหมดเชื่อมต่อ หรือบันทึก credential ใหม่ของการเชื่อมต่อเดิม
  Future<void> connect() async {
    _clearMessages();
    final url = urlController.text.trim();
    final credential = credentialController.text.trim();
    if (url.isEmpty) {
      actionError.value = 'erp_error_url_required'.tr;
      return;
    }
    if (!credential.startsWith(credentialPrefix)) {
      actionError.value = 'erp_error_credential_format'.tr;
      return;
    }
    if (status.value.branchesToFix.isNotEmpty) {
      actionError.value = 'erp_error_fix_branch_codes'.tr;
      return;
    }

    isBusy.value = true;
    final result = await _connect(
      ConnectErpParams(erpUrl: url, credential: credential),
    );
    isBusy.value = false;
    final failure = result.failureOrNull;
    if (failure != null) {
      actionError.value = _messageOf(failure);
      // สาขาที่ต้องแก้รหัสอาจเพิ่งเปลี่ยน (อีกเครื่องแก้) — โหลดใหม่ให้รายการตรงกับที่ backend ตรวจ
      if (failure is ServerFailure && failure.code == 'BRANCH_CODES_INVALID') {
        await _refresh();
      }
      return;
    }
    final next = result.dataOrNull!;
    credentialController.clear();
    editingCredential.value = false;
    _apply(next);
    // เชื่อมต่อได้แต่ดึงรอบแรกไม่สำเร็จ — การ์ดแสดงเหตุผลจาก lastError อยู่แล้ว
    actionNotice.value = 'erp_connected_notice'.trParams({
      'instance': next.connection?.instanceCode ?? '',
    });
  }

  /// โหลดสถานะใหม่เงียบ ๆ หลังการกระทำที่ล้มเหลว (ไม่ทับข้อความ error ของการกระทำนั้น)
  Future<void> _refresh() async {
    final refreshed = await _getStatus();
    final next = refreshed.dataOrNull;
    if (next != null) _apply(next);
  }

  Future<void> disconnect() async {
    _clearMessages();
    isBusy.value = true;
    final result = await _disconnect();
    isBusy.value = false;
    result.fold(
      onSuccess: (next) {
        _apply(next);
        editingCredential.value = false;
        actionNotice.value = 'erp_disconnected_notice'.tr;
      },
      onFailure: (failure) => actionError.value = _messageOf(failure),
    );
  }

  Future<void> pullNow() async {
    _clearMessages();
    isBusy.value = true;
    final result = await _pullNow();
    isBusy.value = false;
    final failure = result.failureOrNull;
    if (failure != null) {
      actionError.value = _messageOf(failure);
      // หน้าที่ดึงสำเร็จก่อนล้มยังถูกนำไปใช้ — โหลดสถานะใหม่ให้เห็นเวอร์ชันและเหตุผลล่าสุด
      await _refresh();
      return;
    }
    final outcome = result.dataOrNull!;
    _apply(outcome.status);
    actionNotice.value = 'erp_pulled_notice'.trParams({
      'count': '${outcome.applied}',
      'version': '${outcome.status.connection?.appliedVersion ?? 0}',
    });
  }

  /// แก้รหัสสาขาในเครื่องให้ตรงรูปแบบก่อนเชื่อมต่อ (ใช้งานเดี่ยวเท่านั้น)
  Future<bool> updateBranchCode(ErpBranchCheck branch, String code) async {
    _clearMessages();
    final value = code.trim().toUpperCase();
    if (!EcosystemCode.isValid(value)) {
      actionError.value = 'erp_error_branch_code_format'.tr;
      return false;
    }
    isBusy.value = true;
    final result = await _updateBranchCode(
      UpdateBranchCodeParams(branchId: branch.id, code: value),
    );
    isBusy.value = false;
    final failure = result.failureOrNull;
    if (failure != null) {
      actionError.value = _messageOf(failure);
      return false;
    }
    await load();
    return true;
  }

  /// "สร้างสาขานี้ในเครื่อง" — backend ดึงข้อมูลจาก ERP ก่อนแล้วสร้างด้วยรหัสและชื่อไทยของ ERP
  /// ถ้า ERP เพิ่งย้ายสาขาเดิมมาใช้รหัสนี้ backend ตอบ 409 พร้อมเหตุผล และรายการโหลดใหม่ให้เห็นว่าสาขาเดิมย้ายแล้ว
  Future<bool> createBranch(ErpServedBranch branch) async {
    _clearMessages();
    isBusy.value = true;
    final result = await _createServedBranch(branch.code);
    isBusy.value = false;
    final failure = result.failureOrNull;
    if (failure != null) {
      actionError.value = _messageOf(failure);
      await _refresh();
      return false;
    }
    final next = result.dataOrNull!;
    _apply(next);
    final created = next.branches.where((b) => b.code == branch.code);
    actionNotice.value = 'erp_branch_created_notice'.trParams({
      'name': created.isEmpty ? branch.nameTh : created.first.name,
      'code': branch.code,
    });
    return true;
  }

  /// การเชื่อมต่อ http ที่บันทึกไว้ก่อนกติกา https (ticket 32) — backend ไม่เรียก ERP เลยจนกว่าจะบันทึกที่อยู่
  /// https:// ใหม่พร้อม credential การ์ดจึงแสดงช่องที่อยู่ และปิดปุ่มที่ต้องเรียก ERP
  bool get transportBlocked =>
      status.value.connection?.transport == ErpTransport.insecureBlocked;

  /// กรอบเตือนสีแดงเรื่องช่องทางของ credential (หัวข้อ, คำอธิบาย) — null = ส่งแบบเข้ารหัสหรือในเครื่องเดียวกัน
  (String, String)? get transportWarning =>
      switch (status.value.connection?.transport) {
        ErpTransport.insecureAllowed => (
          'erp_transport_insecure_allowed_title'.tr,
          'erp_transport_insecure_allowed_note'.tr,
        ),
        ErpTransport.insecureBlocked => (
          'erp_transport_insecure_blocked_title'.tr,
          'erp_transport_insecure_blocked_note'.tr,
        ),
        _ => null,
      };

  /// ดึงตามรอบเวลาหยุดรอคนแก้ต้นเหตุ (credential ที่ถูกปฏิเสธและที่อยู่ http มีข้อความของตัวเองอยู่แล้ว)
  bool get pullStopped {
    final connection = status.value.connection;
    return connection != null &&
        connection.pullStopped &&
        !connection.credentialRejected &&
        !transportBlocked;
  }

  /// เหตุผลของการดึงครั้งล่าสุดที่ล้มเหลว เป็นประโยคตามภาษาของแอป (null = ครั้งล่าสุดสำเร็จ)
  String? get lastPullProblem {
    final connection = status.value.connection;
    if (connection == null || transportBlocked) return null;
    if (connection.credentialRejected) return 'erp_last_error_credential'.tr;
    final error = connection.lastError;
    if (error == null) return null;
    final key = 'erp_last_error_${error.kind}';
    final text = key.tr;
    return text == key ? 'erp_last_error_other'.tr : text;
  }
}
