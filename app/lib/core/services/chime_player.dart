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
    } catch (error) {
      // คืน false เหมือนกันทั้งกรณีเบราว์เซอร์บล็อกและกรณีพังจริง (asset หาย/ปลั๊กอินพัง) จึง log ไว้แยกสาเหตุ
      debugPrint('ChimePlayer.play ล้มเหลว: $error');
      return false;
    }
  }

  @override
  Future<bool> unlock() async {
    try {
      await _player.play(AssetSource(_asset), volume: 0);
      return true;
    } catch (error) {
      debugPrint('ChimePlayer.unlock ล้มเหลว: $error');
      return false;
    } finally {
      // หยุดเสมอ แม้ play ล้ม — และให้ stop ล้มได้โดยไม่ทับผลลัพธ์ข้างบน
      try {
        await _player.stop();
      } catch (error) {
        debugPrint('ChimePlayer.unlock หยุดเสียงไม่สำเร็จ: $error');
      }
    }
  }
}
