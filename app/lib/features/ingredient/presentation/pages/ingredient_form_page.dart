// Copyright 2026 Suruch Chakrapeesirisuk
// SPDX-License-Identifier: Apache-2.0

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';

import '../../../../core/widgets/app_card.dart';
import '../../../erp_connection/domain/entities/erp_connection_status.dart';
import '../../domain/entities/ingredient.dart';
import '../../domain/usecases/ingredient_usecases.dart';
import '../controllers/ingredients_controller.dart';

/// ฟอร์มเพิ่ม/แก้ไขวัตถุดิบ — ตั้งสต๊อกเริ่มต้นได้เฉพาะตอนสร้างใหม่เท่านั้น
/// (แก้ไขสต๊อกภายหลังต้องผ่านปุ่ม "ปรับสต๊อก" ในหน้ารายการ)
class IngredientFormPage extends StatefulWidget {
  const IngredientFormPage({super.key});

  @override
  State<IngredientFormPage> createState() => _IngredientFormPageState();
}

class _IngredientFormPageState extends State<IngredientFormPage> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _unitController = TextEditingController();
  final _currentStockController = TextEditingController(text: '0');
  final _lowStockThresholdController = TextEditingController(text: '0');
  final _itemCodeController = TextEditingController();

  final IngredientsController _controller = Get.find<IngredientsController>();

  Ingredient? _editing;

  @override
  void initState() {
    super.initState();
    final args = Get.arguments;
    _editing = args is Map ? args['ingredient'] as Ingredient? : null;

    final ingredient = _editing;
    if (ingredient != null) {
      _nameController.text = ingredient.name;
      _unitController.text = ingredient.unit;
      _itemCodeController.text = ingredient.itemCode ?? '';
      _lowStockThresholdController.text = ingredient.lowStockThreshold
          .toStringAsFixed(
            ingredient.lowStockThreshold ==
                    ingredient.lowStockThreshold.roundToDouble()
                ? 0
                : 1,
          );
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _unitController.dispose();
    _currentStockController.dispose();
    _lowStockThresholdController.dispose();
    _itemCodeController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    await _controller.save(
      id: _editing?.id,
      data: IngredientFormData(
        name: _nameController.text.trim(),
        unit: _unitController.text.trim(),
        currentStock: double.tryParse(_currentStockController.text.trim()) ?? 0,
        lowStockThreshold:
            double.tryParse(_lowStockThresholdController.text.trim()) ?? 0,
        itemCode: _itemCodeController.text,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          _editing == null
              ? 'ingredient_form_add_title'.tr
              : 'ingredient_form_edit_title'.tr,
        ),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            AppCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  SectionHeader(title: 'ingredient_form_info_section'.tr),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _nameController,
                    decoration: InputDecoration(
                      labelText: 'ingredient_form_name_label'.tr,
                    ),
                    validator: (value) =>
                        (value == null || value.trim().isEmpty)
                        ? 'ingredient_form_name_required'.tr
                        : null,
                  ),
                  const SizedBox(height: 14),
                  TextFormField(
                    controller: _unitController,
                    decoration: InputDecoration(
                      labelText: 'ingredient_form_unit_label'.tr,
                      hintText: 'ingredient_form_unit_hint'.tr,
                    ),
                    validator: (value) =>
                        (value == null || value.trim().isEmpty)
                        ? 'ingredient_form_unit_required'.tr
                        : null,
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      if (_editing == null)
                        Expanded(
                          child: TextFormField(
                            controller: _currentStockController,
                            keyboardType: const TextInputType.numberWithOptions(
                              decimal: true,
                            ),
                            inputFormatters: [
                              FilteringTextInputFormatter.allow(
                                RegExp(r'[0-9.]'),
                              ),
                            ],
                            decoration: InputDecoration(
                              labelText:
                                  'ingredient_form_current_stock_label'.tr,
                            ),
                          ),
                        ),
                      if (_editing == null) const SizedBox(width: 12),
                      Expanded(
                        child: TextFormField(
                          controller: _lowStockThresholdController,
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                          inputFormatters: [
                            FilteringTextInputFormatter.allow(
                              RegExp(r'[0-9.]'),
                            ),
                          ],
                          decoration: InputDecoration(
                            labelText: 'ingredient_form_threshold_label'.tr,
                          ),
                        ),
                      ),
                    ],
                  ),
                  if (_editing != null) ...[
                    const SizedBox(height: 8),
                    Text(
                      'ingredient_form_current_stock_locked_hint'.tr,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                  const SizedBox(height: 14),
                  // รหัสสินค้าใน PaynEat ERP (ticket 25) — ไม่บังคับ ร้านเดี่ยวเว้นว่างได้
                  TextFormField(
                    controller: _itemCodeController,
                    textCapitalization: TextCapitalization.characters,
                    autocorrect: false,
                    decoration: InputDecoration(
                      labelText: 'ingredient_form_item_code_label'.tr,
                      helperText: 'ingredient_form_item_code_hint'.tr,
                      helperMaxLines: 3,
                    ),
                    validator: (value) {
                      final code = value?.trim().toUpperCase() ?? '';
                      return code.isEmpty || EcosystemCode.isValid(code)
                          ? null
                          : 'ingredient_form_item_code_invalid'.tr;
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            Obx(
              () => FilledButton(
                onPressed: _controller.isSaving.value ? null : _submit,
                child: _controller.isSaving.value
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : Text(
                        _editing == null
                            ? 'ingredient_add_button'.tr
                            : 'ingredient_form_submit_edit'.tr,
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
