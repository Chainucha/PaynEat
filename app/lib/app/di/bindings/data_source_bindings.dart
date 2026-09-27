// Copyright 2026 Suruch Chakrapeesirisuk
// SPDX-License-Identifier: Apache-2.0

import 'package:get/get.dart';

import '../../../core/demo/demo_data_sources.dart';
import '../../../core/demo/demo_store.dart';
import '../../../core/network/api_client.dart';
import '../../../core/network/socket_client.dart';
import '../../../features/ai_assistant/data/datasources/ai_assistant_remote_data_source.dart';
import '../../../features/audit_log/data/datasources/audit_log_remote_data_source.dart';
import '../../../features/auth/data/datasources/auth_remote_data_source.dart';
import '../../../features/customer/data/datasources/customer_remote_data_source.dart';
import '../../../features/erp_connection/data/datasources/erp_connection_remote_data_source.dart';
import '../../../features/ingredient/data/datasources/ingredient_remote_data_source.dart';
import '../../../features/menu/data/datasources/menu_remote_data_source.dart';
import '../../../features/order/data/datasources/order_remote_data_source.dart';
import '../../../features/payment/data/datasources/payment_remote_data_source.dart';
import '../../../features/promotion/data/datasources/promotion_remote_data_source.dart';
import '../../../features/receivable/data/datasources/receivable_remote_data_source.dart';
import '../../../features/report/data/datasources/report_remote_data_source.dart';
import '../../../features/scale/data/datasources/scale_remote_data_source.dart';
import '../../../features/self_order/data/datasources/self_order_remote_data_source.dart';
import '../../../features/settings/data/datasources/settings_remote_data_source.dart';
import '../../../features/shift/data/datasources/shift_remote_data_source.dart';
import '../../../features/staff/data/datasources/staff_remote_data_source.dart';
import '../../../features/table/data/datasources/table_remote_data_source.dart';
import '../../../features/tax_invoice/data/datasources/tax_invoice_remote_data_source.dart';
import '../../config/app_config.dart';

/// ผูก data source ของทุกโดเมน — สลับได้ทั้งชุดระหว่างของจริง (ยิง HTTP) กับ Demo Mode
/// ด้วยเงื่อนไขเดียว (`AppConfig.demoMode`) ชั้นอื่นทั้งหมดรู้จักแค่ abstract จึงไม่ต้องแก้อะไรเลย
void bindDataSources() {
  if (AppConfig.demoMode) {
    _bindDemoDataSources();
    return;
  }

  final client = Get.find<ApiClient>();

  Get.lazyPut<AuthRemoteDataSource>(
    () => AuthRemoteDataSourceImpl(client),
    fenix: true,
  );
  Get.lazyPut<MenuRemoteDataSource>(
    () => MenuRemoteDataSourceImpl(client),
    fenix: true,
  );
  Get.lazyPut<IngredientRemoteDataSource>(
    () => IngredientRemoteDataSourceImpl(client),
    fenix: true,
  );
  Get.lazyPut<TableRemoteDataSource>(
    () => TableRemoteDataSourceImpl(client),
    fenix: true,
  );
  Get.lazyPut<OrderRemoteDataSource>(
    () => OrderRemoteDataSourceImpl(client),
    fenix: true,
  );
  Get.lazyPut<PaymentRemoteDataSource>(
    () => PaymentRemoteDataSourceImpl(client),
    fenix: true,
  );
  Get.lazyPut<PromotionRemoteDataSource>(
    () => PromotionRemoteDataSourceImpl(client),
    fenix: true,
  );
  Get.lazyPut<ReportRemoteDataSource>(
    () => ReportRemoteDataSourceImpl(client),
    fenix: true,
  );
  Get.lazyPut<StaffRemoteDataSource>(
    () => StaffRemoteDataSourceImpl(client),
    fenix: true,
  );
  Get.lazyPut<SettingsRemoteDataSource>(
    () => SettingsRemoteDataSourceImpl(client),
    fenix: true,
  );
  Get.lazyPut<ShiftRemoteDataSource>(
    () => ShiftRemoteDataSourceImpl(client),
    fenix: true,
  );
  Get.lazyPut<TaxInvoiceRemoteDataSource>(
    () => TaxInvoiceRemoteDataSourceImpl(client),
    fenix: true,
  );
  Get.lazyPut<AuditLogRemoteDataSource>(
    () => AuditLogRemoteDataSourceImpl(client),
    fenix: true,
  );
  Get.lazyPut<CustomerRemoteDataSource>(
    () => CustomerRemoteDataSourceImpl(client),
    fenix: true,
  );
  Get.lazyPut<AiAssistantRemoteDataSource>(
    () => AiAssistantRemoteDataSourceImpl(client),
    fenix: true,
  );
  // ดู docs/tickets/17-qr-self-order.md — ใช้ ApiClient ตัวเดียวกับทุกโดเมน แต่ endpoint
  // ปลายทางเป็น /public/* ที่ไม่เช็ค Authorization header เลย
  Get.lazyPut<SelfOrderRemoteDataSource>(
    () => SelfOrderRemoteDataSourceImpl(client),
    fenix: true,
  );
  Get.lazyPut<ReceivableRemoteDataSource>(
    () => ReceivableRemoteDataSourceImpl(client),
    fenix: true,
  );
  Get.lazyPut<ScaleRemoteDataSource>(
    () => ScaleRemoteDataSourceImpl(client, Get.find<SocketClient>()),
    fenix: true,
  );
  Get.lazyPut<ErpConnectionRemoteDataSource>(
    () => ErpConnectionRemoteDataSourceImpl(client),
    fenix: true,
  );
}

