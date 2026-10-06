// Copyright 2026 Suruch Chakrapeesirisuk
// SPDX-License-Identifier: Apache-2.0

import '../../../../core/usecases/result.dart';
import '../../../../core/usecases/usecase.dart';
import '../entities/backup_status.dart';
import '../repositories/backup_repository.dart';

class GetBackupStatusUseCase implements NoParamsUseCase<BackupStatus> {
  const GetBackupStatusUseCase(this._repository);

  final BackupRepository _repository;

  @override
  Future<Result<BackupStatus>> call() => _repository.getStatus();
}

class BackupNowUseCase implements NoParamsUseCase<BackupNowOutcome> {
  const BackupNowUseCase(this._repository);

  final BackupRepository _repository;

  @override
  Future<Result<BackupNowOutcome>> call() => _repository.backupNow();
}
