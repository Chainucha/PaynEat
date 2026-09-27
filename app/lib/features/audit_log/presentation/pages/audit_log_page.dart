// Copyright 2026 Suruch Chakrapeesirisuk
// SPDX-License-Identifier: Apache-2.0

import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../core/utils/app_clock.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/widgets/horizontal_fade.dart';
import '../../../../core/widgets/state_views.dart';
import '../../../../core/widgets/status_chip.dart';
import '../../domain/entities/audit_log.dart';
import '../../domain/entities/audit_log_action.dart';
import '../audit_summary_text.dart';
import '../controllers/audit_log_controller.dart';

/// หน้าประวัติ audit log — admin เท่านั้น (ดู docs/tickets/08-audit-log.md)
/// อ่านอย่างเดียว ไม่มีทางแก้ไข/ลบจากหน้านี้ (append-only)
class AuditLogPage extends GetView<AuditLogController> {
  const AuditLogPage({super.key});

  static Color actionColor(String action) {
    if (action.startsWith('order_item.')) return AppColors.warning;
    if (action.startsWith('order.')) return AppColors.primary;
    if (action.startsWith('user.')) return AppColors.purple;
    if (action.startsWith('settings.')) return AppColors.info;
    if (action.startsWith('payment.')) return AppColors.success;
    if (action.startsWith('tax_invoice.')) return AppColors.danger;
    if (action.startsWith('menu.')) return AppColors.secondary;
    if (action.startsWith('promotion.')) return AppColors.secondary;
    if (action.startsWith('ingredient.')) return AppColors.warning;
    return AppColors.textSecondary;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Column(
        children: [
          // แถบเลื่อนแนวนอนสูงคงที่ ไม่ใช่ Wrap — ชิป 11 ตัวใน Wrap กินความสูง
          // 464px บนจอ 400px (52% ของจอ) ทำให้ต้องเลื่อนผ่านตัวกรองครึ่งจอ
          // กว่าจะเห็น log บรรทัดแรก ใช้รูปแบบเดียวกับ CategoryFilterBar
          Container(
            color: AppColors.surface,
            padding: const EdgeInsets.symmetric(vertical: 10),
            child: SizedBox(
              height: 44,
              child: Obx(() {
                // ต้องอ่านค่า observable ตรงนี้ ไม่ใช่ใน itemBuilder —
                // itemBuilder ถูกเรียกแบบ lazy นอกขอบเขตที่ Obx ติดตามอยู่
                // ถ้าอ่านข้างในจะได้ error "improper use of a GetX"
                final selected = controller.actionFilter.value;

                return HorizontalFade(
                  builder: (context, scrollController) => ListView.separated(
                    controller: scrollController,
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: AuditLogAction.all.length + 1,
                    separatorBuilder: (_, _) => const SizedBox(width: 8),
                    itemBuilder: (context, index) {
                      if (index == 0) {
                        return _ActionChip(
                          label: 'common_all'.tr,
                          selected: selected == null,
                          color: AppColors.textSecondary,
                          onTap: () => controller.filterByAction(null),
                        );
                      }
                      final action = AuditLogAction.all[index - 1];
                      return _ActionChip(
                        label: controller.actionLabel(action),
                        selected: selected == action,
                        color: actionColor(action),
                        onTap: () => controller.filterByAction(action),
                      );
                    },
                  ),
                );
              }),
            ),
          ),
          Container(
            color: AppColors.surface,
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
            child: Row(
              children: [
                Expanded(
                  child: Obx(() {
                    final from = controller.dateFrom.value;
                    final to = controller.dateTo.value;
                    final label = from == null && to == null
                        ? 'audit_log_date_range_all'.tr
                        : 'audit_log_date_range_selected'.trParams({
                            'from': from == null ? '…' : Formatters.date(from),
                            'to': to == null ? '…' : Formatters.date(to),
                          });
                    return OutlinedButton.icon(
                      onPressed: () => _pickDateRange(context),
                      icon: const Icon(Icons.date_range_rounded, size: 16),
                      label: Text(
                        label,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 12.5),
                      ),
                    );
                  }),
                ),
                Obx(
                  () =>
                      (controller.dateFrom.value != null ||
                          controller.dateTo.value != null)
                      ? IconButton(
                          tooltip: 'audit_log_date_range_clear'.tr,
                          icon: const Icon(Icons.close_rounded, size: 18),
                          onPressed: () => controller.setDateRange(null, null),
                        )
                      : const SizedBox.shrink(),
                ),
                const SizedBox(width: 4),
                Obx(
                  () => controller.isExporting.value
                      ? const Padding(
                          padding: EdgeInsets.all(10),
                          child: SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                        )
                      : IconButton(
                          tooltip: 'audit_log_export_csv_button'.tr,
                          icon: const Icon(Icons.file_download_rounded),
                          onPressed: controller.exportCsv,
                        ),
                ),
              ],
            ),
          ),
          Expanded(
            child: Obx(() {
              if (controller.isLoading.value) return const LoadingView();

              final error = controller.errorMessage.value;
              if (error != null && controller.logs.isEmpty) {
                return ErrorView(message: error, onRetry: controller.load);
              }

              final logs = controller.logs;
              if (logs.isEmpty) {
                return EmptyView(
                  message: 'audit_log_empty_state'.tr,
                  icon: Icons.history_rounded,
                );
              }

              // +1 แถวท้ายสำหรับป้ายบอกจำนวน/ปุ่มโหลดเพิ่ม เพื่อไม่ให้ผู้ใช้
              // เข้าใจผิดว่ารายการที่เห็นคือทั้งหมดที่มี
              return RefreshIndicator(
                onRefresh: controller.load,
                child: ListView.separated(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
                  itemCount: logs.length + 1,
                  separatorBuilder: (_, _) => const SizedBox(height: 8),
                  itemBuilder: (context, index) {
                    if (index == logs.length) {
                      return _ListFooter(controller: controller);
                    }
                    return _AuditLogRow(log: logs[index]);
                  },
                ),
              );
            }),
          ),
        ],
      ),
    );
  }

  Future<void> _pickDateRange(BuildContext context) async {
    final now = AppClock.now();
    final current =
        controller.dateFrom.value != null && controller.dateTo.value != null
        ? DateTimeRange(
            start: controller.dateFrom.value!,
            end: controller.dateTo.value!,
          )
        : null;

    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(now.year - 5),
      lastDate: now,
      initialDateRange: current,
    );
    if (picked != null) {
      controller.setDateRange(picked.start, picked.end);
    }
  }
}

