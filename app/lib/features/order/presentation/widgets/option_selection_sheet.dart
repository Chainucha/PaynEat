// Copyright 2026 Suruch Chakrapeesirisuk
// SPDX-License-Identifier: Apache-2.0

import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/widgets/quantity_stepper.dart';
import '../../../menu/domain/entities/menu_item.dart';
import '../../../menu/domain/entities/menu_option.dart';

/// ผลลัพธ์ที่ได้จากแผ่นเลือกตัวเลือก
class OptionSelectionResult {
  const OptionSelectionResult({
    required this.quantity,
    required this.options,
    this.note,
  });

  final int quantity;
  final List<MenuOption> options;
  final String? note;
}

/// แผ่นเลือกตัวเลือกเสริมของเมนู (ระดับความเผ็ด / เพิ่มไข่ดาว / โน้ตถึงครัว)
///
/// บังคับกฎเดียวกับ backend: กลุ่มที่ required ต้องเลือก และเลือกได้ไม่เกิน maxSelect
class OptionSelectionSheet extends StatefulWidget {
  const OptionSelectionSheet({
    super.key,
    required this.item,
    this.maxQuantity = 99,
  });

  final MenuItem item;

  /// จำนวนสูงสุดที่ปุ่ม + ไปถึงได้ — พนักงานใช้ค่าเริ่มต้น หน้า QR ส่งเพดานของ QR มา (DECISIONS #99)
  final int maxQuantity;

  /// เปิดแผ่นแล้วคืนค่าที่ผู้ใช้เลือก (null = ยกเลิก)
  static Future<OptionSelectionResult?> show(
    MenuItem item, {
    int maxQuantity = 99,
  }) {
    return Get.bottomSheet<OptionSelectionResult>(
      OptionSelectionSheet(item: item, maxQuantity: maxQuantity),
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
    );
  }

  @override
  State<OptionSelectionSheet> createState() => _OptionSelectionSheetState();
}

class _OptionSelectionSheetState extends State<OptionSelectionSheet> {
  final Map<int, List<MenuOption>> _selected = {};
  final TextEditingController _noteController = TextEditingController();
  int _quantity = 1;

  @override
  void initState() {
    super.initState();
    // เลือกค่าเริ่มต้นที่ร้านตั้งไว้ให้อัตโนมัติ
    for (final group in widget.item.optionGroups) {
      _selected[group.id] = List<MenuOption>.from(group.defaults);
    }
  }

  @override
  void dispose() {
    _noteController.dispose();
    super.dispose();
  }

  List<MenuOption> get _allSelected =>
      _selected.values.expand((options) => options).toList(growable: false);

  double get _unitPrice =>
      widget.item.price +
      _allSelected.fold<double>(0, (sum, o) => sum + o.priceDelta);

  /// กลุ่มที่บังคับเลือกแต่ยังไม่ได้เลือก
  List<String> get _missingGroups => widget.item.optionGroups
      .where(
        (group) => group.isRequired && (_selected[group.id]?.isEmpty ?? true),
      )
      .map((group) => group.name)
      .toList(growable: false);

  void _toggle(MenuOptionGroup group, MenuOption option) {
    setState(() {
      final current = _selected[group.id] ?? [];
      if (group.isSingleChoice) {
        _selected[group.id] = [option];
        return;
      }
      if (current.contains(option)) {
        current.remove(option);
      } else if (current.length < group.maxSelect) {
        current.add(option);
      }
      _selected[group.id] = current;
    });
  }

  @override
  Widget build(BuildContext context) {
    final maxHeight = MediaQuery.sizeOf(context).height * 0.85;

    return Container(
      constraints: BoxConstraints(maxHeight: maxHeight),
      decoration: const BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 10),
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: AppColors.border,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 14, 20, 10),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.item.displayName,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      if (widget.item.description != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 3),
                          child: Text(
                            widget.item.description!,
                            style: TextStyle(
                              fontSize: 12.5,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                IconButton(
                  tooltip: 'common_close'.tr,
                  onPressed: () => Get.back<void>(),
                  icon: const Icon(Icons.close_rounded),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Flexible(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
              shrinkWrap: true,
              children: [
                for (final group in widget.item.optionGroups) ...[
                  Row(
                    children: [
                      Text(
                        group.name,
                        style: const TextStyle(
                          fontSize: 14.5,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(width: 8),
                      if (group.isRequired)
                        Text(
                          'order_option_required'.tr,
                          style: TextStyle(
                            fontSize: 11.5,
                            color: AppColors.dangerInk,
                          ),
                        )
                      else
                        Text(
                          'order_option_max_select'.trParams({
                            'count': '${group.maxSelect}',
                          }),
                          style: TextStyle(
                            fontSize: 11.5,
                            color: AppColors.textSecondary,
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: group.options
                        .map((option) {
                          final selected =
                              _selected[group.id]?.contains(option) ?? false;
                          return _OptionChip(
                            label: option.name,
                            priceDelta: option.priceDelta,
                            selected: selected,
                            onTap: () => _toggle(group, option),
                          );
                        })
                        .toList(growable: false),
                  ),
                  const SizedBox(height: 18),
                ],
                TextField(
                  controller: _noteController,
                  maxLines: 2,
                  decoration: InputDecoration(
                    labelText: 'order_kitchen_note_label'.tr,
                    hintText: 'order_kitchen_note_hint'.tr,
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Padding(
            padding: EdgeInsets.fromLTRB(
              20,
              12,
              20,
              12 + MediaQuery.viewInsetsOf(context).bottom,
            ),
            child: Row(
              children: [
                // สินค้าขายตามน้ำหนักไม่มีจำนวนชิ้น — เลือกตัวเลือกเสร็จแล้วไปหน้าชั่งต่อ
                if (!widget.item.soldByWeight) ...[
                  QuantityStepper(
                    value: _quantity,
                    max: widget.maxQuantity,
                    size: 38,
                    onChanged: (value) => setState(() => _quantity = value),
                  ),
                  const SizedBox(width: 14),
                ],
                Expanded(
                  child: FilledButton(
                    onPressed: _missingGroups.isEmpty
                        ? () => Get.back(
                            result: OptionSelectionResult(
                              quantity: _quantity,
                              options: _allSelected,
                              note: _noteController.text,
                            ),
                          )
                        : null,
                    child: Text(
                      _missingGroups.isEmpty
                          ? widget.item.soldByWeight
                                ? 'order_continue_to_weigh'.tr
                                : 'order_add_to_cart_button'.trParams({
                                    'price': Formatters.baht(
                                      _unitPrice * _quantity,
                                    ),
                                  })
                          : 'order_select_required_group'.trParams({
                              'group': _missingGroups.first,
                            }),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _OptionChip extends StatelessWidget {
  const _OptionChip({
    required this.label,
    required this.priceDelta,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final double priceDelta;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? AppColors.primarySoft : AppColors.surface,
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: selected ? AppColors.primary : AppColors.border,
              width: selected ? 1.5 : 1,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (selected) ...[
                Icon(
                  Icons.check_circle_rounded,
                  size: 15,
                  color: AppColors.brandInk,
                ),
                const SizedBox(width: 6),
              ],
              Text(
                label,
                style: TextStyle(
                  fontSize: 13.5,
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                  color: selected ? AppColors.brandInk : AppColors.textPrimary,
                ),
              ),
              if (priceDelta > 0) ...[
                const SizedBox(width: 6),
                Text(
                  '+${Formatters.money(priceDelta)}',
                  style: TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
