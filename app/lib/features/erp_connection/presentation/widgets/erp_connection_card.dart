// Copyright 2026 Suruch Chakrapeesirisuk
// SPDX-License-Identifier: Apache-2.0

import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../../app/config/app_config.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/widgets/app_card.dart';
import '../../../../core/widgets/app_dialogs.dart';
import '../../domain/entities/erp_connection_status.dart';
import '../controllers/erp_connection_controller.dart';

/// หัวข้อ "การเชื่อมต่อ" ของ admin ในหน้าตั้งค่า (ดู docs/tickets/25-erp-connected-mode.md)
///
/// ส่วนบนคือเซิร์ฟเวอร์ร้าน (ticket 29b จะทำให้ตั้งจากตรงนี้ได้) ส่วนล่างคือ PaynEat ERP
class ErpConnectionCard extends GetView<ErpConnectionController> {
  const ErpConnectionCard({super.key});

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SectionHeader(
            title: 'erp_connection_title'.tr,
            subtitle: 'erp_connection_subtitle'.tr,
          ),
          const SizedBox(height: 12),
          _Row(
            label: 'erp_store_server_title'.tr,
            value: AppConfig.demoMode
                ? 'erp_store_server_demo'.tr
                : AppConfig.baseUrl,
          ),
          const Divider(height: 28),
          Obx(() {
            final status = controller.status.value;
            return SectionHeader(
              title: 'erp_section_title'.tr,
              subtitle: 'erp_section_subtitle'.tr,
              trailing: _ModeChip(status: status),
            );
          }),
          const SizedBox(height: 12),
          Obx(() {
            if (controller.isLoading.value) {
              return const Center(
                child: Padding(
                  padding: EdgeInsets.all(12),
                  child: CircularProgressIndicator(strokeWidth: 2.4),
                ),
              );
            }
            final error = controller.errorMessage.value;
            if (error != null) {
              return _Message(text: error, isError: true);
            }
            if (AppConfig.demoMode) {
              return _Message(text: 'erp_demo_note'.tr);
            }
            final status = controller.status.value;
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (status.isConnected)
                  _ConnectedDetails(status: status)
                else
                  _StandaloneForm(status: status),
                const _ActionMessages(),
              ],
            );
          }),
        ],
      ),
    );
  }
}

class _ModeChip extends StatelessWidget {
  const _ModeChip({required this.status});

  final ErpConnectionStatus status;

  @override
  Widget build(BuildContext context) {
    final connected = status.isConnected;
    final color = connected ? AppColors.successInk : AppColors.textSecondary;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        connected
            ? 'erp_mode_connected'.trParams({
                'instance': status.connection?.instanceCode ?? '',
              })
            : 'erp_mode_standalone'.tr,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          color: color,
        ),
      ),
    );
  }
}

/// ใช้งานเดี่ยว: สาขาที่ต้องแก้รหัส แล้วฟอร์มที่อยู่ + credential
class _StandaloneForm extends GetView<ErpConnectionController> {
  const _StandaloneForm({required this.status});

  final ErpConnectionStatus status;

  @override
  Widget build(BuildContext context) {
    final toFix = status.branchesToFix;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (toFix.isNotEmpty) ...[
          _ListBox(
            title: 'erp_branches_to_fix_title'.tr,
            note: 'erp_branch_code_rule'.tr,
            color: AppColors.warningInk,
            children: [
              for (final branch in toFix)
                ListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.storefront_rounded),
                  title: Text(branch.name),
                  subtitle: Text(
                    branch.codeProblem == BranchCodeProblem.missing
                        ? 'erp_branch_problem_missing'.tr
                        : 'erp_branch_problem_invalid'.trParams({
                            'code': branch.code ?? '',
                          }),
                  ),
                  trailing: TextButton(
                    onPressed: () => _editCode(branch),
                    child: Text('erp_branch_edit_code'.tr),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
        ],
        const _UrlField(),
        const SizedBox(height: 12),
        const _CredentialField(),
        const SizedBox(height: 14),
        Obx(
          () => FilledButton.icon(
            onPressed: controller.isBusy.value ? null : controller.connect,
            icon: const Icon(Icons.link_rounded),
            label: Text('erp_connect_button'.tr),
          ),
        ),
      ],
    );
  }

