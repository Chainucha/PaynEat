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

  /// ปล่อยทรัพยากรเครื่องเล่น — เรียกตอน controller ปิด (CODING_STANDARDS §3.4)
  Future<void> dispose();
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

  @override
  Future<void> dispose() async {}
}

/// เล่น `assets/sounds/ticket_chime.wav` (สร้างจาก scripts/generate-chime.mjs)
class AssetChimePlayer implements ChimePlayer {
  AssetChimePlayer({AudioPlayer? player}) : _player = player ?? AudioPlayer() {
    // โหลดไฟล์รอไว้ก่อนเลย — Safari ให้เล่นเสียงได้เฉพาะใน gesture ถ้ารอโหลดตอนแตะอาจหมดสิทธิ์
    _ensurePrepared().ignore();
  }

  final AudioPlayer _player;
  Future<void>? _prepared;

  /// audioplayers เติม `assets/` ให้เอง
  static const String _asset = 'sounds/ticket_chime.wav';

  /// เสียงเตือนสั้น ๆ ไม่ใช่เพลง: ขอ focus แบบชั่วคราวและยอมให้เสียงอื่น (วิทยุในครัว) เบาลงแทนที่จะถูกหยุด
  /// ค่าเริ่มต้นของ audioplayers คือ `gain` ซึ่งทำให้ทุกครั้งที่ตั๋วเข้า เพลงที่เปิดอยู่หยุดค้าง
  static final AudioContext _context = AudioContext(
    android: const AudioContextAndroid(
      contentType: AndroidContentType.sonification,
      usageType: AndroidUsageType.notification,
      audioFocus: AndroidAudioFocus.gainTransientMayDuck,
    ),
    iOS: AudioContextIOS(
      options: const {
        AVAudioSessionOptions.mixWithOthers,
        AVAudioSessionOptions.duckOthers,
      },
    ),
  );

  @override
  bool get startsLocked => kIsWeb;

  /// ตั้งค่าเครื่องเล่นและโหลดไฟล์ครั้งเดียว — ล้มแล้วเคลียร์ทิ้งให้เรียกครั้งหน้าลองใหม่
  Future<void> _ensurePrepared() =>
      _prepared ??= _prepare().catchError((Object error) {
        _prepared = null;
        debugPrint('ChimePlayer เตรียมเสียงไม่สำเร็จ: $error');
        throw error;
      });

  Future<void> _prepare() async {
    await _player.setReleaseMode(ReleaseMode.stop);
    try {
      await _player.setAudioContext(_context);
    } catch (error) {
      // บางแพลตฟอร์ม (เว็บ) ไม่รองรับ — เสียงยังเล่นได้ แค่ไม่ได้ปรับ focus
      debugPrint('ChimePlayer ตั้ง AudioContext ไม่สำเร็จ: $error');
    }
    await _player.setSource(AssetSource(_asset));
  }

  /// เล่นจากต้นไฟล์ที่โหลดไว้แล้ว (seek + resume) แทน play(AssetSource) ที่โหลดใหม่ทุกครั้ง
  Future<void> _fire(double volume) async {
    await _ensurePrepared();
    await _player.setVolume(volume);
    await _player.seek(Duration.zero);
    await _player.resume();
  }

  @override
  Future<bool> play() async {
    try {
      await _fire(1);
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
      await _fire(0);
      return true;
    } catch (error) {
      debugPrint('ChimePlayer.unlock ล้มเหลว: $error');
      return false;
    } finally {
      // หยุดเสมอ แม้ _fire ล้ม — และให้ stop ล้มได้โดยไม่ทับผลลัพธ์ข้างบน (play ครั้งถัดไปตั้งเสียงกลับเป็น 1 เอง)
      try {
        await _player.stop();
      } catch (error) {
        debugPrint('ChimePlayer.unlock หยุดเสียงไม่สำเร็จ: $error');
      }
    }
  }

  @override
  Future<void> dispose() => _player.dispose();
}
