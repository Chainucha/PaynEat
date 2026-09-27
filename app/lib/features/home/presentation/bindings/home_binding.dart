// Copyright 2026 Suruch Chakrapeesirisuk
// SPDX-License-Identifier: Apache-2.0

import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/printing/receipt_printer_service.dart';
import '../../../../core/services/printer_settings_service.dart';
import '../../../../core/services/session_service.dart';
import '../../../ai_assistant/domain/usecases/ask_ai_assistant_usecase.dart';
import '../../../ai_assistant/presentation/controllers/ai_assistant_controller.dart';
import '../../../ai_assistant/presentation/pages/ai_assistant_page.dart';
import '../../../audit_log/domain/usecases/audit_log_usecases.dart';
import '../../../audit_log/presentation/controllers/audit_log_controller.dart';
import '../../../audit_log/presentation/pages/audit_log_page.dart';
import '../../../auth/presentation/pages/profile_page.dart';
import '../../../customer/domain/usecases/customer_usecases.dart';
import '../../../customer/presentation/controllers/customers_controller.dart';
import '../../../customer/presentation/pages/customers_page.dart';
import '../../../ingredient/domain/usecases/ingredient_usecases.dart';
import '../../../ingredient/presentation/controllers/ingredients_controller.dart';
import '../../../ingredient/presentation/pages/ingredients_page.dart';
import '../../../kitchen/presentation/controllers/kitchen_controller.dart';
import '../../../kitchen/presentation/pages/kitchen_page.dart';
import '../../../menu/domain/usecases/menu_usecases.dart';
import '../../../menu/presentation/controllers/menu_management_controller.dart';
import '../../../menu/presentation/pages/menu_management_page.dart';
import '../../../order/domain/usecases/order_usecases.dart';
import '../../../order/presentation/controllers/order_list_controller.dart';
import '../../../order/presentation/pages/orders_page.dart';
import '../../../promotion/domain/usecases/promotion_usecases.dart';
import '../../../promotion/presentation/controllers/promotions_controller.dart';
import '../../../promotion/presentation/pages/promotions_page.dart';
import '../../../receivable/domain/usecases/receivable_usecases.dart';
import '../../../receivable/presentation/controllers/receivables_controller.dart';
import '../../../receivable/presentation/pages/receivables_page.dart';
import '../../../report/domain/usecases/report_usecases.dart';
import '../../../report/presentation/controllers/dashboard_controller.dart';
import '../../../report/presentation/controllers/report_controller.dart';
import '../../../report/presentation/pages/dashboard_page.dart';
import '../../../report/presentation/pages/reports_page.dart';
import '../../../erp_connection/domain/usecases/erp_connection_usecases.dart';
import '../../../erp_connection/presentation/controllers/erp_connection_controller.dart';
import '../../../settings/domain/usecases/settings_usecases.dart';
import '../../../settings/presentation/controllers/printer_settings_controller.dart';
import '../../../settings/presentation/controllers/settings_controller.dart';
import '../../../settings/presentation/pages/settings_page.dart';
import '../../../shift/presentation/pages/shift_page.dart';
import '../../../staff/domain/usecases/staff_usecases.dart';
import '../../../staff/presentation/controllers/staff_controller.dart';
import '../../../staff/presentation/pages/staff_page.dart';
import '../../../table/domain/usecases/table_usecases.dart';
import '../../../table/presentation/controllers/table_controller.dart';
import '../../../table/presentation/pages/tables_page.dart';
import '../controllers/home_controller.dart';

/// DI ของหน้าหลัก
///
/// controller ของแต่ละแท็บใช้ `lazyPut` จึงถูกสร้างเมื่อผู้ใช้เปิดแท็บนั้นจริง ๆ เท่านั้น
/// (บัญชีครัวไม่ต้องเสียแรงโหลดข้อมูลรายงาน)
class HomeBinding extends Bindings {
  @override
  void dependencies() {
    _bindTabControllers();

    Get.put<HomeController>(
      HomeController(
        session: Get.find<SessionService>(),
        destinationsBuilder: destinationsForRole,
      ),
    );
  }

