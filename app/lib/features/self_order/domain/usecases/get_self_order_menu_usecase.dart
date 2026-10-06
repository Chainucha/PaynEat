// Copyright 2026 Suruch Chakrapeesirisuk
// SPDX-License-Identifier: Apache-2.0

import '../../../../core/usecases/result.dart';
import '../../../../core/usecases/usecase.dart';
import '../repositories/self_order_repository.dart';

class GetSelfOrderMenuUseCase implements UseCase<SelfOrderMenu, String> {
  const GetSelfOrderMenuUseCase(this._repository);

  final SelfOrderRepository _repository;

  @override
  Future<Result<SelfOrderMenu>> call(String qrToken) =>
      _repository.getMenu(qrToken);
}
