// Copyright 2026 Suruch Chakrapeesirisuk
// SPDX-License-Identifier: Apache-2.0

import 'package:get/get.dart';

/// ชื่อหน่วยของรหัสหน่วยฐานใน PaynEat ERP (kg, piece, l …) ตามภาษาของแอป — รหัสที่แอปไม่รู้จัก
/// แสดงรหัสตรง ๆ ไม่เดา (ดู docs/tickets/25-erp-connected-mode.md)
class ErpUnitLabel {
  const ErpUnitLabel._();

  static String of(String code, {String Function(String key)? translate}) {
    final key = 'erp_unit_$code';
    final text = (translate ?? (value) => value.tr)(key);
    return text == key ? code : text;
  }
}