  void _bindTabControllers() {
    Get.lazyPut(
      () => TableController(
        getTables: Get.find<GetTablesUseCase>(),
        setTableStatus: Get.find<SetTableStatusUseCase>(),
        regenerateQrToken: Get.find<RegenerateTableQrTokenUseCase>(),
        session: Get.find<SessionService>(),
      ),
      fenix: true,
    );
    Get.lazyPut(
      () => OrderListController(
        getOrders: Get.find<GetOrdersUseCase>(),
        session: Get.find<SessionService>(),
      ),
      fenix: true,
    );
    Get.lazyPut(
      () => KitchenController(
        getQueue: Get.find<GetKitchenQueueUseCase>(),
        updateItemStatus: Get.find<UpdateOrderItemStatusUseCase>(),
        session: Get.find<SessionService>(),
      ),
      fenix: true,
    );
    Get.lazyPut(
      () => DashboardController(
        getDashboard: Get.find<GetDashboardUseCase>(),
        session: Get.find<SessionService>(),
      ),
      fenix: true,
    );
    Get.lazyPut(
      () => ReportController(
        getSummary: Get.find<GetSalesSummaryUseCase>(),
        getTopItems: Get.find<GetTopItemsUseCase>(),
        getSalesByDay: Get.find<GetSalesByDayUseCase>(),
        exportSummaryCsv: Get.find<ExportSummaryCsvUseCase>(),
        exportTopItemsCsv: Get.find<ExportTopItemsCsvUseCase>(),
        exportSalesByDayCsv: Get.find<ExportSalesByDayCsvUseCase>(),
      ),
      fenix: true,
    );
    Get.lazyPut(
      () => MenuManagementController(
        getMenuItems: Get.find<GetMenuItemsUseCase>(),
        getCategories: Get.find<GetCategoriesUseCase>(),
        createMenuItem: Get.find<CreateMenuItemUseCase>(),
        updateMenuItem: Get.find<UpdateMenuItemUseCase>(),
        deleteMenuItem: Get.find<DeleteMenuItemUseCase>(),
        toggleAvailability: Get.find<ToggleMenuAvailabilityUseCase>(),
        saveCategory: Get.find<SaveCategoryUseCase>(),
        deleteCategory: Get.find<DeleteCategoryUseCase>(),
      ),
      fenix: true,
    );
    Get.lazyPut(
      () => PromotionsController(
        getPromotions: Get.find<GetPromotionsUseCase>(),
        savePromotion: Get.find<SavePromotionUseCase>(),
        setPromotionActive: Get.find<SetPromotionActiveUseCase>(),
        deletePromotion: Get.find<DeletePromotionUseCase>(),
      ),
      fenix: true,
    );
    Get.lazyPut(
      () => IngredientsController(
        getIngredients: Get.find<GetIngredientsUseCase>(),
        saveIngredient: Get.find<SaveIngredientUseCase>(),
        adjustStock: Get.find<AdjustStockUseCase>(),
        deleteIngredient: Get.find<DeleteIngredientUseCase>(),
        getErpMode: Get.find<GetErpModeUseCase>(),
      ),
      fenix: true,
    );
    Get.lazyPut(
      () => ErpConnectionController(
        getStatus: Get.find<GetErpStatusUseCase>(),
        connect: Get.find<ConnectErpUseCase>(),
        disconnect: Get.find<DisconnectErpUseCase>(),
        pullNow: Get.find<PullErpNowUseCase>(),
        updateBranchCode: Get.find<UpdateBranchCodeUseCase>(),
        createServedBranch: Get.find<CreateServedBranchUseCase>(),
      ),
      fenix: true,
    );
    Get.lazyPut(
      () => StaffController(
        getStaff: Get.find<GetStaffUseCase>(),
        createStaff: Get.find<CreateStaffUseCase>(),
        updateStaff: Get.find<UpdateStaffUseCase>(),
        deleteStaff: Get.find<DeleteStaffUseCase>(),
        session: Get.find<SessionService>(),
      ),
      fenix: true,
    );
    Get.lazyPut(
      () => SettingsController(
        getSettings: Get.find<GetSettingsUseCase>(),
        updateSettings: Get.find<UpdateSettingsUseCase>(),
      ),
      fenix: true,
    );
    Get.lazyPut(
      () => PrinterSettingsController(
        settingsService: Get.find<PrinterSettingsService>(),
        printerService: Get.find<ReceiptPrinterService>(),
      ),
      fenix: true,
    );
    Get.lazyPut(
      () => AuditLogController(
        getAuditLogs: Get.find<GetAuditLogsUseCase>(),
        exportAuditLogs: Get.find<ExportAuditLogsUseCase>(),
      ),
      fenix: true,
    );
    Get.lazyPut(
      () => CustomersController(
        searchCustomers: Get.find<SearchCustomersUseCase>(),
      ),
      fenix: true,
    );
    Get.lazyPut(
      () => ReceivablesController(
        getCustomers: Get.find<GetReceivableCustomersUseCase>(),
      ),
      fenix: true,
    );
    Get.lazyPut(
      () => AiAssistantController(
        askAiAssistant: Get.find<AskAiAssistantUseCase>(),
      ),
      fenix: true,
    );
  }

