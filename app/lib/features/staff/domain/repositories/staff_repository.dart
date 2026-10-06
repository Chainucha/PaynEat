// Copyright 2026 Suruch Chakrapeesirisuk
// SPDX-License-Identifier: Apache-2.0

import '../../../../core/usecases/result.dart';
import '../../../auth/domain/entities/user.dart';

abstract class StaffRepository {
  Future<Result<List<User>>> getStaff({String? role});
  Future<Result<User>> create({
    required String name,
    required String username,
    required String password,
    required String role,
    List<int>? stationIds,
  });
  Future<Result<User>> update(
    int id, {
    String? name,
    String? role,
    bool? isActive,
    List<int>? stationIds,
  });
  Future<Result<User>> resetPassword(int id, String password);
  Future<Result<void>> delete(int id);
}
