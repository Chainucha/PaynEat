// Copyright 2026 Suruch Chakrapeesirisuk
// SPDX-License-Identifier: Apache-2.0

/// รวมทุก path ของ API ไว้ที่เดียว — แก้ครั้งเดียวมีผลทั้งแอป
class ApiEndpoints {
  const ApiEndpoints._();

  // Auth
  static const String login = '/auth/login';
  static const String me = '/auth/me';
  static const String changePassword = '/auth/change-password';
  static const String selectBranch = '/auth/select-branch';

  // Branches (ดู docs/tickets/11-multi-branch.md)
  static const String branchesMine = '/branches/mine';
  static String branch(int id) => '/branches/$id';

  // Users
  static const String users = '/users';
  static String user(int id) => '/users/$id';
  static String resetPassword(int id) => '/users/$id/reset-password';

  // Categories
  static const String categories = '/categories';
  static String category(int id) => '/categories/$id';

  // Kitchen stations (ticket 34)
  static const String kitchenStations = '/kitchen-stations';
  static String kitchenStation(int id) => '/kitchen-stations/$id';

  // Menu
  static const String menuItems = '/menu-items';
  static String menuItem(int id) => '/menu-items/$id';
  static String menuAvailability(int id) => '/menu-items/$id/availability';

  // Ingredients
  static const String ingredients = '/ingredients';
  static String ingredient(int id) => '/ingredients/$id';
  static String ingredientAdjustStock(int id) =>
      '/ingredients/$id/adjust-stock';

  // Tables
  static const String tables = '/tables';
  static const String tableZones = '/tables/zones';
  static String table(int id) => '/tables/$id';
  static String tableStatus(int id) => '/tables/$id/status';
  // ดู docs/tickets/17-qr-self-order.md
  static String tableQrTokenRegenerate(int id) =>
      '/tables/$id/qr-token/regenerate';

  // Orders
  static const String orders = '/orders';
  static const String kitchenQueue = '/orders/kitchen/queue';
  static String order(int id) => '/orders/$id';
  static String openOrderByTable(int tableId) => '/orders/table/$tableId/open';
  static String orderItems(int id) => '/orders/$id/items';
  static String orderItem(int orderId, int itemId) =>
      '/orders/$orderId/items/$itemId';
  static String orderItemStatus(int orderId, int itemId) =>
      '/orders/$orderId/items/$itemId/status';
  static String sendToKitchen(int id) => '/orders/$id/send-to-kitchen';
  static String orderDiscount(int id) => '/orders/$id/discount';
  static String cancelOrder(int id) => '/orders/$id/cancel';
  static String moveOrderTable(int id) => '/orders/$id/move-table';
  static String mergeOrder(int id) => '/orders/$id/merge';
  static String orderPromotionRedeem(int id) => '/orders/$id/promotion/redeem';
  static String orderPromotion(int id) => '/orders/$id/promotion';
  static String orderEligiblePromotions(int id) =>
      '/orders/$id/eligible-promotions';

  // Promotions
  static const String promotions = '/promotions';
  static String promotion(int id) => '/promotions/$id';

  // Payments
  static const String payments = '/payments';
  static String paymentSummary(int orderId) => '/payments/order/$orderId';
  static String receipt(int orderId) => '/payments/order/$orderId/receipt';
  static String splitPreview(int orderId) =>
      '/payments/order/$orderId/split-preview';
  static String refundPayment(int paymentId) => '/payments/$paymentId/refund';
  static const String promptPayQr = '/payments/promptpay-qr';

  // Reports
  static const String dashboard = '/reports/dashboard';
  static const String reportSummary = '/reports/summary';
  static const String topItems = '/reports/top-items';
  static const String salesByDay = '/reports/sales-by-day';
  static const String exportSummary = '/reports/export/summary';
  static const String exportTopItems = '/reports/export/top-items';
  static const String exportSalesByDay = '/reports/export/sales-by-day';
  static String zReportByShift(int shiftId) =>
      '/reports/z-report/by-shift/$shiftId';
  static String zReportByShiftExport(int shiftId) =>
      '/reports/z-report/by-shift/$shiftId/export';
  static const String zReportByDate = '/reports/z-report/by-date';
  static const String zReportByDateExport = '/reports/z-report/by-date/export';

  // Settings
  static const String settings = '/settings';

  // Shifts
  static const String shifts = '/shifts';
  static const String currentShift = '/shifts/current';
  static String closeShift(int id) => '/shifts/$id/close';

  // Tax invoices
  static String taxInvoice(int orderId) => '/tax-invoices/order/$orderId';
  static String taxInvoiceVoid(int orderId) =>
      '/tax-invoices/order/$orderId/void';

  // Audit logs
  static const String auditLogs = '/audit-logs';
  static const String auditLogsExport = '/audit-logs/export';

  // Customers
  static const String customers = '/customers';
  static String customer(int id) => '/customers/$id';
  static String customerCredit(int id) => '/customers/$id/credit';

  // ลูกหนี้/ขายเชื่อ (ดู docs/tickets/20-b2b-credit.md)
  static const String receivableCustomers = '/receivables/customers';
  static String receivableStatement(int customerId) =>
      '/receivables/customers/$customerId';
  static const String arReceipts = '/receivables/receipts';
  static String arReceipt(int id) => '/receivables/receipts/$id';
  static String arReceiptVoid(int id) => '/receivables/receipts/$id/void';
  static const String billingNotes = '/receivables/billing-notes';
  static String billingNote(int id) => '/receivables/billing-notes/$id';
  static String billingNoteVoid(int id) =>
      '/receivables/billing-notes/$id/void';

  // ดอกเบี้ยผิดนัด / ใบลดหนี้ (ดู docs/tickets/21-late-fees-credit-notes.md)
  static String lateFeePreview(int customerId) =>
      '/receivables/customers/$customerId/late-fee-preview';
  static const String lateFees = '/receivables/late-fees';
  static String lateFee(int id) => '/receivables/late-fees/$id';
  static String lateFeeVoid(int id) => '/receivables/late-fees/$id/void';
  static const String creditNotes = '/receivables/credit-notes';
  static String creditNote(int id) => '/receivables/credit-notes/$id';

  // PDF + อีเมลเอกสารลูกหนี้ (ดู docs/tickets/23-document-pdf-email.md) — kindPath เช่น billing-notes
  static String receivableDocumentPdf(String kindPath, int id) =>
      '/receivables/$kindPath/$id/pdf';
  static String receivableDocumentEmail(String kindPath, int id) =>
      '/receivables/$kindPath/$id/email';

  // ตาชั่งต่อสาย (ดู docs/tickets/22-live-scale-camera-scan.md)
  static const String scale = '/scale';

  // โหมดเชื่อมต่อ PaynEat ERP (ดู docs/tickets/25-erp-connected-mode.md)
  static const String erpMode = '/erp/mode';
  static const String erpConnection = '/erp/connection';
  static const String erpPull = '/erp/pull';
  static const String erpBranches = '/erp/branches';

  // AI assistant
  static const String aiAssistantAsk = '/ai/ask';

  // ลูกค้าสั่งอาหารเองผ่าน QR ที่โต๊ะ (ดู docs/tickets/17-qr-self-order.md) — ไม่ต้อง login
  static String publicTable(String qrToken) => '/public/tables/$qrToken';
  static String publicTableMenu(String qrToken) =>
      '/public/tables/$qrToken/menu';
  static String publicTableItems(String qrToken) =>
      '/public/tables/$qrToken/items';
}
