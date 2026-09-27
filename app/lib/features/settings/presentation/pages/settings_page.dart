// Copyright 2026 Suruch Chakrapeesirisuk
// SPDX-License-Identifier: Apache-2.0

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';

import '../../../../app/config/app_config.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/localization/locale_service.dart';
import '../../../../core/services/session_service.dart';
import '../../../../core/widgets/app_card.dart';
import '../../../../core/widgets/state_views.dart';
import '../../../erp_connection/presentation/widgets/erp_connection_card.dart';
import '../controllers/printer_settings_controller.dart';
import '../controllers/settings_controller.dart';

/// ตั้งค่าร้าน (admin/manager)
class SettingsPage extends GetView<SettingsController> {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      if (controller.isLoading.value) return const LoadingView();

      final error = controller.errorMessage.value;
      if (error != null) {
        return ErrorView(message: error, onRetry: controller.load);
      }

      return ListView(
        padding: const EdgeInsets.all(16),
        children: [
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 620),
            child: AppCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  SectionHeader(
                    title: 'settings_store_info_title'.tr,
                    subtitle: 'settings_store_info_subtitle'.tr,
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: controller.storeNameController,
                    decoration: InputDecoration(
                      labelText: 'settings_store_name_label'.tr,
                    ),
                  ),
                  const SizedBox(height: 24),
                  SectionHeader(
                    title: 'settings_bill_calc_title'.tr,
                    subtitle: 'settings_bill_calc_subtitle'.tr,
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: controller.vatController,
                          keyboardType: TextInputType.number,
                          inputFormatters: [
                            FilteringTextInputFormatter.digitsOnly,
                          ],
                          decoration: InputDecoration(
                            labelText: 'settings_vat_label'.tr,
                            suffixText: '%',
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextField(
                          controller: controller.serviceChargeController,
                          keyboardType: TextInputType.number,
                          inputFormatters: [
                            FilteringTextInputFormatter.digitsOnly,
                          ],
                          decoration: InputDecoration(
                            labelText: 'settings_service_charge_label'.tr,
                            suffixText: '%',
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Obx(
                    () => SwitchListTile(
                      value: controller.vatIncluded.value,
                      onChanged: (value) =>
                          controller.vatIncluded.value = value,
                      title: Text('settings_vat_included_title'.tr),
                      subtitle: Text('settings_vat_included_subtitle'.tr),
                      contentPadding: EdgeInsets.zero,
                    ),
                  ),
                  const SizedBox(height: 24),
                  SectionHeader(
                    title: 'settings_tax_invoice_title'.tr,
                    subtitle: 'settings_tax_invoice_subtitle'.tr,
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: controller.storeTaxIdController,
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    decoration: InputDecoration(
                      labelText: 'settings_store_tax_id_label'.tr,
                      hintText: 'settings_store_tax_id_hint'.tr,
                    ),
                  ),
                  const SizedBox(height: 14),
                  TextField(
                    controller: controller.storeAddressController,
                    maxLines: 2,
                    decoration: InputDecoration(
                      labelText: 'settings_store_address_label'.tr,
                    ),
                  ),
                  const SizedBox(height: 14),
                  TextField(
                    controller: controller.storeBranchController,
                    decoration: InputDecoration(
                      labelText: 'settings_store_branch_label'.tr,
                      hintText: 'settings_store_branch_hint'.tr,
                    ),
                  ),
                  const SizedBox(height: 24),
                  SectionHeader(
                    title: 'settings_promptpay_title'.tr,
                    subtitle: 'settings_promptpay_subtitle'.tr,
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: controller.promptPayIdController,
                    keyboardType: TextInputType.phone,
                    decoration: InputDecoration(
                      labelText: 'settings_promptpay_id_label'.tr,
                      hintText: 'settings_promptpay_id_hint'.tr,
                    ),
                  ),
                  const SizedBox(height: 24),
                  // ตาชั่งพิมพ์ฉลาก — รูปแบบต้องตรงกับที่ตั้งไว้ในตาชั่ง แอปจึงแยก PLU กับ
                  // น้ำหนักจากบาร์โค้ดได้ถูก (ดู docs/tickets/19-barcode-scale.md)
                  SectionHeader(
                    title: 'settings_scale_title'.tr,
                    subtitle: 'settings_scale_subtitle'.tr,
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: controller.scaleLabelPrefixController,
                          keyboardType: TextInputType.number,
                          inputFormatters: [
                            FilteringTextInputFormatter.digitsOnly,
                            LengthLimitingTextInputFormatter(3),
                          ],
                          decoration: InputDecoration(
                            labelText: 'settings_scale_prefix_label'.tr,
                            hintText: '20',
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Obx(
                          () => DropdownButtonFormField<int>(
                            initialValue: controller.scaleLabelPluDigits.value,
                            decoration: InputDecoration(
                              labelText: 'settings_scale_plu_digits_label'.tr,
                            ),
                            items: const [4, 5, 6]
                                .map(
                                  (digits) => DropdownMenuItem(
                                    value: digits,
                                    child: Text('$digits'),
                                  ),
                                )
                                .toList(growable: false),
                            onChanged: (value) {
                              if (value != null) {
                                controller.scaleLabelPluDigits.value = value;
                              }
                            },
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Obx(
                    () => Text(
                      'settings_scale_example'.trParams({
                        'plu': '${controller.scaleLabelPluDigits.value}',
                      }),
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  // ลูกหนี้ขายเชื่อ: ดอกเบี้ยผิดนัด + สถานะการส่งอีเมล (tickets 21, 23)
                  SectionHeader(
                    title: 'settings_receivable_title'.tr,
                    subtitle: 'settings_receivable_subtitle'.tr,
                  ),
                  const SizedBox(height: 16),
                  _FieldPair(
                    children: [
                      Expanded(
                        child: TextField(
                          key: const ValueKey('settings-late-fee-rate'),
                          controller: controller.lateFeeRateController,
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                          inputFormatters: [
                            FilteringTextInputFormatter.allow(
                              RegExp(r'[0-9.]'),
                            ),
                          ],
                          decoration: InputDecoration(
                            labelText: 'settings_late_fee_rate_label'.tr,
                            suffixText: 'settings_late_fee_rate_suffix'.tr,
                            helperText: 'settings_late_fee_rate_helper'.tr,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextField(
                          controller: controller.lateFeeGraceController,
                          keyboardType: TextInputType.number,
                          inputFormatters: [
                            FilteringTextInputFormatter.digitsOnly,
                          ],
                          decoration: InputDecoration(
                            labelText: 'settings_late_fee_grace_label'.tr,
                            suffixText: 'settings_late_fee_grace_suffix'.tr,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Obx(
                    () => Text(
                      controller.settings.value.emailEnabled
                          ? 'settings_email_enabled'.tr
                          : 'settings_email_disabled'.tr,
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  SectionHeader(
                    title: 'settings_loyalty_title'.tr,
                    subtitle: 'settings_loyalty_subtitle'.tr,
                  ),
                  const SizedBox(height: 16),
                  _FieldPair(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: controller.pointsEarnRateController,
                          keyboardType: TextInputType.number,
                          inputFormatters: [
                            FilteringTextInputFormatter.digitsOnly,
                          ],
                          decoration: InputDecoration(
                            labelText: 'settings_points_earn_rate_label'.tr,
                            suffixText: 'settings_points_baht_per_point'.tr,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextField(
                          controller: controller.pointsRedeemValueController,
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                          decoration: InputDecoration(
                            labelText: 'settings_points_redeem_value_label'.tr,
                            suffixText: 'settings_points_baht_per_point'.tr,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Obx(
                    () => FilledButton(
                      onPressed: controller.isSaving.value
                          ? null
                          : controller.save,
                      child: controller.isSaving.value
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: AppColors.surface,
                              ),
                            )
                          : Text('settings_save_button'.tr),
                    ),
                  ),
                ],
              ),
            ),
          ),
          // การเชื่อมต่อ (เซิร์ฟเวอร์ร้าน + PaynEat ERP) — admin เท่านั้น (ticket 25)
          if (Get.find<SessionService>().currentUser?.role ==
              UserRole.admin) ...[
            const SizedBox(height: 12),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 620),
              child: const ErpConnectionCard(),
            ),
          ],
          const SizedBox(height: 12),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 620),
            child: const _LanguageCard(),
          ),
          const SizedBox(height: 12),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 620),
            child: const _PrinterSettingsCard(),
          ),
          const SizedBox(height: 12),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 620),
            child: AppCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SectionHeader(title: 'settings_about_title'.tr),
                  const SizedBox(height: 12),
                  _InfoRow(
                    label: 'settings_about_app_label'.tr,
                    value: AppConfig.appName,
                  ),
                  _InfoRow(
                    label: 'settings_about_version_label'.tr,
                    value: '1.0.0',
                  ),
                  _InfoRow(
                    label: 'settings_about_server_label'.tr,
                    value: AppConfig.baseUrl,
                  ),
                ],
              ),
            ),
          ),
        ],
      );
    });
  }
}

/// สลับภาษาไทย/อังกฤษของทั้งแอป
class _LanguageCard extends StatefulWidget {
  const _LanguageCard();

  @override
  State<_LanguageCard> createState() => _LanguageCardState();
}

class _LanguageCardState extends State<_LanguageCard> {
  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SectionHeader(
            title: 'settings_language_title'.tr,
            subtitle: 'settings_language_subtitle'.tr,
          ),
          const SizedBox(height: 16),
          SegmentedButton<String>(
            // ป้ายแต่ละภาษาเขียนด้วยภาษานั้นเอง คนที่เปิดแอปมาเจอภาษาที่อ่านไม่ออก
            // จะได้หาภาษาตัวเองเจอโดยไม่ต้องเดา
            segments: [
              ButtonSegment(
                value: 'th',
                label: Text('settings_language_th'.tr),
              ),
              ButtonSegment(
                value: 'en',
                label: Text('settings_language_en'.tr),
              ),
              ButtonSegment(
                value: 'ko',
                label: Text('settings_language_ko'.tr),
              ),
            ],
            selected: {LocaleService.languageCode},
            showSelectedIcon: false,
            onSelectionChanged: (selection) async {
              await LocaleService.change(
                LocaleService.localeOf(selection.first),
              );
              if (mounted) setState(() {});
            },
          ),
        ],
      ),
    );
  }
}

