// Copyright 2026 Suruch Chakrapeesirisuk
// SPDX-License-Identifier: Apache-2.0

/// รายการ action type ที่ระบบบันทึกลง audit log (mirror ของ backend
/// audit-log module — ดู docs/tickets/08-audit-log.md) ใช้ทำตัวกรอง/ป้ายชื่อ
/// บนหน้าจอ admin
class AuditLogAction {
  const AuditLogAction._();

  static const String orderCreate = 'order.create';
  static const String orderItemAdd = 'order.item.add';
  static const String orderItemEdit = 'order.item.edit';
  static const String orderItemRemove = 'order.item.remove';
  static const String orderMoveTable = 'order.move_table';
  static const String orderMerge = 'order.merge';
  static const String orderCancel = 'order.cancel';
  static const String orderItemVoid = 'order_item.void';
  static const String orderDiscount = 'order.discount';
  static const String userDeactivate = 'user.deactivate';
  static const String userDelete = 'user.delete';
  static const String userRoleChange = 'user.role_change';
  static const String userPasswordReset = 'user.password_reset';
  static const String settingsUpdate = 'settings.update';
  static const String paymentRefund = 'payment.refund';
  static const String taxInvoiceVoid = 'tax_invoice.void';

  // Audit ระดับบัญชี/การเงิน (ดู docs/tickets/14-financial-audit-trail.md)
  static const String menuPriceChange = 'menu.price_change';
  static const String promotionCreate = 'promotion.create';
  static const String promotionUpdate = 'promotion.update';
  static const String promotionDelete = 'promotion.delete';
  static const String ingredientStockAdjust = 'ingredient.stock_adjust';

  // ลูกหนี้/ขายเชื่อ (ดู docs/tickets/20-b2b-credit.md)
  static const String customerCreditUpdate = 'customer.credit_update';
  static const String receivableReceipt = 'receivable.receipt';
  static const String receivableReceiptVoid = 'receivable.receipt_void';
  static const String receivableBillingNote = 'receivable.billing_note';
  static const String receivableBillingNoteVoid =
      'receivable.billing_note_void';
  // ดอกเบี้ยผิดนัด / ใบลดหนี้ / ส่งเอกสารทางอีเมล (tickets 21, 23)
  static const String receivableLateFee = 'receivable.late_fee';
  static const String receivableLateFeeVoid = 'receivable.late_fee_void';
  static const String receivableCreditNote = 'receivable.credit_note';
  static const String receivableDocumentEmail = 'receivable.document_email';
  // โหมดเชื่อมต่อ PaynEat ERP (ticket 25)
  static const String erpConnect = 'erp.connect';
  static const String erpDisconnect = 'erp.disconnect';

  static const List<String> all = [
    orderCreate,
    orderItemAdd,
    orderItemEdit,
    orderItemRemove,
    orderMoveTable,
    orderMerge,
    orderCancel,
    orderItemVoid,
    orderDiscount,
    userDeactivate,
    userDelete,
    userRoleChange,
    userPasswordReset,
    settingsUpdate,
    paymentRefund,
    taxInvoiceVoid,
    menuPriceChange,
    promotionCreate,
    promotionUpdate,
    promotionDelete,
    ingredientStockAdjust,
    customerCreditUpdate,
    receivableReceipt,
    receivableReceiptVoid,
    receivableBillingNote,
    receivableBillingNoteVoid,
    receivableLateFee,
    receivableLateFeeVoid,
    receivableCreditNote,
    receivableDocumentEmail,
    erpConnect,
    erpDisconnect,
  ];

  static const Map<String, String> _keys = {
    orderCreate: 'audit_log_action_order_create',
    orderItemAdd: 'audit_log_action_order_item_add',
    orderItemEdit: 'audit_log_action_order_item_edit',
    orderItemRemove: 'audit_log_action_order_item_remove',
    orderMoveTable: 'audit_log_action_order_move_table',
    orderMerge: 'audit_log_action_order_merge',
    orderCancel: 'audit_log_action_order_cancel',
    orderItemVoid: 'audit_log_action_order_item_void',
    orderDiscount: 'audit_log_action_order_discount',
    userDeactivate: 'audit_log_action_user_deactivate',
    userDelete: 'audit_log_action_user_delete',
    userRoleChange: 'audit_log_action_user_role_change',
    userPasswordReset: 'audit_log_action_user_password_reset',
    settingsUpdate: 'audit_log_action_settings_update',
    paymentRefund: 'audit_log_action_payment_refund',
    taxInvoiceVoid: 'audit_log_action_tax_invoice_void',
    menuPriceChange: 'audit_log_action_menu_price_change',
    promotionCreate: 'audit_log_action_promotion_create',
    promotionUpdate: 'audit_log_action_promotion_update',
    promotionDelete: 'audit_log_action_promotion_delete',
    ingredientStockAdjust: 'audit_log_action_ingredient_stock_adjust',
    customerCreditUpdate: 'audit_log_action_customer_credit_update',
    receivableReceipt: 'audit_log_action_receivable_receipt',
    receivableReceiptVoid: 'audit_log_action_receivable_receipt_void',
    receivableBillingNote: 'audit_log_action_receivable_billing_note',
    receivableBillingNoteVoid: 'audit_log_action_receivable_billing_note_void',
    receivableLateFee: 'audit_log_action_receivable_late_fee',
    receivableLateFeeVoid: 'audit_log_action_receivable_late_fee_void',
    receivableCreditNote: 'audit_log_action_receivable_credit_note',
    receivableDocumentEmail: 'audit_log_action_receivable_document_email',
    erpConnect: 'audit_log_action_erp_connect',
    erpDisconnect: 'audit_log_action_erp_disconnect',
  };

  static String translationKey(String action) => _keys[action] ?? action;
}
