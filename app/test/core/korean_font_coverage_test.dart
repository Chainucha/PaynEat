// Copyright 2026 Suruch Chakrapeesirisuk
// SPDX-License-Identifier: Apache-2.0

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:payneat_pos/core/demo/demo_names.dart';
import 'package:payneat_pos/core/demo/demo_seed.dart';
import 'package:get/get.dart';
import 'package:payneat_pos/core/localization/app_translations.dart';
import 'package:payneat_pos/core/localization/locale_service.dart';
import 'package:payneat_pos/core/utils/formatters.dart';

/// ฟอนต์เกาหลีที่ฝังไว้เป็น subset (KS X 1001 + ทุกตัวที่คำแปลใช้ ดู tool/fonts/subset_korean.py)
/// ถ้ามีคนเพิ่มคำแปลเกาหลีที่ใช้ตัวอักษรนอก subset ตัวนั้นจะกลายเป็นกล่องสี่เหลี่ยม
/// บนหน้าจอจริงโดยไม่มีอะไรเตือน — เทสต์นี้อ่าน cmap ของไฟล์ฟอนต์จริงมาเทียบ
void main() {
  test('ทุกตัวอักษรภาษาเกาหลีที่แอปแสดงต้องมี glyph อยู่ในฟอนต์ที่ฝังไว้', () async {
    final translations = AppTranslations().keys['ko_KR'];
    expect(translations, isNotNull, reason: 'ยังไม่ได้ลงทะเบียน ko_KR');

    final used = <int>{};
    for (final value in translations!.values) {
      used.addAll(value.runes);
    }

    // ข้อมูลสาธิตก็ถูกวาดด้วยฟอนต์เดียวกัน และเป็นสิ่งที่คนกดเข้ามาลองเห็นก่อน
    // คำแปล UI ด้วยซ้ำ — รอบแรกตรวจแค่คำแปล ชื่อเมนูภาษาเกาหลีจึงหลุดออกนอก
    // subset ได้โดยไม่มีอะไรฟ้อง
    //
    // รอบที่สองยังตกอีก 3 แหล่ง จนไปโผล่เป็นกล่องสี่เหลี่ยมกลางใบเสร็จ
    // ("할□니 부□", "2026□ 9월", "□지은") — ชื่อร้านใช้คีย์ storeName ไม่ใช่ name,
    // ชื่อพนักงานอยู่ใน users() ซึ่งไม่ได้อยู่ในลิสต์, และตัวอักษร 년/월/일
    // มาจาก pattern ของ DateFormat ไม่ได้อยู่ในข้อมูลสักชุด
    // บทเรียน: ต้องไล่จาก "สิ่งที่วาดบนจอ" ไม่ใช่ "ไฟล์ที่นึกออก"
    used.addAll(
      DemoNames.of(DemoSeed.settings(), lang: 'ko', key: 'storeName').runes,
    );
    for (final user in DemoSeed.users()) {
      used.addAll(DemoNames.of(user, lang: 'ko').runes);
    }
    // รูปแบบวันที่ภาษาเกาหลีมีตัวอักษรเกาหลีฝังอยู่ใน pattern เอง
    // เรียกผ่าน Formatters จริงแทนการพิมพ์ '년월일' ซ้ำไว้ในเทสต์
    // ถ้าวันหนึ่งมีคนเปลี่ยน pattern เทสต์จะตามไปเอง
    Get.locale = LocaleService.korean;
    used.addAll(Formatters.dateTime('2026-09-11T12:42:00Z').runes);
    used.addAll(Formatters.date(DateTime(2026, 9, 11)).runes);
    Get.locale = LocaleService.thai;

    for (final row in [
      ...DemoSeed.categories(),
      ...DemoSeed.menuItems(),
      ...DemoSeed.tables(),
    ]) {
      used.addAll(DemoNames.of(row, lang: 'ko').runes);
      final zoneKo = row['zoneKo'] as String?;
      if (zoneKo != null) used.addAll(zoneKo.runes);
      for (final group in (row['optionGroups'] as List? ?? const [])) {
        final g = (group as Map).cast<String, dynamic>();
        used.addAll(DemoNames.of(g, lang: 'ko').runes);
        for (final option in (g['options'] as List? ?? const [])) {
          used.addAll(
            DemoNames.of(
              (option as Map).cast<String, dynamic>(),
              lang: 'ko',
            ).runes,
          );
        }
      }
    }

    // วัตถุดิบ (ชื่อ + หน่วย) และคำอธิบายเมนู เพิ่งมีคำแปลเกาหลีตอนตรวจ UI หลัง ticket 18–20 —
    // เดิมเป็นไทยล้วนเลยไม่ต้องตรวจ พอแปลแล้วต้องตามมาตรวจด้วย ไม่งั้นหลุด subset เงียบ ๆ อีกรอบ
    for (final ingredient in DemoSeed.ingredients()) {
      used
        ..addAll(DemoNames.of(ingredient, lang: 'ko').runes)
        ..addAll(DemoNames.of(ingredient, lang: 'ko', key: 'unit').runes);
    }
    for (final menu in DemoSeed.menuItems()) {
      used.addAll(DemoNames.of(menu, lang: 'ko', key: 'description').runes);
    }
    // ชื่อ/ที่อยู่ลูกค้าเครดิตมีภาษาเกาหลีตั้งแต่ DECISIONS #74
    for (final customer in DemoSeed.customers()) {
      used
        ..addAll(DemoNames.of(customer, lang: 'ko').runes)
        ..addAll(DemoNames.of(customer, lang: 'ko', key: 'address').runes);
    }

    // ข้อความมาตรฐานของ Material (ปฏิทิน/นาฬิกา/ปุ่มยกเลิก-ตกลง/คัดลอก-วาง) มาจาก
    // flutter_localizations ตั้งแต่ DECISIONS #64 — วาดด้วยฟอนต์เดียวกัน จึงต้องอยู่ใน subset ด้วย
    used.addAll(await _materialKoreanRunes());

    // ข้อความ error ภาษาเกาหลีจาก backend (ตอนต่อ backend จริง) ก็วาดด้วยฟอนต์นี้ (#64)
    // อ่านจากไฟล์แคตตาล็อกฝั่ง backend ตรง ๆ — เพิ่มข้อความใหม่ที่นั่นแล้วลืม subset จะล้มที่นี่
    final catalogue = File(
      '../backend/src/i18n/errorMessages.js',
    ).readAsStringSync();
    for (final m in RegExp(
      r'''ko:\s*(?:'((?:\\.|[^'\\])*)'|"((?:\\.|[^"\\])*)")''',
    ).allMatches(catalogue)) {
      used.addAll((m.group(1) ?? m.group(2)!).runes);
    }

    final covered = _cmapOf('assets/fonts/NotoSansKR-400.ttf')
      ..addAll(_cmapOf('assets/fonts/NotoSansThai-400.ttf'));

    // ตัวอักษรที่ไม่ต้องมีในฟอนต์: อีโมจิ (ระบบปฏิบัติการวาดเอง) และช่องว่าง
    bool needsGlyph(int rune) =>
        rune > 0x20 && !(rune >= 0x1F000 && rune <= 0x1FAFF);

    final missing = used.where(needsGlyph).where((r) => !covered.contains(r));

    expect(
      missing,
      isEmpty,
      reason:
          'อักษรเหล่านี้ไม่มีในฟอนต์ที่ฝังไว้ จะขึ้นเป็นกล่องบนหน้าจอจริง: '
          '${missing.map((r) => String.fromCharCode(r)).join()} — '
          'ต้อง subset ฟอนต์ใหม่ (ดู docs/DECISIONS.md)',
    );
  });

  // ผู้ใช้แอปภาษาเกาหลีพิมพ์ข้อมูลเป็นภาษาเกาหลีด้วย (ชื่อลูกค้า ชื่อโปร หมายเหตุ) แม้เป็นพนักงาน
  // คนไทย — subset เดิมมีแค่อักษรที่คำแปลใช้ พิมพ์ "첫 방문" แล้ว 첫 กลายเป็นกล่อง (DECISIONS #74)
  // จึงเก็บพยางค์ KS X 1001 ครบ 2,350 ตัวในทุกน้ำหนัก เทสต์นี้กันไม่ให้ใครตัดกลับไปเหลือแค่คำแปล
  test('ฟอนต์เกาหลีทุกน้ำหนักพิมพ์ภาษาเกาหลีทั่วไปได้ ไม่ใช่แค่คำแปล', () {
    for (final weight in [400, 500, 700, 800]) {
      final cmap = _cmapOf('assets/fonts/NotoSansKR-$weight.ttf');
      final syllables = cmap.where((r) => r >= 0xAC00 && r <= 0xD7A3);
      expect(
        syllables.length,
        greaterThanOrEqualTo(2350),
        reason: 'NotoSansKR-$weight มีพยางค์ฮันกึลแค่ ${syllables.length} ตัว',
      );
      // จาโมแบบ compatibility คือสิ่งที่เห็นระหว่างพิมพ์ผ่าน IME ก่อนประกอบเป็นพยางค์
      final jamo = [for (var r = 0x3131; r <= 0x318E; r++) r];
      expect(
        jamo.where((r) => !cmap.contains(r)),
        isEmpty,
        reason: 'NotoSansKR-$weight ขาดจาโม',
      );
      // ตัวที่เคยหลุดจริงในภาพหน้าจอและข้อมูลสาธิต
      for (final rune in '첫꿔땅윤강'.runes) {
        expect(
          cmap.contains(rune),
          isTrue,
          reason: 'NotoSansKR-$weight ขาด ${String.fromCharCode(rune)}',
        );
      }
    }
  });
}

