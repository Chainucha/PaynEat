// Copyright 2026 Suruch Chakrapeesirisuk
// SPDX-License-Identifier: Apache-2.0

import 'package:get/get.dart';

import '../../domain/entities/backup_status.dart';
import '../../domain/usecases/backup_usecases.dart';

/// ส่วน "สำรองข้อมูล" ในหน้าตั้งค่า (admin — ดู docs/tickets/33-automatic-backup.md)
///
/// ผลของปุ่ม "สำรองข้อมูลตอนนี้" แสดงเป็นข้อความในการ์ด ([actionError]/[actionNotice]) แบบเดียวกับการ์ด
/// ERP — เหตุผลอย่าง "เขียนโฟลเดอร์ไม่ได้" ต้องอยู่ให้อ่านจนกว่าจะแก้ ไม่ใช่หายไปในสามวินาที
class BackupController extends GetxController {
  BackupController({
    required GetBackupStatusUseCase getStatus,
    required BackupNowUseCase backupNow,
    this.onStatus,
  }) : _getStatus = getStatus,
       _backupNow = backupNow;

  final GetBackupStatusUseCase _getStatus;
  final BackupNowUseCase _backupNow;

  /// ส่งสถานะใหม่ต่อให้แถบเตือนบนหน้าหลัก — กดสำรองสำเร็จแล้วแถบเตือนหายทันที ไม่ต้องรอรอบโหลดถัดไป
  final void Function(BackupStatus status)? onStatus;

  final Rxn<BackupStatus> status = Rxn<BackupStatus>();
  final RxBool isLoading = true.obs;
  final RxBool isBusy = false.obs;
  final RxnString errorMessage = RxnString();
  final RxnString actionError = RxnString();
  final RxnString actionNotice = RxnString();

  @override
  void onInit() {
    super.onInit();
    load();
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

  void _apply(BackupStatus next) {
    status.value = next;
    onStatus?.call(next);
  }

  Future<void> backupNow() async {
    actionError.value = null;
    actionNotice.value = null;
    isBusy.value = true;
    final result = await _backupNow();
    isBusy.value = false;

    final failure = result.failureOrNull;
    if (failure != null) {
      actionError.value = failure.message;
      // คำขอหมดเวลาหรือเน็ตหลุดไม่ได้แปลว่าการสำรองล้ม เซิร์ฟเวอร์อาจยังสำรองต่อ — โหลดสถานะจริงมาแสดง
      final refreshed = (await _getStatus()).dataOrNull;
      if (refreshed != null) _apply(refreshed);
      return;
    }

    final outcome = result.dataOrNull!;
    _apply(outcome.status);
    final run = outcome.result;
    if (!run.ok) {
      actionError.value = 'backup_now_failed'.trParams({
        'reason': run.message ?? run.code ?? '',
      });
      return;
    }
    actionNotice.value = run.copyFailed
        ? 'backup_now_done_copy_failed'.trParams({'file': run.file ?? ''})
        : 'backup_now_done'.trParams({'file': run.file ?? ''});
  }
}