  /// เมนูที่แต่ละบทบาทเห็น — เป็นฟังก์ชันบริสุทธิ์จึงเขียนเทสต์ได้ง่าย
  static List<HomeDestination> destinationsForRole(String role) {
    // labels are translation keys — resolved with `.tr` where they are
    // displayed (AppBar title, nav rail/bar/drawer) so they stay in sync
    // when the user switches language at runtime.
    const tables = HomeDestination(
      label: 'home_nav_tables',
      icon: Icons.table_restaurant_outlined,
      selectedIcon: Icons.table_restaurant_rounded,
      page: TablesPage(),
    );
    const orders = HomeDestination(
      label: 'home_nav_orders',
      icon: Icons.receipt_long_outlined,
      selectedIcon: Icons.receipt_long_rounded,
      page: OrdersPage(),
    );
    const kitchen = HomeDestination(
      label: 'home_nav_kitchen',
      icon: Icons.soup_kitchen_outlined,
      selectedIcon: Icons.soup_kitchen_rounded,
      page: KitchenPage(),
    );
    const dashboard = HomeDestination(
      label: 'home_nav_dashboard',
      icon: Icons.dashboard_outlined,
      selectedIcon: Icons.dashboard_rounded,
      page: DashboardPage(),
    );
    const menu = HomeDestination(
      label: 'home_nav_menu',
      icon: Icons.restaurant_menu_outlined,
      selectedIcon: Icons.restaurant_menu_rounded,
      page: MenuManagementPage(),
    );
    const promotions = HomeDestination(
      label: 'home_nav_promotions',
      icon: Icons.local_offer_outlined,
      selectedIcon: Icons.local_offer_rounded,
      page: PromotionsPage(),
    );
    const ingredients = HomeDestination(
      label: 'home_nav_ingredients',
      icon: Icons.inventory_2_outlined,
      selectedIcon: Icons.inventory_2_rounded,
      page: IngredientsPage(),
    );
    const staff = HomeDestination(
      label: 'home_nav_staff',
      icon: Icons.people_outline_rounded,
      selectedIcon: Icons.people_rounded,
      page: StaffPage(),
    );
    // สมาชิก/แต้มสะสม — เห็นได้ทั้ง admin และ manager (ดู docs/tickets/09-customer-loyalty.md)
    const customers = HomeDestination(
      label: 'home_nav_customers',
      icon: Icons.card_giftcard_outlined,
      selectedIcon: Icons.card_giftcard_rounded,
      page: CustomersPage(),
    );
    // ลูกหนี้/ขายเชื่อ — admin, manager, cashier (คนรับชำระหนี้หน้าร้าน) ตรงกับ receivable.routes.js
    // ดู docs/tickets/20-b2b-credit.md
    const receivables = HomeDestination(
      label: 'home_nav_receivables',
      icon: Icons.request_quote_outlined,
      selectedIcon: Icons.request_quote_rounded,
      page: ReceivablesPage(),
    );
    const reports = HomeDestination(
      label: 'home_nav_reports',
      icon: Icons.insights_outlined,
      selectedIcon: Icons.insights_rounded,
      page: ReportsPage(),
    );
    const settings = HomeDestination(
      label: 'home_nav_settings',
      icon: Icons.settings_outlined,
      selectedIcon: Icons.settings_rounded,
      page: SettingsPage(),
    );
    const profile = HomeDestination(
      label: 'home_nav_profile',
      icon: Icons.person_outline_rounded,
      selectedIcon: Icons.person_rounded,
      page: ProfilePage(),
    );
    const shift = HomeDestination(
      label: 'home_nav_shift',
      icon: Icons.point_of_sale_outlined,
      selectedIcon: Icons.point_of_sale_rounded,
      page: ShiftPage(),
    );
    // เฉพาะ admin เท่านั้น (ไม่รวม manager) mirror ของ audit-log.routes.js —
    // ดู docs/tickets/08-audit-log.md
    const auditLog = HomeDestination(
      label: 'home_nav_audit_log',
      icon: Icons.history_outlined,
      selectedIcon: Icons.history_rounded,
      page: AuditLogPage(),
    );
    // ผู้ช่วย AI ถามตอบข้อมูลร้าน — admin/manager เท่านั้น (ตรงกับ /ai/ask ที่จำกัด role เดียวกัน
    // ฝั่ง backend ดู docs/tickets/15-ai-ask-your-data.md, docs/DECISIONS.md #33)
    const aiAssistant = HomeDestination(
      label: 'home_nav_ai_assistant',
      icon: Icons.auto_awesome_outlined,
      selectedIcon: Icons.auto_awesome_rounded,
      page: AiAssistantPage(),
    );

    return switch (role) {
      UserRole.admin => const [
        dashboard,
        tables,
        orders,
        kitchen,
        menu,
        ingredients,
        promotions,
        staff,
        customers,
        receivables,
        auditLog,
        reports,
        aiAssistant,
        shift,
        settings,
        profile,
      ],
      UserRole.manager => const [
        dashboard,
        tables,
        orders,
        kitchen,
        menu,
        ingredients,
        promotions,
        staff,
        customers,
        receivables,
        reports,
        aiAssistant,
        shift,
        settings,
        profile,
      ],
      UserRole.cashier => const [
        tables,
        orders,
        receivables,
        shift,
        reports,
        profile,
      ],
      UserRole.kitchen => const [kitchen, profile],
      // ตั้งใจให้เห็น "ครัว" ด้วย — backend อนุญาตให้ waiter แก้สถานะอาหารได้เช่นกัน (ดู
      // authorize('admin', 'manager', 'kitchen', 'waiter') ใน order.routes.js) สำหรับร้านเล็ก
      // ที่พนักงานเสิร์ฟอาจต้องช่วยดู/กดสถานะในครัวเอง
      UserRole.waiter => const [tables, orders, kitchen, profile],
      // role ที่ไม่รู้จัก (ข้อมูลเพี้ยน/พิมพ์ผิด) ต้อง fail-safe ไปทางจำกัดสิทธิ์สุด ไม่ใช่เดา
      // ชุดสิทธิ์กว้างๆ ให้เงียบๆ — เห็นได้แค่บัญชีตัวเอง
      _ => const [profile],
    };
  }
}
