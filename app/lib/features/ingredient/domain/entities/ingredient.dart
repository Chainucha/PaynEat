// Copyright 2026 Suruch Chakrapeesirisuk
// SPDX-License-Identifier: Apache-2.0

/// วัตถุดิบ/สต๊อก (ดู docs/tickets/06-inventory-stock.md) — หน่วยนับ (unit) เป็น string
/// อิสระที่ร้านตั้งเอง เช่น "กก.", "ลิตร", "ชิ้น" ไม่มี unit conversion ข้ามหน่วย
///
/// วัตถุดิบที่ดึงมาจาก PaynEat ERP (ticket 25) มี [erpItem] และ [unit] เป็นรหัสหน่วยฐานของ ERP
/// (`kg`, `piece` …) ซึ่งแอปแสดงเป็นชื่อหน่วยตามภาษา
class Ingredient {
  const Ingredient({
    required this.id,
    required this.name,
    required this.unit,
    this.currentStock = 0,
    this.lowStockThreshold = 0,
    this.itemCode,
    this.erpItem,
    this.createdAt,
    this.updatedAt,
  });

  final int id;
  final String name;
  final String unit;
  final double currentStock;
  final double lowStockThreshold;

  /// รหัสสินค้าใน PaynEat ERP ที่วัตถุดิบนี้จับคู่ — ตั้งเองได้ในโหมดเดี่ยว
  final String? itemCode;

  /// ข้อมูลจากรายการสินค้าใน ERP (null = ไม่มีใน ERP)
  final ErpItemInfo? erpItem;
  final String? createdAt;
  final String? updatedAt;

  bool get isLowStock => currentStock <= lowStockThreshold;

  @override
  bool operator ==(Object other) =>
      identical(this, other) || (other is Ingredient && other.id == id);

  @override
  int get hashCode => id.hashCode;
}

/// ข้อมูลของรายการสินค้าใน PaynEat ERP ที่ POS ไม่มีช่องเก็บเอง
class ErpItemInfo {
  const ErpItemInfo({required this.nameEn, required this.active});

  final String nameEn;

  /// false = ERP เลิกใช้รายการนี้แล้ว (ERP ไม่ลบ แค่ปิด)
  final bool active;
}

/// วัตถุดิบ 1 ตัวที่ผูกไว้กับเมนู + ปริมาณที่ใช้ต่อ 1 ที่ (qtyPerUnit)
class MenuItemIngredientUsage {
  const MenuItemIngredientUsage({
    required this.ingredientId,
    required this.qtyPerUnit,
    this.ingredientName,
    this.unit,
  });

  final int ingredientId;
  final double qtyPerUnit;
  final String? ingredientName;
  final String? unit;
}
