// Copyright 2026 Suruch Chakrapeesirisuk
// SPDX-License-Identifier: Apache-2.0

import 'package:flutter_test/flutter_test.dart';
import 'package:payneat_pos/core/errors/failures.dart';
import 'package:payneat_pos/core/usecases/result.dart';
import 'package:payneat_pos/features/erp_connection/domain/entities/erp_connection_status.dart';
import 'package:payneat_pos/features/erp_connection/domain/repositories/erp_connection_repository.dart';
import 'package:payneat_pos/features/erp_connection/domain/usecases/erp_connection_usecases.dart';
import 'package:payneat_pos/features/ingredient/data/models/ingredient_model.dart';
import 'package:payneat_pos/features/ingredient/domain/entities/ingredient.dart';
import 'package:payneat_pos/features/ingredient/domain/repositories/ingredient_repository.dart';
import 'package:payneat_pos/features/ingredient/domain/usecases/ingredient_usecases.dart';
import 'package:payneat_pos/features/ingredient/presentation/controllers/ingredients_controller.dart';

/// หน้าวัตถุดิบในโหมดเชื่อมต่อ PaynEat ERP เป็นอ่านอย่างเดียว (ticket 25)
class _FakeIngredientRepository implements IngredientRepository {
  final lowStockRequests = <bool>[];

  @override
  Future<Result<List<Ingredient>>> getIngredients({
    bool lowStockOnly = false,
  }) async {
    lowStockRequests.add(lowStockOnly);
    return const Result.success([
      Ingredient(
        id: 1,
        name: 'ไก่ทั้งตัว',
        unit: 'kg',
        itemCode: 'WHOLE-CHICKEN',
      ),
    ]);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeErpRepository implements ErpConnectionRepository {
  Result<ErpMode> mode = const Result.success(ErpMode.standalone);

  @override
  Future<Result<ErpMode>> getMode() async => mode;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  late _FakeIngredientRepository ingredients;
  late _FakeErpRepository erp;
  late IngredientsController controller;

  setUp(() {
    ingredients = _FakeIngredientRepository();
    erp = _FakeErpRepository();
    controller = IngredientsController(
      getIngredients: GetIngredientsUseCase(ingredients),
      saveIngredient: SaveIngredientUseCase(ingredients),
      adjustStock: AdjustStockUseCase(ingredients),
      deleteIngredient: DeleteIngredientUseCase(ingredients),
      getErpMode: GetErpModeUseCase(erp),
    );
  });

  group('IngredientsController กับโหมดของเครื่อง', () {
    test('ใช้งานเดี่ยว → แก้ไขได้ตามปกติ', () async {
      await controller.load();

      expect(controller.managedByErp.value, isFalse);
      expect(controller.ingredients.single.itemCode, 'WHOLE-CHICKEN');
    });

    test('เชื่อมต่อ ERP → อ่านอย่างเดียว', () async {
      erp.mode = const Result.success(ErpMode.connected);

      await controller.load();

      expect(controller.managedByErp.value, isTrue);
      expect(controller.ingredients, hasLength(1));
    });

    test(
      'อ่านโหมดไม่ได้ (เน็ตหลุด) → คงค่าเดิม ไม่สลับกลับเป็นแก้ไขได้',
      () async {
        erp.mode = const Result.success(ErpMode.connected);
        await controller.load();
        erp.mode = Result.failure(NetworkFailure('offline'));

        await controller.load();

        expect(controller.managedByErp.value, isTrue);
      },
    );

    test(
      'ตัวกรอง "ใกล้หมด" ถูกล้างในโหมดเชื่อมต่อ เพราะยอดในเครื่องไม่ใช่ความจริง',
      () async {
        controller.lowStockOnly.value = true;
        erp.mode = const Result.success(ErpMode.connected);

        await controller.load();

        expect(controller.lowStockOnly.value, isFalse);
        expect(ingredients.lowStockRequests, [true, false]);
      },
    );
  });

  group('รหัสสินค้าใน ERP', () {
    test(
      'สร้าง: ส่งเป็นตัวพิมพ์ใหญ่ ว่าง = ไม่ส่ง; แก้ไข: ส่ง null เพื่อล้าง',
      () {
        const withCode = IngredientFormData(
          name: 'ไก่',
          unit: 'กก.',
          itemCode: ' whole-chicken ',
        );
        const empty = IngredientFormData(
          name: 'ไก่',
          unit: 'กก.',
          itemCode: '',
        );

        expect(withCode.toCreateJson()['itemCode'], 'WHOLE-CHICKEN');
        expect(empty.toCreateJson().containsKey('itemCode'), isFalse);
        expect(empty.toUpdateJson().containsKey('itemCode'), isTrue);
        expect(empty.toUpdateJson()['itemCode'], isNull);
      },
    );

    test('อ่านข้อมูลจาก ERP ของวัตถุดิบ', () {
      final model = IngredientModel.fromJson({
        'id': 3,
        'name': 'ไก่ทั้งตัว',
        'unit': 'kg',
        'itemCode': 'WHOLE-CHICKEN',
        'erpItem': {'nameEn': 'Whole chicken', 'active': false},
      });

      expect(model.itemCode, 'WHOLE-CHICKEN');
      expect(model.erpItem!.nameEn, 'Whole chicken');
      expect(model.erpItem!.active, isFalse);
      expect(
        IngredientModel.fromJson({'id': 4, 'name': 'x', 'unit': 'y'}).erpItem,
        isNull,
      );
    });
  });
}
