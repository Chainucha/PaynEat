// Copyright 2026 Suruch Chakrapeesirisuk
// SPDX-License-Identifier: Apache-2.0

import 'package:flutter_test/flutter_test.dart';
import 'package:payneat_pos/core/constants/app_constants.dart';
import 'package:payneat_pos/core/errors/failures.dart';
import 'package:payneat_pos/core/network/socket_client.dart';
import 'package:payneat_pos/core/services/session_service.dart';
import 'package:payneat_pos/core/services/storage_service.dart';
import 'package:payneat_pos/core/usecases/result.dart';
import 'package:payneat_pos/features/menu/domain/entities/kitchen_station.dart';
import 'package:payneat_pos/features/menu/domain/repositories/menu_repository.dart';
import 'package:payneat_pos/features/menu/domain/usecases/menu_usecases.dart';
import 'package:payneat_pos/features/auth/domain/entities/user.dart';
import 'package:payneat_pos/features/staff/domain/repositories/staff_repository.dart';
import 'package:payneat_pos/features/staff/domain/usecases/staff_usecases.dart';
import 'package:payneat_pos/features/staff/presentation/controllers/staff_controller.dart';

class _FakeStaffRepository implements StaffRepository {
  Result<List<User>> nextGetStaffResult = const Result.success([]);

  @override
  Future<Result<List<User>>> getStaff({String? role}) async =>
      nextGetStaffResult;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

User _user(int id, {String role = UserRole.waiter, bool isActive = true}) =>
    User(
      id: id,
      name: 'พนักงาน $id',
      username: 'u$id',
      role: role,
      isActive: isActive,
    );

/// repository ของเมนู ใช้เฉพาะดึงรายการสถานีมาทำช่องติ๊กในฟอร์มพนักงาน (ticket 35)
class _FakeMenuRepository implements MenuRepository {
  Result<List<KitchenStation>> nextStationsResult = const Result.success([]);

  @override
  Future<Result<List<KitchenStation>>> getKitchenStations({
    bool activeOnly = false,
  }) async => nextStationsResult;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  late _FakeStaffRepository repository;
  late SessionService session;
  late StaffController controller;

  setUp(() {
    repository = _FakeStaffRepository();
    session = SessionService(
      storage: StorageService.memory(),
      socket: SocketClient(),
    );
    controller = StaffController(
      getStaff: GetStaffUseCase(repository),
      getStations: GetKitchenStationsUseCase(_FakeMenuRepository()),
      createStaff: CreateStaffUseCase(repository),
      updateStaff: UpdateStaffUseCase(repository),
      deleteStaff: DeleteStaffUseCase(repository),
      session: session,
    );
  });

  tearDown(() => controller.onClose());

  group('StaffController', () {
    // create/updateRole/toggleActive/delete ทุกเส้นทางเรียก AppDialogs.error/success/confirm
    // จึงไม่ครอบคลุมในเทสต์ระดับ unit นี้ (ดู docs/CODING_STANDARDS.md) — ทดสอบเฉพาะส่วนอ่านข้อมูล

    test('load สำเร็จ → เติมรายชื่อพนักงาน ปิด loading', () async {
      repository.nextGetStaffResult = Result.success([_user(1), _user(2)]);

      await controller.load();

      expect(controller.staff.length, 2);
      expect(controller.isLoading.value, isFalse);
      expect(controller.errorMessage.value, isNull);
    });

    test('load ล้มเหลว → ตั้ง errorMessage', () async {
      repository.nextGetStaffResult = Result.failure(
        NetworkFailure('ต่อเซิร์ฟเวอร์ไม่ได้'),
      );

      await controller.load();

      expect(controller.errorMessage.value, 'ต่อเซิร์ฟเวอร์ไม่ได้');
    });

    test('filteredStaff กรองตามบทบาทที่เลือก', () async {
      repository.nextGetStaffResult = Result.success([
        _user(1, role: UserRole.waiter),
        _user(2, role: UserRole.kitchen),
        _user(3, role: UserRole.waiter),
      ]);
      await controller.load();

      controller.filterByRole(UserRole.waiter);
      expect(controller.filteredStaff.map((u) => u.id), [1, 3]);

      controller.filterByRole(null);
      expect(controller.filteredStaff.length, 3);
    });

    test('countByRole นับจำนวนพนักงานแยกตามบทบาท', () async {
      repository.nextGetStaffResult = Result.success([
        _user(1, role: UserRole.waiter),
        _user(2, role: UserRole.waiter),
        _user(3, role: UserRole.kitchen),
      ]);
      await controller.load();

      expect(controller.countByRole[UserRole.waiter], 2);
      expect(controller.countByRole[UserRole.kitchen], 1);
    });

    test('currentUserId อ่านจากผู้ใช้ที่ล็อกอินอยู่ในเซสชัน', () {
      expect(controller.currentUserId, isNull);

      session.start(user: _user(7), token: 't');
      expect(controller.currentUserId, 7);
    });

    test(
      'ผู้จัดการ: ตั้ง/เปลี่ยนได้เฉพาะเสิร์ฟ แคชเชียร์ ครัว ไม่มีเมนูของผู้จัดการ/แอดมิน และลบไม่ได้ (T22 #86)',
      () {
        session.start(
          user: _user(2, role: UserRole.manager),
          token: 't',
        );

        expect(controller.assignableRoles, UserRole.staffRoles);
        expect(controller.canDelete, isFalse);
        for (final role in UserRole.staffRoles) {
          expect(controller.canManage(_user(9, role: role)), isTrue);
        }
        expect(controller.canManage(_user(9, role: UserRole.manager)), isFalse);
        expect(controller.canManage(_user(9, role: UserRole.admin)), isFalse);
      },
    );

    test('แอดมิน: ทุกบทบาท จัดการทุกบัญชี และลบได้เหมือนเดิม', () {
      session.start(
        user: _user(1, role: UserRole.admin),
        token: 't',
      );

      expect(controller.assignableRoles, UserRole.all);
      expect(controller.canDelete, isTrue);
      for (final role in UserRole.all) {
        expect(controller.canManage(_user(9, role: role)), isTrue);
      }
    });

    test('roleLabel แปลบทบาทเป็นป้ายภาษาไทย', () {
      expect(
        controller.roleLabel(UserRole.manager),
        UserRole.label(UserRole.manager),
      );
    });
  });
}
