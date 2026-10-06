// Copyright 2026 Suruch Chakrapeesirisuk
// SPDX-License-Identifier: Apache-2.0

import 'dart:async';

import 'package:get/get.dart';

import '../../domain/entities/backup_status.dart';
import '../../domain/usecases/backup_usecases.dart';

/// แถบเตือนบนหน้าหลักของ admin และ manager (ticket 33) — เจ้าของร้านต้องรู้ว่าไม่ได้สำรองข้อมูล
/// โดยไม่ต้องเข้าไปดูเอง
///
/// โหลดสถานะตอนเข้าหน้าหลักและทุก [refreshEvery] เพราะเครื่องในร้านเปิดหน้าหลักค้างไว้ทั้งวัน
/// โหลดไม่สำเร็จไม่แสดงอะไร: เซิร์ฟเวอร์ไม่ตอบมีจุดเชื่อมต่อบน AppBar บอกอยู่แล้ว
class BackupWarningController extends GetxController {
  BackupWarningController({
    required GetBackupStatusUseCase getStatus,
    this.refreshEvery = const Duration(minutes: 15),
  }) : _getStatus = getStatus;

  final GetBackupStatusUseCase _getStatus;
  final Duration refreshEvery;

  final Rxn<BackupStatus> status = Rxn<BackupStatus>();
  Timer? _timer;

  @override
  void onInit() {
    super.onInit();
    reload();
    _timer = Timer.periodic(refreshEvery, (_) => reload());
  }

  @override
  void onClose() {
    _timer?.cancel();
    super.onClose();
  }

  Future<void> reload() async {
    final next = (await _getStatus()).dataOrNull;
    if (next != null) status.value = next;
  }

  void apply(BackupStatus next) => status.value = next;

  /// สถานะที่ต้องเตือน หรือ null ถ้าไม่มีอะไรต้องเตือน
  BackupStatus? get attention {
    final current = status.value;
    return current != null && current.needsAttention ? current : null;
  }
}
