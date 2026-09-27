// Copyright 2026 Suruch Chakrapeesirisuk
// SPDX-License-Identifier: Apache-2.0

/// คำแปลของฟีเจอร์ audit log (ดู docs/tickets/08-audit-log.md)
const Map<String, String> auditLogTranslationsTh = {
  'audit_log_empty_state': 'ยังไม่มีประวัติการทำรายการ',
  'audit_log_reason_prefix': 'เหตุผล: @reason',
  'audit_log_actor_prefix': 'โดย @name',

  'audit_log_action_order_create': 'เปิดออเดอร์ใหม่',
  'audit_log_action_order_item_add': 'เพิ่มรายการเข้าออเดอร์',
  'audit_log_action_order_item_edit': 'แก้ไขจำนวนรายการ',
  'audit_log_action_order_item_remove': 'ลบรายการออกจากออเดอร์',
  'audit_log_action_order_move_table': 'ย้ายโต๊ะ',
  'audit_log_action_order_merge': 'รวมบิล',
  'audit_log_action_order_cancel': 'ยกเลิกออเดอร์',
  'audit_log_action_order_item_void': 'ยกเลิกรายการหลังส่งครัว',
  'audit_log_action_order_discount': 'แก้ไขส่วนลด',
  'audit_log_action_user_deactivate': 'ปิดการใช้งานพนักงาน',
  'audit_log_action_user_delete': 'ลบบัญชีพนักงาน',
  'audit_log_action_user_role_change': 'เปลี่ยนสิทธิ์พนักงาน',
  'audit_log_action_user_password_reset': 'ตั้งรหัสผ่านใหม่ให้พนักงาน',
  'audit_log_action_settings_update': 'แก้ไขค่า VAT/ค่าบริการ',
  'audit_log_action_payment_refund': 'คืนเงิน',
  'audit_log_action_tax_invoice_void': 'ยกเลิกใบกำกับภาษี',
  'audit_log_shown_count': 'แสดง @shown จากทั้งหมด @total รายการ',
  'audit_log_load_more': 'โหลดเพิ่ม',

  // audit ระดับบัญชี/การเงิน (ดู docs/tickets/14-financial-audit-trail.md)
  'audit_log_action_menu_price_change': 'แก้ราคาเมนู',
  'audit_log_action_promotion_create': 'สร้างโปรโมชัน',
  'audit_log_action_promotion_update': 'แก้ไขโปรโมชัน',
  'audit_log_action_promotion_delete': 'ลบโปรโมชัน',
  'audit_log_action_ingredient_stock_adjust': 'ปรับสต๊อกวัตถุดิบมือ',
  'audit_log_date_range_all': 'ทุกช่วงเวลา',
  'audit_log_date_range_selected': '@from – @to',
  'audit_log_date_range_clear': 'ล้างช่วงวันที่',
  'audit_log_export_csv_button': 'ส่งออก CSV',
  'audit_log_export_unsupported_platform':
      'ส่งออก CSV รองรับเฉพาะบนเว็บ (หน้านี้อยู่ในโซนผู้ดูแลระบบซึ่งเป็นเว็บเท่านั้น)',

  // ขายตามน้ำหนัก/บาร์โค้ด/ขายเชื่อ (tickets 18–20)
  'audit_log_action_customer_credit_update': 'ตั้งวงเงินเครดิต',
  'audit_log_action_receivable_receipt': 'รับชำระหนี้',
  'audit_log_action_receivable_receipt_void': 'ยกเลิกใบเสร็จรับชำระหนี้',
  'audit_log_action_receivable_billing_note': 'ออกใบวางบิล',
  'audit_log_action_receivable_billing_note_void': 'ยกเลิกใบวางบิล',
  'audit_log_action_receivable_late_fee': 'คิดดอกเบี้ยผิดนัด',
  'audit_log_action_receivable_late_fee_void': 'ยกเว้นดอกเบี้ยผิดนัด',
  'audit_log_action_receivable_credit_note': 'ออกใบลดหนี้',
  'audit_log_action_receivable_document_email': 'ส่งเอกสารทางอีเมล',
  // ประโยคสรุปแต่ละ action ประกอบจาก metadata.summaryArgs (DECISIONS #74) — ภาษาไทยแสดง
  // ประโยคที่บันทึกไว้จริงเสมอ ชุดไทยนี้มีไว้ให้ครบคีย์และใช้เทียบในเทสต์ว่าค่าที่ส่งมาครบ
  'audit_log_actor_system': 'ระบบ',
  'audit_summary_order_create': 'เปิดออเดอร์ใหม่ #@code (@count รายการ)',
  'audit_summary_order_item_add':
      'เพิ่ม @count รายการเข้าออเดอร์ #@code: @lines',
  'audit_summary_order_item_edit':
      'แก้ไขจำนวน "@name" ในออเดอร์ #@code จาก @from เป็น @to',
  'audit_summary_order_item_remove': 'ลบรายการ "@line" ออกจากออเดอร์ #@code',
  'audit_summary_order_item_void':
      'ยกเลิกรายการ "@name" ในออเดอร์ #@code (สถานะก่อนยกเลิก: @status)',
  'audit_summary_order_discount_none': 'ยกเลิกส่วนลดออเดอร์ #@code',
  'audit_summary_order_discount_percent':
      'ให้ส่วนลดออเดอร์ #@code เป็น @value%',
  'audit_summary_order_discount_amount':
      'ให้ส่วนลดออเดอร์ #@code เป็น @value บาท',
  'audit_summary_order_promotion_redeem':
      'ใช้โค้ดส่วนลด "@promoCode" (@promoName) กับออเดอร์ #@code',
  'audit_summary_order_promotion_remove': 'เอาโปรโมชันออกจากออเดอร์ #@code',
  'audit_summary_order_move_table':
      'ย้ายออเดอร์ #@code จากโต๊ะ "@fromTable" ไปโต๊ะ "@toTable"',
  'audit_summary_order_merge': 'รวมบิล #@source เข้ากับ #@target',
  'audit_summary_order_cancel': 'ยกเลิกออเดอร์ #@code',
  'audit_summary_payment_pay':
      'รับชำระเงิน @amount บาท (@method) ออเดอร์ #@code',
  'audit_summary_payment_refund': 'คืนเงิน @amount บาท ให้ออเดอร์ #@code',
  'audit_summary_promotion_create': 'สร้างโปรโมชัน "@name"',
  'audit_summary_promotion_update': 'แก้ไขโปรโมชัน "@name"',
  'audit_summary_promotion_delete': 'ลบโปรโมชัน "@name"',
  'audit_summary_menu_price_change': 'แก้ราคาเมนู "@name" @from → @to บาท',
  'audit_summary_ingredient_stock_adjust_in':
      'ปรับสต๊อก "@name" รับเข้า @qty @unit (@from → @to)',
  'audit_summary_ingredient_stock_adjust_out':
      'ปรับสต๊อก "@name" ตัดออก @qty @unit (@from → @to)',
  'audit_summary_customer_credit_update':
      'ตั้งวงเงินเครดิต "@name" @fromLimit → @toLimit บาท เครดิต @fromDays → @toDays วัน',
  'audit_summary_receivable_billing_note':
      'ออกใบวางบิล @noteNo ให้ "@customer" @count บิล รวม @total บาท',
  'audit_summary_receivable_billing_note_void':
      'ยกเลิกใบวางบิล @noteNo ของ "@customer"',
  'audit_summary_receivable_receipt':
      'รับชำระหนี้ @amount บาท (@method) จาก "@customer" ใบเสร็จ @receiptNo',
  'audit_summary_receivable_receipt_void':
      'ยกเลิกใบเสร็จรับชำระหนี้ @receiptNo (@amount บาท) ของ "@customer"',
  'audit_summary_receivable_credit_note':
      'ออกใบลดหนี้ @noteNo @amount บาท ให้บิล #@code ของ "@customer"',
  'audit_summary_receivable_late_fee':
      'คิดดอกเบี้ยผิดนัด @total บาท (@rate% ต่อปี) ให้ "@customer" @count บิล ใบแจ้ง @chargeNo',
  'audit_summary_receivable_late_fee_void':
      'ยกเลิกใบแจ้งดอกเบี้ย @chargeNo (@total บาท) ของ "@customer"',
  'audit_summary_receivable_document_email':
      'ส่ง@document @number ของ "@customer" ทางอีเมลถึง @to',
  'audit_summary_demo_not_sent': ' (โหมดสาธิต — ไม่ได้ส่งจริง)',
  'audit_summary_settings_update': 'แก้ไขการตั้งค่า: @changes',
  'audit_summary_setting_vat': 'VAT @from% → @to%',
  'audit_summary_setting_service': 'ค่าบริการ @from% → @to%',
  'audit_summary_setting_late_fee': 'ดอกเบี้ยผิดนัด @from% → @to% ต่อปี',
  'audit_summary_shift_open': 'เปิดกะ เงินสดตั้งต้น @cash บาท',
  'audit_summary_shift_close':
      'ปิดกะ นับได้ @counted บาท คาดไว้ @expected บาท (ส่วนต่าง @variance บาท)',
  'audit_summary_tax_invoice_void':
      'ยกเลิกใบกำกับภาษีเลขที่ @number ของออเดอร์ #@code',
  'audit_summary_user_role_change':
      'เปลี่ยนสิทธิ์บัญชี "@name" จาก @from เป็น @to',
  'audit_summary_user_deactivate': 'ปิดการใช้งานบัญชี "@name" (@username)',
  'audit_summary_user_password_reset':
      'ตั้งรหัสผ่านใหม่ให้บัญชี "@name" (@username)',
  'audit_summary_user_delete': 'ลบบัญชี "@name" (@username) ออกจากระบบ',
  'audit_summary_line_quantity': '@name x@quantity',
  'audit_summary_line_weight': '@name @kg กก.',
  'audit_summary_document_billing_note': 'ใบวางบิล',
  'audit_summary_document_receipt': 'ใบเสร็จรับเงิน',
  'audit_summary_document_credit_note': 'ใบลดหนี้',
  'audit_summary_document_late_fee': 'ใบแจ้งดอกเบี้ยผิดนัด',
};

