// Copyright 2026 Suruch Chakrapeesirisuk
// SPDX-License-Identifier: Apache-2.0

import 'package:get/get.dart';

import '../../app/config/app_config.dart';

import '../../features/auth/domain/entities/user.dart';
import '../network/socket_client.dart';
import 'storage_service.dart';

/// เก็บสถานะ "ใครกำลังใช้งานอยู่" ให้ทั้งแอปเข้าถึงได้
///
/// เป็น GetxService เพราะต้องอยู่ตลอดอายุแอป (ไม่ถูกลบทิ้งตอนเปลี่ยนหน้า)
/// และเป็นตัวกลางเดียวที่รู้ทั้ง token, ผู้ใช้ปัจจุบัน และการต่อ socket
class SessionService extends GetxService {
  SessionService({
    required StorageService storage,
    required SocketClient socket,
  }) : _storage = storage,
       _socket = socket;

  final StorageService _storage;
  final SocketClient _socket;

  final Rxn<User> _currentUser = Rxn<User>();

  User? get currentUser => _currentUser.value;
  Rxn<User> get currentUserRx => _currentUser;
  String? get token => _storage.token;
  bool get isLoggedIn => token != null && _currentUser.value != null;
  SocketClient get socket => _socket;

  /// เรียกหลัง login สำเร็จ หรือตอนเปิดแอปแล้วพบเซสชันเดิม
  void start({required User user, required String token}) {
    _replaceUser(user);
    // โหมดสาธิตไม่มีเซิร์ฟเวอร์ให้ต่อ จึงข้ามการเชื่อม socket
    if (!AppConfig.demoMode) _socket.connect(token);
  }

  void updateUser(User user) => _replaceUser(user);

  /// `User.==` เทียบแค่ id และ Rx ข้ามการกำหนดค่าที่ "เท่ากัน" — สลับสาขาด้วยบัญชีเดิมจึงไม่มีใครรู้
  /// ถ้าผู้ใช้เท่ากับของเดิมต้องบังคับเอง เพื่อให้ `ever(currentUserRx)` เห็น branchId ใหม่
  void _replaceUser(User user) {
    // ตั้งค่าตรง ๆ จะถูก Rx ข้ามทั้งแจ้งเตือนและการเก็บค่าใหม่ (เปลี่ยน branchId ก็ยังได้ค่าเดิม)
    // จึงผ่าน null ก่อนเพื่อบังคับให้ค่าใหม่ถูกเก็บและ listener ถูกเรียก (listener ที่ไม่สน null ข้ามเอง)
    if (_currentUser.value == user) _currentUser.value = null;
    _currentUser.value = user;
  }

  Future<void> end() async {
    _socket.disconnect();
    _currentUser.value = null;
    await _storage.clear();
  }
}
