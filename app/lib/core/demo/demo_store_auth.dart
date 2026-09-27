// Copyright 2026 Suruch Chakrapeesirisuk
// SPDX-License-Identifier: Apache-2.0

part of 'demo_store.dart';

// ---------------------------------------------------------------- auth ---
extension DemoStoreAuth on DemoStore {
  Map<String, dynamic> login(String username, String password) {
    final user = users.firstWhere(
      (row) => row['username'] == username && row['password'] == password,
      orElse: () => throw ApiException(
        message: 'auth_invalid_credentials'.tr,
        statusCode: 401,
      ),
    );
    return {'token': 'demo-token-${user['id']}', 'user': _publicUser(user)};
  }

  // ชื่อพนักงานตัวอย่างมี nameEn/nameKo ใน seed อยู่แล้วแต่เดิมส่งแต่ชื่อไทย หน้าจัดการพนักงาน
  // ภาษาเกาหลีจึงเป็นชื่อไทยทั้งหน้า (#64) — บัญชีที่ร้านสร้างเองไม่มีคำแปล ได้ชื่อตามที่พิมพ์
  Map<String, dynamic> _publicUser(Map<String, dynamic> user) => {
    'id': user['id'],
    'name': DemoNames.of(user),
    'username': user['username'],
    'role': user['role'],
    'isActive': user['isActive'],
  };

  Map<String, dynamic> profile(String? token) {
    final id = int.tryParse(token?.split('-').last ?? '');
    final user = users.firstWhere(
      (row) => row['id'] == id,
      orElse: () => throw ApiException(
        message: 'auth_demo_session_expired'.tr,
        statusCode: 401,
      ),
    );
    return _publicUser(user);
  }

  List<Map<String, dynamic>> staff() =>
      users.map(_publicUser).toList(growable: false);

  Map<String, dynamic> createStaff({
    required String name,
    required String username,
    required String password,
    required String role,
  }) {
    if (users.any((row) => row['username'] == username)) {
      throw ApiException(message: 'auth_username_taken'.tr, statusCode: 409);
    }
    final user = {
      'id': _nextId(),
      'name': name,
      'username': username,
      'password': password,
      'role': role,
      'isActive': true,
    };
    users.add(user);
    return _publicUser(user);
  }

  Map<String, dynamic> updateStaff(
    int id,
    Map<String, dynamic> changes, {
    int? actorId,
  }) {
    final user = _findUser(id);
    final previousRole = user['role'];
    final previousActive = user['isActive'];

    // mirror ของ user.service.js#update — ห้ามลดสิทธิ์/ปิดบัญชีตัวเอง (DECISIONS #62)
    if (actorId != null && actorId == id) {
      if (changes.containsKey('role') && changes['role'] != previousRole) {
        throw ApiException(
          message: 'staff_cannot_change_own_role'.tr,
          statusCode: 400,
        );
      }
      if (changes['isActive'] == false) {
        throw ApiException(
          message: 'staff_cannot_deactivate_self'.tr,
          statusCode: 400,
        );
      }
    }

    changes.forEach((key, value) => user[key] = value);
    // แก้ชื่อเอง = ชื่อที่พิมพ์คือชื่อจริงทุกภาษา ทิ้งคำแปลของ seed ไม่งั้นหน้าจอภาษาอื่นยังโชว์ชื่อเก่า
    if (changes.containsKey('name')) {
      user
        ..remove('nameEn')
        ..remove('nameKo');
    }

    // แก้ role/ปิดการใช้งาน/ตั้งรหัสผ่านใหม่เป็นการกระทำที่เสี่ยง ต้อง log แยกกัน
    // (แก้ชื่อเฉยๆ ไม่ถือว่าเสี่ยง ไม่ต้อง log) — mirror ของ user.service.js#update
    // ดู docs/tickets/08-audit-log.md
    if (changes.containsKey('role') && changes['role'] != previousRole) {
      _logAudit(
        actorId: actorId,
        action: 'user.role_change',
        summaryArgs: {
          'name': user['name'],
          'from': previousRole,
          'to': changes['role'],
        },
        entityType: 'user',
        entityId: id,
        summary:
            'เปลี่ยนสิทธิ์บัญชี "${user['name']}" จาก $previousRole เป็น ${changes['role']}',
        metadata: {
          'username': user['username'],
          'previousRole': previousRole,
          'newRole': changes['role'],
        },
      );
    }
    if (changes['isActive'] == false && previousActive == true) {
      _logAudit(
        actorId: actorId,
        action: 'user.deactivate',
        summaryArgs: {'name': user['name'], 'username': user['username']},
        entityType: 'user',
        entityId: id,
        summary: 'ปิดการใช้งานบัญชี "${user['name']}" (${user['username']})',
        metadata: {'username': user['username']},
      );
    }
    if (changes.containsKey('password')) {
      _logAudit(
        actorId: actorId,
        action: 'user.password_reset',
        summaryArgs: {'name': user['name'], 'username': user['username']},
        entityType: 'user',
        entityId: id,
        summary:
            'ตั้งรหัสผ่านใหม่ให้บัญชี "${user['name']}" (${user['username']})',
        metadata: {'username': user['username']},
      );
    }

    return _publicUser(user);
  }

  void deleteStaff(int id, {int? actorId}) {
    final user = _findUser(id);
    users.removeWhere((row) => row['id'] == id);
    _logAudit(
      actorId: actorId,
      action: 'user.delete',
      summaryArgs: {'name': user['name'], 'username': user['username']},
      entityType: 'user',
      entityId: id,
      summary: 'ลบบัญชี "${user['name']}" (${user['username']}) ออกจากระบบ',
      metadata: {'username': user['username'], 'role': user['role']},
    );
  }

  Map<String, dynamic> _findUser(int id) => users.firstWhere(
    (row) => row['id'] == id,
    orElse: () =>
        throw ApiException(message: 'auth_user_not_found'.tr, statusCode: 404),
  );
}
