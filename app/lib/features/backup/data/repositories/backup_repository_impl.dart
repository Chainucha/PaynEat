// Copyright 2026 Suruch Chakrapeesirisuk
// SPDX-License-Identifier: Apache-2.0

import '../../../../core/errors/failure_mapper.dart';
import '../../../../core/usecases/result.dart';
import '../../domain/entities/backup_status.dart';
import '../../domain/repositories/backup_repository.dart';
import '../datasources/backup_remote_data_source.dart';

class BackupRepositoryImpl implements BackupRepository {
  const BackupRepositoryImpl(this._remote);

  final BackupRemoteDataSource _remote;

  @override
  Future<Result<BackupStatus>> getStatus() => guard(_remote.getStatus);

  @override
  Future<Result<BackupNowOutcome>> backupNow() => guard(_remote.backupNow);
}
