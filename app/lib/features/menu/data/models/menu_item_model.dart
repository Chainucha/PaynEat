// Copyright 2026 Suruch Chakrapeesirisuk
// SPDX-License-Identifier: Apache-2.0

import '../../../ingredient/data/models/ingredient_model.dart';
import '../../domain/entities/menu_item.dart';
import '../../domain/entities/menu_option.dart';

class MenuOptionModel extends MenuOption {
  const MenuOptionModel({
    required super.id,
    required super.name,
    super.priceDelta,
    super.isDefault,
  });

  factory MenuOptionModel.fromJson(Map<String, dynamic> json) =>
      MenuOptionModel(
        id: (json['id'] as num?)?.toInt() ?? 0,
        name: json['name'] as String? ?? '',
        priceDelta: (json['priceDelta'] as num?)?.toDouble() ?? 0,
        isDefault: json['isDefault'] as bool? ?? false,
      );
}

class MenuOptionGroupModel extends MenuOptionGroup {
  const MenuOptionGroupModel({
    required super.id,
    required super.name,
    required super.options,
    super.minSelect,
    super.maxSelect,
    super.isRequired,
  });

  factory MenuOptionGroupModel.fromJson(Map<String, dynamic> json) =>
      MenuOptionGroupModel(
        id: (json['id'] as num?)?.toInt() ?? 0,
        name: json['name'] as String? ?? '',
        minSelect: (json['minSelect'] as num?)?.toInt() ?? 0,
        maxSelect: (json['maxSelect'] as num?)?.toInt() ?? 1,
        isRequired: json['isRequired'] as bool? ?? false,
        options: (json['options'] as List? ?? const [])
            .whereType<Map<String, dynamic>>()
            .map(MenuOptionModel.fromJson)
            .toList(growable: false),
      );
}

class MenuItemModel extends MenuItem {
  const MenuItemModel({
    required super.id,
    required super.categoryId,
    required super.name,
    required super.price,
    super.categoryName,
    super.nameEn,
    super.nameKo,
    super.description,
    super.imageUrl,
    super.isAvailable,
    super.isRecommended,
    super.prepMinutes,
    super.sortOrder,
    super.optionGroups,
    super.ingredients,
    super.soldByWeight,
    super.barcode,
    super.scalePlu,
    super.stationId,
  });

  factory MenuItemModel.fromJson(Map<String, dynamic> json) => MenuItemModel(
    id: (json['id'] as num).toInt(),
    categoryId: (json['categoryId'] as num?)?.toInt() ?? 0,
    categoryName: json['categoryName'] as String?,
    name: json['name'] as String? ?? '',
    nameEn: json['nameEn'] as String?,
    nameKo: json['nameKo'] as String?,
    description: json['description'] as String?,
    price: (json['price'] as num?)?.toDouble() ?? 0,
    imageUrl: json['imageUrl'] as String?,
    isAvailable: json['isAvailable'] as bool? ?? true,
    isRecommended: json['isRecommended'] as bool? ?? false,
    prepMinutes: (json['prepMinutes'] as num?)?.toInt() ?? 10,
    sortOrder: (json['sortOrder'] as num?)?.toInt() ?? 0,
    soldByWeight: json['soldByWeight'] as bool? ?? false,
    barcode: json['barcode'] as String?,
    scalePlu: json['scalePlu'] as String?,
    stationId: (json['stationId'] as num?)?.toInt(),
    optionGroups: (json['optionGroups'] as List? ?? const [])
        .whereType<Map<String, dynamic>>()
        .map(MenuOptionGroupModel.fromJson)
        .toList(growable: false),
    ingredients: (json['ingredients'] as List? ?? const [])
        .whereType<Map<String, dynamic>>()
        .map(MenuItemIngredientUsageModel.fromJson)
        .toList(growable: false),
  );
}
