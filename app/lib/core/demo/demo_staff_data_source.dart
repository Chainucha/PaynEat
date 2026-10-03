// Copyright 2026 Suruch Chakrapeesirisuk
// SPDX-License-Identifier: Apache-2.0

part of 'demo_data_sources.dart';

class DemoStaffDataSource implements StaffRemoteDataSource {
  const DemoStaffDataSource(this._store, this._auth);

  final DemoStore _store;
  final DemoAuthDataSource _auth;

  @override
  Future<List<UserModel>> getStaff({String? role}) => _delayed(
    () => _store
        .staff(actorId: _auth.currentUserId)
        .where((user) => role == null || user['role'] == role)
        .map(UserModel.fromJson)
        .toList(growable: false),
  );

  @override
  Future<UserModel> create({
    required String name,
    required String username,
    required String password,
    required String role,
  }) => _delayed(
    () => UserModel.fromJson(
      _store.createStaff(
        name: name,
        username: username,
        password: password,
        role: role,
        actorId: _auth.currentUserId,
      ),
    ),
  );

  @override
  Future<UserModel> update(int id, Map<String, dynamic> changes) => _delayed(
    () => UserModel.fromJson(
      _store.updateStaff(id, changes, actorId: _auth.currentUserId),
    ),
  );

  @override
  Future<UserModel> resetPassword(int id, String password) => _delayed(
    () => UserModel.fromJson(
      _store.updateStaff(id, {
        'password': password,
      }, actorId: _auth.currentUserId),
    ),
  );

  @override
  Future<void> delete(int id) =>
      _delayed(() => _store.deleteStaff(id, actorId: _auth.currentUserId));
}
