// Copyright 2026 Suruch Chakrapeesirisuk
// SPDX-License-Identifier: Apache-2.0

import 'package:get/get.dart';

/// บทบาทของผู้ใช้ในระบบ — ตรงกับ enum ฝั่ง backend
class UserRole {
  const UserRole._();

  static const String admin = 'admin';
  static const String manager = 'manager';
  static const String waiter = 'waiter';
  static const String cashier = 'cashier';
  static const String kitchen = 'kitchen';

  static const List<String> all = [admin, manager, waiter, cashier, kitchen];

  static const Map<String, String> _keys = {
    admin: 'role_admin',
    manager: 'role_manager',
    waiter: 'role_waiter',
    cashier: 'role_cashier',
    kitchen: 'role_kitchen',
  };

  static String label(String role) => (_keys[role] ?? role).tr;

  static bool isManagement(String role) => role == admin || role == manager;

  /// บัญชีที่ผู้จัดการจัดการได้ — ผู้จัดการและแอดมินเป็นของแอดมินเท่านั้น
  /// (mirror ของ user.service.js STAFF_ROLES, T22 #86)
  static const List<String> staffRoles = [waiter, cashier, kitchen];

  /// บทบาทที่ [actorRole] ตั้งให้บัญชีอื่นได้
  static List<String> assignableBy(String? actorRole) =>
      actorRole == admin ? all : staffRoles;

  /// [actorRole] แก้/ปิด/ตั้งรหัสใหม่ให้บัญชีบทบาท [targetRole] ได้ไหม (สาขาตรวจที่ backend)
  static bool canManage(String? actorRole, String targetRole) =>
      actorRole == admin ||
      (actorRole == manager && staffRoles.contains(targetRole));
  static bool canTakeOrder(String role) =>
      role == admin || role == manager || role == waiter || role == cashier;
  static bool canCollectPayment(String role) =>
      role == admin || role == manager || role == cashier || role == waiter;
  static bool canSeeReports(String role) =>
      role == admin || role == manager || role == cashier;

  /// ขายเชื่อ/รับชำระหนี้/วางบิล (ดู docs/tickets/20-b2b-credit.md) — ตรงกับ receivable.routes.js
  /// และกฎใน payment.service.js ที่ห้ามพนักงานเสิร์ฟขายเชื่อ แม้จะรับเงินสดได้ปกติ
  static bool canHandleCredit(String role) =>
      role == admin || role == manager || role == cashier;
}

/// สถานะโต๊ะ
class TableStatus {
  const TableStatus._();

  static const String available = 'available';
  static const String occupied = 'occupied';
  static const String reserved = 'reserved';
  static const String billing = 'billing';

  static const List<String> all = [available, occupied, reserved, billing];

  static const Map<String, String> _keys = {
    available: 'table_status_available',
    occupied: 'table_status_occupied',
    reserved: 'table_status_reserved',
    billing: 'table_status_billing',
  };

  static String label(String status) => (_keys[status] ?? status).tr;
}

/// สถานะออเดอร์
class OrderStatus {
  const OrderStatus._();

  static const String open = 'open';
  static const String inKitchen = 'in_kitchen';
  static const String served = 'served';
  static const String paid = 'paid';
  static const String cancelled = 'cancelled';

  static const Map<String, String> _keys = {
    open: 'order_status_open',
    inKitchen: 'order_status_in_kitchen',
    served: 'order_status_served',
    paid: 'order_status_paid',
    cancelled: 'order_status_cancelled',
  };

  static String label(String status) => (_keys[status] ?? status).tr;

  static bool isActive(String status) =>
      status == open || status == inKitchen || status == served;
}

/// สถานะรายการอาหารในออเดอร์ (ใช้กับจอครัว)
class OrderItemStatus {
  const OrderItemStatus._();

  static const String pending = 'pending';
  static const String cooking = 'cooking';
  static const String ready = 'ready';
  static const String served = 'served';
  static const String cancelled = 'cancelled';

  static const Map<String, String> _keys = {
    pending: 'order_item_status_pending',
    cooking: 'order_item_status_cooking',
    ready: 'order_item_status_ready',
    served: 'order_item_status_served',
    cancelled: 'order_item_status_cancelled',
  };

  static String label(String status) => (_keys[status] ?? status).tr;

  /// สถานะถัดไปที่กดได้จากหน้าจอครัว/พนักงานเสิร์ฟ
  static String? next(String status) {
    switch (status) {
      case pending:
        return cooking;
      case cooking:
        return ready;
      case ready:
        return served;
      default:
        return null;
    }
  }

  static String? nextActionLabel(String status) {
    switch (status) {
      case pending:
        return 'order_item_next_action_pending'.tr;
      case cooking:
        return 'order_item_next_action_cooking'.tr;
      case ready:
        return 'order_item_next_action_ready'.tr;
      default:
        return null;
    }
  }
}

/// ประเภทออเดอร์
class OrderType {
  const OrderType._();

  static const String dineIn = 'dine_in';
  static const String takeaway = 'takeaway';
  static const String delivery = 'delivery';

