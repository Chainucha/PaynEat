// Copyright 2026 Suruch Chakrapeesirisuk
// SPDX-License-Identifier: Apache-2.0

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:get/get.dart';

import '../../../../app/config/app_config.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/network/socket_client.dart';
import '../../../../core/services/chime_player.dart';
import '../../../../core/services/session_service.dart';
import '../../../../core/utils/app_clock.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/widgets/app_dialogs.dart';
import '../../../../core/services/storage_service.dart';
import '../../../menu/domain/entities/kitchen_station.dart';
import '../../../menu/domain/usecases/menu_usecases.dart';
import '../../../order/domain/entities/order_item.dart';
import '../../../order/domain/usecases/order_usecases.dart';

/// จอครัว (Kitchen Display System)
///
/// รับตั๋วอาหารแบบเรียลไทม์ผ่าน socket แล้วจัดกลุ่มเป็นคอลัมน์ตามสถานะ
/// มี timer เดินทุกนาทีเพื่ออัปเดต "รอมาแล้วกี่นาที" ให้ครัวเห็นว่าจานไหนช้า
class KitchenController extends GetxController {
  KitchenController({
    required GetKitchenQueueUseCase getQueue,
    required UpdateOrderItemStatusUseCase updateItemStatus,
    required SessionService session,
    required GetKitchenStationsUseCase getStations,
    required StorageService storage,
    ChimePlayer chime = const NoopChimePlayer(),
  }) : _getQueue = getQueue,
       _updateItemStatus = updateItemStatus,
       _session = session,
       _getStations = getStations,
       _storage = storage,
       _chime = chime,
       muted = storage.kitchenChimeMuted.obs,
       soundLocked = chime.startsLocked.obs;

  final GetKitchenQueueUseCase _getQueue;
  final UpdateOrderItemStatusUseCase _updateItemStatus;
  final SessionService _session;
  final GetKitchenStationsUseCase _getStations;
  final StorageService _storage;
  final ChimePlayer _chime;

  final RxList<OrderItem> queue = <OrderItem>[].obs;

  /// สถานีครัวที่เปิดใช้งาน ใช้ทำชิปกรอง (ticket 34) — โหลดไม่ขึ้นก็ซ่อนชิปไป ไม่ปิดจอครัว
  final RxList<KitchenStation> stations = <KitchenStation>[].obs;

  /// รหัสสถานีที่จอนี้เลือกอยู่ — null = ทุกสถานี เก็บต่อเครื่องใน [StorageService]
  final RxnString selectedStationCode = RxnString();
  final RxBool isLoading = true.obs;
  final RxnString errorMessage = RxnString();
  final RxInt tick = 0.obs;

  /// จอครัวขาดการเชื่อมต่อเรียลไทม์อยู่หรือไม่ — ใช้ขึ้นแถบเตือนบนหน้าจอ
  final RxBool isOffline = false.obs;

  /// นาทีที่ถือว่า "ช้า" แล้วต้องเน้นสีให้ครัวเห็น
  static const int lateThresholdMinutes = 15;

  /// การเดินสถานะล่าสุดที่ยังย้อนได้ — จอครัวโชว์แถบ "เลิกทำ" จากค่านี้ (DECISIONS #64)
  /// เดิมกดผิด (เช่น "ทำเสร็จแล้ว" ทั้งที่ยังไม่เสร็จ) ต้องเดินหน้าต่อหรือตามผู้จัดการมายกเลิก
  final Rxn<KitchenStatusChange> lastChange = Rxn<KitchenStatusChange>();

  /// แถบเลิกทำค้างให้กดได้นานเท่านี้ พอให้คนเห็นว่ากดผิด แต่ไม่ค้างจนบังตั๋วถัดไป
  static const undoWindow = Duration(seconds: 8);

  /// ตั๋วเข้า (ticket 37): id รายการ → เวลาที่เข้า ใช้ขึ้นป้าย "ใหม่" บนการ์ด
  final RxMap<int, DateTime> newItems = <int, DateTime>{}.obs;

  /// ปิดเสียงเตือนไว้ — จำต่อเครื่อง ([StorageService.kitchenChimeMuted])
  final RxBool muted;

