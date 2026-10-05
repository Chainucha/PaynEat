// Copyright 2026 Suruch Chakrapeesirisuk
// SPDX-License-Identifier: Apache-2.0

import '../../../../core/network/api_client.dart';
import '../../../../core/network/api_endpoints.dart';
import '../../../auth/data/models/user_model.dart';

abstract class StaffRemoteDataSource {
  Future<List<UserModel>> getStaff({String? role});
  Future<UserModel> create({
    required String name,
    required String username,
    required String password,
    required String role,
    List<int>? stationIds,
  });
  Future<UserModel> update(int id, Map<String, dynamic> changes);
  Future<UserModel> resetPassword(int id, String password);
  Future<void> delete(int id);
}

class StaffRemoteDataSourceImpl implements StaffRemoteDataSource {
  const StaffRemoteDataSourceImpl(this._client);

  final ApiClient _client;

  @override
  Future<List<UserModel>> getStaff({String? role}) async {
    final result = await _client.get(ApiEndpoints.users, query: {'role': role});
    return result.asList.map(UserModel.fromJson).toList(growable: false);
  }

  @override
  Future<UserModel> create({
    required String name,
    required String username,
    required String password,
    required String role,
    List<int>? stationIds,
  }) async {
    final result = await _client.post(
      ApiEndpoints.users,
      body: {
        'name': name,
        'username': username,
        'password': password,
        'role': role,
        'stationIds': ?stationIds,
      },
    );
    return UserModel.fromJson(result.asMap);
  }

  @override
  Future<UserModel> update(int id, Map<String, dynamic> changes) async {
    final result = await _client.patch(ApiEndpoints.user(id), body: changes);
    return UserModel.fromJson(result.asMap);
  }

  @override
  Future<UserModel> resetPassword(int id, String password) async {
    final result = await _client.post(
      ApiEndpoints.resetPassword(id),
      body: {'password': password},
    );
    return UserModel.fromJson(result.asMap);
  }

  @override
  Future<void> delete(int id) => _client.delete(ApiEndpoints.user(id));
}
