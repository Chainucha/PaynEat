// Copyright 2026 Suruch Chakrapeesirisuk
// SPDX-License-Identifier: Apache-2.0

import 'package:flutter/foundation.dart';
import 'package:get/get.dart';

import '../../../../core/network/socket_client.dart';
import '../../../../core/services/session_service.dart';
import '../../../menu/domain/entities/station_status.dart';
import '../../../menu/domain/usecases/menu_usecases.dart';

/// สถานะเปิด/ปิดของสถานีครัวในสาขาปัจจุบัน (ticket 36) — ใช้ร่วมกันระหว่างจอครัวกับหน้าสั่งอาหาร
///
/// event `station:status` ไม่ได้แยกห้องตามสาขา จึงไม่กรอง payload แต่โหลดสถานะของสาขาตัวเองใหม่
/// ทุกครั้งที่มี event — ได้ค่าที่ถูกต้องเสมอ และตารางนี้เล็กมาก
class StationStatusController extends GetxController {
  StationStatusController({
    required GetStationStatusesUseCase getStatuses,
    required SetStationClosedUseCase setClosed,
    required SessionService session,
  }) : _getStatuses = getStatuses,
       _setClosed = setClosed,
       _session = session;

  final GetStationStatusesUseCase _getStatuses;
  final SetStationClosedUseCase _setClosed;
  final SessionService _session;

  final RxList<StationStatus> statuses = <StationStatus>[].obs;
  final RxBool isLoading = false.obs;
  final RxnString errorMessage = RxnString();

  /// ขยับเมื่อชุดสถานีที่ปิดเปลี่ยน (ไม่นับโหลดแรก) — หน้าสั่งอาหารฟังค่านี้เพื่อโหลดเมนูใหม่
  final RxInt closedVersion = 0.obs;

  Set<int>? _lastClosedIds;
  VoidCallback? _unsubscribe;

  /// admin โหมด "ทุกสาขา" ไม่มีสาขาปัจจุบัน backend จึงตอบ 400 — ซ่อนปุ่มและแบนเนอร์ไปเลย
  bool get canUse =>
      _session.currentUser == null || _session.currentUser!.branchId != null;

  List<StationStatus> get closed =>
      statuses.where((status) => status.isClosed).toList(growable: false);

  @override
  void onInit() {
    super.onInit();
    load();
    _unsubscribe = _session.socket.on(
      SocketEvents.stationStatus,
      (_) => load(),
    );
  }

  @override
  void onClose() {
    _unsubscribe?.call();
    super.onClose();
  }

  Future<void> load() async {
    if (!canUse) return;
    isLoading.value = true;
    final result = await _getStatuses();
    isLoading.value = false;
    result.fold(
      onSuccess: _apply,
      onFailure: (failure) => errorMessage.value = failure.message,
    );
  }

  /// คืน true เมื่อสำเร็จ — ข้อความ error อยู่ใน [errorMessage] ให้ชีตแสดงเอง
  Future<bool> setClosed(StationStatus station, bool closed) async {
    final result = await _setClosed(
      SetStationClosedParams(stationId: station.stationId, closed: closed),
    );
    return result.fold(
      onSuccess: (updated) {
        _apply([
          for (final row in statuses)
            row.stationId == updated.stationId ? updated : row,
        ]);
        return true;
      },
      onFailure: (failure) {
        errorMessage.value = failure.message;
        return false;
      },
    );
  }

  void _apply(List<StationStatus> rows) {
    errorMessage.value = null;
    statuses.assignAll(rows);
    final ids = {
      for (final row in rows)
        if (row.isClosed) row.stationId,
    };
    final previous = _lastClosedIds;
    _lastClosedIds = ids;
    if (previous != null && !setEquals(previous, ids)) closedVersion.value++;
  }
}