  /// เบราว์เซอร์ยังไม่ยอมให้เล่นเสียง — จอขึ้นแถบ "แตะเพื่อเปิดเสียง"
  final RxBool soundLocked;

  /// ป้าย "ใหม่" ค้างได้นานเท่านี้ ถ้าไม่มีใครแตะหรือเริ่มทำ
  static const highlightWindow = Duration(minutes: 2);

  /// ตั๋วเข้าติด ๆ กันภายในช่วงนี้ดังครั้งเดียว — ไม่ให้ออเดอร์โต๊ะใหญ่กลายเป็นเสียงรัว
  static const chimeCooldown = Duration(seconds: 3);

  /// id ของทุกรายการที่จอนี้เคยเห็นใน session — null = ยังไม่เคยโหลดสำเร็จ (โหลดแรกคือ baseline)
  /// ไม่ล้างตอนสลับชิป เพราะเทียบจากคิวทั้งหมด ไม่ใช่เฉพาะที่กรองอยู่ สลับชิปจึงไม่ทำให้ดังย้อนหลัง
  Set<int>? _seenIds;
  DateTime? _lastChimeAt;

  final List<VoidCallback> _unsubscribers = [];
  Timer? _elapsedTimer;
  Timer? _undoTimer;

  @override
  void onInit() {
    super.onInit();
    // กู้ชิปที่เครื่องนี้เลือกไว้ก่อนโหลดคิว ตั๋วชุดแรกจึงขึ้นตรงสถานีเลยโดยไม่กระพริบ
    // ไม่เคยเลือกบนเครื่องนี้ → ใช้สถานีที่ผูกไว้กับบัญชีเป็นค่าตั้งต้น (ticket 35) แค่ "เลือกให้ล่วงหน้า"
    // ไม่ได้ล็อก: แตะชิปอื่นได้ และค่าที่เลือกบนเครื่องจะทับค่าของบัญชีตั้งแต่นั้นไป
    final savedOnDevice = _storage.kitchenStation;
    selectedStationCode.value = savedOnDevice != null
        ? KitchenStationFilter.parse(savedOnDevice)
        : _session.currentUser?.stationCodes.firstOrNull;
    load();
    _loadStations();
    _listenToRealtimeUpdates();

    _syncConnectionState();
    _session.socket.connected.addListener(_syncConnectionState);

    // ตัวจับเวลานี้ทำสองหน้าที่:
    // 1. เดินตัวเลข "รอมาแล้วกี่นาที" บนตั๋ว
    // 2. เป็น polling สำรองตอน socket หลุด — จอครัวเป็นจอเดียวที่ไม่มีคนคอยกดรีเฟรช
    //    ถ้าพึ่ง socket อย่างเดียว เน็ตสะดุดทีเดียวตั๋วจะหยุดเข้าเงียบ ๆ ทั้งที่ตัวเลขนาที
    //    ยังเดินอยู่ ทำให้ดูเหมือนทุกอย่างปกติ
    _elapsedTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      tick.value++;
      final now = AppClock.now();
      newItems.removeWhere((_, at) => now.difference(at) >= highlightWindow);
      if (isOffline.value) load(showLoader: false);
    });
  }

  @override
  void onClose() {
    _elapsedTimer?.cancel();
    _undoTimer?.cancel();
    _session.socket.connected.removeListener(_syncConnectionState);
    for (final unsubscribe in _unsubscribers) {
      unsubscribe();
    }
    super.onClose();
  }

  /// โหมดสาธิตตั้งใจทำงานโดยไม่มีเซิร์ฟเวอร์ การไม่มี socket จึงเป็นเรื่องปกติ
  /// ไม่ใช่ความผิดปกติที่ต้องเตือน — ถ้าไม่กันไว้ แถบแดงจะขึ้นค้างตลอดทั้งที่ทุกอย่างใช้ได้
  void _syncConnectionState() =>
      isOffline.value = !AppConfig.demoMode && !_session.socket.connected.value;

  /// สถานีค่าเริ่มต้นของร้าน — ตั๋วที่ไม่มีสถานีประทับไว้ถือเป็นของสถานีนี้ (ticket 34)
  String? get defaultStationCode =>
      stations.firstWhereOrNull((station) => station.isDefault)?.code;

  /// คิวหลังกรองสถานี — ทุกอย่างที่จอครัวแสดง (คอลัมน์, ตัวนับ, ตัวนับจานช้า) อ่านจากที่นี่
  /// ที่เดียว ไม่งั้นแท็บเล็ตของบาร์จะขึ้น "ช้า 3 จาน" ของตั๋วที่ตัวเองทำอะไรไม่ได้
  List<OrderItem> get visibleQueue {
    final selected = selectedStationCode.value;
    if (selected == null) return queue.toList(growable: false);
    return queue.where(_matchesStation).toList(growable: false);
  }

  bool _matchesStation(OrderItem item) {
    final selected = selectedStationCode.value;
    if (selected == null) return true;
    if (item.stationCode != null) return item.stationCode == selected;
    // ตั๋วที่ไม่มีสถานี (ข้อมูลก่อน ticket 34) โผล่ที่ชิปสถานีค่าเริ่มต้น จึงไม่หายไปจากทุกชิป
    return selected == defaultStationCode;
  }

  /// เลือกชิปสถานี — กรองในเครื่องทันที ไม่ยิงคิวใหม่ (ใช้ได้แม้ตอน socket หลุด)
  Future<void> selectStation(String? code) async {
    selectedStationCode.value = code;
    await _storage.saveKitchenStation(KitchenStationFilter.store(code));
  }

  Future<void> _loadStations() async {
    final result = await _getStations(true);
    result.fold(
      onSuccess: (rows) {
        stations.assignAll(rows);
        // สถานีที่จำไว้ถูกลบหรือปิดใช้งานไปแล้ว — กลับไป "ทุกสถานี" ดีกว่าโชว์จอเปล่าค้าง
        final selected = selectedStationCode.value;
        if (selected != null && !rows.any((row) => row.code == selected)) {
          selectStation(null);
        }
      },
      // โหลดสถานีไม่ได้ไม่ใช่เรื่องคอขวดของจอครัว — ซ่อนชิปแล้วแสดงตั๋วทั้งหมดต่อไป
      onFailure: (_) => stations.clear(),
    );
  }

  List<OrderItem> byStatus(String status) => visibleQueue
      .where((item) => item.status == status)
      .toList(growable: false);

  List<OrderItem> get pending => byStatus(OrderItemStatus.pending);
  List<OrderItem> get cooking => byStatus(OrderItemStatus.cooking);
  List<OrderItem> get ready => byStatus(OrderItemStatus.ready);

  int get lateCount => visibleQueue
      .where(
        (item) =>
            item.status != OrderItemStatus.ready &&
            _minutesWaiting(item) >= lateThresholdMinutes,
      )
      .length;

  int _minutesWaiting(OrderItem item) =>
      Formatters.elapsedMinutes(item.createdAt);

  bool isLate(OrderItem item) => _minutesWaiting(item) >= lateThresholdMinutes;

  Future<void> load({bool showLoader = true}) async {
    if (showLoader) isLoading.value = true;
    errorMessage.value = null;

    final result = await _getQueue(const [
      OrderItemStatus.pending,
      OrderItemStatus.cooking,
      OrderItemStatus.ready,
    ]);

    isLoading.value = false;
    result.fold(
      onSuccess: (rows) {
        _detectArrivals(rows);
        queue.assignAll(rows);
      },
      onFailure: (failure) => errorMessage.value = failure.message,
    );
  }

  /// ครัวกดปุ่มเดียวเพื่อเดินสถานะไปขั้นถัดไป
  Future<void> advance(OrderItem item) async {
    final next = item.nextStatus;
    if (next == null) return;
    acknowledge(item);

    // อัปเดตในเครื่องก่อนเพื่อให้ปุ่มตอบสนองทันที แล้วค่อย sync กับเซิร์ฟเวอร์
    final index = queue.indexWhere((row) => row.id == item.id);
    final result = await _updateItemStatus(
      UpdateItemStatusParams(
        orderId: item.orderId,
        itemId: item.id,
        status: next,
      ),
    );

    result.fold(
      onSuccess: (_) {
        if (next == OrderItemStatus.served && index >= 0) {
          queue.removeAt(index);
          _clearUndo();
        } else {
          // served ย้อนไม่ได้ (backend ไม่ยอม) — เสนอเลิกทำเฉพาะขั้นในครัว
          _offerUndo(
            KitchenStatusChange(item: item, from: item.status, to: next),
          );
          load(showLoader: false);
        }
      },
      onFailure: (failure) => AppDialogs.error(failure.message),
    );
  }

  /// ย้อนการเดินสถานะล่าสุดกลับหนึ่งขั้น
  Future<void> undoLast() async {
    final change = lastChange.value;
    if (change == null) return;
    _clearUndo();

    final result = await _updateItemStatus(
      UpdateItemStatusParams(
        orderId: change.item.orderId,
        itemId: change.item.id,
        status: change.from,
      ),
    );
    result.fold(
      onSuccess: (_) => load(showLoader: false),
      onFailure: (failure) => AppDialogs.error(failure.message),
    );
  }

  void _offerUndo(KitchenStatusChange change) {
    _undoTimer?.cancel();
    lastChange.value = change;
    _undoTimer = Timer(undoWindow, _clearUndo);
  }

  void _clearUndo() {
    _undoTimer?.cancel();
    _undoTimer = null;
    lastChange.value = null;
  }

  /// ตั๋วเข้า = รายการ pending ที่ไม่เคยเห็นใน session นี้และตรงกับชิปที่เลือก (CONTEXT.md "Ticket arrival")
  /// เทียบในเครื่องทุกครั้งที่โหลดคิว จึงดังได้ทั้งตอนมี event และตอน polling สำรองระหว่าง socket หลุด
  /// รายการที่ถูกเลิกทำถอยกลับมา pending ไม่นับ เพราะ id เคยเห็นแล้ว
  void _detectArrivals(List<OrderItem> rows) {
    final seen = _seenIds;
    _seenIds = {...?seen, for (final row in rows) row.id};

    // รายการที่เลยขั้นรอทำไปแล้ว (หรือหายจากคิว) ไม่ใช่ "ใหม่" อีกต่อไป
    final stillPending = {
      for (final row in rows)
        if (row.status == OrderItemStatus.pending) row.id,
    };
    newItems.removeWhere((id, _) => !stillPending.contains(id));

    if (seen == null) return;
    final arrivals = rows
        .where(
          (row) =>
              !seen.contains(row.id) &&
              row.status == OrderItemStatus.pending &&
              _matchesStation(row),
        )
        .toList(growable: false);
    if (arrivals.isEmpty) return;

    final now = AppClock.now();
    newItems.addAll({for (final row in arrivals) row.id: now});
    _ring(now);
  }

  void _ring(DateTime now) {
    if (muted.value) return;
    final last = _lastChimeAt;
    if (last != null && now.difference(last) < chimeCooldown) return;
    _lastChimeAt = now;
    _chime.play().then((ok) {
      if (!ok) soundLocked.value = true;
    });
  }

  bool isNew(OrderItem item) {
    final at = newItems[item.id];
    return at != null && AppClock.now().difference(at) < highlightWindow;
  }

  /// แตะการ์ดหรือกดเดินสถานะ = เห็นแล้ว
  void acknowledge(OrderItem item) => newItems.remove(item.id);

  Future<void> toggleMute() async {
    muted.toggle();
    await _storage.saveKitchenChimeMuted(muted.value);
  }

  /// เรียกจากปุ่มบนแถบ "แตะเพื่อเปิดเสียง" เท่านั้น — ต้องอยู่ใน gesture ของผู้ใช้
  Future<void> unlockSound() async {
    soundLocked.value = !await _chime.unlock();
  }

  void _listenToRealtimeUpdates() {
    final socket = _session.socket;
    for (final event in [
      SocketEvents.kitchenTicket,
      SocketEvents.orderItemUpdated,
      SocketEvents.orderUpdated,
    ]) {
      _unsubscribers.add(socket.on(event, (_) => load(showLoader: false)));
    }
  }
}

/// การเดินสถานะหนึ่งครั้งในจอครัว — เก็บไว้ให้กด "เลิกทำ" ย้อนกลับได้
@immutable
class KitchenStatusChange {
  const KitchenStatusChange({
    required this.item,
    required this.from,
    required this.to,
  });

  final OrderItem item;
  final String from;
  final String to;
}
