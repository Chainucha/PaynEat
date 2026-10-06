// Copyright 2026 Suruch Chakrapeesirisuk
// SPDX-License-Identifier: Apache-2.0

import '../../domain/entities/kitchen_station.dart';

class KitchenStationModel extends KitchenStation {
  const KitchenStationModel({
    required super.id,
    required super.code,
    required super.name,
    super.nameEn,
    super.nameKo,
    super.icon,
    super.sortOrder,
    super.isActive,
    super.isDefault,
    super.itemCount,
  });

  factory KitchenStationModel.fromJson(Map<String, dynamic> json) =>
      KitchenStationModel(
        id: (json['id'] as num).toInt(),
        code: json['code'] as String? ?? '',
        name: json['name'] as String? ?? '',
        nameEn: json['nameEn'] as String?,
        nameKo: json['nameKo'] as String?,
        icon: json['icon'] as String?,
        sortOrder: (json['sortOrder'] as num?)?.toInt() ?? 0,
        isActive: json['isActive'] as bool? ?? true,
        isDefault: json['isDefault'] as bool? ?? false,
        itemCount: (json['itemCount'] as num?)?.toInt() ?? 0,
      );

  /// `code` ส่งได้เฉพาะตอนสร้าง — backend ปฏิเสธการแก้รหัสของสถานีที่มีอยู่แล้ว
  static Map<String, dynamic> toCreateJson({
    required String code,
    required String name,
    String? nameEn,
    String? nameKo,
    String? icon,
    int? sortOrder,
  }) => {
    'code': code,
    'name': name,
    if (nameEn != null && nameEn.isNotEmpty) 'nameEn': nameEn,
    if (nameKo != null && nameKo.isNotEmpty) 'nameKo': nameKo,
    if (icon != null && icon.isNotEmpty) 'icon': icon,
    'sortOrder': ?sortOrder,
  };

  static Map<String, dynamic> toUpdateJson({
    String? name,
    String? nameEn,
    String? nameKo,
    String? icon,
    int? sortOrder,
    bool? isActive,
    bool? isDefault,
  }) => {
    if (name != null && name.isNotEmpty) 'name': name,
    if (nameEn != null && nameEn.isNotEmpty) 'nameEn': nameEn,
    if (nameKo != null && nameKo.isNotEmpty) 'nameKo': nameKo,
    if (icon != null && icon.isNotEmpty) 'icon': icon,
    'sortOrder': ?sortOrder,
    'isActive': ?isActive,
    'isDefault': ?isDefault,
  };
}
