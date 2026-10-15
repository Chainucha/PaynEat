// Copyright 2026 Suruch Chakrapeesirisuk
// SPDX-License-Identifier: Apache-2.0

import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:payneat_pos/core/network/socket_client.dart';
import 'package:payneat_pos/core/services/session_service.dart';
import 'package:payneat_pos/core/services/storage_service.dart';
import 'package:payneat_pos/features/auth/domain/entities/user.dart';

User _user({int branchId = 1}) => User(
  id: 7,
  name: 'ครัว',
  username: 'kitchen',
  role: 'kitchen',
  isActive: true,
  branchId: branchId,
);

void main() {
  test(
    'start() ผู้ใช้เดิม (id เท่ากัน) แต่สาขาใหม่ → listener ของ currentUserRx ทำงาน',
    () {
      final storage = StorageService.memory();
      final session = SessionService(storage: storage, socket: SocketClient());
      session.start(user: _user(branchId: 1), token: 't1');

      final seen = <int?>[];
      final worker = ever(session.currentUserRx, (user) {
        if (user != null) seen.add(user.branchId);
      });

      session.start(user: _user(branchId: 2), token: 't2');

      expect(seen, [2]);
      expect(session.currentUser!.branchId, 2);
      worker.dispose();
      session.socket.disconnect();
    },
  );

  test('start() ผู้ใช้คนใหม่ → listener ทำงานครั้งเดียว ไม่ซ้ำ', () {
    final session = SessionService(
      storage: StorageService.memory(),
      socket: SocketClient(),
    );
    final seen = <int?>[];
    final worker = ever(session.currentUserRx, (user) => seen.add(user?.id));

    session.start(user: _user(), token: 't1');

    expect(seen, [7]);
    worker.dispose();
    session.socket.disconnect();
  });
}
