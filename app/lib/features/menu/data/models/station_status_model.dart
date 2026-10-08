// Copyright 2026 Suruch Chakrapeesirisuk
// SPDX-License-Identifier: Apache-2.0

import '../../domain/entities/station_status.dart';

class StationStatusModel extends StationStatus {
  const StationStatusModel({
    required super.stationId,
    required super.code,
    required super.name,
    super.nameEn,
    super.nameKo,
    super.icon,
    super.isClosed,
    super.closedAt,
    super.closedByName,
    super.pendingCount,
  });

  factory StationStatusModel.fromJson(Map<String, dynamic> json) =>
      StationStatusModel(
        stationId: (json['stationId'] as num).toInt(),
        code: json['code'] as String? ?? '',
        name: json['name'] as String? ?? '',
        nameEn: json['nameEn'] as String?,
        nameKo: json['nameKo'] as String?,
        icon: json['icon'] as String?,
        isClosed: json['isClosed'] as bool? ?? false,
        closedAt: json['closedAt'] as String?,
        closedByName: json['closedByName'] as String?,
        pendingCount: (json['pendingCount'] as num?)?.toInt() ?? 0,
      );
}
