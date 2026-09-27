// Copyright 2026 Suruch Chakrapeesirisuk
// SPDX-License-Identifier: Apache-2.0

import 'package:get/get.dart';

import '../../../core/services/storage_service.dart';
import '../../../features/ai_assistant/data/datasources/ai_assistant_remote_data_source.dart';
import '../../../features/ai_assistant/data/repositories/ai_assistant_repository_impl.dart';
import '../../../features/ai_assistant/domain/repositories/ai_assistant_repository.dart';
import '../../../features/audit_log/data/datasources/audit_log_remote_data_source.dart';
import '../../../features/audit_log/data/repositories/audit_log_repository_impl.dart';
import '../../../features/audit_log/domain/repositories/audit_log_repository.dart';
import '../../../features/auth/data/datasources/auth_remote_data_source.dart';
import '../../../features/auth/data/repositories/auth_repository_impl.dart';
import '../../../features/auth/domain/repositories/auth_repository.dart';
import '../../../features/customer/data/datasources/customer_remote_data_source.dart';
import '../../../features/customer/data/repositories/customer_repository_impl.dart';
import '../../../features/customer/domain/repositories/customer_repository.dart';
import '../../../features/erp_connection/data/datasources/erp_connection_remote_data_source.dart';
import '../../../features/erp_connection/data/repositories/erp_connection_repository_impl.dart';
import '../../../features/erp_connection/domain/repositories/erp_connection_repository.dart';
import '../../../features/ingredient/data/datasources/ingredient_remote_data_source.dart';
import '../../../features/ingredient/data/repositories/ingredient_repository_impl.dart';
import '../../../features/ingredient/domain/repositories/ingredient_repository.dart';
import '../../../features/menu/data/datasources/menu_remote_data_source.dart';
import '../../../features/menu/data/repositories/menu_repository_impl.dart';
import '../../../features/menu/domain/repositories/menu_repository.dart';
import '../../../features/order/data/datasources/order_remote_data_source.dart';
import '../../../features/order/data/repositories/order_repository_impl.dart';
import '../../../features/order/domain/repositories/order_repository.dart';
import '../../../features/payment/data/datasources/payment_remote_data_source.dart';
import '../../../features/payment/data/repositories/payment_repository_impl.dart';
import '../../../features/payment/domain/repositories/payment_repository.dart';
import '../../../features/promotion/data/datasources/promotion_remote_data_source.dart';
import '../../../features/promotion/data/repositories/promotion_repository_impl.dart';
import '../../../features/promotion/domain/repositories/promotion_repository.dart';
import '../../../features/report/data/datasources/report_remote_data_source.dart';
import '../../../features/report/data/repositories/report_repository_impl.dart';
import '../../../features/report/domain/repositories/report_repository.dart';
import '../../../features/self_order/data/datasources/self_order_remote_data_source.dart';
import '../../../features/self_order/data/repositories/self_order_repository_impl.dart';
import '../../../features/scale/data/datasources/scale_remote_data_source.dart';
import '../../../features/scale/data/repositories/scale_repository_impl.dart';
import '../../../features/scale/domain/repositories/scale_repository.dart';
import '../../../features/self_order/domain/repositories/self_order_repository.dart';
import '../../../features/settings/data/datasources/settings_remote_data_source.dart';
import '../../../features/settings/data/repositories/settings_repository_impl.dart';
import '../../../features/settings/domain/repositories/settings_repository.dart';
import '../../../features/shift/data/datasources/shift_remote_data_source.dart';
import '../../../features/shift/data/repositories/shift_repository_impl.dart';
import '../../../features/shift/domain/repositories/shift_repository.dart';
import '../../../features/staff/data/datasources/staff_remote_data_source.dart';
import '../../../features/staff/data/repositories/staff_repository_impl.dart';
import '../../../features/staff/domain/repositories/staff_repository.dart';
import '../../../features/table/data/datasources/table_remote_data_source.dart';
import '../../../features/table/data/repositories/table_repository_impl.dart';
import '../../../features/table/domain/repositories/table_repository.dart';
import '../../../features/receivable/data/datasources/receivable_remote_data_source.dart';
import '../../../features/receivable/data/repositories/receivable_repository_impl.dart';
import '../../../features/receivable/domain/repositories/receivable_repository.dart';
import '../../../features/tax_invoice/data/datasources/tax_invoice_remote_data_source.dart';
import '../../../features/tax_invoice/data/repositories/tax_invoice_repository_impl.dart';
import '../../../features/tax_invoice/domain/repositories/tax_invoice_repository.dart';