  static const Map<String, String> _keys = {
    dineIn: 'order_type_dine_in',
    takeaway: 'order_type_takeaway',
    delivery: 'order_type_delivery',
  };

  static String label(String type) => (_keys[type] ?? type).tr;
}

/// ช่องทางชำระเงิน
class PaymentMethod {
  const PaymentMethod._();

  static const String cash = 'cash';
  static const String qr = 'qr';
  static const String card = 'card';
  static const String transfer = 'transfer';

  /// ขายเชื่อลงบัญชีลูกค้าเครดิต (ดู docs/tickets/20-b2b-credit.md) — ไม่อยู่ใน [all]
  /// เพราะใช้ได้เฉพาะบิลที่ผูกลูกค้าเครดิต หน้าเก็บเงินจึงเพิ่มปุ่มนี้เองตามเงื่อนไข
  static const String credit = 'credit';

  /// ช่องทางที่ได้เงินทันที — ใช้ทั้งหน้าเก็บเงินและรับชำระหนี้ลูกค้าเครดิต
  static const List<String> all = [cash, qr, card, transfer];

  static const Map<String, String> _keys = {
    cash: 'payment_method_cash',
    qr: 'payment_method_qr',
    card: 'payment_method_card',
    transfer: 'payment_method_transfer',
    credit: 'payment_method_credit',
  };

  static String label(String method) => (_keys[method] ?? method).tr;
}

/// สถานะกะทำงานของแคชเชียร์
class ShiftStatus {
  const ShiftStatus._();

  static const String open = 'open';
  static const String closed = 'closed';
}

/// ชนิดส่วนลด
class DiscountType {
  const DiscountType._();

  static const String none = 'none';
  static const String amount = 'amount';
  static const String percent = 'percent';
}

/// ชนิดโปรโมชัน
class PromotionType {
  const PromotionType._();

  static const String percent = 'percent';
  static const String amount = 'amount';
  static const String bogo = 'bogo';

  static const List<String> all = [percent, amount, bogo];

  static const Map<String, String> _keys = {
    percent: 'promotion_type_percent',
    amount: 'promotion_type_amount',
    bogo: 'promotion_type_bogo',
  };

  static String label(String type) => (_keys[type] ?? type).tr;
}

/// ประเภทใบกำกับภาษี — ดู docs/tickets/07-tax-invoice.md
class TaxInvoiceType {
  const TaxInvoiceType._();

  static const String abbreviated = 'abbreviated';
  static const String full = 'full';
}

/// คีย์ที่ใช้เก็บข้อมูลใน local storage
class StorageKeys {
  const StorageKeys._();

  static const String token = 'auth_token';
  static const String user = 'auth_user';
  static const String printerProfile = 'printer_profile';
  static const String pendingOrderItems = 'pending_order_items';
  static const String locale = 'app_locale';
  static const String contrast = 'app_contrast';
  static const String kitchenStation = 'kitchen_station';
}

/// ชิปกรองสถานีบนจอครัว (ticket 34) — เก็บเป็น "รหัสสถานี" ต่อเครื่อง
///
/// สถานีเป็นแถวในฐานข้อมูลที่ร้านเพิ่มเองได้ จึงไม่มีรายการค่าตายตัวในแอป มีแต่สามรหัสที่
/// migration เตรียมไว้ให้ (ใช้ในโหมดสาธิตและเทสต์) กับค่า [all] ที่หมายถึง "ไม่กรอง"
class KitchenStationFilter {
  const KitchenStationFilter._();

  static const String all = 'all';
  static const String hot = 'hot';
  static const String cold = 'cold';
  static const String bar = 'bar';

  static const Map<String, String> _keys = {
    hot: 'station_hot',
    cold: 'station_cold',
    bar: 'station_bar',
  };

  /// ชื่อสถานีที่แอปรู้จักมาแต่ต้น — สถานีที่ร้านเพิ่มเองไม่มีคำแปล จึงคืนค่ารหัสไปตามเดิม
  /// (ใช้เฉพาะจุดที่ไม่มีข้อมูลสถานีจริงอยู่ในมือ ปกติให้ใช้ `KitchenStation.displayName`)
  static String label(String code) => (_keys[code] ?? code).tr;

  /// แปลงรหัสที่เลือกเป็นค่าที่เก็บลงเครื่อง — null (ทุกสถานี) เก็บเป็น [all]
  static String store(String? code) =>
      code == null || code.isEmpty ? all : code;

  /// อ่านค่าจากเครื่องกลับเป็นรหัสสถานี — [all] หรือค่าว่าง/เสียหายให้ถือว่า "ทุกสถานี"
  /// ไม่โยน error เพราะสถานีถูกลบหรือเปลี่ยนรหัสได้ จอครัวต้องเปิดใช้ต่อได้เสมอ
  static String? parse(String? raw) {
    if (raw == null) return null;
    final value = raw.trim();
    if (value.isEmpty || value == all) return null;
    return value;
  }
}
