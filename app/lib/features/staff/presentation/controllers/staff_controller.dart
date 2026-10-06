// Copyright 2026 Suruch Chakrapeesirisuk
// SPDX-License-Identifier: Apache-2.0

import 'package:get/get.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/services/session_service.dart';
import '../../../../core/widgets/app_dialogs.dart';
import '../../../auth/domain/entities/user.dart';
import '../../../menu/domain/entities/kitchen_station.dart';
import '../../../menu/domain/usecases/menu_usecases.dart';
import '../../domain/usecases/staff_usecases.dart';

/// จัดการบัญชีพนักงาน (admin/manager เท่านั้น)
class StaffController extends GetxController {
  StaffController({
    required GetStaffUseCase getStaff,
    required GetKitchenStationsUseCase getStations,
    required CreateStaffUseCase createStaff,
    required UpdateStaffUseCase updateStaff,
    required DeleteStaffUseCase deleteStaff,
    required SessionService session,
  }) : _getStaff = getStaff,
       _getStations = getStations,
       _createStaff = createStaff,
       _updateStaff = updateStaff,
       _deleteStaff = deleteStaff,
       _session = session;

  final GetStaffUseCase _getStaff;
  final GetKitchenStationsUseCase _getStations;
  final CreateStaffUseCase _createStaff;
  final UpdateStaffUseCase _updateStaff;
  final DeleteStaffUseCase _deleteStaff;
  final SessionService _session;

  final RxList<User> staff = <User>[].obs;
  final RxBool isLoading = true.obs;
  final RxBool isSaving = false.obs;
  final RxnString errorMessage = RxnString();
  final RxnString roleFilter = RxnString();

  @override
  void onInit() {
    super.onInit();
    load();
    loadStations();
  }

  int? get currentUserId => _session.currentUser?.id;

  String? get _currentRole => _session.currentUser?.role;

  /// บทบาทที่ตั้งให้พนักงานได้ — ผู้จัดการตั้งได้เฉพาะเสิร์ฟ/แคชเชียร์/ครัว (T22 #86)
  List<String> get assignableRoles => UserRole.assignableBy(_currentRole);

  /// มีเมนูจัดการบัญชีนี้ไหม — backend กรองรายการตามสาขาและตรวจซ้ำทุกคำขอ
  bool canManage(User user) => UserRole.canManage(_currentRole, user.role);

  /// ลบบัญชีได้เฉพาะแอดมิน (DELETE /users/:id เป็นของ admin)
  bool get canDelete => _currentRole == UserRole.admin;

  List<User> get filteredStaff => roleFilter.value == null
      ? staff
      : staff
            .where((user) => user.role == roleFilter.value)
            .toList(growable: false);

  Map<String, int> get countByRole {
    final counts = <String, int>{};
    for (final user in staff) {
      counts[user.role] = (counts[user.role] ?? 0) + 1;
    }
    return counts;
  }

  Future<void> load() async {
    isLoading.value = true;
    errorMessage.value = null;

    final result = await _getStaff(null);

    isLoading.value = false;
    result.fold(
      onSuccess: staff.assignAll,
      onFailure: (failure) => errorMessage.value = failure.message,
    );
  }

  /// สถานีครัวที่เปิดใช้งาน ใช้ทำช่องติ๊กในฟอร์มพนักงาน (ticket 35)
  /// โหลดไม่ขึ้นก็ซ่อนช่องไป หน้าจัดการพนักงานยังทำงานได้ทุกอย่างเหมือนเดิม
  final RxList<KitchenStation> stations = <KitchenStation>[].obs;

  Future<void> loadStations() async {
    final result = await _getStations(true);
    result.fold(
      onSuccess: stations.assignAll,
      onFailure: (_) => stations.clear(),
    );
  }

  /// ตั้งสถานีที่พนักงานคนนี้รับผิดชอบ — ส่งชุดเต็มเสมอ ([] = ถอดออกทั้งหมด)
  Future<void> setStations(User user, List<int> stationIds) async {
    final result = await _updateStaff(
      UpdateStaffParams(id: user.id, stationIds: stationIds),
    );
    result.fold(
      onSuccess: (_) {
        AppDialogs.success('staff_stations_saved'.tr);
        load();
      },
      onFailure: (failure) => AppDialogs.error(failure.message),
    );
  }

  void filterByRole(String? role) => roleFilter.value = role;

  Future<bool> create({
    required String name,
    required String username,
    required String password,
    required String role,
    List<int>? stationIds,
  }) async {
    isSaving.value = true;
    final result = await _createStaff(
      CreateStaffParams(
        name: name,
        username: username,
        password: password,
        role: role,
        stationIds: stationIds,
      ),
    );
    isSaving.value = false;

    return result.fold(
      onSuccess: (_) {
        AppDialogs.success('staff_added_success'.tr);
        load();
        return true;
      },
      onFailure: (failure) {
        AppDialogs.error(failure.message);
        return false;
      },
    );
  }

  Future<void> updateRole(User user, String role) async {
    // ลดสิทธิ์ตัวเองพลาดครั้งเดียว = หลุดจากหน้านี้ทันที (backend ก็กันไว้อีกชั้น ดู DECISIONS #62)
    if (user.id == currentUserId) {
      AppDialogs.error('staff_cannot_change_own_role'.tr);
      return;
    }
    final confirmed = await AppDialogs.confirm(
      title: 'staff_change_role_title'.tr,
      message: 'staff_change_role_confirm'.trParams({
        'name': user.name,
        'from': UserRole.label(user.role),
        'to': UserRole.label(role),
      }),
      confirmLabel: 'staff_change_role_button'.tr,
    );
    if (!confirmed) return;

    final result = await _updateStaff(
      UpdateStaffParams(id: user.id, role: role),
    );
    result.fold(
      onSuccess: (_) {
        AppDialogs.success(
          'staff_role_changed_success'.trParams({'name': user.name}),
        );
        load();
      },
      onFailure: (failure) => AppDialogs.error(failure.message),
    );
  }

  Future<void> toggleActive(User user) async {
    if (user.isActive) {
      if (user.id == currentUserId) {
        AppDialogs.error('staff_cannot_deactivate_self'.tr);
        return;
      }
      final confirmed = await AppDialogs.confirm(
        title: 'staff_deactivate_title'.tr,
        message: 'staff_deactivate_confirm'.trParams({'name': user.name}),
        confirmLabel: 'staff_deactivate_action'.tr,
        destructive: true,
      );
      if (!confirmed) return;
    }

    final result = await _updateStaff(
      UpdateStaffParams(id: user.id, isActive: !user.isActive),
    );
    result.fold(
      onSuccess: (_) {
        AppDialogs.success(
          user.isActive
              ? 'staff_deactivated_success'.tr
              : 'staff_activated_success'.tr,
        );
        load();
      },
      onFailure: (failure) => AppDialogs.error(failure.message),
    );
  }

  Future<void> delete(User user) async {
    if (user.id == currentUserId) {
      AppDialogs.error('staff_cannot_delete_self'.tr);
      return;
    }

    final confirmed = await AppDialogs.confirm(
      title: 'staff_delete_title'.tr,
      message: 'staff_delete_confirm'.trParams({'name': user.name}),
      confirmLabel: 'staff_delete_account'.tr,
      destructive: true,
    );
    if (!confirmed) return;

    final result = await _deleteStaff(user.id);
    result.fold(
      onSuccess: (_) {
        AppDialogs.success('staff_deleted_success'.tr);
        load();
      },
      onFailure: (failure) => AppDialogs.error(failure.message),
    );
  }

  String roleLabel(String role) => UserRole.label(role);
}
