// Copyright 2026 Suruch Chakrapeesirisuk
// SPDX-License-Identifier: Apache-2.0

import '../../../../core/network/api_client.dart';
import '../../../../core/network/api_endpoints.dart';
import '../../domain/entities/erp_connection_status.dart';
import '../models/erp_connection_status_model.dart';

abstract class ErpConnectionRemoteDataSource {
  Future<ErpMode> getMode();
  Future<ErpConnectionStatus> getStatus();
  Future<ErpConnectionStatus> connect({
    required String erpUrl,
    required String credential,
  });
  Future<ErpConnectionStatus> disconnect();
  Future<ErpPullOutcome> pullNow();
  Future<void> updateBranchCode(int branchId, String code);
}

class ErpConnectionRemoteDataSourceImpl
    implements ErpConnectionRemoteDataSource {
  const ErpConnectionRemoteDataSourceImpl(this._client);

  final ApiClient _client;

  @override
  Future<ErpMode> getMode() async {
    final result = await _client.get(ApiEndpoints.erpMode);
    return ErpMode.parse(result.asMap['mode'] as String?);
  }

  @override
  Future<ErpConnectionStatus> getStatus() async {
    final result = await _client.get(ApiEndpoints.erpConnection);
    return ErpConnectionStatusModel.fromJson(result.asMap);
  }

  @override
  Future<ErpConnectionStatus> connect({
    required String erpUrl,
    required String credential,
  }) async {
    // credential ถูกส่งไปครั้งเดียวตอนบันทึก — แอปไม่เก็บไว้ในเครื่อง และ backend ไม่ส่งกลับมาอีก
    final result = await _client.put(
      ApiEndpoints.erpConnection,
      body: {'erpUrl': erpUrl, 'credential': credential},
    );
    return ErpConnectionStatusModel.fromJson(result.asMap);
  }

  @override
  Future<ErpConnectionStatus> disconnect() async {
    final result = await _client.delete(ApiEndpoints.erpConnection);
    return ErpConnectionStatusModel.fromJson(result.asMap);
  }

  @override
  Future<ErpPullOutcome> pullNow() async {
    final result = await _client.post(ApiEndpoints.erpPull);
    return ErpConnectionStatusModel.pullFromJson(result.asMap);
  }

  @override
  Future<void> updateBranchCode(int branchId, String code) =>
      _client.patch(ApiEndpoints.branch(branchId), body: {'code': code});
}
