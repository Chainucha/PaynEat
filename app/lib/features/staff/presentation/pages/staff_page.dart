// Copyright 2026 Suruch Chakrapeesirisuk
// SPDX-License-Identifier: Apache-2.0

import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/widgets/state_views.dart';
import '../../../../core/widgets/status_chip.dart';
import '../../../auth/domain/entities/user.dart';
import '../controllers/staff_controller.dart';

/// จัดการพนักงาน — เพิ่มบัญชี เปลี่ยนบทบาท ปิด/เปิดการใช้งาน
class StaffPage extends GetView<StaffController> {
  const StaffPage({super.key});

  static Color roleColor(String role) => switch (role) {
    UserRole.admin => AppColors.purple,
    UserRole.manager => AppColors.info,
    UserRole.waiter => AppColors.primary,
    UserRole.cashier => AppColors.success,
    UserRole.kitchen => AppColors.warning,
    _ => AppColors.textSecondary,
  };

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'fab-staff',
        onPressed: () => _showCreateDialog(context),
        icon: const Icon(Icons.person_add_rounded),
        label: Text('staff_add_staff'.tr),
      ),
      body: Column(
        children: [
          Container(
            color: AppColors.surface,
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
            child: Obx(
              () => Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _RoleChip(
                    label: '${'common_all'.tr} (${controller.staff.length})',
                    selected: controller.roleFilter.value == null,
                    color: AppColors.textSecondary,
                    onTap: () => controller.filterByRole(null),
                  ),
                  ...controller.assignableRoles.map(
                    (role) => _RoleChip(
                      label:
                          '${UserRole.label(role)} (${controller.countByRole[role] ?? 0})',
                      selected: controller.roleFilter.value == role,
                      color: roleColor(role),
                      onTap: () => controller.filterByRole(role),
                    ),
                  ),
                ],
              ),
            ),
          ),
          Expanded(
            child: Obx(() {
              if (controller.isLoading.value) return const LoadingView();

              final error = controller.errorMessage.value;
              if (error != null && controller.staff.isEmpty) {
                return ErrorView(message: error, onRetry: controller.load);
              }

              final staff = controller.filteredStaff;
              if (staff.isEmpty) {
                return EmptyView(
                  message: 'staff_empty_state'.tr,
                  icon: Icons.people_outline_rounded,
                );
              }

              return ListView.separated(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 90),
                itemCount: staff.length,
                separatorBuilder: (_, _) => const SizedBox(height: 8),
                itemBuilder: (context, index) => _StaffRow(user: staff[index]),
              );
            }),
          ),
        ],
      ),
    );
  }

  Future<void> _showCreateDialog(BuildContext context) async {
    final nameController = TextEditingController();
    final usernameController = TextEditingController();
    final passwordController = TextEditingController();
    final formKey = GlobalKey<FormState>();
    String role = UserRole.waiter;

    await Get.dialog<void>(
      StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: Text('staff_add_staff'.tr),
          content: SizedBox(
            width: 360,
            child: Form(
              key: formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextFormField(
                    controller: nameController,
                    autofocus: true,
                    decoration: InputDecoration(
                      labelText: 'staff_name_label'.tr,
                    ),
                    validator: (value) =>
                        (value == null || value.trim().length < 2)
                        ? 'staff_name_required'.tr
                        : null,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: usernameController,
                    decoration: InputDecoration(
                      labelText: 'staff_username_label'.tr,
                    ),
                    validator: (value) =>
                        (value == null || value.trim().length < 3)
                        ? 'staff_username_min_length'.tr
                        : null,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: passwordController,
                    decoration: InputDecoration(
                      labelText: 'staff_password_label'.tr,
                    ),
                    validator: (value) => (value == null || value.length < 6)
                        ? 'staff_password_min_length'.tr
                        : null,
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    initialValue: role,
                    decoration: InputDecoration(
                      labelText: 'staff_role_label'.tr,
                    ),
                    items: controller.assignableRoles
                        .map(
                          (value) => DropdownMenuItem(
                            value: value,
                            child: Text(UserRole.label(value)),
                          ),
                        )
                        .toList(growable: false),
                    onChanged: (value) =>
                        setState(() => role = value ?? UserRole.waiter),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Get.back<void>(),
              child: Text('common_cancel'.tr),
            ),
            FilledButton(
              onPressed: () async {
                if (!(formKey.currentState?.validate() ?? false)) return;
                final created = await controller.create(
                  name: nameController.text.trim(),
                  username: usernameController.text.trim(),
                  password: passwordController.text,
                  role: role,
                );
                if (created) Get.back<void>();
              },
              child: Text('staff_add_staff'.tr),
            ),
          ],
        ),
      ),
    );
  }
}