  Future<void> _editCode(ErpBranchCheck branch) async {
    final input = TextEditingController(text: branch.code ?? '');
    await Get.dialog<bool>(
      AlertDialog(
        title: Text(
          'erp_branch_code_dialog_title'.trParams({'name': branch.name}),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: input,
              autofocus: true,
              textCapitalization: TextCapitalization.characters,
              decoration: InputDecoration(
                labelText: 'erp_branch_code_label'.tr,
              ),
            ),
            const SizedBox(height: 8),
            Text('erp_branch_code_rule'.tr, style: Get.textTheme.bodySmall),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Get.back<bool>(result: false),
            child: Text('common_cancel'.tr),
          ),
          FilledButton(
            onPressed: () async {
              final ok = await controller.updateBranchCode(branch, input.text);
              Get.back<bool>(result: ok);
            },
            child: Text('common_save'.tr),
          ),
        ],
      ),
    );
    input.dispose();
  }
}

class _UrlField extends GetView<ErpConnectionController> {
  const _UrlField();

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller.urlController,
      keyboardType: TextInputType.url,
      autocorrect: false,
      decoration: InputDecoration(
        labelText: 'erp_url_label'.tr,
        hintText: 'https://erp.example.com',
        helperText: 'erp_url_https_hint'.tr,
      ),
    );
  }
}

class _CredentialField extends GetView<ErpConnectionController> {
  const _CredentialField();

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller.credentialController,
      obscureText: true,
      autocorrect: false,
      enableSuggestions: false,
      decoration: InputDecoration(
        labelText: 'erp_credential_label'.tr,
        hintText: 'erp_credential_hint'.tr,
      ),
    );
  }
}

/// โหมดเชื่อมต่อ: รายละเอียด ปัญหาของการดึงครั้งล่าสุด สาขาที่ไม่ตรงกัน และปุ่มต่าง ๆ
class _ConnectedDetails extends GetView<ErpConnectionController> {
  const _ConnectedDetails({required this.status});

  final ErpConnectionStatus status;

