// Copyright 2026 Suruch Chakrapeesirisuk
// SPDX-License-Identifier: Apache-2.0

import 'package:get/get.dart';

import '../../features/ai_assistant/data/datasources/ai_assistant_remote_data_source.dart';
import '../../features/ai_assistant/data/models/ai_assistant_answer_model.dart';
import '../../features/audit_log/data/datasources/audit_log_remote_data_source.dart';
import '../../features/audit_log/data/models/audit_log_model.dart';
import '../../features/auth/data/datasources/auth_remote_data_source.dart';
import '../../features/auth/data/models/branch_model.dart';
import '../../features/auth/data/models/user_model.dart';
import '../../features/auth/domain/entities/login_result.dart';
import '../../features/backup/data/datasources/backup_remote_data_source.dart';
import '../../features/backup/domain/entities/backup_status.dart';
import '../../features/customer/data/datasources/customer_remote_data_source.dart';
import '../../features/customer/data/models/customer_model.dart';
import '../../features/customer/domain/entities/customer.dart';
import '../../features/erp_connection/data/datasources/erp_connection_remote_data_source.dart';
import '../../features/erp_connection/domain/entities/erp_connection_status.dart';
import '../../features/ingredient/data/datasources/ingredient_remote_data_source.dart';
import '../../features/ingredient/data/models/ingredient_model.dart';
import '../../features/menu/data/datasources/menu_remote_data_source.dart';
import '../../features/menu/data/models/category_model.dart';
import '../../features/menu/data/models/kitchen_station_model.dart';
import '../../features/menu/data/models/menu_item_model.dart';
import '../../features/menu/domain/entities/menu_item_payload.dart';
import '../../features/order/data/datasources/order_remote_data_source.dart';
import '../../features/order/domain/entities/order_item_payload.dart';
import '../../features/promotion/data/datasources/promotion_remote_data_source.dart';
import '../../features/promotion/data/models/promotion_model.dart';
import '../../features/receivable/data/datasources/receivable_remote_data_source.dart';
import '../../features/receivable/data/models/receivable_model.dart';
import '../../features/receivable/domain/entities/receivable.dart';
import '../../features/receivable/domain/repositories/receivable_repository.dart';
import '../../features/table/data/datasources/table_remote_data_source.dart';
import '../../features/table/data/models/dining_table_model.dart';
import '../../features/order/data/models/order_model.dart';
import '../../features/payment/data/datasources/payment_remote_data_source.dart';
import '../../features/payment/data/models/payment_model.dart';
import '../../features/payment/domain/entities/payment.dart';
import '../../features/report/data/datasources/report_remote_data_source.dart';
import '../../features/report/data/models/report_model.dart';
import '../../features/report/domain/entities/report.dart';
import '../../features/self_order/data/datasources/self_order_remote_data_source.dart';
import '../../features/scale/data/datasources/scale_remote_data_source.dart';
import '../../features/scale/domain/entities/scale_status.dart';
import '../../features/self_order/data/models/self_order_table_model.dart';
import '../../features/settings/data/datasources/settings_remote_data_source.dart';
import '../../features/settings/domain/entities/store_settings.dart';
import '../../features/shift/data/datasources/shift_remote_data_source.dart';
import '../../features/shift/data/models/shift_model.dart';
import '../../features/staff/data/datasources/staff_remote_data_source.dart';
import '../../features/tax_invoice/data/datasources/tax_invoice_remote_data_source.dart';
import '../../features/tax_invoice/data/models/tax_invoice_model.dart';
import '../constants/app_constants.dart';
import '../errors/exceptions.dart';
import '../utils/app_clock.dart';
import '../utils/promptpay.dart';
import 'demo_names.dart';
import 'demo_store.dart';

part 'demo_auth_data_source.dart';
part 'demo_menu_data_source.dart';
part 'demo_ingredient_data_source.dart';
part 'demo_table_data_source.dart';
part 'demo_order_data_source.dart';
part 'demo_promotion_data_source.dart';
part 'demo_payment_data_source.dart';
part 'demo_tax_invoice_data_source.dart';
part 'demo_shift_data_source.dart';
part 'demo_report_data_source.dart';
part 'demo_staff_data_source.dart';
part 'demo_settings_data_source.dart';
part 'demo_audit_log_data_source.dart';
part 'demo_customer_data_source.dart';
part 'demo_ai_assistant_data_source.dart';
part 'demo_self_order_data_source.dart';
part 'demo_receivable_data_source.dart';
part 'demo_scale_data_source.dart';
part 'demo_erp_connection_data_source.dart';
part 'demo_backup_data_source.dart';

/// Data source ชุด "Demo Mode"
///
/// สลับมาใช้ชุดนี้แทนตัวที่ยิง HTTP จริงได้โดยไม่ต้องแก้โค้ดหน้าจอหรือ use case เลย
/// เพราะทุกชั้นบนรู้จักแค่ abstract — เป็นประโยชน์ที่จับต้องได้ของการแยกชั้น
///
/// ใช้ตอน deploy ตัวอย่างผลงานขึ้น static hosting (ไม่มี backend ให้เรียก)
///
/// แยกเป็นไฟล์ย่อยต่อ 1 data source ด้วย `part`/`part of` (ดู `docs/CODING_STANDARDS.md` 2.2) —
/// ทุกคลาสในไฟล์ย่อยเป็นอิสระต่อกัน ไม่ได้แชร์ state เหมือน `DemoStore` แต่แชร์ helper `_delayed`
/// ตัวเดียวนี้ จึงยังใช้ part แทนแยกเป็นไฟล์ import ปกติ เพิ่ม data source ใหม่จากนี้ไปให้เพิ่มไฟล์
/// ย่อยใหม่ ไม่ใช่ต่อท้ายไฟล์ใดไฟล์หนึ่ง
Future<T> _delayed<T>(T Function() action) async {
  await Future<void>.delayed(DemoStore.latency);
  return action();
}
