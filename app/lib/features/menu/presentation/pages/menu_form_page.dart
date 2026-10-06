// Copyright 2026 Suruch Chakrapeesirisuk
// SPDX-License-Identifier: Apache-2.0

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:image_picker/image_picker.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../core/widgets/app_card.dart';
import '../../../../core/widgets/app_dialogs.dart';
import '../../../ingredient/domain/entities/ingredient.dart';
import '../../../ingredient/domain/usecases/ingredient_usecases.dart';
import '../../domain/entities/menu_item_payload.dart';
import '../../domain/entities/menu_item.dart';
import '../../domain/entities/menu_option.dart';
import '../controllers/menu_management_controller.dart';
import '../widgets/menu_image_picker.dart';
import '../widgets/menu_item_thumbnail.dart';

/// ฟอร์มเพิ่ม/แก้ไขเมนู พร้อมตัวจัดการกลุ่มตัวเลือก
class MenuFormPage extends StatefulWidget {
  const MenuFormPage({super.key});

  @override
  State<MenuFormPage> createState() => _MenuFormPageState();
}

class _MenuFormPageState extends State<MenuFormPage> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _nameEnController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _priceController = TextEditingController();
  final _prepController = TextEditingController(text: '10');
  final _barcodeController = TextEditingController();
  final _pluController = TextEditingController();

  final MenuManagementController _controller =
      Get.find<MenuManagementController>();

  MenuItem? _editing;
  int? _categoryId;

  /// สถานีครัวของจานนี้ (ticket 34) — null = "ตามหมวดหมู่" ซึ่งเป็นค่าปกติของเมนูส่วนใหญ่
  int? _stationId;
  bool _isAvailable = true;
  bool _isRecommended = false;

  /// ขายตามน้ำหนัก — ราคาในฟอร์มกลายเป็นราคาต่อกิโลกรัม (ดู docs/tickets/18-sell-by-weight.md)
  bool _soldByWeight = false;
  final List<MenuOptionGroup> _optionGroups = [];
  final List<MenuItemIngredientUsage> _ingredientLinks = [];

  bool _loadingIngredients = true;
  List<Ingredient> _availableIngredients = [];

  /// เก็บเป็น data URL (base64) ตอนเลือกรูปใหม่ หรือ URL เดิมจากเซิร์ฟเวอร์
  /// ค่าเป็น `''` หมายถึง "ผู้ใช้ตั้งใจลบรูป" (ต้องส่งค่านี้จริงไปให้ backend เพราะ
  /// `MenuItemPayload.toJson` จะไม่ส่ง key นี้เลยถ้าเป็น null — ดู menu_item_payload.dart)
  String? _imageUrl;

  bool get _hasImage => _imageUrl != null && _imageUrl!.isNotEmpty;

  static const _maxImageBytes = 1600 * 1024;

  @override
  void initState() {
    super.initState();
    final args = Get.arguments;
    _editing = args is Map ? args['item'] as MenuItem? : null;

    final item = _editing;
    if (item != null) {
      _nameController.text = item.name;
      _nameEnController.text = item.nameEn ?? '';
      _descriptionController.text = item.description ?? '';
      _priceController.text = item.price.toStringAsFixed(0);
      _prepController.text = '${item.prepMinutes}';
      _categoryId = item.categoryId;
      _stationId = item.stationId;
      _isAvailable = item.isAvailable;
      _isRecommended = item.isRecommended;
      _soldByWeight = item.soldByWeight;
      _barcodeController.text = item.barcode ?? '';
      _pluController.text = item.scalePlu ?? '';
      _optionGroups.addAll(item.optionGroups);
      _imageUrl = (item.imageUrl?.isNotEmpty ?? false) ? item.imageUrl : null;
      _ingredientLinks.addAll(item.ingredients);
    } else if (_controller.categories.isNotEmpty) {
      _categoryId = _controller.categories.first.id;
    }

    _loadIngredientOptions();
  }

  Future<void> _loadIngredientOptions() async {
    final result = await Get.find<GetIngredientsUseCase>()(false);
    setState(() {
      _availableIngredients = result.dataOrNull ?? const [];
      _loadingIngredients = false;
    });
  }

  Future<void> _pickImage() async {
    // เว็บมีแค่ช่องทางเดียว (file input ของเบราว์เซอร์) จึงไม่ต้องถามก่อน
    // ส่วนมือถือ/แท็บเล็ตถามก่อนว่าจะถ่ายใหม่หรือเลือกจากคลัง — ในร้านจริง
    // การเดินไปถ่ายจานที่เพิ่งทำเสร็จเป็นวิธีที่เร็วที่สุด
    final source = kIsWeb ? ImageSource.gallery : await _askImageSource();
    if (source == null) return;

    try {
      final picked = await pickMenuImage(source);
      if (picked == null) return;
      if (picked.sizeBytes > _maxImageBytes) {
        AppDialogs.error('menu_form_photo_too_large'.tr);
        return;
      }
      setState(() => _imageUrl = picked.dataUrl);
    } catch (_) {
      AppDialogs.error('menu_form_photo_pick_failed'.tr);
    }
  }

  Future<ImageSource?> _askImageSource() => Get.bottomSheet<ImageSource>(
    SafeArea(
      child: Container(
        decoration: const BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_camera_rounded),
              title: Text('menu_form_photo_source_camera'.tr),
              onTap: () => Get.back(result: ImageSource.camera),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_rounded),
              title: Text('menu_form_photo_source_gallery'.tr),
              onTap: () => Get.back(result: ImageSource.gallery),
            ),
          ],
        ),
      ),
    ),
  );

  void _removeImage() => setState(() => _imageUrl = '');

  @override
  void dispose() {
    _nameController.dispose();
    _nameEnController.dispose();
    _descriptionController.dispose();
    _priceController.dispose();
    _prepController.dispose();
    _barcodeController.dispose();
    _pluController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false) || _categoryId == null) {
      return;
    }

    await _controller.save(
      id: _editing?.id,
      payload: MenuItemPayload(
        name: _nameController.text.trim(),
        nameEn: _nameEnController.text.trim(),
        description: _descriptionController.text.trim(),
        categoryId: _categoryId!,
        price: double.parse(_priceController.text.trim()),
        prepMinutes: int.tryParse(_prepController.text.trim()) ?? 10,
        imageUrl: _imageUrl,
        isAvailable: _isAvailable,
        isRecommended: _isRecommended,
        optionGroups: _optionGroups,
        ingredients: _ingredientLinks,
        soldByWeight: _soldByWeight,
        // ส่ง '' เสมอเมื่อช่องว่าง = ตั้งใจล้างรหัสเดิม — PLU ใช้ได้เฉพาะเมนูขายตามน้ำหนัก
        barcode: _barcodeController.text.trim(),
        scalePlu: _soldByWeight ? _pluController.text.trim() : '',
        stationId: _stationId,
      ),
    );
  }

  /// สถานีครัวของจานนี้ — ตัวเลือกแรกคือ "ตามหมวดหมู่" (ค่า null) พร้อมบอกว่าหมวดหมู่ที่เลือกอยู่
  /// ส่งจานไปสถานีไหน ไม่มี validator เพราะ null เป็นค่าที่ถูกต้อง (ticket 34)
  Widget _stationField() {
    final stations = _controller.stations;
    final category = _controller.categories.firstWhereOrNull(
      (row) => row.id == _categoryId,
    );
    final inherited = stations.firstWhereOrNull(
      (row) => row.id == category?.stationId,
    );
    final fallback = stations.firstWhereOrNull((row) => row.isDefault);
    final resolved = inherited ?? fallback;

    return DropdownButtonFormField<int?>(
      key: const ValueKey('menu_form_station'),
      initialValue: stations.any((row) => row.id == _stationId)
          ? _stationId
          : null,
      decoration: InputDecoration(labelText: 'menu_form_station_label'.tr),
      items: [
        DropdownMenuItem<int?>(
          value: null,
          child: Text(
            'menu_form_station_inherit'.trParams({
              'station': resolved?.displayName ?? 'menu_station_none'.tr,
            }),
          ),
        ),
        ...stations.map(
          (station) => DropdownMenuItem<int?>(
            value: station.id,
            child: Text(station.labelWithIcon),
          ),
        ),
      ],
      onChanged: (value) => setState(() => _stationId = value),
    );
  }

  // เครื่องสแกนบาร์โค้ด USB/บลูทูธพิมพ์รหัสลงช่องนี้ได้เลยตอนตั้งค่าสินค้า
  // (ดู docs/tickets/19-barcode-scale.md)
  Widget _barcodeField() => TextFormField(
    controller: _barcodeController,
    decoration: InputDecoration(
      labelText: 'menu_form_barcode_label'.tr,
      helperText: 'menu_form_barcode_helper'.tr,
      helperMaxLines: 2,
      prefixIcon: const Icon(Icons.qr_code_scanner_rounded),
    ),
    validator: (value) {
      final text = value?.trim() ?? '';
      if (text.isEmpty) return null;
      return RegExp(r'^[0-9A-Za-z-]{1,32}$').hasMatch(text)
          ? null
          : 'menu_form_barcode_invalid'.tr;
    },
  );

  Widget _pluField() => TextFormField(
    controller: _pluController,
    keyboardType: TextInputType.number,
    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
    decoration: InputDecoration(
      labelText: 'menu_form_scale_plu_label'.tr,
      helperText: 'menu_form_scale_plu_helper'.tr,
      helperMaxLines: 2,
    ),
    validator: (value) {
      final text = value?.trim() ?? '';
      if (text.isEmpty) return null;
      return text.length <= 6 ? null : 'menu_form_scale_plu_invalid'.tr;
    },
  );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          _editing == null
              ? 'menu_form_add_title'.tr
              : 'menu_form_edit_title'.tr,
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
                  SectionHeader(title: 'menu_form_info_section'.tr),
                  const SizedBox(height: 16),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: SizedBox(
                          width: 88,
                          height: 88,
                          child: MenuItemThumbnail(
                            imageUrl: _imageUrl,
                            placeholder: Container(
                              color: AppColors.surfaceAlt,
                              alignment: Alignment.center,
                              child: Icon(
                                Icons.image_outlined,
                                color: AppColors.textDisabled,
                                size: 28,
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'menu_form_photo_label'.tr,
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Wrap(
                              spacing: 10,
                              runSpacing: 6,
                              children: [
                                OutlinedButton.icon(
                                  onPressed: _pickImage,
                                  icon: Icon(
                                    kIsWeb
                                        ? Icons.upload_rounded
                                        : Icons.add_a_photo_rounded,
                                    size: 17,
                                  ),
                                  label: Text(
                                    _hasImage
                                        ? 'menu_form_photo_change'.tr
                                        : 'menu_form_photo_pick'.tr,
                                  ),
                                ),
                                if (_hasImage)
                                  TextButton(
                                    onPressed: _removeImage,
                                    style: TextButton.styleFrom(
                                      foregroundColor: AppColors.dangerInk,
                                    ),
                                    child: Text('menu_form_photo_remove'.tr),
                                  ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'menu_form_photo_hint'.tr,
                              style: TextStyle(
                                fontSize: 11.5,
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),
                  TextFormField(
                    controller: _nameController,
                    decoration: InputDecoration(
                      labelText: 'menu_form_name_label'.tr,
                    ),
                    validator: (value) =>
                        (value == null || value.trim().isEmpty)
                        ? 'menu_form_name_required'.tr
                        : null,
                  ),
                  const SizedBox(height: 14),
                  TextFormField(
                    controller: _nameEnController,
                    decoration: InputDecoration(
                      labelText: 'menu_form_name_en_label'.tr,
                    ),
                  ),
                  const SizedBox(height: 14),
                  Obx(
                    () => DropdownButtonFormField<int>(
                      initialValue: _categoryId,
                      decoration: InputDecoration(
                        labelText: 'menu_form_category_label'.tr,
                      ),
                      items: _controller.categories
                          .map(
                            (category) => DropdownMenuItem(
                              value: category.id,
                              child: Text(
                                '${category.icon ?? ''} ${category.name}'
                                    .trim(),
                              ),
                            ),
                          )
                          .toList(growable: false),
                      onChanged: (value) => setState(() => _categoryId = value),
                      validator: (value) => value == null
                          ? 'menu_form_category_required'.tr
                          : null,
                    ),
                  ),
                  const SizedBox(height: 14),
                  Obx(() => _stationField()),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: _priceController,
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                          inputFormatters: [
                            FilteringTextInputFormatter.allow(
                              RegExp(r'[0-9.]'),
                            ),
                          ],
                          decoration: InputDecoration(
                            labelText: _soldByWeight
                                ? 'menu_form_price_per_kg_label'.tr
                                : 'menu_form_price_label'.tr,
                            suffixText: _soldByWeight
                                ? 'common_baht_per_kg'.tr
                                : 'common_baht'.tr,
                          ),
                          validator: (value) {
                            final price = double.tryParse(value?.trim() ?? '');
                            if (price == null || price < 0) {
                              return 'menu_form_price_invalid'.tr;
                            }
                            return null;
                          },
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextFormField(
                          controller: _prepController,
                          keyboardType: TextInputType.number,
                          inputFormatters: [
                            FilteringTextInputFormatter.digitsOnly,
                          ],
                          decoration: InputDecoration(
                            labelText: 'menu_form_prep_time_label'.tr,
                            suffixText: 'menu_form_minutes_suffix'.tr,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  TextFormField(
                    controller: _descriptionController,
                    maxLines: 2,
                    decoration: InputDecoration(
                      labelText: 'menu_form_description_label'.tr,
                    ),
                  ),
                  const SizedBox(height: 6),
                  SwitchListTile(
                    key: const ValueKey('menu-form-sold-by-weight'),
                    value: _soldByWeight,
                    onChanged: (value) => setState(() => _soldByWeight = value),
                    title: Text('menu_form_sold_by_weight_label'.tr),
                    subtitle: Text('menu_form_sold_by_weight_subtitle'.tr),
                    contentPadding: EdgeInsets.zero,
                  ),
                  // จอแคบ (มือถือ) เรียงบาร์โค้ด/PLU ลงมาทีละช่อง — วางคู่กันแล้วป้ายและคำอธิบาย
                  // ถูกตัดเป็น "Barcode (..." / "Scan or type the ..." ทุกภาษา
                  LayoutBuilder(
                    builder: (context, constraints) {
                      final barcode = _barcodeField();
                      if (!_soldByWeight) return barcode;
                      if (constraints.maxWidth < 560) {
                        return Column(
                          children: [
                            barcode,
                            const SizedBox(height: 14),
                            _pluField(),
                          ],
                        );
                      }
                      return Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(child: barcode),
                          const SizedBox(width: 12),
                          Expanded(child: _pluField()),
                        ],
                      );
                    },
                  ),
                  const SizedBox(height: 6),
                  SwitchListTile(
                    value: _isAvailable,
                    onChanged: (value) => setState(() => _isAvailable = value),
                    title: Text('menu_form_available_label'.tr),
                    contentPadding: EdgeInsets.zero,
                  ),
                  SwitchListTile(
                    value: _isRecommended,
                    onChanged: (value) =>
                        setState(() => _isRecommended = value),
                    title: Text('menu_form_recommended_label'.tr),
                    subtitle: Text('menu_form_recommended_subtitle'.tr),
                    contentPadding: EdgeInsets.zero,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            AppCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  SectionHeader(
                    title: 'menu_form_option_groups_section'.tr,
                    subtitle: 'menu_form_option_groups_hint'.tr,
                    trailing: TextButton.icon(
                      onPressed: _addGroup,
                      icon: const Icon(Icons.add_rounded, size: 18),
                      label: Text('menu_form_add_group_button'.tr),
                    ),
                  ),
                  if (_optionGroups.isEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 18),
                      child: Center(
                        child: Text(
                          'menu_form_no_option_groups'.tr,
                          style: TextStyle(
                            color: AppColors.textSecondary,
                            fontSize: 13,
                          ),
                        ),
                      ),
                    )
                  else
                    for (final entry in _optionGroups.asMap().entries)
                      _OptionGroupRow(
                        group: entry.value,
                        onRemove: () =>
                            setState(() => _optionGroups.removeAt(entry.key)),
                      ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            AppCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  SectionHeader(
                    title: 'menu_form_ingredients_section'.tr,
                    subtitle: 'menu_form_ingredients_hint'.tr,
                    trailing: TextButton.icon(
                      onPressed: _loadingIngredients
                          ? null
                          : _addIngredientLink,
                      icon: const Icon(Icons.add_rounded, size: 18),
                      label: Text('menu_form_add_ingredient_button'.tr),
                    ),
                  ),
                  if (_loadingIngredients)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 18),
                      child: Center(
                        child: SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      ),
                    )
                  else if (_ingredientLinks.isEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 18),
                      child: Center(
                        child: Text(
                          'menu_form_no_ingredients'.tr,
                          style: TextStyle(
                            color: AppColors.textDisabled,
                            fontSize: 13,
                          ),
                        ),
                      ),
                    )
                  else
                    for (final entry in _ingredientLinks.asMap().entries)
                      _IngredientLinkRow(
                        perKg: _soldByWeight,
                        link: entry.value,
                        onRemove: () => setState(
                          () => _ingredientLinks.removeAt(entry.key),
                        ),
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
                          color: AppColors.surface,
                        ),
                      )
                    : Text(
                        _editing == null
                            ? 'menu_add_item_button'.tr
                            : 'menu_form_submit_edit'.tr,
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _addGroup() async {
    final result = await Get.dialog<MenuOptionGroup>(
      const _OptionGroupDialog(),
    );
    if (result != null) setState(() => _optionGroups.add(result));
  }

  Future<void> _addIngredientLink() async {
    final linkedIds = _ingredientLinks.map((link) => link.ingredientId).toSet();
    final choices = _availableIngredients
        .where((ingredient) => !linkedIds.contains(ingredient.id))
        .toList(growable: false);
    if (choices.isEmpty) {
      Get.snackbar(
        'common_info_title'.tr,
        'menu_form_no_more_ingredients'.tr,
        snackPosition: SnackPosition.TOP,
      );
      return;
    }

    final result = await Get.dialog<MenuItemIngredientUsage>(
      _IngredientLinkDialog(choices: choices, perKg: _soldByWeight),
    );
    if (result != null) setState(() => _ingredientLinks.add(result));
  }
}

class _OptionGroupRow extends StatelessWidget {
  const _OptionGroupRow({required this.group, required this.onRemove});

  final MenuOptionGroup group;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(top: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surfaceAlt,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                group.name,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                group.isRequired
                    ? 'menu_option_required_badge'.tr
                    : 'menu_option_max_select_badge'.trParams({
                        'count': '${group.maxSelect}',
                      }),
                style: TextStyle(
                  fontSize: 11.5,
                  color: AppColors.textSecondary,
                ),
              ),
              const Spacer(),
              IconButton(
                tooltip: 'common_remove'.tr,
                onPressed: onRemove,
                icon: const Icon(Icons.close_rounded, size: 17),
                visualDensity: VisualDensity.compact,
                color: AppColors.dangerInk,
              ),
            ],
          ),
          const SizedBox(height: 6),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: group.options
                .map(
                  (option) => Chip(
                    label: Text(
                      option.priceDelta > 0
                          ? '${option.name} +${option.priceDelta.toStringAsFixed(0)}'
                          : option.name,
                      style: const TextStyle(fontSize: 12),
                    ),
                    backgroundColor: AppColors.surface,
                    visualDensity: VisualDensity.compact,
                  ),
                )
                .toList(growable: false),
          ),
        ],
      ),
    );
  }
}

