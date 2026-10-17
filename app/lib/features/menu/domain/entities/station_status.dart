// Copyright 2026 Suruch Chakrapeesirisuk
// SPDX-License-Identifier: Apache-2.0

import '../../../../core/localization/localized_name.dart';

/// สถานะเปิด/ปิดของสถานีครัวหนึ่งในสาขาปัจจุบัน (ticket 36)
///
/// "ปิด" เป็นเรื่องหน้างานรายสาขา ไม่ใช่ "ปิดใช้งาน" ของเครือร้าน (CONTEXT.md)
class StationStatus {
  const StationStatus({
    required this.stationId,
    required this.code,
    required this.name,
    this.nameEn,
    this.nameKo,
    this.icon,
    this.isClosed = false,
    this.closedAt,
    this.closedByName,
    this.pendingCount = 0,
  });

  final int stationId;
  final String code;
  final String name;
  final String? nameEn;
  final String? nameKo;
  final String? icon;
  final bool isClosed;

  /// เวลาที่ปิด (UTC จาก SQLite) — แสดงผ่าน `Formatters.dateTime`
  final String? closedAt;
  final String? closedByName;

  /// รายการของสถานีนี้ที่ยังค้างในครัว (รอทำ/กำลังทำ) — ใช้เตือนตอนจะปิด
  final int pendingCount;

  String get displayName =>
      LocalizedName.pick(name: name, nameEn: nameEn, nameKo: nameKo);

  String get labelWithIcon =>
      icon == null || icon!.isEmpty ? displayName : '$icon $displayName';
}
