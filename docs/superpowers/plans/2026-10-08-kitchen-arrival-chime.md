# Kitchen Arrival Chime Implementation Plan (ticket 37)

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** The kitchen screen plays one short chime and marks the card "NEW" whenever new items reach the pending queue of the station(s) it is showing.

**Architecture:** App-only. `KitchenController` keeps a per-session set of every queue item id it has seen; after each queue load (socket-triggered or the existing 30-second offline polling) any *pending* item with an unseen id that matches the station filter is a ticket arrival. Arrivals get highlighted and trigger one chime through a small `ChimePlayer` interface (real implementation on `audioplayers`, fake in tests), with a cooldown so bursts ring once. Mute is stored per device; on the web a one-time "tap to enable sound" bar unlocks audio.

**Tech Stack:** Flutter 3.41 + GetX + `audioplayers` (new, MIT) + flutter_test; Node script to generate the chime WAV.

**Spec:** `docs/tickets/37-kitchen-arrival-chime.md` · glossary `CONTEXT.md` ("Ticket arrival")

**Order:** execute after `docs/superpowers/plans/2026-10-08-station-open-close.md` (both touch `kitchen_page.dart`; this plan assumes the station-status button from that plan is already in the header).

## Global Constraints

- Every new source file starts with `Copyright 2026 Suruch Chakrapeesirisuk` + `SPDX-License-Identifier: Apache-2.0` (`node scripts/license-headers.mjs --fix`).
- No backend change in this ticket.
- Every new app string has th/en/ko keys in `app/lib/core/localization/translations/kitchen_translations.dart`.
- Code comments in Thai, matching the surrounding code.
- Kitchen screen must not overflow at 360px width (DECISIONS #62) — header and highlighted cards.
- Per-device settings survive logout: never clear them in `StorageService.clear()` (same rule as the station chip, DECISIONS #97).
- New dependency must be MIT/BSD/Apache-compatible, resolve with the current Flutter SDK without touching the `image_picker` pin (#111), and be recorded in DECISIONS #102.
- Gate before every commit: `cd app && dart format --set-exit-if-changed . && flutter analyze && flutter test`; `node scripts/license-headers.mjs`; `bash tool/check-architecture.sh`.
- Branch `feat/station-close-and-chime`; commit after each task.

## Review Focus

1. **Socket down, ticket arrives through the 30-second polling fallback** — must still chime. Covered because detection runs inside `load()` regardless of who called it; pinned by a test that calls `load()` with `isOffline` true.
2. **Undo puts an item back to pending** (`cooking → pending`) — not an arrival, no chime. Pinned in Task 2.
3. **First queue load fails, second succeeds with a backlog** — the second load is the baseline, no chime. Pinned in Task 2.
4. **Station list loads after the queue** — an item without a station code (pre-ticket-34 data) is judged against the default station; arrivals while `stations` is still empty with a specific chip selected are simply not matched (no false chime). Pinned in Task 2.
5. **Browser blocks audio** — `play()` fails → the unlock bar appears instead of silently doing nothing. Pinned in Task 2 (controller) and Task 3 (widget).

---

## File Structure

- Create `scripts/generate-chime.mjs` — writes `app/assets/sounds/ticket_chime.wav`.
- Create `app/assets/sounds/ticket_chime.wav` (generated, committed).
- Create `app/lib/core/services/chime_player.dart` — `ChimePlayer` interface, `NoopChimePlayer`, `AssetChimePlayer`.
- Modify `app/pubspec.yaml` — `audioplayers` dependency, `assets/sounds/ticket_chime.wav` asset.
- Modify `app/lib/core/constants/app_constants.dart` (`StorageKeys.kitchenChimeMuted`), `app/lib/core/services/storage_service.dart`.
- Modify `app/lib/features/kitchen/presentation/controllers/kitchen_controller.dart` — detection, highlight, mute, unlock.
- Create `app/lib/features/kitchen/presentation/widgets/chime_controls.dart` — `ChimeMuteButton`, `SoundUnlockBar`.
- Modify `app/lib/features/kitchen/presentation/widgets/kitchen_ticket_card.dart` — `isNew`, `onTap`.
- Modify `app/lib/features/kitchen/presentation/pages/kitchen_page.dart`, `app/lib/features/home/presentation/bindings/home_binding.dart`.
- Tests: `app/test/presentation/kitchen_controller_test.dart`, `app/test/presentation/storage_service_test.dart`, `app/test/widget/kitchen_arrival_test.dart` (new).
- Docs: README ×3, `docs/DECISIONS.md` #102, `docs/FEATURE-GAP-ANALYSIS.md`, `docs/tickets/37-kitchen-arrival-chime.md`, `docs/tickets/README.md`.

---

### Task 1: Chime asset, `ChimePlayer`, mute storage

**Files:**
- Create: `scripts/generate-chime.mjs`, `app/assets/sounds/ticket_chime.wav`, `app/lib/core/services/chime_player.dart`
- Modify: `app/pubspec.yaml`, `app/lib/core/constants/app_constants.dart`, `app/lib/core/services/storage_service.dart`
- Test: `app/test/presentation/storage_service_test.dart`

**Interfaces:**
- Produces:
  - `abstract class ChimePlayer { bool get startsLocked; Future<bool> play(); Future<bool> unlock(); }`
  - `class NoopChimePlayer implements ChimePlayer` (const, always succeeds, never locked)
  - `class AssetChimePlayer implements ChimePlayer` (audioplayers, `startsLocked == kIsWeb`)
  - `StorageKeys.kitchenChimeMuted = 'kitchen_chime_muted'`; `StorageService.kitchenChimeMuted: bool`; `StorageService.saveKitchenChimeMuted(bool)`

- [ ] **Step 1: Write the failing storage test** — append to `app/test/presentation/storage_service_test.dart` (inside `main()`):

```dart
  test('ปิดเสียงจอครัวจำต่อเครื่อง ไม่ถูกล้างตอน logout (ticket 37)', () async {
    final storage = StorageService.memory();
    expect(storage.kitchenChimeMuted, isFalse);

    await storage.saveKitchenChimeMuted(true);
    await storage.clear();

    expect(storage.kitchenChimeMuted, isTrue);
  });
```

- [ ] **Step 2: Run to verify failure**

Run: `cd app && flutter test test/presentation/storage_service_test.dart`
Expected: compile error — `kitchenChimeMuted` undefined.

- [ ] **Step 3: Storage key + accessors**

`app_constants.dart` `StorageKeys`:

```dart
  static const String kitchenStation = 'kitchen_station';
  static const String kitchenChimeMuted = 'kitchen_chime_muted';
```

`storage_service.dart`, after `saveKitchenStation`:

```dart
  /// ปิดเสียงเตือนตั๋วเข้าของจอครัว (ticket 37) — ผูกกับเครื่องเหมือนชิปสถานี จึงไม่ถูกล้างตอน [clear]
  bool get kitchenChimeMuted => _read(StorageKeys.kitchenChimeMuted) == 'true';

  Future<void> saveKitchenChimeMuted(bool muted) =>
      _write(StorageKeys.kitchenChimeMuted, muted ? 'true' : 'false');
```

Run the storage test → PASS.

- [ ] **Step 4: Generate the chime** — `scripts/generate-chime.mjs`:

```js
#!/usr/bin/env node
// Copyright 2026 Suruch Chakrapeesirisuk
// SPDX-License-Identifier: Apache-2.0

// สร้างเสียงเตือนตั๋วเข้าจอครัว (ticket 37) จากคลื่นไซน์ล้วน ๆ — สร้างเองจึงไม่มีเรื่องลิขสิทธิ์ของไฟล์เสียง
// สองโน้ตลงต่ำ (E6 → C6) แบบกระดิ่ง ยาวไม่ถึงวินาที ดังพอได้ยินข้ามเสียงพัดลมดูดควัน
// รันใหม่เมื่ออยากเปลี่ยนเสียง: node scripts/generate-chime.mjs (ไฟล์ผลลัพธ์ commit เข้า repo)

import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const SAMPLE_RATE = 22050;
const DURATION = 0.65;
const NOTES = [
  { freq: 1318.5, start: 0, length: 0.32 },
  { freq: 1046.5, start: 0.16, length: 0.45 },
];

const total = Math.round(SAMPLE_RATE * DURATION);
const samples = new Float32Array(total);
for (const note of NOTES) {
  const from = Math.round(note.start * SAMPLE_RATE);
  const count = Math.round(note.length * SAMPLE_RATE);
  for (let i = 0; i < count && from + i < total; i += 1) {
    const t = i / SAMPLE_RATE;
    const attack = Math.min(1, t / 0.005);
    const decay = Math.exp(-t * 7);
    // ฮาร์มอนิกที่สองเล็กน้อยให้เป็นเสียงกระดิ่ง ไม่ใช่เสียงบี๊ปของเครื่องมือวัด
    const wave =
      Math.sin(2 * Math.PI * note.freq * t) + 0.3 * Math.sin(2 * Math.PI * note.freq * 2 * t);
    samples[from + i] += 0.45 * attack * decay * wave;
  }
}

const data = Buffer.alloc(total * 2);
for (let i = 0; i < total; i += 1) {
  const clamped = Math.max(-1, Math.min(1, samples[i]));
  data.writeInt16LE(Math.round(clamped * 32767), i * 2);
}

const header = Buffer.alloc(44);
header.write('RIFF', 0);
header.writeUInt32LE(36 + data.length, 4);
header.write('WAVE', 8);
header.write('fmt ', 12);
header.writeUInt32LE(16, 16);
header.writeUInt16LE(1, 20); // PCM
header.writeUInt16LE(1, 22); // mono
header.writeUInt32LE(SAMPLE_RATE, 24);
header.writeUInt32LE(SAMPLE_RATE * 2, 28);
header.writeUInt16LE(2, 32);
header.writeUInt16LE(16, 34);
header.write('data', 36);
header.writeUInt32LE(data.length, 40);

const out = path.resolve(
  path.dirname(fileURLToPath(import.meta.url)),
  '../app/assets/sounds/ticket_chime.wav',
);
fs.mkdirSync(path.dirname(out), { recursive: true });
fs.writeFileSync(out, Buffer.concat([header, data]));
console.log(`wrote ${out} (${header.length + data.length} bytes)`);
```

Run: `node scripts/generate-chime.mjs`
Expected: `wrote …/app/assets/sounds/ticket_chime.wav (28710 bytes)` (≈ 28 KB). Play the file once locally to confirm it sounds like a two-note chime.

- [ ] **Step 5: Add the dependency and asset**

Run: `cd app && flutter pub add audioplayers`
Then check: `flutter pub deps --style=compact | grep -E "audioplayers|image_picker"` — `image_picker` must still be in `>=1.2.0 <1.2.3`; note the resolved `audioplayers` version for DECISIONS #102. Confirm its licence is MIT (`flutter pub deps` → open `~/.pub-cache/hosted/pub.dev/audioplayers-*/LICENSE`).

In `app/pubspec.yaml` under `flutter: assets:` add:

```yaml
    - assets/sounds/ticket_chime.wav
```

- [ ] **Step 6: `ChimePlayer`** — `app/lib/core/services/chime_player.dart`:

```dart
// Copyright 2026 Suruch Chakrapeesirisuk
// SPDX-License-Identifier: Apache-2.0

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';

/// เล่นเสียงเตือนตั๋วเข้าจอครัว (ticket 37) — ซ่อน package เสียงไว้หลัง interface นี้ เทสต์จึงใช้ตัวปลอมได้
abstract class ChimePlayer {
  /// เบราว์เซอร์บล็อกเสียงจนกว่าผู้ใช้จะแตะหน้าจอ — จอครัวบนเว็บจึงเริ่มแบบ "ยังไม่ปลดล็อก"
  bool get startsLocked;

  /// เล่นหนึ่งครั้ง — false เมื่อเล่นไม่ได้ (เช่นเบราว์เซอร์ยังบล็อกอยู่)
  Future<bool> play();

  /// เรียกจาก onTap เท่านั้น: เล่นแบบไม่มีเสียงหนึ่งครั้งภายใน gesture ให้เบราว์เซอร์ยอมเล่นเสียงต่อจากนี้
  Future<bool> unlock();
}

/// ไม่มีเสียง — ค่าเริ่มต้นของ KitchenController ในเทสต์และที่ที่ไม่ต้องการเสียง
class NoopChimePlayer implements ChimePlayer {
  const NoopChimePlayer();

  @override
  bool get startsLocked => false;

  @override
  Future<bool> play() async => true;

  @override
  Future<bool> unlock() async => true;
}

/// เล่น `assets/sounds/ticket_chime.wav` (สร้างจาก scripts/generate-chime.mjs)
class AssetChimePlayer implements ChimePlayer {
  AssetChimePlayer({AudioPlayer? player}) : _player = player ?? AudioPlayer();

  final AudioPlayer _player;

  /// audioplayers เติม `assets/` ให้เอง
  static const String _asset = 'sounds/ticket_chime.wav';

  @override
  bool get startsLocked => kIsWeb;

  @override
  Future<bool> play() async {
    try {
      await _player.stop();
      await _player.play(AssetSource(_asset), volume: 1);
      return true;
    } catch (_) {
      return false;
    }
  }

  @override
  Future<bool> unlock() async {
    try {
      await _player.play(AssetSource(_asset), volume: 0);
      await _player.stop();
      return true;
    } catch (_) {
      return false;
    }
  }
}
```

- [ ] **Step 7: Run tests + analyzer**

Run: `cd app && flutter test test/presentation/storage_service_test.dart && flutter analyze`
Expected: PASS.

- [ ] **Step 8: Commit**

```bash
git add scripts/generate-chime.mjs app/assets/sounds app/pubspec.yaml app/pubspec.lock app/lib/core app/test/presentation/storage_service_test.dart
git commit -m "feat(app): bundled kitchen chime and per-device mute setting"
```

---

### Task 2: Arrival detection, highlight, mute and unlock in `KitchenController`

**Files:**
- Modify: `app/lib/features/kitchen/presentation/controllers/kitchen_controller.dart`
- Test: `app/test/presentation/kitchen_controller_test.dart`

**Interfaces:**
- Consumes: `ChimePlayer`, `NoopChimePlayer`, `StorageService.kitchenChimeMuted` / `saveKitchenChimeMuted` (Task 1); `AppClock` (`app/lib/core/utils/app_clock.dart`).
- Produces on `KitchenController`:
  - constructor param `ChimePlayer chime = const NoopChimePlayer()`
  - `RxMap<int, DateTime> newItems` (item id → arrival time)
  - `RxBool muted`, `RxBool soundLocked`
  - `static const highlightWindow = Duration(minutes: 2)`, `static const chimeCooldown = Duration(seconds: 3)`
  - `bool isNew(OrderItem item)`, `void acknowledge(OrderItem item)`, `Future<void> toggleMute()`, `Future<void> unlockSound()`

- [ ] **Step 1: Write the failing tests** — append a new group to `app/test/presentation/kitchen_controller_test.dart` (top-level, after the existing groups; it reuses `_FakeOrderRepository`, `_FakeMenuRepository`, `_item`, `_station` from the file):

```dart
class _FakeChime implements ChimePlayer {
  _FakeChime({this.startsLocked = false});

  @override
  final bool startsLocked;
  int plays = 0;
  int unlocks = 0;
  bool playResult = true;

  @override
  Future<bool> play() async {
    plays++;
    return playResult;
  }

  @override
  Future<bool> unlock() async {
    unlocks++;
    return true;
  }
}
```

(put the class next to the other fakes at the top of the file and import `package:payneat_pos/core/services/chime_player.dart`), then inside `main()`:

```dart
  group('KitchenController — ตั๋วเข้า (ticket 37)', () {
    late _FakeChime chime;
    late KitchenController kds;
    final t0 = DateTime(2026, 10, 8, 18);

    KitchenController build({StorageService? store}) => KitchenController(
      getQueue: GetKitchenQueueUseCase(repository),
      updateItemStatus: UpdateOrderItemStatusUseCase(repository),
      session: session,
      getStations: GetKitchenStationsUseCase(menuRepository),
      storage: store ?? storage,
      chime: chime,
    );

    Future<void> loadWith(List<OrderItem> rows) async {
      repository.nextQueueResult = Result.success(rows);
      await kds.load();
    }

    setUp(() {
      AppClock.freeze(t0);
      chime = _FakeChime();
      kds = build();
    });

    tearDown(() {
      kds.onClose();
      AppClock.unfreeze();
    });

    test('โหลดแรกตั้ง baseline ไม่ดัง — รายการ pending ใหม่ในรอบถัดไปดังและขึ้น "ใหม่"', () async {
      await loadWith([_item(1), _item(2), _item(3)]);
      expect(chime.plays, 0);
      expect(kds.newItems, isEmpty);

      await loadWith([_item(1), _item(2), _item(3), _item(4)]);
      expect(chime.plays, 1);
      expect(kds.isNew(_item(4)), isTrue);
      expect(kds.isNew(_item(1)), isFalse);
    });

    test('โหลดแรกล้มเหลว → รอบที่สำเร็จรอบแรกเป็น baseline ไม่ดัง', () async {
      repository.nextQueueResult = Result.failure(NetworkFailure('หลุด'));
      await kds.load();
      await loadWith([_item(1), _item(2)]);
      expect(chime.plays, 0);
    });

    test('เปลี่ยนสถานะ และเลิกทำถอยกลับ pending ไม่ใช่ตั๋วเข้า', () async {
      await loadWith([_item(1)]);
      await loadWith([_item(1, status: OrderItemStatus.cooking)]);
      await loadWith([_item(1)]);
      expect(chime.plays, 0);
    });

    test('เลือกชิปบาร์ → รายการของครัวร้อนเข้ามาไม่ดัง และสลับชิปทีหลังก็ไม่ดังย้อน', () async {
      kds.stations.assignAll([_station(1, 'hot', isDefault: true), _station(3, 'bar')]);
      await kds.selectStation('bar');
      await loadWith([_item(1, stationCode: 'bar')]);

      await loadWith([_item(1, stationCode: 'bar'), _item(2, stationCode: 'hot')]);
      expect(chime.plays, 0);

      await kds.selectStation('hot');
      await loadWith([_item(1, stationCode: 'bar'), _item(2, stationCode: 'hot')]);
      expect(chime.plays, 0);

      await loadWith([
        _item(1, stationCode: 'bar'),
        _item(2, stationCode: 'hot'),
        _item(5, stationCode: 'hot'),
      ]);
      expect(chime.plays, 1);
    });

    test('ตั๋วเข้าติดกันภายในช่วงพัก → ดังครั้งเดียว ทุกใบขึ้น "ใหม่"; พ้นช่วงพักแล้วดังใหม่', () async {
      await loadWith([_item(1)]);
      await loadWith([_item(1), _item(2), _item(3)]);
      AppClock.freeze(t0.add(const Duration(seconds: 1)));
      await loadWith([_item(1), _item(2), _item(3), _item(4)]);
      expect(chime.plays, 1);
      expect(kds.newItems.keys, containsAll([2, 3, 4]));

      AppClock.freeze(t0.add(const Duration(seconds: 5)));
      await loadWith([_item(1), _item(2), _item(3), _item(4), _item(6)]);
      expect(chime.plays, 2);
    });

    test('ตอน socket หลุด ตั๋วที่มาทาง polling ก็ดัง (ทางเดียวกันคือ load)', () async {
      kds.isOffline.value = true;
      await loadWith([_item(1)]);
      await loadWith([_item(1), _item(2)]);
      expect(chime.plays, 1);
    });

    test('ป้าย "ใหม่" หายเมื่อแตะ / สถานะเปลี่ยน / ครบ 2 นาที', () async {
      await loadWith([_item(1)]);
      await loadWith([_item(1), _item(2), _item(3), _item(4)]);

      kds.acknowledge(_item(2));
      expect(kds.isNew(_item(2)), isFalse);

      await loadWith([
        _item(1),
        _item(3, status: OrderItemStatus.cooking),
        _item(4),
      ]);
      expect(kds.isNew(_item(3)), isFalse);

      AppClock.freeze(t0.add(KitchenController.highlightWindow));
      expect(kds.isNew(_item(4)), isFalse);
    });

    test('ปิดเสียง → ไม่ดังแต่ยังไฮไลต์ และค่าที่ปิดไว้รอดการสร้าง controller ใหม่', () async {
      await kds.toggleMute();
      expect(kds.muted.value, isTrue);

      await loadWith([_item(1)]);
      await loadWith([_item(1), _item(2)]);
      expect(chime.plays, 0);
      expect(kds.isNew(_item(2)), isTrue);

      final revived = build();
      expect(revived.muted.value, isTrue);
      revived.onClose();
    });

    test('เบราว์เซอร์บล็อกเสียง → soundLocked; แตะปลดล็อกแล้วหาย', () async {
      chime.playResult = false;
      await loadWith([_item(1)]);
      await loadWith([_item(1), _item(2)]);
      await Future<void>.delayed(Duration.zero);
      expect(kds.soundLocked.value, isTrue);

      await kds.unlockSound();
      expect(chime.unlocks, 1);
      expect(kds.soundLocked.value, isFalse);
    });

    test('ChimePlayer ที่เริ่มแบบล็อก (เว็บ) → soundLocked ตั้งแต่สร้าง', () {
      chime = _FakeChime(startsLocked: true);
      final web = build();
      expect(web.soundLocked.value, isTrue);
      web.onClose();
    });
  });
```

`NetworkFailure` is already imported by this file (used in the existing failure test).

- [ ] **Step 2: Run to verify failure**

Run: `cd app && flutter test test/presentation/kitchen_controller_test.dart`
Expected: compile errors — `chime` param, `newItems`, `isNew`, etc. undefined.

- [ ] **Step 3: Implement** — in `kitchen_controller.dart`:

Imports: `../../../../core/services/chime_player.dart`, `../../../../core/utils/app_clock.dart`.

Constructor:

```dart
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

  final ChimePlayer _chime;
```

Fields (after `lastChange`):

```dart
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
```

In `onInit`'s periodic timer callback, prune expired highlights:

```dart
    _elapsedTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      tick.value++;
      final now = AppClock.now();
      newItems.removeWhere((_, at) => now.difference(at) >= highlightWindow);
      if (isOffline.value) load(showLoader: false);
    });
```

In `load`, replace `onSuccess: queue.assignAll,` with:

```dart
      onSuccess: (rows) {
        _detectArrivals(rows);
        queue.assignAll(rows);
      },
```

In `advance`, first line after the `next == null` guard: `acknowledge(item);`

New methods (before `_listenToRealtimeUpdates`):

```dart
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
```

- [ ] **Step 4: Run tests**

Run: `cd app && flutter test test/presentation/kitchen_controller_test.dart test/widget/kitchen_station_filter_test.dart`
Expected: all PASS (existing tests unchanged — `chime` defaults to `NoopChimePlayer`).

- [ ] **Step 5: Commit**

```bash
git add app/lib/features/kitchen/presentation/controllers/kitchen_controller.dart app/test/presentation/kitchen_controller_test.dart
git commit -m "feat(kitchen): detect ticket arrivals, chime once, highlight new cards"
```

---

### Task 3: Kitchen screen UI — NEW badge, mute button, unlock bar, wiring

**Files:**
- Create: `app/lib/features/kitchen/presentation/widgets/chime_controls.dart`
- Modify: `app/lib/features/kitchen/presentation/widgets/kitchen_ticket_card.dart`, `app/lib/features/kitchen/presentation/pages/kitchen_page.dart`, `app/lib/features/home/presentation/bindings/home_binding.dart`, `app/lib/core/localization/translations/kitchen_translations.dart`
- Test: `app/test/widget/kitchen_arrival_test.dart` (new)

**Interfaces:**
- Consumes: `KitchenController.isNew/acknowledge/muted/soundLocked/toggleMute/unlockSound/newItems` (Task 2), `AssetChimePlayer` (Task 1).
- Produces: `KitchenTicketCard({..., bool isNew = false, VoidCallback? onTap})`; widgets `ChimeMuteButton` and `SoundUnlockBar` (both `GetView<KitchenController>`).

- [ ] **Step 1: Write the failing widget tests** — `app/test/widget/kitchen_arrival_test.dart`:

```dart
// Copyright 2026 Suruch Chakrapeesirisuk
// SPDX-License-Identifier: Apache-2.0

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:payneat_pos/core/constants/app_constants.dart';
import 'package:payneat_pos/core/localization/app_translations.dart';
import 'package:payneat_pos/core/localization/locale_service.dart';
import 'package:payneat_pos/core/network/socket_client.dart';
import 'package:payneat_pos/core/services/chime_player.dart';
import 'package:payneat_pos/core/services/session_service.dart';
import 'package:payneat_pos/core/services/storage_service.dart';
import 'package:payneat_pos/core/usecases/result.dart';
import 'package:payneat_pos/features/kitchen/presentation/controllers/kitchen_controller.dart';
import 'package:payneat_pos/features/kitchen/presentation/widgets/chime_controls.dart';
import 'package:payneat_pos/features/kitchen/presentation/widgets/kitchen_ticket_card.dart';
import 'package:payneat_pos/features/menu/domain/entities/kitchen_station.dart';
import 'package:payneat_pos/features/menu/domain/repositories/menu_repository.dart';
import 'package:payneat_pos/features/menu/domain/usecases/menu_usecases.dart';
import 'package:payneat_pos/features/order/domain/entities/order_item.dart';
import 'package:payneat_pos/features/order/domain/repositories/order_repository.dart';
import 'package:payneat_pos/features/order/domain/usecases/order_usecases.dart';

/// เสียงเตือนตั๋วเข้า (ticket 37) — ป้าย "ใหม่", ปุ่มปิดเสียง, แถบปลดล็อกเสียงบนเว็บ ที่ 360px
class _FakeOrderRepository implements OrderRepository {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeMenuRepository implements MenuRepository {
  @override
  Future<Result<List<KitchenStation>>> getKitchenStations({
    bool activeOnly = false,
  }) async => const Result.success([]);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _LockedChime implements ChimePlayer {
  int unlocks = 0;

  @override
  bool get startsLocked => true;

  @override
  Future<bool> play() async => false;

  @override
  Future<bool> unlock() async {
    unlocks++;
    return true;
  }
}

const _ticket = OrderItem(
  id: 7,
  orderId: 1,
  name: 'ผัดกะเพราหมูกรอบไข่ดาวไม่สุกพิเศษ',
  unitPrice: 75,
  quantity: 1,
  lineTotal: 75,
  status: OrderItemStatus.pending,
  tableName: 'VIP2',
);

void main() {
  late _LockedChime chime;
  late StorageService storage;
  late KitchenController controller;

  setUp(() {
    chime = _LockedChime();
    storage = StorageService.memory();
    controller = KitchenController(
      getQueue: GetKitchenQueueUseCase(_FakeOrderRepository()),
      updateItemStatus: UpdateOrderItemStatusUseCase(_FakeOrderRepository()),
      session: SessionService(storage: storage, socket: SocketClient()),
      getStations: GetKitchenStationsUseCase(_FakeMenuRepository()),
      storage: storage,
      chime: chime,
    );
    Get.put<KitchenController>(controller);
  });

  tearDown(() {
    controller.onClose();
    Get.reset();
  });

  Future<void> pump(WidgetTester tester, Widget child) async {
    tester.view.physicalSize = const Size(360, 720);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      GetMaterialApp(
        translations: AppTranslations(),
        locale: LocaleService.thai,
        home: Scaffold(body: child),
      ),
    );
    await tester.pump();
  }

  testWidgets('การ์ดตั๋วเข้าใหม่มีป้าย "ใหม่" แตะแล้วเรียก onTap — ไม่ล้นที่ 360px', (
    tester,
  ) async {
    var taps = 0;
    await pump(
      tester,
      KitchenTicketCard(
        item: _ticket,
        isLate: false,
        isNew: true,
        onAdvance: () {},
        onTap: () => taps++,
      ),
    );

    expect(find.text('ใหม่'), findsOneWidget);
    await tester.tap(find.text('ใหม่'));
    expect(taps, 1);
    expect(tester.takeException(), isNull);
  });

  testWidgets('แถบ "แตะเพื่อเปิดเสียง" ขึ้นตอนล็อก แตะแล้วหาย; ปิดเสียงอยู่ไม่ขึ้นแถบ', (
    tester,
  ) async {
    await pump(tester, const Column(children: [SoundUnlockBar()]));
    expect(find.text('แตะเพื่อเปิดเสียงแจ้งเตือนตั๋วใหม่'), findsOneWidget);

    await tester.tap(find.text('แตะเพื่อเปิดเสียงแจ้งเตือนตั๋วใหม่'));
    await tester.pump();
    expect(chime.unlocks, 1);
    expect(find.text('แตะเพื่อเปิดเสียงแจ้งเตือนตั๋วใหม่'), findsNothing);

    controller.soundLocked.value = true;
    await controller.toggleMute();
    await tester.pump();
    expect(find.text('แตะเพื่อเปิดเสียงแจ้งเตือนตั๋วใหม่'), findsNothing);
  });

  testWidgets('ปุ่มลำโพงสลับปิด/เปิดเสียงและจำไว้ในเครื่อง', (tester) async {
    await pump(tester, const ChimeMuteButton());
    expect(find.byIcon(Icons.volume_up_rounded), findsOneWidget);

    await tester.tap(find.byType(ChimeMuteButton));
    await tester.pump();
    expect(find.byIcon(Icons.volume_off_rounded), findsOneWidget);
    expect(storage.kitchenChimeMuted, isTrue);
  });
}
```

Confirm `OrderItem` has a `const` constructor and a `tableName` param (it is used that way in `kitchen_ticket_card.dart`); if not `const`, drop `const` from `_ticket`.

- [ ] **Step 2: Run to verify failure**

Run: `cd app && flutter test test/widget/kitchen_arrival_test.dart`
Expected: compile errors — `chime_controls.dart`, `isNew`, `onTap` missing.

- [ ] **Step 3: Translations** — `kitchen_translations.dart` th/en/ko:

```dart
  // th
  'kitchen_new_badge': 'ใหม่',
  'kitchen_sound_unlock': 'แตะเพื่อเปิดเสียงแจ้งเตือนตั๋วใหม่',
  'kitchen_mute_tooltip': 'ปิดเสียงแจ้งเตือน',
  'kitchen_unmute_tooltip': 'เปิดเสียงแจ้งเตือน',
  // en
  'kitchen_new_badge': 'NEW',
  'kitchen_sound_unlock': 'Tap to turn on the new-ticket sound',
  'kitchen_mute_tooltip': 'Mute alerts',
  'kitchen_unmute_tooltip': 'Unmute alerts',
  // ko
  'kitchen_new_badge': '신규',
  'kitchen_sound_unlock': '새 주문 알림음을 켜려면 탭하세요',
  'kitchen_mute_tooltip': '알림음 끄기',
  'kitchen_unmute_tooltip': '알림음 켜기',
```

- [ ] **Step 4: Controls** — `chime_controls.dart`:

```dart
// Copyright 2026 Suruch Chakrapeesirisuk
// SPDX-License-Identifier: Apache-2.0

import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../../app/theme/app_colors.dart';
import '../controllers/kitchen_controller.dart';

/// ปุ่มลำโพงบนหัวจอครัว (ticket 37) — ค่าที่เลือกจำต่อเครื่อง
class ChimeMuteButton extends GetView<KitchenController> {
  const ChimeMuteButton({super.key});

  @override
  Widget build(BuildContext context) {
    return Obx(
      () => IconButton(
        tooltip: controller.muted.value
            ? 'kitchen_unmute_tooltip'.tr
            : 'kitchen_mute_tooltip'.tr,
        onPressed: controller.toggleMute,
        icon: Icon(
          controller.muted.value
              ? Icons.volume_off_rounded
              : Icons.volume_up_rounded,
        ),
      ),
    );
  }
}

/// แถบ "แตะเพื่อเปิดเสียง" — เบราว์เซอร์ไม่ยอมเล่นเสียงจนกว่าผู้ใช้จะแตะหน้าจอ (ticket 37)
/// ขึ้นเฉพาะตอนเสียงยังล็อกและไม่ได้ปิดเสียงไว้ ไม่บังการใช้งานจอ แตะครั้งเดียวแล้วหาย
class SoundUnlockBar extends GetView<KitchenController> {
  const SoundUnlockBar({super.key});

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      if (!controller.soundLocked.value || controller.muted.value) {
        return const SizedBox.shrink();
      }
      return Material(
        color: AppColors.primarySoft,
        child: InkWell(
          onTap: controller.unlockSound,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            child: Row(
              children: [
                Icon(Icons.volume_up_rounded, size: 18, color: AppColors.brandInk),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'kitchen_sound_unlock'.tr,
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      color: AppColors.brandInk,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    });
  }
}
```

- [ ] **Step 5: Ticket card** — in `kitchen_ticket_card.dart`:

Constructor/fields:

```dart
    this.stationLabel,
    this.isNew = false,
    this.onTap,
  });

  /// ตั๋วเข้าใหม่ที่ยังไม่มีใครแตะ (ticket 37) — ขึ้นป้าย "ใหม่" และขอบหนาสีหลัก
  final bool isNew;

  /// แตะการ์ด = รับทราบตั๋วใหม่แล้ว
  final VoidCallback? onTap;
```

In `build`: border becomes

```dart
        border: Border.all(
          color: isNew ? AppColors.primary : accent.withValues(alpha: 0.4),
          width: isNew || isLate ? 2 : 1,
        ),
```

wrap the outer `Container` in `GestureDetector(onTap: onTap, behavior: HitTestBehavior.opaque, child: …)`, wrap the table/order-type `Text` in the header row with `Flexible(child: Text(..., maxLines: 1, overflow: TextOverflow.ellipsis))`, and insert after it (before `const Spacer()`):

```dart
                if (isNew) ...[
                  const SizedBox(width: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                    decoration: BoxDecoration(
                      color: AppColors.primary,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      'kitchen_new_badge'.tr,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ],
```

Replace `const Spacer()` with `const SizedBox(width: 8)` + keep the time pushed right by changing the `Flexible` above to `Expanded`-like behaviour: use `Flexible(fit: FlexFit.tight, ...)` on the label so the badge and time stay right-aligned. Height of the card must not change (badge sits inside the existing header row).

- [ ] **Step 6: Kitchen page wiring** — in `kitchen_page.dart`:

- `KitchenPage.build` column: after `const _OfflineBanner()` add `const SoundUnlockBar(),`.
- `_KitchenHeader` row: add `const ChimeMuteButton(),` before the refresh `IconButton`. With the station-status button from the previous plan there are now three icon buttons; at 360px give all three `visualDensity: VisualDensity.compact` if the header overflows (the 360px test in `kitchen_station_filter_test.dart` / a manual check decides).
- Where the page reads `controller.tick.value;` inside the columns `Obx`, also read `controller.newItems.length;` so badges update when arrivals come in.
- The shared ticket builder (`return KitchenTicketCard(` around line 360):

```dart
        return KitchenTicketCard(
          item: item,
          isLate: controller.isLate(item),
          isNew: controller.isNew(item),
          onTap: () => controller.acknowledge(item),
          onAdvance: () => controller.advance(item),
          // ...stationLabel unchanged
```

`home_binding.dart` — pass the real player:

```dart
      () => KitchenController(
        // ...existing args
        chime: AssetChimePlayer(),
      ),
```

- [ ] **Step 7: Run all app checks**

Run: `cd app && flutter test && flutter analyze && dart format --set-exit-if-changed .`
Expected: all PASS.

- [ ] **Step 8: Browser check (agent-browser)** — build and serve the release web app the way phones get it (`flutter build web --dart-define=API_BASE_URL=http://localhost:3001` then `node C:\project-code\PaynEat-deploy\serve-web.mjs` or `flutter run -d web-server` for a quick check). With `/agent-browser` (claude-in-chrome fallback):
  1. Reload the kitchen screen as `kitchen` → unlock bar visible → tap it → bar disappears.
  2. As `waiter1` in another session, send an order with a hot-kitchen dish → kitchen card shows "ใหม่"; verify a play request for `ticket_chime.wav` in the network log.
  3. Send three dishes in one order → one chime.
  4. Toggle mute, reload → still muted, no unlock bar.
  5. Resize to 360px → header and cards don't overflow.

- [ ] **Step 9: Commit**

```bash
git add app
git commit -m "feat(kitchen): new-ticket badge, mute button and sound unlock bar"
```

---

### Task 4: Docs, counts, full verification

**Files:**
- Modify: `README.md`, `README.en.md`, `README.ko.md`, `docs/DECISIONS.md`, `docs/FEATURE-GAP-ANALYSIS.md`, `docs/tickets/37-kitchen-arrival-chime.md`, `docs/tickets/README.md`

- [ ] **Step 1: Run every gate and record real counts**

```bash
cd backend && npm run format:check && npm run lint && npm test
cd ../app && dart format --set-exit-if-changed . && flutter analyze && flutter test
cd .. && node scripts/license-headers.mjs && bash tool/check-architecture.sh
```

- [ ] **Step 2: README th/en/ko (in sync)** — badge + "🧪 การทดสอบ" with the real numbers and a sentence on `kitchen_arrival_test.dart` and the new controller group; "🗺 ทัวร์ 5 นาที": add a step "เปิดจอครัวไว้ แล้วสั่งอาหารจากอีกเครื่อง/QR → ได้ยินเสียงและเห็นป้าย 'ใหม่' (บนเว็บแตะแถบเปิดเสียงก่อนครั้งแรก)"; "✨ ฟีเจอร์" ครัว bullet; "🔭 สิ่งที่จะทำต่อ" tick ticket 37.

- [ ] **Step 3: DECISIONS** — add a ticket-37 part to #102 (or `## 103` if #102 is already long — keep one decision per number as the file does): chime detection on the device by diffing queue loads (works with the polling fallback) instead of a server "arrival" event; seen-id set per session, so undo and chip switches never ring; 3-second cooldown; 2-minute highlight; per-device mute; web unlock bar; `audioplayers` (version, MIT) added as the only audio dependency, hidden behind `ChimePlayer`; chime generated from `scripts/generate-chime.mjs` (no third-party audio licence). Not done: OS/browser push, vibration, selectable sounds, repeat-until-acknowledged, waiter notification. Demo mode needs no specific code: detection is data-source agnostic, and a single-device demo has no other device sending tickets while the kitchen screen is open.

- [ ] **Step 4: FEATURE-GAP + tickets** — update `docs/FEATURE-GAP-ANALYSIS.md`; mark ticket 37 ✅ with acceptance criteria ticked; update its line in `docs/tickets/README.md`.

- [ ] **Step 5: Commit**

```bash
git add README.md README.en.md README.ko.md docs
git commit -m "docs: kitchen arrival chime (ticket 37)"
```