/// ผูก repository ของทุกโดเมน — สร้างจาก data source ที่ `bindDataSources()` ผูกไว้แล้วเสมอ
/// (real หรือ demo ก็ได้ ชั้นนี้ไม่รู้และไม่สนใจ)
void bindRepositories(StorageService storage) {
  Get.lazyPut<AuthRepository>(
    () => AuthRepositoryImpl(
      remote: Get.find<AuthRemoteDataSource>(),
      storage: storage,
    ),
    fenix: true,
  );
  Get.lazyPut<MenuRepository>(
    () => MenuRepositoryImpl(Get.find<MenuRemoteDataSource>()),
    fenix: true,
  );
  Get.lazyPut<IngredientRepository>(
    () => IngredientRepositoryImpl(Get.find<IngredientRemoteDataSource>()),
    fenix: true,
  );
  Get.lazyPut<TableRepository>(
    () => TableRepositoryImpl(Get.find<TableRemoteDataSource>()),
    fenix: true,
  );
  Get.lazyPut<OrderRepository>(
    () => OrderRepositoryImpl(Get.find<OrderRemoteDataSource>()),
    fenix: true,
  );
  Get.lazyPut<PaymentRepository>(
    () => PaymentRepositoryImpl(Get.find<PaymentRemoteDataSource>()),
    fenix: true,
  );
  Get.lazyPut<PromotionRepository>(
    () => PromotionRepositoryImpl(Get.find<PromotionRemoteDataSource>()),
    fenix: true,
  );
  Get.lazyPut<ReportRepository>(
    () => ReportRepositoryImpl(Get.find<ReportRemoteDataSource>()),
    fenix: true,
  );
  Get.lazyPut<StaffRepository>(
    () => StaffRepositoryImpl(Get.find<StaffRemoteDataSource>()),
    fenix: true,
  );
  Get.lazyPut<SettingsRepository>(
    () => SettingsRepositoryImpl(Get.find<SettingsRemoteDataSource>()),
    fenix: true,
  );
  Get.lazyPut<ShiftRepository>(
    () => ShiftRepositoryImpl(Get.find<ShiftRemoteDataSource>()),
    fenix: true,
  );
  Get.lazyPut<TaxInvoiceRepository>(
    () => TaxInvoiceRepositoryImpl(Get.find<TaxInvoiceRemoteDataSource>()),
    fenix: true,
  );
  Get.lazyPut<AuditLogRepository>(
    () => AuditLogRepositoryImpl(Get.find<AuditLogRemoteDataSource>()),
    fenix: true,
  );
  Get.lazyPut<CustomerRepository>(
    () => CustomerRepositoryImpl(Get.find<CustomerRemoteDataSource>()),
    fenix: true,
  );
  Get.lazyPut<AiAssistantRepository>(
    () => AiAssistantRepositoryImpl(Get.find<AiAssistantRemoteDataSource>()),
    fenix: true,
  );
  Get.lazyPut<SelfOrderRepository>(
    () => SelfOrderRepositoryImpl(Get.find<SelfOrderRemoteDataSource>()),
    fenix: true,
  );
  Get.lazyPut<ReceivableRepository>(
    () => ReceivableRepositoryImpl(Get.find<ReceivableRemoteDataSource>()),
    fenix: true,
  );
  Get.lazyPut<ScaleRepository>(
    () => ScaleRepositoryImpl(Get.find<ScaleRemoteDataSource>()),
    fenix: true,
  );
  Get.lazyPut<ErpConnectionRepository>(
    () =>
        ErpConnectionRepositoryImpl(Get.find<ErpConnectionRemoteDataSource>()),
    fenix: true,
  );
}