const Map<String, String> auditLogTranslationsEn = {
  'audit_log_empty_state': 'No activity recorded yet',
  'audit_log_reason_prefix': 'Reason: @reason',
  'audit_log_actor_prefix': 'By @name',

  'audit_log_action_order_create': 'Open new order',
  'audit_log_action_order_item_add': 'Add item to order',
  'audit_log_action_order_item_edit': 'Edit item quantity',
  'audit_log_action_order_item_remove': 'Remove item from order',
  'audit_log_action_order_move_table': 'Move table',
  'audit_log_action_order_merge': 'Merge bill',
  'audit_log_action_order_cancel': 'Cancel order',
  'audit_log_action_order_item_void': 'Void item after cooking',
  'audit_log_action_order_discount': 'Edit discount',
  'audit_log_action_user_deactivate': 'Deactivate staff',
  'audit_log_action_user_delete': 'Delete staff account',
  'audit_log_action_user_role_change': "Change staff's role",
  'audit_log_action_user_password_reset': 'Reset staff password',
  'audit_log_action_settings_update': 'Edit VAT/service charge',
  'audit_log_action_payment_refund': 'Refund',
  'audit_log_action_tax_invoice_void': 'Void tax invoice',
  'audit_log_shown_count': 'Showing @shown of @total entries',
  'audit_log_load_more': 'Load more',

  // Financial/accounting audit (see docs/tickets/14-financial-audit-trail.md)
  'audit_log_action_menu_price_change': 'Change menu price',
  'audit_log_action_promotion_create': 'Create promotion',
  'audit_log_action_promotion_update': 'Update promotion',
  'audit_log_action_promotion_delete': 'Delete promotion',
  'audit_log_action_ingredient_stock_adjust': 'Manual stock adjustment',
  'audit_log_date_range_all': 'All time',
  'audit_log_date_range_selected': '@from – @to',
  'audit_log_date_range_clear': 'Clear date range',
  'audit_log_export_csv_button': 'Export CSV',
  'audit_log_export_unsupported_platform':
      'CSV export is only supported on the web (this page is admin/web-only)',

  'audit_log_action_customer_credit_update': 'Credit terms change',
  'audit_log_action_receivable_receipt': 'Debt collected',
  'audit_log_action_receivable_receipt_void': 'Debt receipt voided',
  'audit_log_action_receivable_billing_note': 'Billing note issued',
  'audit_log_action_receivable_billing_note_void': 'Billing note voided',
  'audit_log_action_receivable_late_fee': 'Late interest charged',
  'audit_log_action_receivable_late_fee_void': 'Late interest waived',
  'audit_log_action_receivable_credit_note': 'Credit note issued',
  'audit_log_action_receivable_document_email': 'Document e-mailed',
  'audit_log_actor_system': 'System',
  'audit_summary_order_create': 'Opened order #@code (items: @count)',
  'audit_summary_order_item_add':
      'Added to order #@code (items: @count): @lines',
  'audit_summary_order_item_edit':
      'Changed the quantity of "@name" on order #@code from @from to @to',
  'audit_summary_order_item_remove': 'Removed "@line" from order #@code',
  'audit_summary_order_item_void':
      'Voided "@name" on order #@code (status before voiding: @status)',
  'audit_summary_order_discount_none': 'Removed the discount on order #@code',
  'audit_summary_order_discount_percent':
      'Gave order #@code a @value% discount',
  'audit_summary_order_discount_amount':
      'Gave order #@code a @value baht discount',
  'audit_summary_order_promotion_redeem':
      'Applied code "@promoCode" (@promoName) to order #@code',
  'audit_summary_order_promotion_remove':
      'Removed the promotion from order #@code',
  'audit_summary_order_move_table':
      'Moved order #@code from table "@fromTable" to "@toTable"',
  'audit_summary_order_merge': 'Merged bill #@source into #@target',
  'audit_summary_order_cancel': 'Cancelled order #@code',
  'audit_summary_payment_pay':
      'Received @amount baht (@method) for order #@code',
  'audit_summary_payment_refund': 'Refunded @amount baht on order #@code',
  'audit_summary_promotion_create': 'Created promotion "@name"',
  'audit_summary_promotion_update': 'Edited promotion "@name"',
  'audit_summary_promotion_delete': 'Deleted promotion "@name"',
  'audit_summary_menu_price_change':
      'Changed the price of "@name" from @from to @to baht',
  'audit_summary_ingredient_stock_adjust_in':
      'Adjusted stock of "@name": received @qty @unit (@from → @to)',
  'audit_summary_ingredient_stock_adjust_out':
      'Adjusted stock of "@name": removed @qty @unit (@from → @to)',
  'audit_summary_customer_credit_update':
      'Set the credit limit of "@name" from @fromLimit to @toLimit baht, terms @fromDays → @toDays days',
  'audit_summary_receivable_billing_note':
      'Issued billing note @noteNo to "@customer" (bills: @count, total @total baht)',
  'audit_summary_receivable_billing_note_void':
      'Voided billing note @noteNo of "@customer"',
  'audit_summary_receivable_receipt':
      'Received a @amount baht debt payment (@method) from "@customer", receipt @receiptNo',
  'audit_summary_receivable_receipt_void':
      'Voided payment receipt @receiptNo (@amount baht) of "@customer"',
  'audit_summary_receivable_credit_note':
      'Issued credit note @noteNo for @amount baht on bill #@code of "@customer"',
  'audit_summary_receivable_late_fee':
      'Charged "@customer" @total baht late-payment interest (@rate% a year, bills: @count), notice @chargeNo',
  'audit_summary_receivable_late_fee_void':
      'Voided interest notice @chargeNo (@total baht) of "@customer"',
  'audit_summary_receivable_document_email':
      'Emailed @document @number of "@customer" to @to',
  'audit_summary_demo_not_sent': ' (demo mode — not actually sent)',
  'audit_summary_settings_update': 'Changed settings: @changes',
  'audit_summary_setting_vat': 'VAT @from% → @to%',
  'audit_summary_setting_service': 'service charge @from% → @to%',
  'audit_summary_setting_late_fee':
      'late-payment interest @from% → @to% a year',
  'audit_summary_shift_open': 'Opened a shift with @cash baht starting cash',
  'audit_summary_shift_close':
      'Closed the shift: counted @counted baht, expected @expected baht (difference @variance baht)',
  'audit_summary_tax_invoice_void':
      'Voided tax invoice @number of order #@code',
  'audit_summary_user_role_change':
      'Changed the role of "@name" from @from to @to',
  'audit_summary_user_deactivate': 'Deactivated account "@name" (@username)',
  'audit_summary_user_password_reset':
      'Reset the password of "@name" (@username)',
  'audit_summary_user_delete': 'Deleted account "@name" (@username)',
  'audit_summary_line_quantity': '@name x@quantity',
  'audit_summary_line_weight': '@name @kg kg',
  'audit_summary_document_billing_note': 'billing note',
  'audit_summary_document_receipt': 'receipt',
  'audit_summary_document_credit_note': 'credit note',
  'audit_summary_document_late_fee': 'late-payment interest notice',
};

