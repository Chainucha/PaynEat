// Copyright 2026 Suruch Chakrapeesirisuk
// SPDX-License-Identifier: Apache-2.0

import '../../../../core/localization/localized_name.dart';

/// หมวดหมู่อาหาร เช่น อาหารจานเดียว / เครื่องดื่ม
class Category {
  const Category({
    required this.id,
    required this.name,
    this.nameEn,
    this.nameKo,
    this.icon,
    this.sortOrder = 0,
    this.isActive = true,
    this.itemCount = 0,
    this.stationId,
  });

  final int id;
  final String name;
  final String? nameEn;
  final String? nameKo;
  final String? icon;
  final int sortOrder;
  final bool isActive;
  final int itemCount;

  /// สถานีครัวตั้งต้นของทุกเมนูในหมวดนี้ (ticket 34) — null = ใช้สถานีค่าเริ่มต้นของร้าน
  /// เมนูรายตัวทับค่านี้ได้ที่ `MenuItem.stationId`
  final int? stationId;

  /// ชื่อที่จะแสดงตามภาษาปัจจุบัน (ดู [LocalizedName.pick])
  String get displayName =>
      LocalizedName.pick(name: name, nameEn: nameEn, nameKo: nameKo);

  @override
  bool operator ==(Object other) =>
      identical(this, other) || (other is Category && other.id == id);

  @override
  int get hashCode => id.hashCode;
}
