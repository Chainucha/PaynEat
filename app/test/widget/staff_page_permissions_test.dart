// Copyright 2026 Suruch Chakrapeesirisuk
// SPDX-License-Identifier: Apache-2.0

import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:payneat_pos/core/constants/app_constants.dart';
import 'package:payneat_pos/core/localization/app_translations.dart';
import 'package:payneat_pos/core/localization/locale_service.dart';
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
import 'package:payneat_pos/features/staff/presentation/pages/staff_page.dart';

/// หน้าจัดการพนักงานของผู้จัดการไม่มีปุ่มที่ backend จะปฏิเสธ (T22 #86, docs/DECISIONS.md #92)
class _FakeStaffRepository implements StaffRepository {
  _FakeStaffRepository(this.users);

  final List<User> users;

  @override
  Future<Result<List<User>>> getStaff({String? role}) async =>
      Result.success(users);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

User _user(int id, String role) => User(
  id: id,
  name: 'บัญชี $id',
  username: 'u$id',
  role: role,
  isActive: true,
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
  tearDown(Get.reset);

  Future<void> pump(WidgetTester tester, {required String viewerRole}) async {
    final session = SessionService(
      storage: StorageService.memory(),
      socket: SocketClient(),
    )..updateUser(_user(1, viewerRole)); // ไม่ start() — ไม่ต่อ socket ในเทสต์
    final repository = _FakeStaffRepository([
      _user(1, viewerRole),
      _user(2, UserRole.manager),
      _user(3, UserRole.waiter),
    ]);
    Get.put(
      StaffController(
        getStaff: GetStaffUseCase(repository),
        getStations: GetKitchenStationsUseCase(_FakeMenuRepository()),
        createStaff: CreateStaffUseCase(repository),
        updateStaff: UpdateStaffUseCase(repository),
        deleteStaff: DeleteStaffUseCase(repository),
        session: session,
      ),
    );
    await tester.pumpWidget(
      GetMaterialApp(
        translations: AppTranslations(),
        locale: LocaleService.thai,
        home: const StaffPage(),
      ),
    );
    await tester.pumpAndSettle();
  }

  Finder actions() => find.byTooltip('staff_actions_tooltip'.tr);
  Finder chip(String role) => find.textContaining('${UserRole.label(role)} (');

  testWidgets(
    'ผู้จัดการ: เมนูจัดการมีเฉพาะแถวพนักงาน ไม่มีปุ่มลบ และเปลี่ยนได้เฉพาะเสิร์ฟ/แคชเชียร์/ครัว',
    (tester) async {
      await pump(tester, viewerRole: UserRole.manager);

      // แถวของตัวเองมีป้าย "คุณ" แถวผู้จัดการอีกคนไม่มีเมนู เหลือเฉพาะแถวพนักงานเสิร์ฟ
      expect(actions(), findsOneWidget);
      expect(chip(UserRole.admin), findsNothing);

      await tester.tap(actions());
      await tester.pumpAndSettle();
      expect(find.text('staff_delete_account'.tr), findsNothing);
      for (final role in [UserRole.manager, UserRole.admin]) {
        expect(
          find.text(
            'staff_change_role_to'.trParams({'role': UserRole.label(role)}),
          ),
          findsNothing,
        );
      }
      expect(
        find.text(
          'staff_change_role_to'.trParams({
            'role': UserRole.label(UserRole.cashier),
          }),
        ),
        findsOneWidget,
      );
    },
  );

  testWidgets('แอดมิน: เมนูจัดการทุกแถวที่ไม่ใช่ตัวเอง พร้อมปุ่มลบ', (
    tester,
  ) async {
    await pump(tester, viewerRole: UserRole.admin);

    expect(actions(), findsNWidgets(2));
    expect(chip(UserRole.admin), findsOneWidget);
    await tester.tap(actions().first);
    await tester.pumpAndSettle();
    expect(find.text('staff_delete_account'.tr), findsOneWidget);
  });
}
