// Copyright 2026 Suruch Chakrapeesirisuk
// SPDX-License-Identifier: Apache-2.0

import 'package:get/get.dart';
import 'package:intl/intl.dart';
import '../localization/locale_service.dart';
import 'app_clock.dart';

/// จัดรูปแบบจำนวนเงินและวันที่ให้ตรงกับที่คนไทยอ่านแล้วเข้าใจทันที
class Formatters {
  const Formatters._();

  static final NumberFormat _money = NumberFormat('#,##0.00', 'en_US');
  static final NumberFormat _compact = NumberFormat('#,##0', 'en_US');
  static final DateFormat _time = DateFormat('HH:mm');
  static final DateFormat _isoDate = DateFormat('yyyy-MM-dd');

  /// รูปแบบวันที่ต่อภาษา
  ///
  /// ไทยกับอังกฤษใช้ `d MMM yyyy` เหมือนเดิมทุกประการ — จงใจไม่แตะ เพราะรูปแบบนี้
  /// ไปโผล่บนใบเสร็จที่พิมพ์ออกเครื่องจริงและบนภาพ golden ทุกใบ การเปลี่ยนเป็น
  /// เรื่องที่เจ้าของร้านควรตัดสินใจเอง ไม่ใช่ผลพลอยได้ของงานเพิ่มภาษา
  ///
  /// เกาหลีเขียน "2026년 9월 11일" ไม่ใช่ "11 Sep 2026" — ใบเสร็จเกาหลีที่ขึ้นเดือน
  /// เป็นตัวย่อภาษาอังกฤษอ่านแล้วรู้ทันทีว่าเป็นระบบที่แปลมาไม่สุด
  /// (ใช้ตัวอักษรเกาหลีในตัว pattern เลย จึงไม่ต้องโหลด locale data ของ intl)
  static final Map<String, (DateFormat date, DateFormat dateTime)> _formats = {
    'ko': (DateFormat('yyyy년 M월 d일'), DateFormat('yyyy년 M월 d일 HH:mm')),
  };

  static final (DateFormat, DateFormat) _default = (
    DateFormat('d MMM yyyy'),
    DateFormat('d MMM yyyy HH:mm'),
  );

  static (DateFormat, DateFormat) get _current =>
      _formats[LocaleService.languageCode] ?? _default;

  static DateFormat get _date => _current.$1;
  static DateFormat get _dateTime => _current.$2;

  static String money(num value) => _money.format(value);

  static String baht(num value) => '฿${_money.format(value)}';

  static String compact(num value) => _compact.format(value);

  /// น้ำหนักจากกรัม เช่น 485 → "0.485 กก." (ภาษาอังกฤษ/เกาหลี "0.485 kg") — ทศนิยม 3 ตำแหน่งเสมอ
  /// ตรงกับความละเอียดของตาชั่ง (ดู docs/tickets/18-sell-by-weight.md)
  static String weight(int grams) =>
      'common_weight_kg'.trParams({'kg': (grams / 1000).toStringAsFixed(3)});

  /// ราคาต่อกิโลกรัม เช่น "฿280.00/กก."
  static String bahtPerKg(num value) => '${baht(value)}${'common_per_kg'.tr}';

  /// backend เก็บเวลาเป็น UTC → แปลงเป็นเวลาเครื่องก่อนแสดง
  static DateTime? parse(String? value) {
    if (value == null || value.isEmpty) return null;
    final normalized = value.contains('T')
        ? value
        : value.replaceFirst(' ', 'T');
    final withZone = normalized.endsWith('Z') ? normalized : '${normalized}Z';
    return DateTime.tryParse(withZone)?.toLocal();
  }

  static String time(String? value) {
    final date = parse(value);
    return date == null ? '-' : _time.format(date);
  }

  static String dateTime(String? value) {
    final date = parse(value);
    return date == null ? '-' : _dateTime.format(date);
  }

  static String date(DateTime value) => _date.format(value);

  /// เวลาที่แปลงเป็นเวลาเครื่องแล้ว เช่น เวลาสำรองข้อมูลล่าสุด (ticket 33)
  static String dateTimeOf(DateTime value) => _dateTime.format(value.toLocal());

  /// ขนาดไฟล์แบบอ่านง่าย เช่น "4.2 MB" — หน่วยเป็นสากลจึงไม่ผ่านคำแปล
  static String fileSize(int bytes) {
    const units = ['B', 'KB', 'MB', 'GB'];
    var size = bytes.toDouble();
    var unit = 0;
    while (size >= 1024 && unit < units.length - 1) {
      size /= 1024;
      unit++;
    }
    return unit == 0 ? '$bytes B' : '${size.toStringAsFixed(1)} ${units[unit]}';
  }

  static String isoDate(DateTime value) => _isoDate.format(value);

  /// วันครบกำหนดชำระ — backend ส่งมาเป็นวันที่ล้วน "2026-10-11" (ไม่มีเวลา/โซนเวลา)
  /// เดิมหน้าลูกหนี้โชว์สตริงนี้ตรง ๆ ทุกภาษา อ่านเหมือนหน้าจอโปรแกรมเมอร์ ไม่ใช่เอกสารการค้า
  /// ห้ามส่งผ่าน [parse] — มันเติม Z แล้วแปลงเป็นเวลาเครื่อง วันครบกำหนดอาจเลื่อนไปหนึ่งวัน
  static String dueDate(String? value) {
    if (value == null || value.length < 10) return value ?? '-';
    final date = DateTime.tryParse(value.substring(0, 10));
    return date == null ? value : _date.format(date);
  }

  /// เวลาที่ผ่านไปแบบอ่านง่าย เช่น "5 นาทีที่แล้ว" — ใช้ในจอครัวเพื่อดูว่าออเดอร์รอนานแค่ไหน
  static String elapsed(String? value) {
    final date = parse(value);
    if (date == null) return '-';
    final diff = AppClock.now().difference(date);
    if (diff.inSeconds < 60) return 'common_time_just_now'.tr;
    if (diff.inMinutes < 60) {
      return 'common_time_minutes'.trParams({
        'minutes': diff.inMinutes.toString(),
      });
    }
    if (diff.inHours < 24) {
      return 'common_time_hours_minutes'.trParams({
        'hours': diff.inHours.toString(),
        'minutes': (diff.inMinutes % 60).toString(),
      });
    }
    return 'common_time_days'.trParams({'days': diff.inDays.toString()});
  }

  static int elapsedMinutes(String? value) {
    final date = parse(value);
    if (date == null) return 0;
    return AppClock.now().difference(date).inMinutes;
  }
}