/// ตั้งค่าเครื่องพิมพ์ใบเสร็จของเครื่องนี้ (ไม่ผูกกับร้าน — เก็บในเครื่องเท่านั้น)
class _PrinterSettingsCard extends GetView<PrinterSettingsController> {
  const _PrinterSettingsCard();

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SectionHeader(
            title: 'settings_printer_title'.tr,
            subtitle: 'settings_printer_subtitle'.tr,
          ),
          const SizedBox(height: 16),
          Obx(
            () => SwitchListTile(
              value: controller.enabled.value,
              onChanged: (value) => controller.enabled.value = value,
              title: Text('settings_printer_enable_title'.tr),
              subtitle: Text('settings_printer_enable_subtitle'.tr),
              contentPadding: EdgeInsets.zero,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                flex: 2,
                child: TextField(
                  controller: controller.ipController,
                  decoration: InputDecoration(
                    labelText: 'settings_printer_ip_label'.tr,
                    hintText: 'settings_printer_ip_hint'.tr,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextField(
                  controller: controller.portController,
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  decoration: InputDecoration(
                    labelText: 'settings_printer_port_label'.tr,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Obx(
            () => SegmentedButton<int>(
              segments: [
                ButtonSegment(
                  value: 58,
                  label: Text('settings_printer_paper_58mm'.tr),
                ),
                ButtonSegment(
                  value: 80,
                  label: Text('settings_printer_paper_80mm'.tr),
                ),
              ],
              selected: {controller.paperWidthMm.value},
              onSelectionChanged: (selection) =>
                  controller.paperWidthMm.value = selection.first,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: Obx(
                  () => OutlinedButton(
                    onPressed: controller.isTesting.value
                        ? null
                        : controller.testPrint,
                    child: controller.isTesting.value
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : Text('settings_printer_test_button'.tr),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Obx(
                  () => FilledButton(
                    onPressed: controller.isSaving.value
                        ? null
                        : controller.save,
                    child: controller.isSaving.value
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: AppColors.surface,
                            ),
                          )
                        : Text('common_save'.tr),
                  ),
                ),
              ),
            ],
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
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Text(
            label,
            style: TextStyle(fontSize: 13.5, color: AppColors.textSecondary),
          ),
          const Spacer(),
          Flexible(
            child: Text(
              value,
              style: const TextStyle(
                fontSize: 13.5,
                fontWeight: FontWeight.w600,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}

/// ช่องกรอกสองช่องคู่กัน — จอกว้างวางข้างกัน จอแคบกว่า 560px เรียงลงมา
/// (วางคู่บนมือถือแล้วป้ายถูกตัด "Late-payment intere…" / "Baht spent per 1 poi…" ทุกภาษา)
/// รับ children แบบเดียวกับ Row เดิม (Expanded + SizedBox + Expanded) จะได้ไม่ต้องรื้อโค้ดช่อง
class _FieldPair extends StatelessWidget {
  const _FieldPair({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth >= 560) {
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: children,
          );
        }
        final fields = children
            .map((child) => child is Expanded ? child.child : null)
            .whereType<Widget>()
            .toList(growable: false);
        return Column(
          children: [
            for (var i = 0; i < fields.length; i++) ...[
              if (i > 0) const SizedBox(height: 14),
              fields[i],
            ],
          ],
        );
      },
    );
  }
}
