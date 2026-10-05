// Copyright 2026 Suruch Chakrapeesirisuk
// SPDX-License-Identifier: Apache-2.0

import 'package:flutter/widgets.dart';
import 'package:get/get.dart';

import 'translations/ai_assistant_translations.dart';
import 'translations/audit_log_translations.dart';
import 'translations/auth_translations.dart';
import 'translations/backup_translations.dart';
import 'translations/common_translations.dart';
import 'translations/customer_translations.dart';
import 'translations/erp_connection_translations.dart';
import 'translations/home_translations.dart';
import 'translations/ingredient_translations.dart';
import 'translations/kitchen_translations.dart';
import 'translations/menu_translations.dart';
import 'translations/order_translations.dart';
import 'translations/payment_translations.dart';
import 'translations/printing_translations.dart';
import 'translations/promotion_translations.dart';
import 'translations/receivable_document_translations.dart';
import 'translations/receivable_translations.dart';
import 'translations/report_translations.dart';
import 'translations/scale_translations.dart';
import 'translations/self_order_translations.dart';
import 'translations/settings_translations.dart';
import 'translations/shift_translations.dart';
import 'translations/staff_translations.dart';
import 'translations/status_translations.dart';
import 'translations/table_translations.dart';
import 'translations/tax_invoice_translations.dart';

/// รวมคำแปลทั้งแอป — ไทย (ค่าเริ่มต้น) อังกฤษ และเกาหลี
///
/// แต่ละฟีเจอร์มีไฟล์คำแปลของตัวเองใน translations/ เพื่อให้แก้ไขแยกกันได้
/// โดยไม่ชนกัน ไฟล์นี้แค่รวมทุกอย่างเข้าด้วยกัน
class AppTranslations extends Translations {
  static const List<Locale> supportedLocales = [
    Locale('th', 'TH'),
    Locale('en', 'US'),
    Locale('ko', 'KR'),
  ];

  static const Locale fallbackLocale = Locale('en', 'US');

  @override
  Map<String, Map<String, String>> get keys => {
    'th_TH': {
      ...commonTranslationsTh,
      ...statusTranslationsTh,
      ...auditLogTranslationsTh,
      ...authTranslationsTh,
      ...customerTranslationsTh,
      ...erpConnectionTranslationsTh,
      ...backupTranslationsTh,
      ...homeTranslationsTh,
      ...ingredientTranslationsTh,
      ...kitchenTranslationsTh,
      ...menuTranslationsTh,
      ...orderTranslationsTh,
      ...paymentTranslationsTh,
      ...printingTranslationsTh,
      ...promotionTranslationsTh,
      ...receivableTranslationsTh,
      ...receivableDocumentTranslationsTh,
      ...scaleTranslationsTh,
      ...reportTranslationsTh,
      ...selfOrderTranslationsTh,
      ...settingsTranslationsTh,
      ...shiftTranslationsTh,
      ...staffTranslationsTh,
      ...tableTranslationsTh,
      ...taxInvoiceTranslationsTh,
      ...aiAssistantTranslationsTh,
    },
    'en_US': {
      ...commonTranslationsEn,
      ...statusTranslationsEn,
      ...auditLogTranslationsEn,
      ...authTranslationsEn,
      ...customerTranslationsEn,
      ...erpConnectionTranslationsEn,
      ...backupTranslationsEn,
      ...homeTranslationsEn,
      ...ingredientTranslationsEn,
      ...kitchenTranslationsEn,
      ...menuTranslationsEn,
      ...orderTranslationsEn,
      ...paymentTranslationsEn,
      ...printingTranslationsEn,
      ...promotionTranslationsEn,
      ...receivableTranslationsEn,
      ...receivableDocumentTranslationsEn,
      ...scaleTranslationsEn,
      ...reportTranslationsEn,
      ...selfOrderTranslationsEn,
      ...settingsTranslationsEn,
      ...shiftTranslationsEn,
      ...staffTranslationsEn,
      ...tableTranslationsEn,
      ...taxInvoiceTranslationsEn,
      ...aiAssistantTranslationsEn,
    },
    'ko_KR': {
      ...commonTranslationsKo,
      ...statusTranslationsKo,
      ...auditLogTranslationsKo,
      ...authTranslationsKo,
      ...customerTranslationsKo,
      ...erpConnectionTranslationsKo,
      ...backupTranslationsKo,
      ...homeTranslationsKo,
      ...ingredientTranslationsKo,
      ...kitchenTranslationsKo,
      ...menuTranslationsKo,
      ...orderTranslationsKo,
      ...paymentTranslationsKo,
      ...printingTranslationsKo,
      ...promotionTranslationsKo,
      ...receivableTranslationsKo,
      ...receivableDocumentTranslationsKo,
      ...scaleTranslationsKo,
      ...reportTranslationsKo,
      ...selfOrderTranslationsKo,
      ...settingsTranslationsKo,
      ...shiftTranslationsKo,
      ...staffTranslationsKo,
      ...tableTranslationsKo,
      ...taxInvoiceTranslationsKo,
      ...aiAssistantTranslationsKo,
    },
  };
}
