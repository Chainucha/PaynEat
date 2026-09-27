// Copyright 2026 Suruch Chakrapeesirisuk
// SPDX-License-Identifier: Apache-2.0

import '../../../../core/usecases/result.dart';
import '../../../../core/usecases/usecase.dart';
import '../entities/erp_connection_status.dart';
import '../repositories/erp_connection_repository.dart';

class GetErpModeUseCase implements NoParamsUseCase<ErpMode> {
  const GetErpModeUseCase(this._repository);

  final ErpConnectionRepository _repository;

  @override
  Future<Result<ErpMode>> call() => _repository.getMode();
}

class GetErpStatusUseCase implements NoParamsUseCase<ErpConnectionStatus> {
  const GetErpStatusUseCase(this._repository);

  final ErpConnectionRepository _repository;

  @override
  Future<Result<ErpConnectionStatus>> call() => _repository.getStatus();
}

class ConnectErpParams {
  const ConnectErpParams({required this.erpUrl, required this.credential});

  final String erpUrl;
  final String credential;
}

class ConnectErpUseCase
    implements UseCase<ErpConnectionStatus, ConnectErpParams> {
  const ConnectErpUseCase(this._repository);

  final ErpConnectionRepository _repository;

  @override
  Future<Result<ErpConnectionStatus>> call(ConnectErpParams params) =>
      _repository.connect(
        erpUrl: params.erpUrl.trim(),
        credential: params.credential.trim(),
      );
}

class DisconnectErpUseCase implements NoParamsUseCase<ErpConnectionStatus> {
  const DisconnectErpUseCase(this._repository);

  final ErpConnectionRepository _repository;

  @override
  Future<Result<ErpConnectionStatus>> call() => _repository.disconnect();
}

class PullErpNowUseCase implements NoParamsUseCase<ErpPullOutcome> {
  const PullErpNowUseCase(this._repository);

  final ErpConnectionRepository _repository;

  @override
  Future<Result<ErpPullOutcome>> call() => _repository.pullNow();
}

class UpdateBranchCodeParams {
  const UpdateBranchCodeParams({required this.branchId, required this.code});

  final int branchId;
  final String code;
}

class UpdateBranchCodeUseCase implements UseCase<void, UpdateBranchCodeParams> {
  const UpdateBranchCodeUseCase(this._repository);

  final ErpConnectionRepository _repository;

  @override
  Future<Result<void>> call(UpdateBranchCodeParams params) =>
      _repository.updateBranchCode(params.branchId, params.code.trim());
}
