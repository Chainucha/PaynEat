// Copyright 2026 Suruch Chakrapeesirisuk
// SPDX-License-Identifier: Apache-2.0

import 'package:get/get.dart';

import '../../../core/services/offline_order_queue_service.dart';
import '../../../core/services/storage_service.dart';
import '../../../features/ai_assistant/domain/repositories/ai_assistant_repository.dart';
import '../../../features/ai_assistant/domain/usecases/ask_ai_assistant_usecase.dart';
import '../../../features/audit_log/domain/repositories/audit_log_repository.dart';
import '../../../features/audit_log/domain/usecases/audit_log_usecases.dart';
import '../../../features/auth/domain/repositories/auth_repository.dart';
import '../../../features/auth/domain/usecases/change_password_usecase.dart';
import '../../../features/auth/domain/usecases/get_my_branches_usecase.dart';
import '../../../features/auth/domain/usecases/get_profile_usecase.dart';
import '../../../features/auth/domain/usecases/login_usecase.dart';
import '../../../features/auth/domain/usecases/logout_usecase.dart';
import '../../../features/auth/domain/usecases/select_branch_usecase.dart';
import '../../../features/customer/domain/repositories/customer_repository.dart';
import '../../../features/customer/domain/usecases/customer_usecases.dart';
import '../../../features/erp_connection/domain/repositories/erp_connection_repository.dart';
import '../../../features/erp_connection/domain/usecases/erp_connection_usecases.dart';
import '../../../features/ingredient/domain/repositories/ingredient_repository.dart';
import '../../../features/ingredient/domain/usecases/ingredient_usecases.dart';
import '../../../features/menu/domain/repositories/menu_repository.dart';
import '../../../features/menu/domain/usecases/menu_usecases.dart';
import '../../../features/order/domain/repositories/order_repository.dart';
import '../../../features/order/domain/usecases/order_usecases.dart';
import '../../../features/payment/domain/repositories/payment_repository.dart';
import '../../../features/payment/domain/usecases/payment_usecases.dart';
import '../../../features/promotion/domain/repositories/promotion_repository.dart';
import '../../../features/promotion/domain/usecases/promotion_usecases.dart';
import '../../../features/report/domain/repositories/report_repository.dart';
import '../../../features/report/domain/usecases/report_usecases.dart';
import '../../../features/scale/domain/repositories/scale_repository.dart';
import '../../../features/scale/domain/usecases/scale_usecases.dart';
import '../../../features/self_order/domain/repositories/self_order_repository.dart';
import '../../../features/self_order/domain/usecases/add_self_order_items_usecase.dart';
import '../../../features/self_order/domain/usecases/get_self_order_menu_usecase.dart';
import '../../../features/self_order/domain/usecases/get_self_order_table_usecase.dart';
import '../../../features/settings/domain/repositories/settings_repository.dart';
import '../../../features/settings/domain/usecases/settings_usecases.dart';
import '../../../features/shift/domain/repositories/shift_repository.dart';
import '../../../features/shift/domain/usecases/shift_usecases.dart';
import '../../../features/shift/presentation/controllers/shift_controller.dart';
import '../../../features/staff/domain/repositories/staff_repository.dart';
import '../../../features/staff/domain/usecases/staff_usecases.dart';
import '../../../features/table/domain/repositories/table_repository.dart';
import '../../../features/table/domain/usecases/table_usecases.dart';
import '../../../features/receivable/domain/repositories/receivable_repository.dart';
import '../../../features/receivable/domain/usecases/receivable_usecases.dart';
import '../../../features/tax_invoice/domain/repositories/tax_invoice_repository.dart';
import '../../../features/tax_invoice/domain/usecases/tax_invoice_usecases.dart';

