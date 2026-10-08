// Copyright 2026 Suruch Chakrapeesirisuk
// SPDX-License-Identifier: Apache-2.0

import '../../../../core/localization/localized_name.dart';

/// สถานีครัวที่ปิดอยู่ของจานหนึ่ง (ticket 36) — ติดมากับเมนูเฉพาะตอนสถานีปิด ใช้ทำป้าย "บาร์ปิด"
class ClosedStation {
  const ClosedStation({
    required this.id,
    required this.name,
    this.nameEn,
    this.nameKo,
  });

  factory ClosedStation.fromJson(Map<String, dynamic> json) => ClosedStation(
    id: (json['id'] as num).toInt(),
    name: json['name'] as String? ?? '',
    nameEn: json['nameEn'] as String?,
    nameKo: json['nameKo'] as String?,
  );

  final int id;
  final String name;
  final String? nameEn;
  final String? nameKo;

  String get displayName =>
      LocalizedName.pick(name: name, nameEn: nameEn, nameKo: nameKo);
}
