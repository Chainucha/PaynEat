// Copyright 2026 Suruch Chakrapeesirisuk
// SPDX-License-Identifier: Apache-2.0

import '../../../ingredient/domain/entities/ingredient.dart';
import 'menu_option.dart';

/// ข้อมูลที่ใช้สร้าง/แก้ไขเมนู (แยกจาก entity เพราะรูปร่างต่างกัน)
class MenuItemPayload {
  const MenuItemPayload({
    required this.name,
    required this.categoryId,
    required this.price,
    this.nameEn,
    this.description,
    this.imageUrl,
    this.isAvailable,
    this.isRecommended,
    this.prepMinutes,
    this.optionGroups,
    this.ingredients,
    this.soldByWeight,
    this.barcode,
    this.scalePlu,
    this.stationId,
  });

  final String name;
  final int categoryId;
  final double price;
  final String? nameEn;
  final String? description;
  final String? imageUrl;
  final bool? isAvailable;
  final bool? isRecommended;
  final int? prepMinutes;
  final List<MenuOptionGroup>? optionGroups;
  final List<MenuItemIngredientUsage>? ingredients;
  final bool? soldByWeight;

  /// ส่ง '' เพื่อล้างบาร์โค้ด/PLU เดิม (null = ไม่แตะ)
  final String? barcode;
  final String? scalePlu;

  /// สถานีครัว (ticket 34) — null = "ตามหมวดหมู่" ซึ่งเป็นค่าที่มีความหมาย ไม่ใช่ "ไม่ได้ส่งมา"
  /// จึงส่งคีย์นี้ไปทุกครั้งแบบไม่มีเงื่อนไข ต่างจากช่องอื่นด้านบน
  final int? stationId;

  Map<String, dynamic> toJson() => {
    'name': name,
    'categoryId': categoryId,
    'price': price,
    if (nameEn != null && nameEn!.isNotEmpty) 'nameEn': nameEn,
    if (description != null && description!.isNotEmpty)
      'description': description,
    if (imageUrl != null) 'imageUrl': imageUrl,
    if (isAvailable != null) 'isAvailable': isAvailable,
    if (isRecommended != null) 'isRecommended': isRecommended,
    if (prepMinutes != null) 'prepMinutes': prepMinutes,
    if (soldByWeight != null) 'soldByWeight': soldByWeight,
    if (barcode != null) 'barcode': barcode,
    if (scalePlu != null) 'scalePlu': scalePlu,
    'stationId': stationId,
    if (optionGroups != null)
      'optionGroups': optionGroups!
          .map(
            (group) => {
              'name': group.name,
              'minSelect': group.minSelect,
              'maxSelect': group.maxSelect,
              'isRequired': group.isRequired,
              'options': group.options
                  .map(
                    (option) => {
                      'name': option.name,
                      'priceDelta': option.priceDelta,
                      'isDefault': option.isDefault,
                    },
                  )
                  .toList(growable: false),
            },
          )
          .toList(growable: false),
    if (ingredients != null)
      'ingredients': ingredients!
          .map(
            (link) => {
              'ingredientId': link.ingredientId,
              'qtyPerUnit': link.qtyPerUnit,
            },
          )
          .toList(growable: false),
  };
}
