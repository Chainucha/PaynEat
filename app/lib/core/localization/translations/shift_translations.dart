// Copyright 2026 Suruch Chakrapeesirisuk
// SPDX-License-Identifier: Apache-2.0

/// คำแปลของฟีเจอร์ shift — เปิด/ปิดกะแคชเชียร์ และกระทบยอดเงินสด
const Map<String, String> shiftTranslationsTh = {
  'shift_page_title': 'เปิด / ปิดกะ',

  'shift_open_new_shift': 'เปิดกะใหม่',
  'shift_open_new_subtitle': 'กรอกเงินสดตั้งต้นในลิ้นชักก่อนเริ่มรับชำระเงิน',
  'shift_starting_cash_label': 'เงินตั้งต้น',
  'shift_open_button': 'เปิดกะ',

  'shift_currently_open_title': 'กะกำลังเปิดอยู่',
  'shift_opened_by_label': 'เปิดโดย',
  'shift_opened_at_label': 'เวลาเปิดกะ',

  'shift_close_button': 'ปิดกะ',
  'shift_close_subtitle':
      'นับเงินสดในลิ้นชักจริงแล้วกรอกยอด ระบบจะคำนวณส่วนต่างให้อัตโนมัติ',
  'shift_counted_cash_label': 'ยอดเงินสดที่นับได้จริง',
  'shift_note_label': 'หมายเหตุ (ถ้ามี)',

  'shift_close_summary_title': 'สรุปผลปิดกะ',
  'shift_expected_cash_label': 'ยอดที่ระบบคาดไว้',
  'shift_variance_balanced': 'ยอดตรงพอดี',
  'shift_variance_short': 'เงินขาด',
  'shift_variance_over': 'เงินเกิน',

  'shift_history_title': 'ประวัติกะย้อนหลัง',
  'shift_history_open_subtitle': 'เปิดอยู่ · @name',
  'shift_variance_label': 'ปิดแล้ว · ส่วนต่าง @amount',

  'shift_invalid_opening_cash': 'กรุณากรอกเงินตั้งต้นให้ถูกต้อง',
  'shift_open_success': 'เปิดกะเรียบร้อย',
  'shift_invalid_counted_cash': 'กรุณากรอกยอดเงินสดที่นับได้ให้ถูกต้อง',
  'shift_close_confirm_title': 'ยืนยันปิดกะ',
  'shift_close_confirm_message':
      'ปิดกะนี้แล้วจะแก้ไขไม่ได้ ต้องการดำเนินการต่อหรือไม่?',
  'shift_close_success': 'ปิดกะเรียบร้อย',
  'shift_close_backup_failed':
      'ปิดกะเรียบร้อยแล้ว แต่สำรองข้อมูลหลังปิดกะไม่สำเร็จ แจ้งเจ้าของร้านให้ตรวจส่วนสำรองข้อมูลในหน้าตั้งค่า',

  'shift_error_already_open': 'มีกะที่เปิดอยู่แล้ว ต้องปิดกะเดิมก่อนเปิดกะใหม่',
  'shift_error_not_found': 'ไม่พบกะนี้',
  'shift_error_already_closed': 'กะนี้ปิดไปแล้ว',

  // Z-report ปิดกะ (ดู docs/tickets/12-report-export.md)
  'shift_z_report_view_button': 'ดูใบสรุปปิดกะ (Z-report)',
  'shift_z_report_title': 'ใบสรุปปิดกะ (Z-report)',
  'shift_z_report_guest_count_label': 'จำนวนลูกค้า',
  'shift_z_report_discount_label': 'ส่วนลดที่กรอกเอง',
  'shift_z_report_promotion_discount_label': 'ส่วนลดจากโปรโมชัน',
  'shift_z_report_total_discount_label': 'ส่วนลดรวม',
  'shift_z_report_service_charge_label': 'ค่าบริการ',
  'shift_z_report_vat_label': 'ภาษีมูลค่าเพิ่ม',
  'shift_z_report_refund_label': 'ยอดคืนเงิน',
  'shift_z_report_cash_reconciliation_title': 'กระทบยอดเงินสด',
  'shift_z_report_variance_label': 'ส่วนต่างเงินสด',
  'shift_z_report_export_button': 'ส่งออก CSV',
  'shift_z_report_export_unsupported_platform': 'ส่งออก CSV รองรับเฉพาะบนเว็บ',

  // ขายตามน้ำหนัก/บาร์โค้ด/ขายเชื่อ (tickets 18–20)
  'shift_z_report_receivables_title': 'รับชำระหนี้ (ลูกหนี้)',
};

