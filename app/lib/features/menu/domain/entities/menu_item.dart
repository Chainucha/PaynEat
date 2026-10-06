// Copyright 2026 Suruch Chakrapeesirisuk
// SPDX-License-Identifier: Apache-2.0

import '../../../../core/localization/localized_name.dart';
import '../../../ingredient/domain/entities/ingredient.dart';
import 'menu_option.dart';

/// เมนูอาหาร 1 รายการ
class MenuItem {
  const MenuItem({
    required this.id,
    required this.categoryId,
    required this.name,
    required this.price,
    this.categoryName,
    this.nameEn,
    this.nameKo,
    this.description,
    this.imageUrl,
    this.isAvailable = true,
    this.isRecommended = false,
    this.prepMinutes = 10,
    this.sortOrder = 0,
    this.optionGroups = const [],
    this.ingredients = const [],
    this.soldByWeight = false,
    this.barcode,
    this.scalePlu,
    this.stationId,
  });

  final int id;
  final int categoryId;
  final String? categoryName;
  final String name;
  final String? nameEn;
  final String? nameKo;
  final String? description;
  final double price;
  final String? imageUrl;
  final bool isAvailable;
  final bool isRecommended;
  final int prepMinutes;
  final int sortOrder;
  final List<MenuOptionGroup> optionGroups;

  /// วัตถุดิบที่ผูกไว้ + ปริมาณที่ใช้ต่อ 1 ที่ — ระบบตัดสต๊อกอัตโนมัติเมื่อขาย
  /// (ดู docs/tickets/06-inventory-stock.md)
  final List<MenuItemIngredientUsage> ingredients;

  /// ขายตามน้ำหนัก — [price] คือราคาต่อกิโลกรัม และต้องชั่งก่อนใส่ตะกร้าทุกครั้ง
  /// (ดู docs/tickets/18-sell-by-weight.md)
  final bool soldByWeight;

  /// บาร์โค้ดสินค้าสำเร็จรูป — สแกนแล้วลงตะกร้า 1 ชิ้น (ดู docs/tickets/19-barcode-scale.md)
  final String? barcode;

  /// รหัสสินค้าบนฉลากตาชั่ง (PLU) เก็บแบบไม่มีเลข 0 นำหน้า — ใช้กับเมนูขายตามน้ำหนักเท่านั้น
  final String? scalePlu;

  /// สถานีครัวของจานนี้ (ticket 34) — null = ตามหมวดหมู่ ซึ่งถอยไปหาสถานีค่าเริ่มต้นถ้าหมวดหมู่
  /// ก็ไม่ได้กำหนดไว้ สถานีถูกตัดสินและประทับลงตั๋วตอนบันทึกรายการ ไม่ใช่ตอนอ่านคิวครัว
  final int? stationId;

  /// ชื่อที่จะแสดงตามภาษาปัจจุบัน
  ///
  /// ลำดับการถอย: ชื่อในภาษานั้น → ชื่ออังกฤษ → ชื่อไทย
  /// ข้อมูลที่ร้านจริงกรอกเองมักมีแค่ชื่อไทย จึงต้องไม่คืนค่าว่างเด็ดขาด
  String get displayName =>
      LocalizedName.pick(name: name, nameEn: nameEn, nameKo: nameKo);

  bool get hasOptions => optionGroups.isNotEmpty;

  /// ต้องเปิดหน้าเลือกตัวเลือกก่อนใส่ตะกร้าไหม
  bool get requiresSelection =>
      optionGroups.any((group) => group.isRequired || group.options.length > 1);

  @override
  bool operator ==(Object other) =>
      identical(this, other) || (other is MenuItem && other.id == id);

  @override
  int get hashCode => id.hashCode;
}