/// ตัวอักษรทุกตัวในข้อความ Material ภาษาเกาหลีที่แอปมีโอกาสแสดง — กล่องเลือกวัน/ช่วงวัน/เวลา
/// (ใช้ในโปรโมชัน รายงาน ประวัติการทำรายการ), ปุ่มมาตรฐานของ dialog, เมนูคัดลอก-วางของช่องกรอก
Future<Set<int>> _materialKoreanRunes() async {
  final l = await GlobalMaterialLocalizations.delegate.load(const Locale('ko'));
  final texts = <String>[
    l.cancelButtonLabel,
    l.okButtonLabel,
    l.closeButtonLabel,
    l.continueButtonLabel,
    l.saveButtonLabel,
    l.backButtonTooltip,
    l.closeButtonTooltip,
    l.deleteButtonTooltip,
    l.moreButtonTooltip,
    l.showMenuTooltip,
    l.copyButtonLabel,
    l.cutButtonLabel,
    l.pasteButtonLabel,
    l.selectAllButtonLabel,
    l.lookUpButtonLabel,
    l.searchWebButtonLabel,
    l.shareButtonLabel,
    l.searchFieldLabel,
    l.modalBarrierDismissLabel,
    l.dialogLabel,
    l.alertDialogLabel,
    l.datePickerHelpText,
    l.dateRangePickerHelpText,
    l.dateHelpText,
    l.dateInputLabel,
    l.dateRangeStartLabel,
    l.dateRangeEndLabel,
    l.dateOutOfRangeLabel,
    l.invalidDateFormatLabel,
    l.invalidDateRangeLabel,
    l.unspecifiedDate,
    l.unspecifiedDateRange,
    l.calendarModeButtonLabel,
    l.inputDateModeButtonLabel,
    l.previousMonthTooltip,
    l.nextMonthTooltip,
    l.selectYearSemanticsLabel,
    l.currentDateLabel,
    l.timePickerDialHelpText,
    l.timePickerInputHelpText,
    l.timePickerHourLabel,
    l.timePickerMinuteLabel,
    l.timePickerHourModeAnnouncement,
    l.timePickerMinuteModeAnnouncement,
    l.dialModeButtonLabel,
    l.inputTimeModeButtonLabel,
    l.invalidTimeLabel,
    l.anteMeridiemAbbreviation,
    l.postMeridiemAbbreviation,
    l.refreshIndicatorSemanticLabel,
    l.drawerLabel,
    l.popupMenuLabel,
    l.menuDismissLabel,
    l.clearButtonTooltip,
    l.selectedDateLabel,
    ...l.narrowWeekdays,
  ];
  for (var month = 1; month <= 12; month++) {
    final date = DateTime(2026, month, 28);
    texts
      ..add(l.formatMonthYear(date))
      ..add(l.formatMediumDate(date))
      ..add(l.formatFullDate(date))
      ..add(l.formatShortDate(date))
      ..add(l.formatShortMonthDay(date));
  }
  return {for (final text in texts) ...text.runes};
}

