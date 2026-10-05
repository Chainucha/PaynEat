// Copyright 2026 Suruch Chakrapeesirisuk
// SPDX-License-Identifier: Apache-2.0

import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../../app/config/app_config.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/widgets/app_card.dart';
import '../../domain/entities/backup_status.dart';
import '../backup_warning_text.dart';
import '../controllers/backup_controller.dart';

/// หัวข้อ "สำรองข้อมูล" ของ admin ในหน้าตั้งค่า (ดู docs/tickets/33-automatic-backup.md)
///
/// แสดงเวลาที่สำเร็จล่าสุด ขนาดไฟล์ ที่เก็บทั้งสองที่พร้อมสถานะแยกกัน และจำนวนไฟล์ที่เก็บอยู่
/// ไม่มีปุ่มกู้คืนหรือดาวน์โหลด: กู้คืนทำบนเครื่องเซิร์ฟเวอร์เท่านั้น
class BackupCard extends GetView<BackupController> {
  const BackupCard({super.key});

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Obx(
            () => SectionHeader(
              title: 'backup_title'.tr,
              subtitle: 'backup_subtitle'.tr,
              trailing: _StateChip(status: controller.status.value),
            ),
          ),
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
            final status = controller.status.value;
            if (error != null || status == null) {
              return _Message(text: error ?? '', isError: true);
            }
            return _Details(status: status);
          }),
        ],
      ),
    );
  }
}

class _StateChip extends StatelessWidget {
  const _StateChip({required this.status});

  final BackupStatus? status;

  @override
  Widget build(BuildContext context) {
    final current = status;
    if (current == null || !current.enabled) return const SizedBox.shrink();
    final attention = current.needsAttention;
    final color = attention ? AppColors.warningInk : AppColors.successInk;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        attention ? 'backup_state_attention'.tr : 'backup_state_ok'.tr,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          color: color,
        ),
      ),
    );
  }
}

class _Details extends GetView<BackupController> {
  const _Details({required this.status});

  final BackupStatus status;

  @override
  Widget build(BuildContext context) {
    if (!status.enabled) return _Message(text: 'backup_disabled'.tr);
    final warning = BackupWarningText.of(status);
    final last = status.primary.lastSuccess;
    final primaryFailure = status.primary.lastFailure;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (AppConfig.demoMode) ...[
          _Message(text: 'backup_demo_note'.tr),
          const SizedBox(height: 10),
        ],
        if (warning != null) ...[
          _Box(
            key: const Key('backup-warning'),
            color: AppColors.warning,
            icon: Icons.warning_amber_rounded,
            text: warning,
            detail: status.warning == BackupWarning.failed
                ? primaryFailure?.message
                : null,
          ),
          const SizedBox(height: 10),
        ],
        if (status.lowDiskSpace) ...[
          _Box(
            key: const Key('backup-low-disk'),
            color: AppColors.warning,
            icon: Icons.storage_rounded,
            text: 'backup_low_disk'.tr,
          ),
          const SizedBox(height: 10),
        ],
        _Row(
          label: 'backup_last_success'.tr,
          value: last == null
              ? 'backup_never'.tr
              : '${Formatters.dateTimeOf(last.at)} · '
                    '${BackupWarningText.reason(last.reason)}',
        ),
        if (last?.sizeBytes != null)
          _Row(
            label: 'backup_last_size'.tr,
            value: Formatters.fileSize(last!.sizeBytes!),
          ),
        const Divider(height: 24),
        _DestinationSection(
          title: 'backup_primary_title'.tr,
          destination: status.primary,
          failing: status.warning == BackupWarning.failed,
        ),
        const Divider(height: 24),
        if (status.copy.configured)
          _DestinationSection(
            title: 'backup_copy_title'.tr,
            destination: status.copy,
            failing: status.copy.failing,
          )
        else ...[
          Text(
            'backup_copy_title'.tr,
            style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 4),
          _Message(
            key: const Key('backup-copy-not-configured'),
            text: 'backup_copy_not_configured'.tr,
          ),
        ],
        const SizedBox(height: 16),
        Obx(() {
          final busy = controller.isBusy.value || status.running;
          return FilledButton.icon(
            key: const Key('backup-now'),
            style: FilledButton.styleFrom(minimumSize: const Size(0, 48)),
            onPressed: busy ? null : controller.backupNow,
            icon: busy
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: AppColors.surface,
                    ),
                  )
                : const Icon(Icons.backup_rounded),
            label: Text(
              busy ? 'backup_now_running'.tr : 'backup_now_button'.tr,
            ),
          );
        }),
        Obx(() {
          final error = controller.actionError.value;
          final notice = controller.actionNotice.value;
          if (error == null && notice == null) return const SizedBox.shrink();
          return Padding(
            padding: const EdgeInsets.only(top: 12),
            child: _Message(
              key: const Key('backup-action-message'),
              text: error ?? notice!,
              isError: error != null,
            ),
          );
        }),
        const SizedBox(height: 12),
        _Message(text: 'backup_restore_note'.tr),
      ],
    );
  }
}

/// ที่เก็บหนึ่งที่ — โฟลเดอร์ สถานะ และจำนวนไฟล์ แยกจากอีกที่
class _DestinationSection extends StatelessWidget {
  const _DestinationSection({
    required this.title,
    required this.destination,
    required this.failing,
  });

  final String title;
  final BackupDestination destination;
  final bool failing;

  @override
  Widget build(BuildContext context) {
    final failure = destination.lastFailure;
    final success = destination.lastSuccess;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                title,
                style: const TextStyle(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            Icon(
              failing
                  ? Icons.error_outline_rounded
                  : Icons.check_circle_rounded,
              size: 18,
              color: failing
                  ? AppColors.dangerInk
                  : (success == null
                        ? AppColors.textSecondary
                        : AppColors.successInk),
            ),
          ],
        ),
        const SizedBox(height: 6),
        _Row(label: 'backup_folder'.tr, value: destination.dir ?? '-'),
        _Row(
          label: 'backup_file_count'.tr,
          value: 'backup_file_count_value'.trParams({
            'count': '${destination.fileCount}',
          }),
        ),
        _Row(
          label: 'backup_destination_last_success'.tr,
          value: success == null
              ? 'backup_never'.tr
              : Formatters.dateTimeOf(success.at),
        ),
        if (failing && failure != null)
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: _Message(
              text: 'backup_destination_failed'.trParams({
                'time': Formatters.dateTimeOf(failure.at),
                'reason': failure.message,
              }),
              isError: true,
            ),
          ),
      ],
    );
  }
}

class _Box extends StatelessWidget {
  const _Box({
    super.key,
    required this.color,
    required this.icon,
    required this.text,
    this.detail,
  });

  final Color color;
  final IconData icon;
  final String text;
  final String? detail;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.45)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: AppColors.inkOf(color)),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  text,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                if (detail != null && detail!.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    detail!,
                    style: TextStyle(
                      fontSize: 12.5,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Message extends StatelessWidget {
  const _Message({super.key, required this.text, this.isError = false});

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