/// โหมดสาธิต: เปลี่ยนเฉพาะชั้น data source ชั้นอื่นทั้งหมดไม่ต้องแก้แม้แต่บรรทัดเดียว
void _bindDemoDataSources() {
  final store = DemoStore.instance;
  final auth = DemoAuthDataSource(store);

  Get.put<AuthRemoteDataSource>(auth, permanent: true);
  Get.put<MenuRemoteDataSource>(
    DemoMenuDataSource(store, auth),
    permanent: true,
  );
  Get.put<IngredientRemoteDataSource>(
    DemoIngredientDataSource(store, auth),
    permanent: true,
  );
  Get.put<TableRemoteDataSource>(DemoTableDataSource(store), permanent: true);
  Get.put<OrderRemoteDataSource>(
    DemoOrderDataSource(store, auth),
    permanent: true,
  );
  Get.put<PaymentRemoteDataSource>(
    DemoPaymentDataSource(store, auth),
    permanent: true,
  );
  Get.put<PromotionRemoteDataSource>(
    DemoPromotionDataSource(store, auth),
    permanent: true,
  );
  Get.put<ReportRemoteDataSource>(DemoReportDataSource(store), permanent: true);
  Get.put<StaffRemoteDataSource>(
    DemoStaffDataSource(store, auth),
    permanent: true,
  );
  Get.put<SettingsRemoteDataSource>(
    DemoSettingsDataSource(store, auth),
    permanent: true,
  );
  Get.put<ShiftRemoteDataSource>(
    DemoShiftDataSource(store, auth),
    permanent: true,
  );
  Get.put<TaxInvoiceRemoteDataSource>(
    DemoTaxInvoiceDataSource(store, auth),
    permanent: true,
  );
  Get.put<AuditLogRemoteDataSource>(
    DemoAuditLogDataSource(store),
    permanent: true,
  );
  Get.put<CustomerRemoteDataSource>(
    DemoCustomerDataSource(store, auth),
    permanent: true,
  );
  Get.put<AiAssistantRemoteDataSource>(
    const DemoAiAssistantDataSource(),
    permanent: true,
  );
  Get.put<SelfOrderRemoteDataSource>(
    DemoSelfOrderDataSource(store),
    permanent: true,
  );
  Get.put<ReceivableRemoteDataSource>(
    DemoReceivableDataSource(store, auth),
    permanent: true,
  );
  Get.put<ScaleRemoteDataSource>(DemoScaleDataSource(), permanent: true);
  Get.put<ErpConnectionRemoteDataSource>(
    const DemoErpConnectionDataSource(),
    permanent: true,
  );
}