/// ท้ายรายการ — บอกว่าเห็นอยู่กี่จาก, มีต่อไหม, และปุ่มโหลดเพิ่ม
class _ListFooter extends StatelessWidget {
  const _ListFooter({required this.controller});

  final AuditLogController controller;

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final shown = controller.logs.length;
      final total = controller.total.value;

      return Padding(
        padding: const EdgeInsets.only(top: 8),
        child: Column(
          children: [
            Text(
              'audit_log_shown_count'.trParams({
                'shown': '$shown',
                'total': '$total',
              }),
              style: TextStyle(fontSize: 12.5, color: AppColors.textSecondary),
            ),
            if (controller.hasMore) ...[
              const SizedBox(height: 8),
              controller.isLoadingMore.value
                  ? const Padding(
                      padding: EdgeInsets.all(8),
                      child: SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    )
                  : OutlinedButton.icon(
                      onPressed: controller.loadMore,
                      icon: const Icon(Icons.expand_more_rounded, size: 18),
                      label: Text('audit_log_load_more'.tr),
                    ),
            ],
          ],
        ),
      );
    });
  }
}

class _ActionChip extends StatelessWidget {
  const _ActionChip({
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
      selectedColor: AppColors.fillOf(color),
      backgroundColor: AppColors.surfaceAlt,
      labelStyle: TextStyle(
        color: selected
            ? AppColors.onColor(AppColors.fillOf(color))
            : AppColors.textSecondary,
        fontWeight: FontWeight.w600,
        fontSize: 12.5,
      ),
    );
  }
}

class _AuditLogRow extends StatelessWidget {
  const _AuditLogRow({required this.log});

  final AuditLog log;

  @override
  Widget build(BuildContext context) {
    final color = AuditLogPage.actionColor(log.action);

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              StatusChip(
                label: AuditLogAction.translationKey(log.action).tr,
                color: color,
                dense: true,
              ),
              const Spacer(),
              Text(
                Formatters.dateTime(log.createdAt),
                style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            AuditSummaryText.of(log),
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
          ),
          if (log.reason != null && log.reason!.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              'audit_log_reason_prefix'.trParams({'reason': log.reason!}),
              style: TextStyle(fontSize: 12.5, color: AppColors.textSecondary),
            ),
          ],
          const SizedBox(height: 6),
          Text(
            'audit_log_actor_prefix'.trParams({
              // log ที่ไม่มีคนทำ (งานของระบบ) บันทึกชื่อไว้เป็นคำไทย "ระบบ"
              'name': log.actorUserId == null && log.actorName == 'ระบบ'
                  ? 'audit_log_actor_system'.tr
                  : log.actorName,
            }),
            style: TextStyle(
              fontSize: 12,
              color: AppColors.textSecondary,
              fontStyle: FontStyle.italic,
            ),
          ),
        ],
      ),
    );
  }
}