/// กล่องสร้างกลุ่มตัวเลือกใหม่ พร้อมใส่ตัวเลือกย่อยได้หลายอัน
class _OptionGroupDialog extends StatefulWidget {
  const _OptionGroupDialog();

  @override
  State<_OptionGroupDialog> createState() => _OptionGroupDialogState();
}

class _OptionGroupDialogState extends State<_OptionGroupDialog> {
  final _nameController = TextEditingController();
  final _optionNameController = TextEditingController();
  final _optionPriceController = TextEditingController();
  final List<MenuOption> _options = [];
  bool _isRequired = false;
  int _maxSelect = 1;

  @override
  void dispose() {
    _nameController.dispose();
    _optionNameController.dispose();
    _optionPriceController.dispose();
    super.dispose();
  }

  void _addOption() {
    final name = _optionNameController.text.trim();
    if (name.isEmpty) return;

    setState(() {
      _options.add(
        MenuOption(
          id:
              -(_options.length +
                  1), // id ชั่วคราวฝั่ง client — backend จะออก id จริงให้
          name: name,
          priceDelta: double.tryParse(_optionPriceController.text.trim()) ?? 0,
        ),
      );
      _optionNameController.clear();
      _optionPriceController.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('menu_option_group_dialog_title'.tr),
      content: SizedBox(
        width: 380,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextField(
                controller: _nameController,
                autofocus: true,
                // rebuild เพื่อให้ปุ่ม "เพิ่มกลุ่ม" เปิด-ปิดตามความถูกต้องของฟอร์มทันที
                onChanged: (_) => setState(() {}),
                decoration: InputDecoration(
                  labelText: 'menu_option_group_name_label'.tr,
                  hintText: 'menu_option_group_name_hint'.tr,
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: CheckboxListTile(
                      value: _isRequired,
                      onChanged: (value) =>
                          setState(() => _isRequired = value ?? false),
                      title: Text(
                        'menu_option_required_badge'.tr,
                        style: const TextStyle(fontSize: 13.5),
                      ),
                      contentPadding: EdgeInsets.zero,
                      controlAffinity: ListTileControlAffinity.leading,
                      dense: true,
                    ),
                  ),
                  SizedBox(
                    width: 110,
                    child: DropdownButtonFormField<int>(
                      initialValue: _maxSelect,
                      decoration: InputDecoration(
                        labelText: 'menu_option_max_select_label'.tr,
                        isDense: true,
                      ),
                      items: [1, 2, 3, 4, 5]
                          .map(
                            (n) =>
                                DropdownMenuItem(value: n, child: Text('$n')),
                          )
                          .toList(growable: false),
                      onChanged: (value) =>
                          setState(() => _maxSelect = value ?? 1),
                    ),
                  ),
                ],
              ),
              const Divider(height: 24),
              Row(
                children: [
                  Expanded(
                    flex: 3,
                    child: TextField(
                      controller: _optionNameController,
                      decoration: InputDecoration(
                        labelText: 'menu_option_name_label'.tr,
                        isDense: true,
                      ),
                      onSubmitted: (_) => _addOption(),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextField(
                      controller: _optionPriceController,
                      keyboardType: TextInputType.number,
                      inputFormatters: [
                        FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
                      ],
                      decoration: InputDecoration(
                        labelText: 'menu_option_price_delta_label'.tr,
                        isDense: true,
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: 'common_add'.tr,
                    onPressed: _addOption,
                    icon: Icon(
                      Icons.add_circle_rounded,
                      color: AppColors.brandInk,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: _options
                    .map(
                      (option) => Chip(
                        label: Text(
                          option.priceDelta > 0
                              ? '${option.name} +${option.priceDelta.toStringAsFixed(0)}'
                              : option.name,
                        ),
                        onDeleted: () =>
                            setState(() => _options.remove(option)),
                      ),
                    )
                    .toList(growable: false),
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
          onPressed: _nameController.text.trim().isEmpty || _options.isEmpty
              ? null
              : () => Get.back(
                  result: MenuOptionGroup(
                    id: -1,
                    name: _nameController.text.trim(),
                    minSelect: _isRequired ? 1 : 0,
                    maxSelect: _maxSelect,
                    isRequired: _isRequired,
                    options: _options,
                  ),
                ),
          child: Text('menu_form_add_group_button'.tr),
        ),
      ],
    );
  }
}

class _IngredientLinkRow extends StatelessWidget {
  const _IngredientLinkRow({
    required this.link,
    required this.onRemove,
    this.perKg = false,
  });

  /// เมนูขายตามน้ำหนัก ปริมาณวัตถุดิบคิดต่อ 1 กก. ที่ขาย ไม่ใช่ "ต่อที่/ต่อจาน"
  final bool perKg;

  final MenuItemIngredientUsage link;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(top: 10),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.surfaceAlt,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              link.ingredientName ?? '#${link.ingredientId}',
              style: const TextStyle(
                fontSize: 13.5,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          Text(
            (perKg
                    ? 'menu_form_ingredient_qty_summary_kg'
                    : 'menu_form_ingredient_qty_summary')
                .trParams({
                  'qty': link.qtyPerUnit.toStringAsFixed(
                    link.qtyPerUnit == link.qtyPerUnit.roundToDouble() ? 0 : 1,
                  ),
                  'unit': link.unit ?? '',
                }),
            style: TextStyle(fontSize: 12.5, color: AppColors.textSecondary),
          ),
          IconButton(
            tooltip: 'common_remove'.tr,
            onPressed: onRemove,
            icon: const Icon(Icons.close_rounded, size: 17),
            visualDensity: VisualDensity.compact,
            color: AppColors.dangerInk,
          ),
        ],
      ),
    );
  }
}

/// กล่องเลือกวัตถุดิบที่เมนูนี้ใช้ + ปริมาณต่อ 1 ที่ (denormalize ชื่อ/หน่วยจากวัตถุดิบที่เลือก)
class _IngredientLinkDialog extends StatefulWidget {
  const _IngredientLinkDialog({required this.choices, this.perKg = false});

  final bool perKg;

  final List<Ingredient> choices;

  @override
  State<_IngredientLinkDialog> createState() => _IngredientLinkDialogState();
}

class _IngredientLinkDialogState extends State<_IngredientLinkDialog> {
  late Ingredient _selected = widget.choices.first;
  final _qtyController = TextEditingController(text: '1');

  @override
  void dispose() {
    _qtyController.dispose();
    super.dispose();
  }

  double get _qty => double.tryParse(_qtyController.text.trim()) ?? 0;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('menu_form_add_ingredient_button'.tr),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          DropdownButtonFormField<Ingredient>(
            initialValue: _selected,
            decoration: InputDecoration(
              labelText: 'menu_form_ingredient_select_label'.tr,
            ),
            items: widget.choices
                .map(
                  (ingredient) => DropdownMenuItem(
                    value: ingredient,
                    child: Text(ingredient.name),
                  ),
                )
                .toList(growable: false),
            onChanged: (value) =>
                setState(() => _selected = value ?? _selected),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _qtyController,
            autofocus: true,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
            ],
            decoration: InputDecoration(
              labelText:
                  (widget.perKg
                          ? 'menu_form_ingredient_qty_label_kg'
                          : 'menu_form_ingredient_qty_label')
                      .tr,
              suffixText: _selected.unit,
            ),
            onChanged: (_) => setState(() {}),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Get.back<void>(),
          child: Text('common_cancel'.tr),
        ),
        FilledButton(
          onPressed: _qty > 0
              ? () => Get.back(
                  result: MenuItemIngredientUsage(
                    ingredientId: _selected.id,
                    qtyPerUnit: _qty,
                    ingredientName: _selected.name,
                    unit: _selected.unit,
                  ),
                )
              : null,
          child: Text('menu_form_add_ingredient_button'.tr),
        ),
      ],
    );
  }
}
