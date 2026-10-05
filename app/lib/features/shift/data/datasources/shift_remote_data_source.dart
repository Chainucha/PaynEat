// Copyright 2026 Suruch Chakrapeesirisuk
// SPDX-License-Identifier: Apache-2.0

import '../../../../app/config/app_config.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/network/api_endpoints.dart';
import '../models/shift_model.dart';

abstract class ShiftRemoteDataSource {
  Future<ShiftModel?> getCurrent();
  Future<ShiftModel> open(double openingCash);
  Future<ShiftModel> close(int id, {required double countedCash, String? note});
  Future<List<ShiftModel>> getHistory();
}

class ShiftRemoteDataSourceImpl implements ShiftRemoteDataSource {
  const ShiftRemoteDataSourceImpl(this._client);

  final ApiClient _client;

  @override
  Future<ShiftModel?> getCurrent() async {
    final response = await _client.get(ApiEndpoints.currentShift);
    if (response.data == null) return null;
    return ShiftModel.fromJson(response.asMap);
  }

  @override
  Future<ShiftModel> open(double openingCash) async {
    final response = await _client.post(
      ApiEndpoints.shifts,
      body: {'openingCash': openingCash},
    );
    return ShiftModel.fromJson(response.asMap);
  }

  @override
  Future<ShiftModel> close(
    int id, {
    required double countedCash,
    String? note,
  }) async {
    final response = await _client.patch(
      ApiEndpoints.closeShift(id),
      body: {
        'countedCash': countedCash,
        if (note != null && note.isNotEmpty) 'note': note,
      },
      // ปิดกะรอให้สำรองข้อมูลหลังปิดกะเสร็จก่อนตอบ (ticket 33)
      receiveTimeout: AppConfig.backupTimeout,
    );
    return ShiftModel.fromJson(response.asMap);
  }

  @override
  Future<List<ShiftModel>> getHistory() async {
    final response = await _client.get(ApiEndpoints.shifts);
    return response.asList.map(ShiftModel.fromJson).toList(growable: false);
  }
}
