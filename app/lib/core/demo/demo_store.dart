// Copyright 2026 Suruch Chakrapeesirisuk
// SPDX-License-Identifier: Apache-2.0

import 'dart:math';

import 'package:get/get.dart';

import '../../features/order/domain/services/bill_calculator.dart';
import '../../features/order/domain/services/promotion_engine.dart';
import '../constants/app_constants.dart';
import '../errors/exceptions.dart';
import 'demo_names.dart';
import 'demo_seed.dart';
import '../utils/app_clock.dart';
import '../utils/csv.dart';

part 'demo_store_auth.dart';
part 'demo_store_menu.dart';
part 'demo_store_ingredients.dart';
part 'demo_store_tables.dart';
part 'demo_store_orders.dart';
part 'demo_store_order_items.dart';
part 'demo_store_order_promotions.dart';
part 'demo_store_payments.dart';
part 'demo_store_promotions.dart';
part 'demo_store_refunds.dart';
part 'demo_store_shifts.dart';
part 'demo_store_reports.dart';
part 'demo_store_seed_history.dart';
part 'demo_store_tax_invoices.dart';
part 'demo_store_settings.dart';
part 'demo_store_audit_logs.dart';
part 'demo_store_customers.dart';
part 'demo_store_receivables.dart';
part 'demo_store_ar_documents.dart';
part 'demo_store_ar_adjustments.dart';

/// "เซิร์ฟเวอร์จำลอง" ที่อยู่ในหน่วยความจำของแอป
///
/// ใช้เฉพาะ Demo Mode เพื่อให้เปิดลิงก์เดียวแล้วลองใช้งานได้ครบทุกฟีเจอร์
/// โดยไม่ต้องรัน backend — เก็บข้อมูลเป็น Map รูปร่างเดียวกับ JSON ของ API จริง
/// จึงใช้ Model.fromJson ตัวเดียวกันได้ทั้งหมด
///
/// ข้อมูลอยู่แค่ในหน่วยความจำ รีเฟรชหน้าเว็บแล้วเริ่มใหม่
///
/// เมธอดแบ่งเป็นไฟล์ย่อยตามโดเมนด้วย `part`/`part of` (ยังเป็นคลาสเดียวกัน
/// เข้าถึง field/เมธอด private ข้ามไฟล์ได้ปกติ เพราะ part ทั้งหมดอยู่ใน
/// library เดียวกัน) — ไฟล์นี้เก็บเฉพาะ state และ helper ที่ใช้ร่วมกันทุกโดเมน:
/// [DemoStoreAuth] บัญชี/พนักงาน · [DemoStoreMenu] เมนู/หมวดหมู่ ·
/// [DemoStoreTables] ผังโต๊ะ · [DemoStoreOrders] ออเดอร์ ·
/// [DemoStorePayments] การชำระเงิน · [DemoStoreRefunds] คืนเงินหลังชำระเงินแล้ว ·
/// [DemoStoreShifts] กะทำงาน/กระทบยอดเงินสด · [DemoStoreReports] รายงาน/แดชบอร์ด ·
/// [DemoStoreSeedHistory] สร้างยอดขายย้อนหลังไว้ให้รายงานมีข้อมูลตั้งแต่เปิดแอป
class DemoStore {
  DemoStore() {
    reset();
  }

  static final DemoStore instance = DemoStore();

  late List<Map<String, dynamic>> users;
  late List<Map<String, dynamic>> categories;
  late List<Map<String, dynamic>> menuItems;
  late List<Map<String, dynamic>> ingredients;
  late List<Map<String, dynamic>> tables;
  late Map<String, dynamic> settings;

  final List<Map<String, dynamic>> orders = [];
  final List<Map<String, dynamic>> payments = [];
  final List<Map<String, dynamic>> refunds = [];
  final List<Map<String, dynamic>> shifts = [];
  final List<Map<String, dynamic>> promotions = [];
  final List<Map<String, dynamic>> taxInvoices = [];
  final List<Map<String, dynamic>> auditLogs = [];
  final List<Map<String, dynamic>> customers = [];

  /// ลูกหนี้/ขายเชื่อ (ดู docs/tickets/20-b2b-credit.md) — [DemoStoreReceivables]
  final List<Map<String, dynamic>> arReceipts = [];
  final List<Map<String, dynamic>> billingNotes = [];

  /// ดอกเบี้ยผิดนัด / ใบลดหนี้ / ประวัติอีเมลเอกสาร (tickets 21, 23) — [DemoStoreArAdjustments]
  final List<Map<String, dynamic>> arCharges = [];
  final List<Map<String, dynamic>> creditNotes = [];
  final List<Map<String, dynamic>> documentEmails = [];

  /// ผู้ใช้แคชเชียร์ที่ seed ไว้ให้ — ใช้เปิดกะแรกอัตโนมัติเหมือนวันแรกที่ร้านเปิดใช้ระบบ
  static const int _defaultCashierId = 6;

  int _orderSequence = 0;
  int _idSequence = 1000;

  /// หน่วงเวลาเล็กน้อยให้เหมือนเรียก API จริง (จอ loading จึงทำงานสมจริง)
  static const Duration latency = Duration(milliseconds: 180);

  /// เวลาเปิดร้านของข้อมูลตัวอย่าง ใช้กระจายยอดขายให้ดูสมจริง
  static const int openingHour = 11;

  void reset() {
    users = DemoSeed.users();
    categories = DemoSeed.categories();
    menuItems = DemoSeed.menuItems();
    ingredients = DemoSeed.ingredients();
    tables = DemoSeed.tables();
    settings = DemoSeed.settings();
    orders.clear();
    payments.clear();
    refunds.clear();
    shifts.clear();
    promotions.clear();
    taxInvoices.clear();
    auditLogs.clear();
    customers
      ..clear()
      ..addAll([
        // ร้านกรอกชื่อลูกค้าเป็นภาษาที่ตัวเองใช้ (DECISIONS #74) — เลือกครั้งเดียวตอนเริ่ม
        // ข้อมูลที่กรอกไปแล้วไม่เปลี่ยนภาษาตามปุ่มสลับภาษา เหมือนร้านจริง
        for (final row in DemoSeed.customers())
          {
            ...row,
            'name': DemoNames.of(row),
            'address': DemoNames.of(row, key: 'address'),
          }..removeWhere(
            (key, _) => const {
              'nameEn',
              'nameKo',
              'addressEn',
              'addressKo',
            }.contains(key),
          ),
      ]);
    arReceipts.clear();
    billingNotes.clear();
    arCharges.clear();
    creditNotes.clear();
    documentEmails.clear();
    _orderSequence = 0;
    _idSequence = 1000;
    _seedHistoricalSales();
    _seedOverdueCreditSale();
    openShift(openingCash: 2000, openedById: _defaultCashierId);
  }

  int _nextId() => ++_idSequence;

  String _now() => AppClock.now().toUtc().toIso8601String();

  BillCalculator get _calculator => BillCalculator(
    vatRate: settings['vatRate'] as double,
    serviceChargeRate: settings['serviceChargeRate'] as double,
    vatIncluded: settings['vatIncluded'] as bool,
  );
}
