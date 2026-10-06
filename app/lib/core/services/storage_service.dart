// Copyright 2026 Suruch Chakrapeesirisuk
// SPDX-License-Identifier: Apache-2.0

import 'dart:async';
import 'dart:convert';

import 'package:get_storage/get_storage.dart';

import '../constants/app_constants.dart';

/// เก็บข้อมูลถาวรในเครื่อง (token / โปรไฟล์ผู้ใช้)
///
/// รองรับกรณีที่เบราว์เซอร์ปิด local storage (เช่นโหมดไม่ระบุตัวตนบางตัว)
/// ด้วยการถอยไปใช้หน่วยความจำแทน เพื่อไม่ให้แอปค้างอยู่ที่จอขาวตอนเปิด
class StorageService {
  StorageService._(this._box);

  final GetStorage? _box;
  final Map<String, String> _memory = {};

  bool get isPersistent => _box != null;

  /// สร้างตัวเก็บข้อมูลแบบอยู่ในหน่วยความจำล้วน
  ///
  /// ใช้ในเทสต์และเครื่องมือถ่ายภาพหน้าจอ ที่ไม่มี local storage จริงให้เขียน
  factory StorageService.memory() => StorageService._(null);

  /// เตรียม storage ให้พร้อมใช้งาน
  ///
  /// [timeout] กันกรณี GetStorage.init() ค้าง — ถ้าเกินเวลาจะใช้โหมดหน่วยความจำแทน
  static Future<StorageService> init({
    Duration timeout = const Duration(seconds: 3),
  }) async {
    try {
      await GetStorage.init().timeout(timeout);
      return StorageService._(GetStorage());
    } catch (_) {
      return StorageService._(null);
    }
  }

  String? _read(String key) =>
      _box == null ? _memory[key] : _box.read<String>(key);

  Future<void> _write(String key, String value) async {
    if (_box == null) {
      _memory[key] = value;
      return;
    }
    await _box.write(key, value);
  }

  Future<void> _remove(String key) async {
    if (_box == null) {
      _memory.remove(key);
      return;
    }
    await _box.remove(key);
  }

  String? get token => _read(StorageKeys.token);

  Map<String, dynamic>? get user {
    final raw = _read(StorageKeys.user);
    if (raw == null) return null;
    try {
      return jsonDecode(raw) as Map<String, dynamic>;
    } catch (_) {
      return null;
    }
  }

  Future<void> saveSession({
    required String token,
    required Map<String, dynamic> user,
  }) async {
    await _write(StorageKeys.token, token);
    await _write(StorageKeys.user, jsonEncode(user));
  }

  Future<void> clear() async {
    await _remove(StorageKeys.token);
    await _remove(StorageKeys.user);
  }

  /// ตั้งค่าเครื่องพิมพ์ใบเสร็จ — ผูกกับเครื่องนี้เท่านั้น จึงไม่ถูกล้างตอน [clear] (logout)
  String? get printerProfileJson => _read(StorageKeys.printerProfile);

  Future<void> savePrinterProfile(String json) =>
      _write(StorageKeys.printerProfile, json);

  /// คิวรายการอาหารที่สั่งเพิ่มไว้ตอนออฟไลน์ รอส่งขึ้นเซิร์ฟเวอร์ — เก็บในเครื่องเท่านั้น
  /// ไม่ผูกกับผู้ใช้ที่ login จึงไม่ถูกล้างตอน [clear] เช่นกัน (พนักงานคนอื่นอาจต้อง sync ต่อ)
  String? get pendingOrderItemsJson => _read(StorageKeys.pendingOrderItems);

  Future<void> savePendingOrderItems(String json) =>
      _write(StorageKeys.pendingOrderItems, json);

  /// ภาษาที่ผู้ใช้เลือกไว้ — ผูกกับเครื่องนี้เท่านั้น จึงไม่ถูกล้างตอน [clear] (logout)
  String? get locale => _read(StorageKeys.locale);

  Future<void> saveLocale(String languageCode) =>
      _write(StorageKeys.locale, languageCode);

  String? get contrast => _read(StorageKeys.contrast);

  Future<void> saveContrast(String value) =>
      _write(StorageKeys.contrast, value);

  /// สถานีครัวที่จอนี้เลือกไว้ (ticket 34) — ผูกกับเครื่อง ไม่ใช่กับบัญชี จึงไม่ถูกล้างตอน [clear]
  /// (logout) เหมือน [printerProfileJson]: แท็บเล็ตของบาร์ติดอยู่ที่บาร์ ไม่ว่าใครจะล็อกอินอยู่
  String? get kitchenStation => _read(StorageKeys.kitchenStation);

  Future<void> saveKitchenStation(String value) =>
      _write(StorageKeys.kitchenStation, value);
}
