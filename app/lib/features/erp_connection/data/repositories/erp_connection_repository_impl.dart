// Copyright 2026 Suruch Chakrapeesirisuk
// SPDX-License-Identifier: Apache-2.0

import '../../../../core/errors/failure_mapper.dart';
import '../../../../core/usecases/result.dart';
import '../../domain/entities/erp_connection_status.dart';
import '../../domain/repositories/erp_connection_repository.dart';
import '../datasources/erp_connection_remote_data_source.dart';

class ErpConnectionRepositoryImpl implements ErpConnectionRepository {
  const ErpConnectionRepositoryImpl(this._remote);

  final ErpConnectionRemoteDataSource _remote;

  @override
  Future<Result<ErpMode>> getMode() => guard(_remote.getMode);

  @override
  Future<Result<ErpConnectionStatus>> getStatus() => guard(_remote.getStatus);

  @override
  Future<Result<ErpConnectionStatus>> connect({
    required String erpUrl,
    required String credential,
  }) => guard(() => _remote.connect(erpUrl: erpUrl, credential: credential));

  @override
  Future<Result<ErpConnectionStatus>> disconnect() => guard(_remote.disconnect);

  @override
  Future<Result<ErpPullOutcome>> pullNow() => guard(_remote.pullNow);

  @override
  Future<Result<void>> updateBranchCode(int branchId, String code) =>
      guard(() => _remote.updateBranchCode(branchId, code));
}
