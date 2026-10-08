// Copyright 2026 Suruch Chakrapeesirisuk
// SPDX-License-Identifier: Apache-2.0

import 'package:flutter/foundation.dart';
import 'package:socket_io_client/socket_io_client.dart' as io;

import '../../app/config/app_config.dart';

/// ชื่อ event ที่ backend ยิงมา (ต้องตรงกับ src/realtime/socket.js)
class SocketEvents {
  const SocketEvents._();

  static const String orderCreated = 'order:created';
  static const String orderUpdated = 'order:updated';
  static const String orderItemUpdated = 'order_item:updated';
  static const String orderPaid = 'order:paid';
  static const String kitchenTicket = 'kitchen:ticket';
  static const String tableUpdated = 'table:updated';
  static const String scaleReading = 'scale:reading';
  static const String stationStatus = 'station:status';
}

/// ห่อ socket.io ให้ใช้ง่ายและ mock ได้
///
/// จุดสำคัญ: ทุกหน้าจอ subscribe ผ่าน [on] แล้วเก็บฟังก์ชันยกเลิกไว้เรียกตอน dispose
/// เพื่อไม่ให้ listener ค้างและกิน memory
class SocketClient {
  io.Socket? _socket;

  final Map<String, List<void Function(dynamic)>> _handlers = {};
  final ValueNotifier<bool> connected = ValueNotifier<bool>(false);

  bool get isConnected => _socket?.connected ?? false;

  /// [url] ใช้ในเทสต์ E2E ที่ backend สุ่มพอร์ตตอนรัน — แอปจริงใช้ [AppConfig.baseUrl] เสมอ
  void connect(String token, {String? url}) {
    if (_socket != null) disconnect();

    _socket = io.io(
      url ?? AppConfig.baseUrl,
      io.OptionBuilder()
          .setTransports(['websocket'])
          .setAuth({'token': token})
          .enableReconnection()
          .setReconnectionDelay(2000)
          .build(),
    );

    _socket!
      ..onConnect((_) => connected.value = true)
      ..onDisconnect((_) => connected.value = false)
      ..onConnectError((_) => connected.value = false);

    // ผูก handler ที่ลงทะเบียนไว้ก่อนหน้ากลับเข้ากับ socket ตัวใหม่
    _handlers.forEach((event, handlers) {
      for (final handler in handlers) {
        _socket!.on(event, handler);
      }
    });
  }

  /// ยิง event เข้า handler ที่ลงทะเบียนไว้โดยไม่ผ่าน socket จริง — ใช้ในเทสต์เท่านั้น
  @visibleForTesting
  void dispatchLocal(String event, dynamic data) {
    for (final handler in List.of(_handlers[event] ?? const [])) {
      handler(data);
    }
  }

  /// ลงทะเบียนรับ event — คืนฟังก์ชันสำหรับยกเลิกการรับ
  VoidCallback on(String event, void Function(dynamic data) handler) {
    _handlers.putIfAbsent(event, () => []).add(handler);
    _socket?.on(event, handler);

    return () {
      _handlers[event]?.remove(handler);
      _socket?.off(event, handler);
    };
  }

  void disconnect() {
    _socket?.dispose();
    _socket = null;
    connected.value = false;
  }
}
