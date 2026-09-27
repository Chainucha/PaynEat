// Copyright 2026 Suruch Chakrapeesirisuk
// SPDX-License-Identifier: Apache-2.0

import '../../domain/entities/ingredient.dart';

class IngredientModel extends Ingredient {
  const IngredientModel({
    required super.id,
    required super.name,
    required super.unit,
    super.currentStock,
    super.lowStockThreshold,
    super.itemCode,
    super.erpItem,
    super.createdAt,
    super.updatedAt,
  });

  factory IngredientModel.fromJson(Map<String, dynamic> json) {
    final erp = json['erpItem'] as Map<String, dynamic>?;
    return IngredientModel(
      id: (json['id'] as num).toInt(),
      name: json['name'] as String? ?? '',
      unit: json['unit'] as String? ?? '',
      currentStock: (json['currentStock'] as num?)?.toDouble() ?? 0,
      lowStockThreshold: (json['lowStockThreshold'] as num?)?.toDouble() ?? 0,
      itemCode: json['itemCode'] as String?,
      erpItem: erp == null
          ? null
          : ErpItemInfo(
              nameEn: erp['nameEn'] as String? ?? '',
              active: erp['active'] as bool? ?? true,
            ),
      createdAt: json['createdAt'] as String?,
      updatedAt: json['updatedAt'] as String?,
    );
  }
}

class MenuItemIngredientUsageModel extends MenuItemIngredientUsage {
  const MenuItemIngredientUsageModel({
    required super.ingredientId,
    required super.qtyPerUnit,
    super.ingredientName,
    super.unit,
  });

  factory MenuItemIngredientUsageModel.fromJson(Map<String, dynamic> json) =>
      MenuItemIngredientUsageModel(
        ingredientId: (json['ingredientId'] as num).toInt(),
        qtyPerUnit: (json['qtyPerUnit'] as num?)?.toDouble() ?? 0,
        ingredientName: json['ingredientName'] as String?,
        unit: json['unit'] as String?,
      );
}