/// ผูก use case ของทุกโดเมน — สร้างจาก repository ที่ `bindRepositories()` ผูกไว้แล้วเสมอ
void bindUseCases() {
  // auth
  Get.lazyPut(() => LoginUseCase(Get.find<AuthRepository>()), fenix: true);
  Get.lazyPut(
    () => SelectBranchUseCase(Get.find<AuthRepository>()),
    fenix: true,
  );
  Get.lazyPut(
    () => GetMyBranchesUseCase(Get.find<AuthRepository>()),
    fenix: true,
  );
  Get.lazyPut(() => GetProfileUseCase(Get.find<AuthRepository>()), fenix: true);
  Get.lazyPut(() => LogoutUseCase(Get.find<AuthRepository>()), fenix: true);
  Get.lazyPut(
    () => ChangePasswordUseCase(Get.find<AuthRepository>()),
    fenix: true,
  );

  // menu
  Get.lazyPut(
    () => GetMenuItemsUseCase(Get.find<MenuRepository>()),
    fenix: true,
  );
  Get.lazyPut(
    () => GetCategoriesUseCase(Get.find<MenuRepository>()),
    fenix: true,
  );
  Get.lazyPut(
    () => CreateMenuItemUseCase(Get.find<MenuRepository>()),
    fenix: true,
  );
  Get.lazyPut(
    () => UpdateMenuItemUseCase(Get.find<MenuRepository>()),
    fenix: true,
  );
  Get.lazyPut(
    () => DeleteMenuItemUseCase(Get.find<MenuRepository>()),
    fenix: true,
  );
  Get.lazyPut(
    () => ToggleMenuAvailabilityUseCase(Get.find<MenuRepository>()),
    fenix: true,
  );
  Get.lazyPut(
    () => SaveCategoryUseCase(Get.find<MenuRepository>()),
    fenix: true,
  );
  Get.lazyPut(
    () => DeleteCategoryUseCase(Get.find<MenuRepository>()),
    fenix: true,
  );

  // ingredient
  Get.lazyPut(
    () => GetIngredientsUseCase(Get.find<IngredientRepository>()),
    fenix: true,
  );
  Get.lazyPut(
    () => SaveIngredientUseCase(Get.find<IngredientRepository>()),
    fenix: true,
  );
  Get.lazyPut(
    () => AdjustStockUseCase(Get.find<IngredientRepository>()),
    fenix: true,
  );
  Get.lazyPut(
    () => DeleteIngredientUseCase(Get.find<IngredientRepository>()),
    fenix: true,
  );

  // table
  Get.lazyPut(() => GetTablesUseCase(Get.find<TableRepository>()), fenix: true);
  Get.lazyPut(
    () => SetTableStatusUseCase(Get.find<TableRepository>()),
    fenix: true,
  );
  Get.lazyPut(() => SaveTableUseCase(Get.find<TableRepository>()), fenix: true);
  Get.lazyPut(
    () => DeleteTableUseCase(Get.find<TableRepository>()),
    fenix: true,
  );
  Get.lazyPut(() => GetZonesUseCase(Get.find<TableRepository>()), fenix: true);
  Get.lazyPut(
    () => RegenerateTableQrTokenUseCase(Get.find<TableRepository>()),
    fenix: true,
  );

  // order
  Get.lazyPut(() => GetOrdersUseCase(Get.find<OrderRepository>()), fenix: true);
  Get.lazyPut(() => GetOrderUseCase(Get.find<OrderRepository>()), fenix: true);
  Get.lazyPut(
    () => GetOpenOrderByTableUseCase(Get.find<OrderRepository>()),
    fenix: true,
  );
  Get.lazyPut(
    () => CreateOrderUseCase(Get.find<OrderRepository>()),
    fenix: true,
  );
  Get.lazyPut(
    () => AddOrderItemsUseCase(Get.find<OrderRepository>()),
    fenix: true,
  );
  // lazyPut (ไม่ eager) ด้วยเหตุผลเดียวกับ ShiftController ด้านล่าง — สร้างตอนแอปเริ่ม
  // (ก่อน login เสร็จ) อาจแข่งกับการกู้เซสชันแล้วยิง sync ด้วย token ที่ยังไม่พร้อม
  // ทำให้เจอ 401 ชั่วคราวแล้วเข้าใจผิดว่าเป็น conflict จริงจนตัดรายการทิ้งทั้งที่ไม่ควร
  Get.lazyPut(
    () => OfflineOrderQueueService(
      storage: Get.find<StorageService>(),
      orderRepository: Get.find<OrderRepository>(),
    ),
    fenix: true,
  );
  Get.lazyPut(
    () => UpdateOrderItemUseCase(Get.find<OrderRepository>()),
    fenix: true,
  );
  Get.lazyPut(
    () => RemoveOrderItemUseCase(Get.find<OrderRepository>()),
    fenix: true,
  );
  Get.lazyPut(
    () => UpdateOrderItemStatusUseCase(Get.find<OrderRepository>()),
    fenix: true,
  );
  Get.lazyPut(
    () => SendToKitchenUseCase(Get.find<OrderRepository>()),
    fenix: true,
  );
  Get.lazyPut(
    () => ApplyDiscountUseCase(Get.find<OrderRepository>()),
    fenix: true,
  );
  Get.lazyPut(
    () => CancelOrderUseCase(Get.find<OrderRepository>()),
    fenix: true,
  );
  Get.lazyPut(
    () => MoveOrderTableUseCase(Get.find<OrderRepository>()),
    fenix: true,
  );
  Get.lazyPut(
    () => MergeOrdersUseCase(Get.find<OrderRepository>()),
    fenix: true,
  );
  Get.lazyPut(
    () => GetKitchenQueueUseCase(Get.find<OrderRepository>()),
    fenix: true,
  );
  Get.lazyPut(
    () => RedeemPromotionCodeUseCase(Get.find<OrderRepository>()),
    fenix: true,
  );
  Get.lazyPut(
    () => RemovePromotionUseCase(Get.find<OrderRepository>()),
    fenix: true,
  );
  Get.lazyPut(
    () => GetEligiblePromotionsUseCase(Get.find<OrderRepository>()),
    fenix: true,
  );

  // payment
  Get.lazyPut(
    () => PayOrderUseCase(Get.find<PaymentRepository>()),
    fenix: true,
  );
  Get.lazyPut(
    () => GetPaymentSummaryUseCase(Get.find<PaymentRepository>()),
    fenix: true,
  );
  Get.lazyPut(
    () => GetSplitPreviewUseCase(Get.find<PaymentRepository>()),
    fenix: true,
  );
  Get.lazyPut(
    () => GetReceiptUseCase(Get.find<PaymentRepository>()),
    fenix: true,
  );
  Get.lazyPut(
    () => GetPromptPayQrUseCase(Get.find<PaymentRepository>()),
    fenix: true,
  );
  Get.lazyPut(
    () => RefundPaymentUseCase(Get.find<PaymentRepository>()),
    fenix: true,
  );

  // tax invoice
  Get.lazyPut(
    () => GetTaxInvoiceUseCase(Get.find<TaxInvoiceRepository>()),
    fenix: true,
  );
  Get.lazyPut(
    () => IssueTaxInvoiceUseCase(Get.find<TaxInvoiceRepository>()),
    fenix: true,
  );
  Get.lazyPut(
    () => VoidTaxInvoiceUseCase(Get.find<TaxInvoiceRepository>()),
    fenix: true,
  );

  // audit log
  Get.lazyPut(
    () => GetAuditLogsUseCase(Get.find<AuditLogRepository>()),
    fenix: true,
  );
  Get.lazyPut(
    () => ExportAuditLogsUseCase(Get.find<AuditLogRepository>()),
    fenix: true,
  );

  // customer / loyalty
  Get.lazyPut(
    () => SearchCustomersUseCase(Get.find<CustomerRepository>()),
    fenix: true,
  );
  Get.lazyPut(
    () => GetCustomerUseCase(Get.find<CustomerRepository>()),
    fenix: true,
  );
  Get.lazyPut(
    () => CreateCustomerUseCase(Get.find<CustomerRepository>()),
    fenix: true,
  );
  Get.lazyPut(
    () => UpdateCustomerCreditUseCase(Get.find<CustomerRepository>()),
    fenix: true,
  );

  // ลูกหนี้ / ขายเชื่อ / ใบวางบิล (ดู docs/tickets/20-b2b-credit.md)
  Get.lazyPut(
    () => GetReceivableCustomersUseCase(Get.find<ReceivableRepository>()),
    fenix: true,
  );
  Get.lazyPut(
    () => GetCustomerStatementUseCase(Get.find<ReceivableRepository>()),
    fenix: true,
  );
  Get.lazyPut(
    () => CreateArReceiptUseCase(Get.find<ReceivableRepository>()),
    fenix: true,
  );
  Get.lazyPut(
    () => GetArReceiptUseCase(Get.find<ReceivableRepository>()),
    fenix: true,
  );
  Get.lazyPut(
    () => VoidArReceiptUseCase(Get.find<ReceivableRepository>()),
    fenix: true,
  );
  Get.lazyPut(
    () => CreateBillingNoteUseCase(Get.find<ReceivableRepository>()),
    fenix: true,
  );
  Get.lazyPut(
    () => GetBillingNoteUseCase(Get.find<ReceivableRepository>()),
    fenix: true,
  );
  Get.lazyPut(
    () => VoidBillingNoteUseCase(Get.find<ReceivableRepository>()),
    fenix: true,
  );
  Get.lazyPut(
    () => PreviewLateFeeUseCase(Get.find<ReceivableRepository>()),
    fenix: true,
  );
  Get.lazyPut(
    () => CreateLateFeeUseCase(Get.find<ReceivableRepository>()),
    fenix: true,
  );
  Get.lazyPut(
    () => GetLateFeeUseCase(Get.find<ReceivableRepository>()),
    fenix: true,
  );
  Get.lazyPut(
    () => VoidLateFeeUseCase(Get.find<ReceivableRepository>()),
    fenix: true,
  );
  Get.lazyPut(
    () => CreateCreditNoteUseCase(Get.find<ReceivableRepository>()),
    fenix: true,
  );
  Get.lazyPut(
    () => GetCreditNoteUseCase(Get.find<ReceivableRepository>()),
    fenix: true,
  );
  Get.lazyPut(
    () => DownloadReceivablePdfUseCase(Get.find<ReceivableRepository>()),
    fenix: true,
  );
  Get.lazyPut(
    () => EmailReceivableDocumentUseCase(Get.find<ReceivableRepository>()),
    fenix: true,
  );

  // ตาชั่งต่อสาย (ดู docs/tickets/22-live-scale-camera-scan.md)
  Get.lazyPut(
    () => GetScaleStatusUseCase(Get.find<ScaleRepository>()),
    fenix: true,
  );
  Get.lazyPut(
    () => WatchScaleUseCase(Get.find<ScaleRepository>()),
    fenix: true,
  );

  // ai assistant
  Get.lazyPut(
    () => AskAiAssistantUseCase(Get.find<AiAssistantRepository>()),
    fenix: true,
  );

  // shift
  Get.lazyPut(
    () => GetCurrentShiftUseCase(Get.find<ShiftRepository>()),
    fenix: true,
  );
  Get.lazyPut(() => OpenShiftUseCase(Get.find<ShiftRepository>()), fenix: true);
  Get.lazyPut(
    () => CloseShiftUseCase(Get.find<ShiftRepository>()),
    fenix: true,
  );
  Get.lazyPut(
    () => GetShiftHistoryUseCase(Get.find<ShiftRepository>()),
    fenix: true,
  );

  // report
  Get.lazyPut(
    () => GetDashboardUseCase(Get.find<ReportRepository>()),
    fenix: true,
  );
  Get.lazyPut(
    () => GetSalesSummaryUseCase(Get.find<ReportRepository>()),
    fenix: true,
  );
  Get.lazyPut(
    () => GetTopItemsUseCase(Get.find<ReportRepository>()),
    fenix: true,
  );
  Get.lazyPut(
    () => GetSalesByDayUseCase(Get.find<ReportRepository>()),
    fenix: true,
  );
  Get.lazyPut(
    () => ExportSummaryCsvUseCase(Get.find<ReportRepository>()),
    fenix: true,
  );
  Get.lazyPut(
    () => ExportTopItemsCsvUseCase(Get.find<ReportRepository>()),
    fenix: true,
  );
  Get.lazyPut(
    () => ExportSalesByDayCsvUseCase(Get.find<ReportRepository>()),
    fenix: true,
  );
  Get.lazyPut(
    () => GetZReportByShiftUseCase(Get.find<ReportRepository>()),
    fenix: true,
  );
  Get.lazyPut(
    () => GetZReportByDateUseCase(Get.find<ReportRepository>()),
    fenix: true,
  );
  Get.lazyPut(
    () => ExportZReportByShiftCsvUseCase(Get.find<ReportRepository>()),
    fenix: true,
  );
  Get.lazyPut(
    () => ExportZReportByDateCsvUseCase(Get.find<ReportRepository>()),
    fenix: true,
  );

  // lazyPut (ไม่ eager) เพราะ onInit ของ controller นี้ยิง API ทันที
  // ถ้าสร้างตอนแอปเริ่ม (ก่อนล็อกอิน) จะโดน 401 และอาจไปเข้าเงื่อนไข session
  // หมดอายุใน ApiClient ทั้งที่ผู้ใช้ยังไม่เคยล็อกอินเลย — ต้องรอให้มีคนเรียกใช้จริง
  // (เปิดแท็บ "กะ" หรือเข้าหน้าเก็บเงิน ซึ่งเกิดหลังล็อกอินเสมอ) ก่อนจะสร้าง
  Get.lazyPut(
    () => ShiftController(
      getCurrent: Get.find<GetCurrentShiftUseCase>(),
      openShift: Get.find<OpenShiftUseCase>(),
      closeShift: Get.find<CloseShiftUseCase>(),
      getHistory: Get.find<GetShiftHistoryUseCase>(),
      getZReportByShift: Get.find<GetZReportByShiftUseCase>(),
      exportZReportByShiftCsv: Get.find<ExportZReportByShiftCsvUseCase>(),
    ),
    fenix: true,
  );

  // staff
  Get.lazyPut(() => GetStaffUseCase(Get.find<StaffRepository>()), fenix: true);
  Get.lazyPut(
    () => CreateStaffUseCase(Get.find<StaffRepository>()),
    fenix: true,
  );
  Get.lazyPut(
    () => UpdateStaffUseCase(Get.find<StaffRepository>()),
    fenix: true,
  );
  Get.lazyPut(
    () => DeleteStaffUseCase(Get.find<StaffRepository>()),
    fenix: true,
  );

  // settings
  Get.lazyPut(
    () => GetSettingsUseCase(Get.find<SettingsRepository>()),
    fenix: true,
  );
  Get.lazyPut(
    () => UpdateSettingsUseCase(Get.find<SettingsRepository>()),
    fenix: true,
  );

  // promotion
  Get.lazyPut(
    () => GetPromotionsUseCase(Get.find<PromotionRepository>()),
    fenix: true,
  );
  Get.lazyPut(
    () => SavePromotionUseCase(Get.find<PromotionRepository>()),
    fenix: true,
  );
  Get.lazyPut(
    () => SetPromotionActiveUseCase(Get.find<PromotionRepository>()),
    fenix: true,
  );
  Get.lazyPut(
    () => DeletePromotionUseCase(Get.find<PromotionRepository>()),
    fenix: true,
  );

  // self order (ดู docs/tickets/17-qr-self-order.md)
  Get.lazyPut(
    () => GetSelfOrderTableUseCase(Get.find<SelfOrderRepository>()),
    fenix: true,
  );
  Get.lazyPut(
    () => GetSelfOrderMenuUseCase(Get.find<SelfOrderRepository>()),
    fenix: true,
  );
  Get.lazyPut(
    () => AddSelfOrderItemsUseCase(Get.find<SelfOrderRepository>()),
    fenix: true,
  );

  // โหมดเชื่อมต่อ PaynEat ERP (ดู docs/tickets/25-erp-connected-mode.md)
  Get.lazyPut(
    () => GetErpModeUseCase(Get.find<ErpConnectionRepository>()),
    fenix: true,
  );
  Get.lazyPut(
    () => GetErpStatusUseCase(Get.find<ErpConnectionRepository>()),
    fenix: true,
  );
  Get.lazyPut(
    () => ConnectErpUseCase(Get.find<ErpConnectionRepository>()),
    fenix: true,
  );
  Get.lazyPut(
    () => DisconnectErpUseCase(Get.find<ErpConnectionRepository>()),
    fenix: true,
  );
  Get.lazyPut(
    () => PullErpNowUseCase(Get.find<ErpConnectionRepository>()),
    fenix: true,
  );
  Get.lazyPut(
    () => UpdateBranchCodeUseCase(Get.find<ErpConnectionRepository>()),
    fenix: true,
  );
}
