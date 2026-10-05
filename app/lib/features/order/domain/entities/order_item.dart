// Copyright 2026 Suruch Chakrapeesirisuk
// SPDX-License-Identifier: Apache-2.0

import '../../../../core/constants/app_constants.dart';

/// ตัวเลือกที่ลูกค้าเลือกไว้ ณ ตอนสั่ง (snapshot — ราคาไม่เปลี่ยนตามเมนูภายหลัง)
class SelectedOption {
  const SelectedOption({
    required this.id,
    required this.name,
    this.groupName,
    this.priceDelta = 0,
  });

  final int id;
  final String name;
  final String? groupName;
  final double priceDelta;
}

/// รายการอาหาร 1 บรรทัดในออเดอร์
class OrderItem {
  const OrderItem({
    required this.id,
    required this.orderId,
    required this.name,
    required this.unitPrice,
    required this.quantity,
    required this.lineTotal,
    required this.status,
    this.menuItemId,
    this.options = const [],
    this.optionsPrice = 0,
    this.note,
    this.isPaid = false,
    this.kitchenReached,
    this.createdAt,
    this.updatedAt,
    this.orderCode,
    this.tableName,
    this.orderType,
    this.stationId,
    this.stationName,
    this.stationCode,
    this.weightGrams,
  });

  final int id;
  final int orderId;
  final int? menuItemId;
  final String name;
  final double unitPrice;
  final int quantity;

  /// น้ำหนักที่ชั่งได้ของสินค้าขายตามน้ำหนัก (กรัม) — null = ขายเป็นชิ้น
  final int? weightGrams;
  final List<SelectedOption> options;
  final double optionsPrice;
  final double lineTotal;
  final String? note;
  final String status;

  /// จ่ายไปแล้วในรอบแยกบิลรายการอาหารหรือยัง (ใช้กันเลือกจ่ายซ้ำ)
  final bool isPaid;

  /// ขั้นที่ครัวเคยทำถึง (cooking/ready/served) ไม่ถอยลงแม้ครัวกด "เลิกทำ" — null = ครัวยังไม่เคยเริ่ม
  /// (T05 #104, docs/DECISIONS.md #86)
  final String? kitchenReached;
  final String? createdAt;
  final String? updatedAt;

  // เติมมาเฉพาะตอนดึงจากคิวครัว
  final String? orderCode;
  final String? tableName;
  final String? orderType;

  /// สถานีครัวที่ประทับไว้ตอนบันทึกรายการ (ticket 34) — [stationName] คือชื่อ ณ ตอนนั้น
  /// เปลี่ยนชื่อสถานีหรือย้ายเมนูไปสถานีอื่นภายหลังจึงไม่กระทบตั๋วที่ครัวกำลังทำอยู่
  final int? stationId;
  final String? stationName;

  /// รหัสสถานี join มาให้เฉพาะตอนดึงจากคิวครัว — ใช้เป็นกุญแจของชิปกรองบนจอครัว
  final String? stationCode;

  String get statusLabel => OrderItemStatus.label(status);
  bool get isCancelled => status == OrderItemStatus.cancelled;

  /// ครัวเคยลงมือทำแล้ว — นับรวมรายการที่ถูกเลิกทำถอยกลับไปรอทำ: แก้/ลบไม่ได้ ยกเลิกได้โดยผู้จัดการเท่านั้น
  bool get kitchenStarted =>
      status != OrderItemStatus.pending || kitchenReached != null;
  bool get isEditable => !kitchenStarted;
  String? get nextStatus => OrderItemStatus.next(status);
  String? get nextActionLabel => OrderItemStatus.nextActionLabel(status);

  String get optionsSummary => options.map((option) => option.name).join(' • ');

  bool get isWeighed => weightGrams != null;

  @override
  bool operator ==(Object other) =>
      identical(this, other) || (other is OrderItem && other.id == id);

  @override
  int get hashCode => id.hashCode;
}
