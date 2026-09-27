// Copyright 2026 Suruch Chakrapeesirisuk
// SPDX-License-Identifier: Apache-2.0

/// คำแปลของฟีเจอร์ ingredient (วัตถุดิบ/สต๊อก — ดู docs/tickets/06-inventory-stock.md)
const Map<String, String> ingredientTranslationsTh = {
  'ingredient_form_item_code_label': 'รหัสสินค้าใน PaynEat ERP (ถ้ามี)',
  'ingredient_form_item_code_hint':
      'เช่น WHOLE-CHICKEN — ใส่ไว้แล้ววัตถุดิบนี้จะจับคู่กับ ERP เมื่อเชื่อมต่อ สูตรเมนูเดิมไม่หลุด',
  'ingredient_form_item_code_invalid':
      'รหัสสินค้าต้องเป็นตัวพิมพ์ใหญ่ A–Z ตัวเลข หรือ - ยาว 2–32 ตัว',
  // List page
  'ingredient_add_button': 'เพิ่มวัตถุดิบ',
  'ingredient_low_stock_filter': 'ใกล้หมดเท่านั้น',
  'ingredient_empty_state': 'ยังไม่มีวัตถุดิบในระบบ',
  'ingredient_low_stock_badge': 'ใกล้หมด',
  'ingredient_stock_summary':
      'เหลือ @stock @unit (แจ้งเตือนที่ @threshold @unit)',
  'ingredient_adjust_stock_tooltip': 'ปรับสต๊อก',

  // Adjust stock dialog
  'ingredient_adjust_stock_title': 'ปรับสต๊อก "@name"',
  'ingredient_current_stock_label': 'สต๊อกปัจจุบัน: @stock @unit',
  'ingredient_receive_stock_option': 'รับเข้า',
  'ingredient_deduct_stock_option': 'ตัดออก',
  'ingredient_adjust_amount_label': 'จำนวน',
  'ingredient_adjust_apply_button': 'บันทึก',

  // Form
  'ingredient_form_add_title': 'เพิ่มวัตถุดิบใหม่',
  'ingredient_form_edit_title': 'แก้ไขวัตถุดิบ',
  'ingredient_form_info_section': 'ข้อมูลวัตถุดิบ',
  'ingredient_form_name_label': 'ชื่อวัตถุดิบ *',
  'ingredient_form_name_required': 'กรุณากรอกชื่อวัตถุดิบ',
  'ingredient_form_unit_label': 'หน่วย *',
  'ingredient_form_unit_hint': 'เช่น กก., ลิตร, ชิ้น',
  'ingredient_form_unit_required': 'กรุณากรอกหน่วย',
  'ingredient_form_current_stock_label': 'สต๊อกเริ่มต้น',
  'ingredient_form_threshold_label': 'แจ้งเตือนเมื่อเหลือ',
  'ingredient_form_current_stock_locked_hint':
      'แก้ไขสต๊อกภายหลังต้องใช้ปุ่ม "ปรับสต๊อก" ในหน้ารายการ',
  'ingredient_form_submit_edit': 'บันทึกการแก้ไข',

  // Controller feedback messages
  'ingredient_created_success': 'เพิ่มวัตถุดิบใหม่แล้ว',
  'ingredient_updated_success': 'บันทึกการแก้ไขแล้ว',
  'ingredient_stock_adjusted_success': 'ปรับสต๊อกแล้ว',
  'ingredient_delete_title': 'ลบวัตถุดิบ',
  'ingredient_delete_confirm': 'ต้องการลบ "@name" ออกจากระบบใช่หรือไม่?',
  'ingredient_deleted_success': 'ลบวัตถุดิบแล้ว',

  // Demo store errors
  'ingredient_error_not_found': 'ไม่พบวัตถุดิบนี้',
  'ingredient_error_zero_delta': 'ต้องระบุจำนวนที่เปลี่ยนแปลงไม่เท่ากับ 0',
  'ingredient_error_linked_cannot_delete':
      'ลบไม่ได้ เพราะวัตถุดิบนี้ถูกผูกกับเมนูอยู่',
  'ingredient_error_duplicate_link': 'เลือกวัตถุดิบซ้ำกันในเมนูเดียวไม่ได้',
  'ingredient_error_link_not_found': 'ไม่พบวัตถุดิบที่เลือก',
};

