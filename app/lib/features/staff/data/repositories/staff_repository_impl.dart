// Copyright 2026 Suruch Chakrapeesirisuk
// SPDX-License-Identifier: Apache-2.0

import '../../../../core/errors/failure_mapper.dart';
import '../../../../core/usecases/result.dart';
import '../../../auth/domain/entities/user.dart';
import '../../domain/repositories/staff_repository.dart';
import '../datasources/staff_remote_data_source.dart';

class StaffRepositoryImpl implements StaffRepository {
  const StaffRepositoryImpl(this._remote);

  final StaffRemoteDataSource _remote;

  @override
  Future<Result<List<User>>> getStaff({String? role}) =>
      guard(() async => await _remote.getStaff(role: role));

  @override
  Future<Result<User>> create({
    required String name,
    required String username,
    required String password,
    required String role,
    List<int>? stationIds,
  }) => guard(
    () async => await _remote.create(
      name: name,
      username: username,
      password: password,
      role: role,
      stationIds: stationIds,
    ),
  );

  @override
  Future<Result<User>> update(
    int id, {
    String? name,
    String? role,
    bool? isActive,
    List<int>? stationIds,
  }) => guard(
    () async => await _remote.update(id, {
      'name': ?name,
      'role': ?role,
      'isActive': ?isActive,
      'stationIds': ?stationIds,
    }),
  );

  @override
  Future<Result<User>> resetPassword(int id, String password) =>
      guard(() async => await _remote.resetPassword(id, password));

  @override
  Future<Result<void>> delete(int id) => guard(() => _remote.delete(id));
}
