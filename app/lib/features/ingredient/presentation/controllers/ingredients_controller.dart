// Copyright 2026 Suruch Chakrapeesirisuk
// SPDX-License-Identifier: Apache-2.0

import 'package:get/get.dart';

import '../../../../app/routes/app_routes.dart';
import '../../../../core/usecases/result.dart';
import '../../../../core/widgets/app_dialogs.dart';
import '../../../erp_connection/domain/entities/erp_connection_status.dart';
import '../../../erp_connection/domain/usecases/erp_connection_usecases.dart';
import '../../domain/entities/ingredient.dart';
import '../../domain/usecases/ingredient_usecases.dart';

/// จัดการวัตถุดิบ/สต๊อก (สำหรับผู้จัดการ/แอดมิน) — เพิ่ม แก้ไข ปรับสต๊อก และลบ
/// (ดู docs/tickets/06-inventory-stock.md)
///
/// เครื่องที่เชื่อมต่อ PaynEat ERP อยู่ ([managedByErp]) หน้านี้เป็นอ่านอย่างเดียว: วัตถุดิบจัดการใน ERP
/// และยอดคงเหลือเป็นของ ERP (ticket 25) — backend ปฏิเสธการแก้ด้วย 409 อยู่แล้ว หน้าจอแค่ไม่ชวนให้ลอง
class IngredientsController extends GetxController {
  IngredientsController({
    required GetIngredientsUseCase getIngredients,
    required SaveIngredientUseCase saveIngredient,
    required AdjustStockUseCase adjustStock,
    required DeleteIngredientUseCase deleteIngredient,
    required GetErpModeUseCase getErpMode,
  }) : _getIngredients = getIngredients,
       _saveIngredient = saveIngredient,
       _adjustStock = adjustStock,
       _deleteIngredient = deleteIngredient,
       _getErpMode = getErpMode;

  final GetIngredientsUseCase _getIngredients;
  final SaveIngredientUseCase _saveIngredient;
  final AdjustStockUseCase _adjustStock;
  final DeleteIngredientUseCase _deleteIngredient;
  final GetErpModeUseCase _getErpMode;

  final RxList<Ingredient> ingredients = <Ingredient>[].obs;
  final RxBool isLoading = true.obs;
  final RxBool isSaving = false.obs;
  final RxnString errorMessage = RxnString();
  final RxBool lowStockOnly = false.obs;

  /// true = เชื่อมต่อ PaynEat ERP อยู่ หน้าวัตถุดิบเป็นอ่านอย่างเดียว
  final RxBool managedByErp = false.obs;

  @override
  void onInit() {
    super.onInit();
    load();
  }

  Future<void> load() async {
    isLoading.value = true;
    errorMessage.value = null;

    // โหมดของเครื่องอ่านทุกครั้งที่โหลด: admin อาจเพิ่งเชื่อมต่อหรือออกจาก ERP จากอีกเครื่อง
    // อ่านโหมดไม่ได้ (เน็ตหลุด) = คงค่าเดิมไว้ backend ยังปฏิเสธการแก้ในโหมดเชื่อมต่ออยู่แล้ว
    final results = await Future.wait([
      _getIngredients(lowStockOnly.value),
      _getErpMode(),
    ]);
    final result = results[0] as Result<List<Ingredient>>;
    final mode = (results[1] as Result<ErpMode>).dataOrNull;
    if (mode != null) managedByErp.value = mode == ErpMode.connected;
    // ตัวกรอง "ใกล้หมด" ไม่มีความหมายในโหมดเชื่อมต่อ (ยอดในเครื่องไม่ใช่ความจริง) และถูกซ่อนไว้ — ล้างแล้วโหลดใหม่
    if (managedByErp.value && lowStockOnly.value) {
      lowStockOnly.value = false;
      return load();
    }
    isLoading.value = false;
    result.fold(
      onSuccess: (data) => ingredients.assignAll(data),
      onFailure: (failure) => errorMessage.value = failure.message,
    );
  }

  Future<void> toggleLowStockOnly(bool value) async {
    lowStockOnly.value = value;
    await load();
  }

  Future<void> save({int? id, required IngredientFormData data}) async {
    isSaving.value = true;
    final result = await _saveIngredient(
      SaveIngredientParams(id: id, data: data),
    );
    isSaving.value = false;

    result.fold(
      onSuccess: (_) {
        AppDialogs.success(
          id == null
              ? 'ingredient_created_success'.tr
              : 'ingredient_updated_success'.tr,
        );
        Get.back<void>();
        load();
      },
      onFailure: (failure) => AppDialogs.error(failure.message),
    );
  }

  Future<void> adjustStock(Ingredient ingredient, double delta) async {
    final result = await _adjustStock(
      AdjustStockParams(id: ingredient.id, delta: delta),
    );
    result.fold(
      onSuccess: (updated) {
        final index = ingredients.indexWhere((row) => row.id == updated.id);
        if (index >= 0) ingredients[index] = updated;
        AppDialogs.success('ingredient_stock_adjusted_success'.tr);
      },
      onFailure: (failure) => AppDialogs.error(failure.message),
    );
  }

  Future<void> delete(Ingredient ingredient) async {
    final confirmed = await AppDialogs.confirm(
      title: 'ingredient_delete_title'.tr,
      message: 'ingredient_delete_confirm'.trParams({'name': ingredient.name}),
      confirmLabel: 'common_delete'.tr,
      destructive: true,
    );
    if (!confirmed) return;

    final result = await _deleteIngredient(ingredient.id);
    result.fold(
      onSuccess: (_) {
        ingredients.removeWhere((row) => row.id == ingredient.id);
        AppDialogs.success('ingredient_deleted_success'.tr);
      },
      onFailure: (failure) => AppDialogs.error(failure.message),
    );
  }

  Future<void> openForm({Ingredient? ingredient}) async {
    await Get.toNamed<void>(
      AppRoutes.ingredientForm,
      arguments: {'ingredient': ingredient},
    );
  }
}