/// อ่านตาราง cmap ของไฟล์ TrueType ตรง ๆ — คืนชุด code point ที่ฟอนต์รองรับ
Set<int> _cmapOf(String path) {
  final bytes = File(path).readAsBytesSync().buffer.asByteData();
  final numTables = bytes.getUint16(4);

  var cmapOffset = -1;
  for (var i = 0; i < numTables; i++) {
    final rec = 12 + i * 16;
    final tag = String.fromCharCodes(
      List.generate(4, (j) => bytes.getUint8(rec + j)),
    );
    if (tag == 'cmap') cmapOffset = bytes.getUint32(rec + 8);
  }
  if (cmapOffset < 0) return <int>{};

  // เลือก subtable แบบ format 4 (Unicode BMP) ซึ่ง Noto ใช้เป็นหลัก
  final numSub = bytes.getUint16(cmapOffset + 2);
  var best = -1;
  for (var i = 0; i < numSub; i++) {
    final rec = cmapOffset + 4 + i * 8;
    final platform = bytes.getUint16(rec);
    final encoding = bytes.getUint16(rec + 2);
    final offset = cmapOffset + bytes.getUint32(rec + 4);
    final isUnicode = platform == 0 || (platform == 3 && encoding >= 1);
    if (isUnicode && bytes.getUint16(offset) == 4) best = offset;
  }
  if (best < 0) return <int>{};

  final segCount = bytes.getUint16(best + 6) ~/ 2;
  final endBase = best + 14;
  final startBase = endBase + segCount * 2 + 2;

  final out = <int>{};
  for (var s = 0; s < segCount; s++) {
    final end = bytes.getUint16(endBase + s * 2);
    final start = bytes.getUint16(startBase + s * 2);
    if (start > end || end == 0xFFFF) continue;
    for (var c = start; c <= end; c++) {
      out.add(c);
    }
  }
  return out;
}
