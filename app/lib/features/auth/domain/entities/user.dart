// Copyright 2026 Suruch Chakrapeesirisuk
// SPDX-License-Identifier: Apache-2.0

import '../../../../core/constants/app_constants.dart';

/// ผู้ใช้งานระบบ — entity บริสุทธิ์ ไม่ผูกกับ JSON หรือ framework ใด ๆ
class User {
  const User({
    required this.id,
    required this.name,
    required this.username,
    required this.role,
    required this.isActive,
    this.branchId,
    this.branchName,
    this.stationIds = const [],
    this.stationCodes = const [],
  });

  final int id;
  final String name;
  final String username;
  final String role;
  final bool isActive;
  // สาขาที่ token ปัจจุบันทำงานอยู่ (ดู docs/tickets/11-multi-branch.md) — เป็นของ session ไม่ใช่
  // property ถาวรของ user คนเดียวมีได้หลายสาขา — null ได้เฉพาะ admin โหมด "ทุกสาขา"
  final int? branchId;
  final String? branchName;

  // สถานีครัวที่พนักงานคนนี้รับผิดชอบ (ticket 35) — ชุดว่าง = ไม่ผูกสถานี ซึ่งหมายถึง "เห็นทุกสถานี"
  // ใช้เลือกชิปสถานีบนจอครัวให้ล่วงหน้าเท่านั้น ไม่ได้ซ่อนตั๋ว จอยังสลับสถานีได้เอง
  // `stationIds` ให้หน้าจัดการพนักงานติ๊กช่อง, `stationCodes` ให้จอครัวใช้เลือกชิป
  final List<int> stationIds;
  final List<String> stationCodes;

  String get roleLabel => UserRole.label(role);

  bool get isManagement => UserRole.isManagement(role);
  bool get canTakeOrder => UserRole.canTakeOrder(role);
  bool get canCollectPayment => UserRole.canCollectPayment(role);
  bool get canSeeReports => UserRole.canSeeReports(role);
  bool get canHandleCredit => UserRole.canHandleCredit(role);
  bool get isKitchen => role == UserRole.kitchen;

  /// ตัวอักษรย่อสำหรับแสดงใน avatar
  String get initials {
    final trimmed = name.trim();
    if (trimmed.isEmpty) return '?';
    return trimmed.substring(0, 1).toUpperCase();
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) || (other is User && other.id == id);

  @override
  int get hashCode => id.hashCode;
}