class _RoleChip extends StatelessWidget {
  const _RoleChip({
    required this.label,
    required this.selected,
    required this.color,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ChoiceChip(
      label: Text(label),
      selected: selected,
      showCheckmark: false,
      onSelected: (_) => onTap(),
      // คงพื้นสีสดของบทบาทไว้ แล้วให้ onColor เลือกสีป้ายเอง — สีครัว (เหลือง)
      // ได้ป้ายสีเข้ม 7.93:1 ส่วนสีแอดมิน (ม่วง) ได้ป้ายสีขาว 5.55:1
      selectedColor: AppColors.fillOf(color),
      backgroundColor: AppColors.surfaceAlt,
      labelStyle: TextStyle(
        color: selected
            ? AppColors.onColor(AppColors.fillOf(color))
            : AppColors.textSecondary,
        fontWeight: FontWeight.w600,
        fontSize: 13,
      ),
    );
  }
}

class _StaffRow extends GetView<StaffController> {
  const _StaffRow({required this.user});

  final User user;

  @override
  Widget build(BuildContext context) {
    final color = StaffPage.roleColor(user.role);
    final isSelf = user.id == controller.currentUserId;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 21,
            backgroundColor: color.withValues(alpha: 0.14),
            child: Text(
              user.initials,
              style: TextStyle(
                color: color,
                fontWeight: FontWeight.w900,
                fontSize: 16,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        user.name,
                        style: const TextStyle(
                          fontSize: 14.5,
                          fontWeight: FontWeight.w700,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 8),
                    StatusChip(
                      label: user.roleLabel,
                      color: color,
                      dense: true,
                    ),
                    if (!user.isActive) ...[
                      const SizedBox(width: 6),
                      StatusChip(
                        label: 'staff_status_inactive'.tr,
                        color: AppColors.danger,
                        dense: true,
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  '@${user.username}',
                  style: TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          // แถวของบัญชีตัวเอง: ไม่มีเมนูให้กดลดสิทธิ์/ปิด/ลบตัวเองพลาด แสดงป้าย "คุณ" แทน
          if (isSelf)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: StatusChip(
                label: 'staff_you_badge'.tr,
                color: AppColors.primary,
                dense: true,
              ),
            )
          else if (controller.canManage(user))
            PopupMenuButton<String>(
              tooltip: 'staff_actions_tooltip'.tr,
              icon: const Icon(Icons.more_vert_rounded, size: 20),
              onSelected: (value) {
                switch (value) {
                  case 'toggle':
                    controller.toggleActive(user);
                  case 'delete':
                    controller.delete(user);
                  default:
                    controller.updateRole(user, value);
                }
              },
              itemBuilder: (context) => [
                ...controller.assignableRoles
                    .where((role) => role != user.role)
                    .map(
                      (role) => PopupMenuItem(
                        value: role,
                        child: Text(
                          'staff_change_role_to'.trParams({
                            'role': UserRole.label(role),
                          }),
                        ),
                      ),
                    ),
                const PopupMenuDivider(),
                PopupMenuItem(
                  value: 'toggle',
                  child: Text(
                    user.isActive
                        ? 'staff_deactivate_action'.tr
                        : 'staff_activate_action'.tr,
                  ),
                ),
                if (controller.canDelete)
                  PopupMenuItem(
                    value: 'delete',
                    child: Text(
                      'staff_delete_account'.tr,
                      style: TextStyle(color: AppColors.dangerInk),
                    ),
                  ),
              ],
            ),
        ],
      ),
    );
  }
}