const Map<String, String> shiftTranslationsEn = {
  'shift_page_title': 'Open / Close Shift',

  'shift_open_new_shift': 'Open new shift',
  'shift_open_new_subtitle':
      'Enter the starting cash in the drawer before you start accepting payments',
  'shift_starting_cash_label': 'Starting cash',
  'shift_open_button': 'Open shift',

  'shift_currently_open_title': 'Shift currently open',
  'shift_opened_by_label': 'Opened by',
  'shift_opened_at_label': 'Opened at',

  'shift_close_button': 'Close shift',
  'shift_close_subtitle':
      'Count the actual cash in the drawer and enter the amount — the system will calculate the variance automatically',
  'shift_counted_cash_label': 'Counted cash',
  'shift_note_label': 'Note (optional)',

  'shift_close_summary_title': 'Shift close summary',
  'shift_expected_cash_label': 'Expected cash',
  'shift_variance_balanced': 'Balanced',
  'shift_variance_short': 'Cash short',
  'shift_variance_over': 'Cash over',

  'shift_history_title': 'Shift history',
  'shift_history_open_subtitle': 'Open · @name',
  'shift_variance_label': 'Closed · Variance @amount',

  'shift_invalid_opening_cash': 'Please enter a valid starting cash amount',
  'shift_open_success': 'Shift opened successfully',
  'shift_invalid_counted_cash': 'Please enter a valid counted cash amount',
  'shift_close_confirm_title': 'Confirm close shift',
  'shift_close_confirm_message':
      'Once closed, this shift cannot be edited. Do you want to continue?',
  'shift_close_success': 'Shift closed successfully',
  'shift_close_backup_failed':
      'The shift is closed, but the backup after closing it failed. Ask the shop owner to check Backups in Settings',

  'shift_error_already_open':
      'A shift is already open. Close it before opening a new one.',
  'shift_error_not_found': 'Shift not found',
  'shift_error_already_closed': 'This shift is already closed',

  // Z-report (see docs/tickets/12-report-export.md)
  'shift_z_report_view_button': 'View Z-report',
  'shift_z_report_title': 'Z-report',
  'shift_z_report_guest_count_label': 'Guest count',
  'shift_z_report_discount_label': 'Manual discount',
  'shift_z_report_promotion_discount_label': 'Promotion discount',
  'shift_z_report_total_discount_label': 'Total discount',
  'shift_z_report_service_charge_label': 'Service charge',
  'shift_z_report_vat_label': 'VAT',
  'shift_z_report_refund_label': 'Refunds',
  'shift_z_report_cash_reconciliation_title': 'Cash reconciliation',
  'shift_z_report_variance_label': 'Cash variance',
  'shift_z_report_export_button': 'Export CSV',
  'shift_z_report_export_unsupported_platform':
      'CSV export is only supported on the web',

  'shift_z_report_receivables_title': 'Debt collected (receivables)',
};

const Map<String, String> shiftTranslationsKo = {
  'shift_page_title': '근무 시작 / 마감',
  'shift_open_new_shift': '근무 시작',
  'shift_open_new_subtitle': '결제를 받기 전에 금전등록기에 있는 시재를 입력하세요',
  'shift_starting_cash_label': '시작 시재',
  'shift_open_button': '근무 시작',
  'shift_currently_open_title': '진행 중인 근무',
  'shift_opened_by_label': '시작한 사람',
  'shift_opened_at_label': '시작 시각',
  'shift_close_button': '근무 마감',
  'shift_close_subtitle': '금전등록기의 실제 현금을 세어 입력하면 차액을 자동으로 계산합니다',
  'shift_counted_cash_label': '실제 현금',
  'shift_note_label': '메모 (선택)',
  'shift_close_summary_title': '마감 정산 요약',
  'shift_expected_cash_label': '예상 현금',
  'shift_variance_balanced': '일치',
  'shift_variance_short': '현금 부족',
  'shift_variance_over': '현금 초과',
  'shift_history_title': '근무 이력',
  'shift_history_open_subtitle': '진행 중 · @name',
  'shift_variance_label': '마감됨 · 차액 @amount',
  'shift_invalid_opening_cash': '올바른 시작 시재 금액을 입력해 주세요',
  'shift_open_success': '근무를 시작했습니다',
  'shift_invalid_counted_cash': '올바른 실제 현금 금액을 입력해 주세요',
  'shift_close_confirm_title': '근무 마감 확인',
  'shift_close_confirm_message': '마감한 근무는 수정할 수 없습니다. 계속하시겠습니까?',
  'shift_close_success': '근무를 마감했습니다',
  'shift_close_backup_failed':
      '근무는 마감되었지만 마감 후 백업에 실패했습니다. 매장 주인에게 설정의 백업을 확인해 달라고 하세요',
  'shift_error_already_open': '이미 진행 중인 근무가 있습니다. 마감한 뒤 새로 시작해 주세요.',
  'shift_error_not_found': '근무 기록을 찾을 수 없습니다',
  'shift_error_already_closed': '이미 마감된 근무입니다',
  'shift_z_report_view_button': 'Z 리포트 보기',
  'shift_z_report_title': 'Z 리포트',
  'shift_z_report_guest_count_label': '방문 인원',
  'shift_z_report_discount_label': '수동 할인',
  'shift_z_report_promotion_discount_label': '프로모션 할인',
  'shift_z_report_total_discount_label': '할인 합계',
  'shift_z_report_service_charge_label': '서비스 차지',
  'shift_z_report_vat_label': '부가가치세',
  'shift_z_report_refund_label': '환불',
  'shift_z_report_cash_reconciliation_title': '현금 정산',
  'shift_z_report_variance_label': '현금 차액',
  'shift_z_report_export_button': 'CSV 내보내기',
  'shift_z_report_export_unsupported_platform': 'CSV 내보내기는 웹에서만 지원됩니다',

  'shift_z_report_receivables_title': '외상 수금',
};