const Map<String, String> auditLogTranslationsKo = {
  'audit_log_empty_state': '기록된 활동이 없습니다',
  'audit_log_reason_prefix': '사유: @reason',
  'audit_log_actor_prefix': '처리자: @name',
  'audit_log_action_order_create': '신규 주문 생성',
  'audit_log_action_order_item_add': '주문에 메뉴 추가',
  'audit_log_action_order_item_edit': '메뉴 수량 변경',
  'audit_log_action_order_item_remove': '주문에서 메뉴 삭제',
  'audit_log_action_order_move_table': '테이블 이동',
  'audit_log_action_order_merge': '주문 합치기',
  'audit_log_action_order_cancel': '주문 취소',
  'audit_log_action_order_item_void': '조리 후 메뉴 취소',
  'audit_log_action_order_discount': '할인 변경',
  'audit_log_action_user_deactivate': '직원 계정 사용 중지',
  'audit_log_action_user_delete': '직원 계정 삭제',
  'audit_log_action_user_role_change': '직원 역할 변경',
  'audit_log_action_user_password_reset': '직원 비밀번호 재설정',
  'audit_log_action_settings_update': '부가가치세/서비스 차지 변경',
  'audit_log_action_payment_refund': '환불',
  'audit_log_action_tax_invoice_void': '세금계산서 취소',
  'audit_log_shown_count': '전체 @total건 중 @shown건 표시',
  'audit_log_load_more': '더 보기',
  'audit_log_action_menu_price_change': '메뉴 가격 변경',
  'audit_log_action_promotion_create': '프로모션 생성',
  'audit_log_action_promotion_update': '프로모션 수정',
  'audit_log_action_promotion_delete': '프로모션 삭제',
  'audit_log_action_ingredient_stock_adjust': '재고 수동 조정',
  'audit_log_date_range_all': '전체 기간',
  'audit_log_date_range_selected': '@from – @to',
  'audit_log_date_range_clear': '기간 초기화',
  'audit_log_export_csv_button': 'CSV 내보내기',
  'audit_log_export_unsupported_platform':
      'CSV 내보내기는 웹에서만 지원됩니다 (이 화면은 관리자 웹 전용입니다)',

  'audit_log_action_customer_credit_update': '신용 조건 변경',
  'audit_log_action_receivable_receipt': '외상 수금',
  'audit_log_action_receivable_receipt_void': '수금 영수증 취소',
  'audit_log_action_receivable_billing_note': '청구서 발행',
  'audit_log_action_receivable_billing_note_void': '청구서 취소',
  'audit_log_action_receivable_late_fee': '연체 이자 부과',
  'audit_log_action_receivable_late_fee_void': '연체 이자 면제',
  'audit_log_action_receivable_credit_note': '감액 전표 발행',
  'audit_log_action_receivable_document_email': '문서 이메일 발송',
  'audit_log_actor_system': '시스템',
  'audit_summary_order_create': '새 주문 #@code 열기 (@count개 항목)',
  'audit_summary_order_item_add': '주문 #@code에 @count개 항목 추가: @lines',
  'audit_summary_order_item_edit': '주문 #@code의 "@name" 수량을 @from에서 @to(으)로 변경',
  'audit_summary_order_item_remove': '주문 #@code에서 "@line" 삭제',
  'audit_summary_order_item_void': '주문 #@code의 "@name" 취소 (취소 전 상태: @status)',
  'audit_summary_order_discount_none': '주문 #@code 할인 해제',
  'audit_summary_order_discount_percent': '주문 #@code에 @value% 할인 적용',
  'audit_summary_order_discount_amount': '주문 #@code에 @value바트 할인 적용',
  'audit_summary_order_promotion_redeem':
      '주문 #@code에 할인 코드 "@promoCode"(@promoName) 적용',
  'audit_summary_order_promotion_remove': '주문 #@code에서 프로모션 제거',
  'audit_summary_order_move_table':
      '주문 #@code을(를) 테이블 "@fromTable"에서 "@toTable"(으)로 이동',
  'audit_summary_order_merge': '계산서 #@source을(를) #@target에 합침',
  'audit_summary_order_cancel': '주문 #@code 취소',
  'audit_summary_payment_pay': '주문 #@code 결제 @amount바트 수납 (@method)',
  'audit_summary_payment_refund': '주문 #@code에 @amount바트 환불',
  'audit_summary_promotion_create': '프로모션 "@name" 생성',
  'audit_summary_promotion_update': '프로모션 "@name" 수정',
  'audit_summary_promotion_delete': '프로모션 "@name" 삭제',
  'audit_summary_menu_price_change': '"@name" 가격 @from → @to바트로 변경',
  'audit_summary_ingredient_stock_adjust_in':
      '"@name" 재고 조정: @qty @unit 입고 (@from → @to)',
  'audit_summary_ingredient_stock_adjust_out':
      '"@name" 재고 조정: @qty @unit 차감 (@from → @to)',
  'audit_summary_customer_credit_update':
      '"@name" 신용 한도 @fromLimit → @toLimit바트, 결제 기한 @fromDays → @toDays일로 설정',
  'audit_summary_receivable_billing_note':
      '"@customer"에 청구서 @noteNo 발행 (@count건, 합계 @total바트)',
  'audit_summary_receivable_billing_note_void': '"@customer"의 청구서 @noteNo 취소',
  'audit_summary_receivable_receipt':
      '"@customer"에게서 외상 @amount바트 수금 (@method), 수금 영수증 @receiptNo',
  'audit_summary_receivable_receipt_void':
      '"@customer"의 수금 영수증 @receiptNo(@amount바트) 취소',
  'audit_summary_receivable_credit_note':
      '"@customer"의 계산서 #@code에 @amount바트 감액 전표 @noteNo 발행',
  'audit_summary_receivable_late_fee':
      '"@customer"에 연체 이자 @total바트 부과 (연 @rate%, @count건, 청구서 @chargeNo)',
  'audit_summary_receivable_late_fee_void':
      '"@customer"의 연체 이자 청구서 @chargeNo(@total바트) 취소',
  'audit_summary_receivable_document_email':
      '"@customer"의 @document @number을(를) @to(으)로 이메일 발송',
  'audit_summary_demo_not_sent': ' (데모 모드 — 실제로 발송되지 않음)',
  'audit_summary_settings_update': '설정 변경: @changes',
  'audit_summary_setting_vat': '부가세 @from% → @to%',
  'audit_summary_setting_service': '봉사료 @from% → @to%',
  'audit_summary_setting_late_fee': '연체 이자 연 @from% → @to%',
  'audit_summary_shift_open': '근무 시작, 시작 현금 @cash바트',
  'audit_summary_shift_close':
      '근무 종료: 실제 @counted바트, 예상 @expected바트 (차액 @variance바트)',
  'audit_summary_tax_invoice_void': '주문 #@code의 세금계산서 @number 취소',
  'audit_summary_user_role_change': '"@name" 계정 권한을 @from에서 @to(으)로 변경',
  'audit_summary_user_deactivate': '"@name"(@username) 계정 비활성화',
  'audit_summary_user_password_reset': '"@name"(@username) 계정 비밀번호 재설정',
  'audit_summary_user_delete': '"@name"(@username) 계정 삭제',
  'audit_summary_line_quantity': '@name x@quantity',
  'audit_summary_line_weight': '@name @kg kg',
  'audit_summary_document_billing_note': '청구서',
  'audit_summary_document_receipt': '수금 영수증',
  'audit_summary_document_credit_note': '감액 전표',
  'audit_summary_document_late_fee': '연체 이자 청구서',
};
