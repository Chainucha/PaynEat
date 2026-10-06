// Copyright 2026 Suruch Chakrapeesirisuk
// SPDX-License-Identifier: Apache-2.0

import '../../../../core/localization/localized_name.dart';

/// สถานีครัวที่รับผิดชอบอาหารแต่ละจาน เช่น ครัวร้อน / ครัวเย็น / บาร์ (ticket 34)
///
/// [code] เป็นรหัสคงที่ที่ใช้ทั้งใน API (`?station=bar`) และในค่าที่จอครัวจำไว้ต่อเครื่อง
/// จึงแก้ไม่ได้หลังสร้าง ส่วนชื่อที่แสดงแก้ได้ตามปกติ
class KitchenStation {
  const KitchenStation({
    required this.id,
    required this.code,
    required this.name,
    this.nameEn,
    this.nameKo,
    this.icon,
    this.sortOrder = 0,
    this.isActive = true,
    this.isDefault = false,
    this.itemCount = 0,
  });

  final int id;
  final String code;
  final String name;
  final String? nameEn;
  final String? nameKo;
  final String? icon;
  final int sortOrder;
  final bool isActive;

  /// สถานีปลายทางของจานที่ไม่ได้กำหนดสถานีไว้เลย — มีได้สถานีเดียว
  final bool isDefault;

  /// จำนวนเมนูที่ตกลงสถานีนี้จริงตามกฎการตัดสิน (เมนู → หมวดหมู่ → ค่าเริ่มต้น)
  final int itemCount;

  /// ชื่อที่จะแสดงตามภาษาปัจจุบัน (ดู [LocalizedName.pick])
  String get displayName =>
      LocalizedName.pick(name: name, nameEn: nameEn, nameKo: nameKo);

  /// ชื่อพร้อมไอคอนสำหรับชิป/ดรอปดาวน์ — ไม่มีไอคอนก็เหลือแค่ชื่อ
  String get labelWithIcon =>
      icon == null || icon!.isEmpty ? displayName : '$icon $displayName';

  @override
  bool operator ==(Object other) =>
      identical(this, other) || (other is KitchenStation && other.id == id);

  @override
  int get hashCode => id.hashCode;
}
