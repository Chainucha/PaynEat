// Copyright 2026 Suruch Chakrapeesirisuk
// SPDX-License-Identifier: Apache-2.0

import '../../../../app/config/app_config.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/network/api_endpoints.dart';
import '../../domain/entities/backup_status.dart';
import '../models/backup_status_model.dart';

abstract class BackupRemoteDataSource {
  Future<BackupStatus> getStatus();
  Future<BackupNowOutcome> backupNow();
}

class BackupRemoteDataSourceImpl implements BackupRemoteDataSource {
  const BackupRemoteDataSourceImpl(this._client);

  final ApiClient _client;

  @override
  Future<BackupStatus> getStatus() async {
    final result = await _client.get(ApiEndpoints.backupStatus);
    return BackupStatusModel.fromJson(result.asMap);
  }

  @override
  Future<BackupNowOutcome> backupNow() async {
    final result = await _client.post(
      ApiEndpoints.backups,
      receiveTimeout: AppConfig.backupTimeout,
    );
    return BackupStatusModel.outcomeFromJson(result.asMap);
  }
}