  @override
  Widget build(BuildContext context) {
    final connection = status.connection!;
    final problem = controller.lastPullProblem;
    final transportWarning = controller.transportWarning;
    final blocked = controller.transportBlocked;
    final notServed = status.branchesNotServed;
    final missing = status.servedButMissing;
    final superseded = status.branches
        .where((branch) => branch.supersededBy != null)
        .toList(growable: false);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _Row(label: 'erp_url_label'.tr, value: connection.erpUrl),
        _Row(
          label: 'erp_info_instance'.tr,
          value: '${connection.instanceCode} · ${connection.instanceName}',
        ),
        _Row(label: 'erp_info_contract'.tr, value: connection.contractVersion),
        _Row(
          label: 'erp_info_version'.tr,
          value: 'erp_info_version_value'.trParams({
            'applied': '${connection.appliedVersion}',
            'latest':
                '${connection.latestVersion ?? connection.appliedVersion}',
          }),
        ),
        _Row(
          label: 'erp_info_last_pull'.tr,
          value: connection.lastPullAt == null
              ? 'erp_info_never'.tr
              : Formatters.dateTime(connection.lastPullAt),
        ),
        _Row(
          label: 'erp_credential_label'.tr,
          value: 'erp_credential_saved'.tr,
        ),
        // ช่องทางของ credential (ticket 32): http ที่อนุญาตไว้เตือนถาวร, http เดิมบอกให้เปลี่ยนเป็น https
        if (transportWarning case (final title, final note)) ...[
          const SizedBox(height: 8),
          _ListBox(
            key: const ValueKey('erp-transport-warning'),
            title: title,
            note: note,
            color: AppColors.dangerInk,
            children: const [],
          ),
        ],
        if (problem != null) ...[
          const SizedBox(height: 8),
          _Message(text: problem, isError: true),
        ],
        if (controller.pullStopped) ...[
          const SizedBox(height: 4),
          _Message(text: 'erp_pull_stopped_note'.tr, isError: true),
        ],
        const SizedBox(height: 8),
        _Message(text: 'erp_stock_note'.tr),
        if (notServed.isNotEmpty) ...[
          const SizedBox(height: 12),
          _ListBox(
            title: 'erp_branches_not_served_title'.tr,
            note: 'erp_branches_not_served_note'.tr,
            color: AppColors.warningInk,
            children: [
              for (final branch in notServed)
                Text('• ${branch.name} (${branch.code ?? '-'})'),
            ],
          ),
        ],
        if (missing.isNotEmpty) ...[
          const SizedBox(height: 12),
          _ListBox(
            title: 'erp_served_missing_title'.tr,
            note: 'erp_served_missing_note'.tr,
            color: AppColors.infoInk,
            children: [
              for (final branch in missing)
                Row(
                  children: [
                    Expanded(
                      child: Text('• ${_servedName(branch)} (${branch.code})'),
                    ),
                    Obx(
                      () => TextButton.icon(
                        onPressed:
                            controller.isBusy.value ||
                                connection.credentialRejected ||
                                blocked
                            ? null
                            : () => _confirmCreate(branch),
                        icon: const Icon(Icons.add_business_rounded, size: 18),
                        label: Text('erp_branch_create_button'.tr),
                      ),
                    ),
                  ],
                ),
            ],
          ),
        ],
        for (final branch in superseded) ...[
          const SizedBox(height: 8),
          _Message(
            text:
                '${branch.name}: ${'erp_branch_superseded'.trParams({'code': branch.supersededBy!})}',
            isError: true,
          ),
        ],
        const SizedBox(height: 14),
        Obx(() {
          if (!controller.editingCredential.value &&
              !connection.credentialRejected &&
              !blocked) {
            return const SizedBox.shrink();
          }
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // ที่อยู่ http เดิมใช้ไม่ได้แล้ว — แก้ที่อยู่ได้ตรงนี้ credential ต้องกรอกใหม่ด้วย (backend ไม่ส่ง credential
              // ที่บันทึกไว้ไปที่อยู่ใหม่ให้เอง)
              if (blocked) ...[const _UrlField(), const SizedBox(height: 12)],
              const _CredentialField(),
              const SizedBox(height: 10),
              FilledButton(
                onPressed: controller.isBusy.value ? null : controller.connect,
                child: Text(
                  blocked
                      ? 'erp_save_address_button'.tr
                      : 'erp_save_credential_button'.tr,
                ),
              ),
              const SizedBox(height: 10),
            ],
          );
        }),
        Obx(
          () => Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              FilledButton.icon(
                onPressed:
                    controller.isBusy.value ||
                        connection.credentialRejected ||
                        blocked
                    ? null
                    : controller.pullNow,
                icon: const Icon(Icons.sync_rounded),
                label: Text('erp_pull_button'.tr),
              ),
              if (!connection.credentialRejected && !blocked)
                OutlinedButton(
                  onPressed: controller.isBusy.value
                      ? null
                      : () => controller.editingCredential.toggle(),
                  child: Text('erp_change_credential_button'.tr),
                ),
              OutlinedButton(
                onPressed: controller.isBusy.value ? null : _confirmDisconnect,
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.dangerInk,
                ),
                child: Text('erp_disconnect_button'.tr),
              ),
            ],
          ),
        ),
      ],
    );
  }

  String _servedName(ErpServedBranch branch) =>
      Get.locale?.languageCode == 'th' ? branch.nameTh : branch.nameEn;

  Future<void> _confirmCreate(ErpServedBranch branch) async {
    final confirmed = await AppDialogs.confirm(
      title: 'erp_branch_create_title'.tr,
      message: 'erp_branch_create_confirm'.trParams({
        'name': _servedName(branch),
        'code': branch.code,
      }),
      confirmLabel: 'erp_branch_create_button'.tr,
    );
    if (confirmed) await controller.createBranch(branch);
  }

  Future<void> _confirmDisconnect() async {
    final confirmed = await AppDialogs.confirm(
      title: 'erp_disconnect_title'.tr,
      message: 'erp_disconnect_confirm'.tr,
      confirmLabel: 'erp_disconnect_button'.tr,
      destructive: true,
    );
    if (confirmed) await controller.disconnect();
  }
}

class _ActionMessages extends GetView<ErpConnectionController> {
  const _ActionMessages();

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final error = controller.actionError.value;
      final notice = controller.actionNotice.value;
      if (error == null && notice == null) return const SizedBox.shrink();
      return Padding(
        padding: const EdgeInsets.only(top: 12),
        child: _Message(text: error ?? notice!, isError: error != null),
      );
    });
  }
}

class _ListBox extends StatelessWidget {
  const _ListBox({
    super.key,
    required this.title,
    required this.color,
    required this.children,
    this.note,
  });

  final String title;
  final String? note;
  final Color color;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(fontWeight: FontWeight.w700, color: color),
          ),
          if (note != null) ...[
            const SizedBox(height: 4),
            Text(note!, style: Theme.of(context).textTheme.bodySmall),
          ],
          const SizedBox(height: 6),
          ...children,
        ],
      ),
    );
  }
}

class _Message extends StatelessWidget {
  const _Message({required this.text, this.isError = false});

  final String text;
  final bool isError;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: TextStyle(
        fontSize: 13,
        color: isError ? AppColors.dangerInk : AppColors.textSecondary,
      ),
    );
  }
}

class _Row extends StatelessWidget {
  const _Row({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 160,
            child: Text(
              label,
              style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
}