const Map<String, String> ingredientTranslationsEn = {
  'ingredient_form_item_code_label': 'Item code in PaynEat ERP (optional)',
  'ingredient_form_item_code_hint':
      'e.g. WHOLE-CHICKEN — with it, this ingredient is matched to the ERP when the POS connects, keeping its recipes',
  'ingredient_form_item_code_invalid':
      'An item code is 2–32 capital letters A–Z, digits or -',
  // List page
  'ingredient_add_button': 'Add ingredient',
  'ingredient_low_stock_filter': 'Low stock only',
  'ingredient_empty_state': 'No ingredients yet',
  'ingredient_low_stock_badge': 'Low stock',
  'ingredient_stock_summary': '@stock @unit left (alerts at @threshold @unit)',
  'ingredient_adjust_stock_tooltip': 'Adjust stock',

  // Adjust stock dialog
  'ingredient_adjust_stock_title': 'Adjust stock for "@name"',
  'ingredient_current_stock_label': 'Current stock: @stock @unit',
  'ingredient_receive_stock_option': 'Receive',
  'ingredient_deduct_stock_option': 'Deduct',
  'ingredient_adjust_amount_label': 'Amount',
  'ingredient_adjust_apply_button': 'Save',

  // Form
  'ingredient_form_add_title': 'Add new ingredient',
  'ingredient_form_edit_title': 'Edit ingredient',
  'ingredient_form_info_section': 'Ingredient information',
  'ingredient_form_name_label': 'Ingredient name *',
  'ingredient_form_name_required': 'Please enter an ingredient name',
  'ingredient_form_unit_label': 'Unit *',
  'ingredient_form_unit_hint': 'e.g. kg, liter, piece',
  'ingredient_form_unit_required': 'Please enter a unit',
  'ingredient_form_current_stock_label': 'Starting stock',
  'ingredient_form_threshold_label': 'Alert when at or below',
  'ingredient_form_current_stock_locked_hint':
      'Use the "Adjust stock" button in the list to change stock later',
  'ingredient_form_submit_edit': 'Save changes',

  // Controller feedback messages
  'ingredient_created_success': 'New ingredient added',
  'ingredient_updated_success': 'Changes saved',
  'ingredient_stock_adjusted_success': 'Stock adjusted',
  'ingredient_delete_title': 'Delete ingredient',
  'ingredient_delete_confirm': 'Delete "@name" from the system?',
  'ingredient_deleted_success': 'Ingredient deleted',

  // Demo store errors
  'ingredient_error_not_found': 'Ingredient not found',
  'ingredient_error_zero_delta': 'Delta must not be zero',
  'ingredient_error_linked_cannot_delete':
      'Cannot delete: this ingredient is linked to a menu item',
  'ingredient_error_duplicate_link':
      'Cannot select the same ingredient twice for one menu item',
  'ingredient_error_link_not_found': 'Selected ingredient not found',
};

const Map<String, String> ingredientTranslationsKo = {
  'ingredient_form_item_code_label': 'PaynEat ERP 품목 코드 (선택)',
  'ingredient_form_item_code_hint':
      '예: WHOLE-CHICKEN — 입력해 두면 ERP에 연결할 때 이 재료가 연결되어 기존 레시피가 유지됩니다',
  'ingredient_form_item_code_invalid': '품목 코드는 대문자 A–Z, 숫자, - 로 2–32자입니다',
  'ingredient_add_button': '재료 추가',
  'ingredient_low_stock_filter': '재고 부족만',
  'ingredient_empty_state': '등록된 재료가 없습니다',
  'ingredient_low_stock_badge': '재고 부족',
  'ingredient_stock_summary': '@stock @unit 남음 (@threshold @unit 이하 시 알림)',
  'ingredient_adjust_stock_tooltip': '재고 조정',
  'ingredient_adjust_stock_title': '"@name" 재고 조정',
  'ingredient_current_stock_label': '현재 재고: @stock @unit',
  'ingredient_receive_stock_option': '입고',
  'ingredient_deduct_stock_option': '차감',
  'ingredient_adjust_amount_label': '수량',
  'ingredient_adjust_apply_button': '저장',
  'ingredient_form_add_title': '재료 추가',
  'ingredient_form_edit_title': '재료 수정',
  'ingredient_form_info_section': '재료 정보',
  'ingredient_form_name_label': '재료명 *',
  'ingredient_form_name_required': '재료명을 입력해 주세요',
  'ingredient_form_unit_label': '단위 *',
  'ingredient_form_unit_hint': '예: kg, 리터, 개',
  'ingredient_form_unit_required': '단위를 입력해 주세요',
  'ingredient_form_current_stock_label': '초기 재고',
  'ingredient_form_threshold_label': '이 수량 이하일 때 알림',
  'ingredient_form_current_stock_locked_hint':
      '재고를 나중에 변경하려면 목록의 "재고 조정" 버튼을 사용하세요',
  'ingredient_form_submit_edit': '변경사항 저장',
  'ingredient_created_success': '재료를 추가했습니다',
  'ingredient_updated_success': '변경사항을 저장했습니다',
  'ingredient_stock_adjusted_success': '재고를 조정했습니다',
  'ingredient_delete_title': '재료 삭제',
  'ingredient_delete_confirm': '"@name"을(를) 삭제할까요?',
  'ingredient_deleted_success': '재료를 삭제했습니다',
  'ingredient_error_not_found': '재료를 찾을 수 없습니다',
  'ingredient_error_zero_delta': '변경 수량은 0일 수 없습니다',
  'ingredient_error_linked_cannot_delete': '메뉴에 연결된 재료는 삭제할 수 없습니다',
  'ingredient_error_duplicate_link': '한 메뉴에 같은 재료를 두 번 선택할 수 없습니다',
  'ingredient_error_link_not_found': '선택한 재료를 찾을 수 없습니다',
};
