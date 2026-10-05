// Copyright 2026 Suruch Chakrapeesirisuk
// SPDX-License-Identifier: Apache-2.0

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/widgets/app_card.dart';
import '../../../../core/widgets/state_views.dart';
import '../../domain/entities/shift.dart';
import '../controllers/shift_controller.dart';
import '../widgets/z_report_dialog.dart';

/// หน้าจอเปิด/ปิดกะ — ใช้กระทบยอดเงินสดของแคชเชียร์ก่อน/หลังให้บริการ
class ShiftPage extends GetView<ShiftController> {
  const ShiftPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('shift_page_title'.tr)),
      body: Obx(() {
        if (controller.isLoading.value) return const LoadingView();
        final error = controller.errorMessage.value;
        if (error != null) {
          return ErrorView(message: error, onRetry: controller.load);
        }

        final shift = controller.current.value;
        final closed = controller.lastClosed.value;

        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            if (shift != null)
              _OpenShiftCard(shift: shift)
            else if (closed != null)
              _ClosedShiftSummary(shift: closed)
            else
              const _OpenShiftForm(),
            const SizedBox(height: 16),
            _ShiftHistory(),
          ],
        );
      }),
    );
  }
}

class _OpenShiftForm extends GetView<ShiftController> {
  const _OpenShiftForm();

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'shift_open_new_shift'.tr,
            style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 4),
          Text(
            'shift_open_new_subtitle'.tr,
            style: TextStyle(fontSize: 12.5, color: AppColors.textSecondary),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: controller.openingCashController,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
            ],
            decoration: InputDecoration(
              labelText: 'shift_starting_cash_label'.tr,
              suffixText: 'common_baht'.tr,
            ),
          ),
          const SizedBox(height: 16),
          Obx(
            () => FilledButton.icon(
              style: FilledButton.styleFrom(minimumSize: const Size(0, 52)),
              onPressed: controller.isSubmitting.value
                  ? null
                  : controller.submitOpen,
              icon: controller.isSubmitting.value
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: AppColors.surface,
                      ),
                    )
                  : const Icon(Icons.lock_open_rounded),
              label: Text('shift_open_button'.tr),
            ),
          ),
        ],
      ),
    );
  }
}

class _OpenShiftCard extends GetView<ShiftController> {
  const _OpenShiftCard({required this.shift});

  final Shift shift;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                width: 9,
                height: 9,
                decoration: const BoxDecoration(
                  color: AppColors.success,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                'shift_currently_open_title'.tr,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _InfoRow(
            label: 'shift_opened_by_label'.tr,
            value: shift.openedByName ?? '-',
          ),
          _InfoRow(
            label: 'shift_opened_at_label'.tr,
            value: Formatters.dateTime(shift.openedAt),
          ),
          _InfoRow(
            label: 'shift_starting_cash_label'.tr,
            value: Formatters.baht(shift.openingCash),
          ),
          const Divider(height: 28),
          Text(
            'shift_close_button'.tr,
            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 4),
          Text(
            'shift_close_subtitle'.tr,
            style: TextStyle(fontSize: 12.5, color: AppColors.textSecondary),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: controller.countedCashController,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
            ],
            decoration: InputDecoration(
              labelText: 'shift_counted_cash_label'.tr,
              suffixText: 'common_baht'.tr,
            ),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: controller.noteController,
            decoration: InputDecoration(labelText: 'shift_note_label'.tr),
          ),
          const SizedBox(height: 16),
          Obx(
            () => FilledButton.icon(
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.danger,
                minimumSize: const Size(0, 52),
              ),
              onPressed: controller.isSubmitting.value
                  ? null
                  : controller.submitClose,
              icon: controller.isSubmitting.value
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: AppColors.surface,
                      ),
                    )
                  : const Icon(Icons.lock_rounded),
              label: Text('shift_close_button'.tr),
            ),
          ),
        ],
      ),
    );
  }
}

class _ClosedShiftSummary extends GetView<ShiftController> {
  const _ClosedShiftSummary({required this.shift});

  final Shift shift;

  @override
  Widget build(BuildContext context) {
    final variance = shift.variance ?? 0;
    final varianceColor = variance == 0
        ? AppColors.success
        : (variance < 0 ? AppColors.danger : AppColors.warning);
    final varianceLabel = variance == 0
        ? 'shift_variance_balanced'.tr
        : (variance < 0 ? 'shift_variance_short'.tr : 'shift_variance_over'.tr);

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'shift_close_summary_title'.tr,
            style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 12),
          _InfoRow(
            label: 'shift_starting_cash_label'.tr,
            value: Formatters.baht(shift.openingCash),
          ),
          _InfoRow(
            label: 'shift_expected_cash_label'.tr,
            value: Formatters.baht(shift.expectedCash ?? 0),
          ),
          _InfoRow(
            label: 'shift_counted_cash_label'.tr,
            value: Formatters.baht(shift.countedCash ?? 0),
          ),
          const Divider(height: 24),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: varianceColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Text(
                  varianceLabel,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: varianceColor,
                  ),
                ),
                const Spacer(),
                Text(
                  Formatters.baht(variance.abs()),
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                    color: varianceColor,
                  ),
                ),
              ],
            ),
          ),
          // กะปิดสำเร็จแล้ว แต่สำรองข้อมูลหลังปิดกะไม่สำเร็จ (ticket 33) — แสดงค้างไว้ในการ์ด ไม่ใช่
          // snackbar ที่หายในสองวินาที แคชเชียร์ต้องอ่านทันและบอกเจ้าของร้านได้
          if (shift.backupFailed) ...[
            const SizedBox(height: 12),
            Container(
              key: const Key('shift-backup-failed'),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.warning.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: AppColors.warning.withValues(alpha: 0.5),
                ),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.backup_outlined, color: AppColors.warningInk),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'shift_close_backup_failed'.tr,
                      style: const TextStyle(fontSize: 13.5),
                    ),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 12),
          OutlinedButton.icon(
            style: OutlinedButton.styleFrom(minimumSize: const Size(0, 48)),
            onPressed: () => ZReportDialog.show(shift.id),
            icon: const Icon(Icons.receipt_long_rounded),
            label: Text('shift_z_report_view_button'.tr),
          ),
          const SizedBox(height: 12),
          FilledButton.icon(
            style: FilledButton.styleFrom(minimumSize: const Size(0, 52)),
            onPressed: controller.startNewShift,
            icon: const Icon(Icons.lock_open_rounded),
            label: Text('shift_open_new_shift'.tr),
          ),
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          Text(
            label,
            style: TextStyle(fontSize: 13.5, color: AppColors.textSecondary),
          ),
          const Spacer(),
          Text(
            value,
            style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }
}

class _ShiftHistory extends GetView<ShiftController> {
  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final history = controller.history;
      if (history.isEmpty) return const SizedBox.shrink();

      return AppCard(
        padding: EdgeInsets.zero,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 6),
              child: Text(
                'shift_history_title'.tr,
                style: const TextStyle(fontWeight: FontWeight.w800),
              ),
            ),
            for (final shift in history) _HistoryTile(shift: shift),
            const SizedBox(height: 6),
          ],
        ),
      );
    });
  }
}

class _HistoryTile extends StatelessWidget {
  const _HistoryTile({required this.shift});

  final Shift shift;

  @override
  Widget build(BuildContext context) {
    final isOpen = shift.isOpen;
    return ListTile(
      leading: Icon(
        isOpen ? Icons.lock_open_rounded : Icons.lock_rounded,
        color: isOpen ? AppColors.success : AppColors.textSecondary,
      ),
      title: Text(Formatters.dateTime(shift.openedAt)),
      subtitle: Text(
        isOpen
            ? 'shift_history_open_subtitle'.trParams({
                'name': shift.openedByName ?? '-',
              })
            : 'shift_variance_label'.trParams({
                'amount': Formatters.baht((shift.variance ?? 0).abs()),
              }),
      ),
      trailing: Text(
        Formatters.baht(shift.openingCash),
        style: const TextStyle(fontWeight: FontWeight.w700),
      ),
      // ดู Z-report ย้อนหลังได้ทุกกะที่ปิดแล้ว (ดู docs/tickets/12-report-export.md) —
      // ไม่เปิดให้กะที่ยังเปิดอยู่ เพราะยอดกระทบเงินสดยังไม่ถูกคำนวณจนกว่าจะปิดกะ
      onTap: isOpen ? null : () => ZReportDialog.show(shift.id),
    );
  }
}
