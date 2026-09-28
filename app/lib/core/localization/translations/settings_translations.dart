// Copyright 2026 Suruch Chakrapeesirisuk
// SPDX-License-Identifier: Apache-2.0

/// ข้อความในหน้าตั้งค่าร้าน (SettingsPage) และตัวสลับภาษา
const Map<String, String> settingsTranslationsTh = {
  'settings_store_info_title': 'ข้อมูลร้าน',
  'settings_store_info_subtitle': 'ชื่อร้านจะแสดงบนใบเสร็จ',
  'settings_store_name_label': 'ชื่อร้าน',
  'settings_bill_calc_title': 'การคำนวณบิล',
  'settings_bill_calc_subtitle': 'มีผลกับทุกออเดอร์ที่เปิดใหม่หลังจากนี้',
  'settings_vat_label': 'VAT',
  'settings_service_charge_label': 'Service Charge',
  'settings_vat_included_title': 'ราคาเมนูรวม VAT แล้ว',
  'settings_vat_included_subtitle':
      'ถ้าเปิด ระบบจะถอด VAT ออกมาแสดงแทนการบวกเพิ่ม',
  'settings_save_button': 'บันทึกการตั้งค่า',
  'settings_vat_range_error': 'VAT ต้องอยู่ระหว่าง 0-100',
  'settings_service_charge_range_error': 'Service Charge ต้องอยู่ระหว่าง 0-100',
  'settings_saved_success': 'บันทึกการตั้งค่าแล้ว',

  'settings_tax_invoice_title': 'ข้อมูลสำหรับออกใบกำกับภาษี',
  'settings_tax_invoice_subtitle':
      'ต้องตั้งค่าเลขผู้เสียภาษีและที่อยู่ร้านก่อน จึงจะออกใบกำกับภาษีได้',
  'settings_store_tax_id_label': 'เลขประจำตัวผู้เสียภาษี',
  'settings_store_tax_id_hint': '13 หลัก',
  'settings_store_address_label': 'ที่อยู่ร้าน',
  'settings_store_branch_label': 'สาขา',
  'settings_store_branch_hint': 'เช่น สำนักงานใหญ่, สาขาที่ 001',

  'settings_promptpay_title': 'พร้อมเพย์',
  'settings_promptpay_subtitle':
      'ต้องตั้งค่าก่อน ช่องทางจ่าย "QR" จึงจะแสดง QR พร้อมเพย์จริงให้ลูกค้าสแกนได้',
  'settings_promptpay_id_label': 'เลขพร้อมเพย์',
  'settings_promptpay_id_hint': 'เบอร์โทร/เลขบัตรประชาชน/เลขผู้เสียภาษี',
  'settings_promptpay_not_configured_error':
      'ร้านยังไม่ได้ตั้งค่าเลขพร้อมเพย์ (ตั้งได้ที่หน้าตั้งค่าระบบ)',

  'settings_printer_title': 'เครื่องพิมพ์ใบเสร็จ',
  'settings_printer_subtitle':
      'พิมพ์ผ่านเครื่องพิมพ์ความร้อนบนวง LAN/WiFi เดียวกัน (ยังไม่รองรับบนเว็บ)',
  'settings_printer_enable_title': 'เปิดใช้เครื่องพิมพ์นี้',
  'settings_printer_enable_subtitle': 'ปิดไว้ = ใช้ใบเสร็จบนจอเหมือนเดิม',
  'settings_printer_ip_label': 'IP เครื่องพิมพ์',
  'settings_printer_ip_hint': 'เช่น 192.168.1.50',
  'settings_printer_port_label': 'พอร์ต',
  'settings_printer_paper_58mm': '58 มม.',
  'settings_printer_paper_80mm': '80 มม.',
  'settings_printer_test_button': 'ทดสอบพิมพ์',
  'settings_printer_ip_required': 'กรุณากรอก IP เครื่องพิมพ์',
  'settings_printer_port_invalid': 'พอร์ตไม่ถูกต้อง',
  'settings_printer_saved_success': 'บันทึกการตั้งค่าเครื่องพิมพ์แล้ว',
  'settings_printer_test_success': 'พิมพ์ทดสอบสำเร็จ',
  'settings_printer_web_not_supported':
      'พิมพ์ผ่านเครื่องพิมพ์ความร้อนยังไม่รองรับบนเว็บ ใช้ใบเสร็จบนจอแทนได้',
  'settings_printer_not_configured':
      'ยังไม่ได้ตั้งค่าเครื่องพิมพ์ ไปที่ตั้งค่า > เครื่องพิมพ์ใบเสร็จ',
  'settings_printer_print_failed':
      'พิมพ์ใบเสร็จไม่สำเร็จ: เชื่อมต่อเครื่องพิมพ์ @error ไม่ได้ — ตรวจว่าเปิดเครื่องและอยู่ Wi-Fi เดียวกัน',
  'settings_printer_platform_not_supported':
      'ไม่รองรับการเชื่อมต่อเครื่องพิมพ์บนแพลตฟอร์มนี้',

  'settings_about_title': 'เกี่ยวกับระบบ',
  'settings_about_app_label': 'แอปพลิเคชัน',
  'settings_about_version_label': 'เวอร์ชัน',
  'settings_about_server_label': 'เซิร์ฟเวอร์',

  'settings_language_title': 'ภาษา',
  'settings_language_subtitle': 'เปลี่ยนภาษาที่แสดงในแอปทันที',
  'settings_language_th': 'ไทย',
  'settings_language_en': 'English',
  'settings_language_ko': '한국어',
  'settings_contrast_title': 'ความคมชัดของหน้าจอ',
  'settings_contrast_subtitle':
      'เลือก "สูง" ถ้าจอโดนแดด อยู่ในครัว หรือมองเห็นตัวหนังสือไม่ชัด',
  'settings_contrast_standard': 'ปกติ',
  'settings_contrast_high': 'สูง',

  'settings_loyalty_title': 'แต้มสะสม',
  'settings_loyalty_subtitle': 'อัตราแลกแต้ม มีผลกับทุกออเดอร์หลังจากนี้',
  'settings_points_earn_rate_label': 'จ่ายกี่บาทได้ 1 แต้ม',
  'settings_points_redeem_value_label': 'มูลค่า 1 แต้มตอนใช้แลกส่วนลด',
  'settings_points_baht_per_point': 'บาท',
  'settings_points_earn_rate_error': 'ยอดซื้อต่อ 1 แต้มต้องอย่างน้อย 0.01 บาท',
  'settings_points_redeem_value_error': 'มูลค่า 1 แต้มต้องอย่างน้อย 0.01 บาท',

  // ขายตามน้ำหนัก/บาร์โค้ด/ขายเชื่อ (tickets 18–20)
  'settings_scale_title': 'ฉลากตาชั่ง (บาร์โค้ดน้ำหนัก)',
  'settings_scale_subtitle':
      'ให้ตรงกับที่ตั้งไว้ในตาชั่งพิมพ์ฉลาก — สแกนฉลากแล้วได้ทั้งสินค้าและน้ำหนัก',
  'settings_scale_prefix_label': 'รหัสนำหน้า (prefix)',
  'settings_scale_plu_digits_label': 'จำนวนหลักของ PLU',
  'settings_scale_example':
      'EAN-13 = prefix + PLU @plu หลัก + น้ำหนัก (กรัม) + check digit',
  'settings_scale_label_invalid':
      'รูปแบบฉลากตาชั่ง: prefix ขึ้นต้นด้วย 2 (1–3 หลัก) และต้องเหลือหลักน้ำหนัก 4–6 หลัก',
  'settings_receivable_title': 'ลูกหนี้ขายเชื่อ',
  'settings_receivable_subtitle': 'ดอกเบี้ยผิดนัดชำระ และการส่งเอกสารทางอีเมล',
  'settings_late_fee_rate_label': 'ดอกเบี้ยผิดนัด',
  'settings_late_fee_rate_suffix': '% ต่อปี',
  'settings_late_fee_rate_helper': 'ใส่ 0 = ไม่คิดดอกเบี้ย',
  'settings_late_fee_grace_label': 'ผ่อนผันหลังครบกำหนด',
  'settings_late_fee_grace_suffix': 'วัน',
  'settings_late_fee_invalid':
      'ดอกเบี้ยผิดนัดต้องอยู่ระหว่าง 0–15% ต่อปี และวันผ่อนผัน 0–365 วัน',
  'settings_email_enabled':
      'ส่งใบวางบิล/เอกสารลูกหนี้เป็น PDF ทางอีเมลได้ (เซิร์ฟเวอร์ตั้งค่า SMTP แล้ว)',
  'settings_email_disabled':
      'ยังส่งอีเมลไม่ได้ — ผู้ดูแลเซิร์ฟเวอร์ต้องตั้ง SMTP_HOST ใน .env (ดาวน์โหลด PDF ยังใช้ได้)',
};

const Map<String, String> settingsTranslationsEn = {
  'settings_store_info_title': 'Store Info',
  'settings_store_info_subtitle': 'The store name appears on receipts',
  'settings_store_name_label': 'Store name',
  'settings_bill_calc_title': 'Bill Calculation',
  'settings_bill_calc_subtitle': 'Applies to every order opened after this',
  'settings_vat_label': 'VAT',
  'settings_service_charge_label': 'Service Charge',
  'settings_vat_included_title': 'Menu prices already include VAT',
  'settings_vat_included_subtitle':
      'When on, VAT is extracted from the price instead of added on top',
  'settings_save_button': 'Save settings',
  'settings_vat_range_error': 'VAT must be between 0-100',
  'settings_service_charge_range_error': 'Service Charge must be between 0-100',
  'settings_saved_success': 'Settings saved',

  'settings_tax_invoice_title': 'Tax Invoice Info',
  'settings_tax_invoice_subtitle':
      'Set the store tax ID and address first — required before issuing a tax invoice',
  'settings_store_tax_id_label': 'Tax ID',
  'settings_store_tax_id_hint': '13 digits',
  'settings_store_address_label': 'Store address',
  'settings_store_branch_label': 'Branch',
  'settings_store_branch_hint': 'e.g. Head Office, Branch 001',

  'settings_promptpay_title': 'PromptPay',
  'settings_promptpay_subtitle':
      'Set this before the "QR" payment method can show a real scannable PromptPay QR code',
  'settings_promptpay_id_label': 'PromptPay ID',
  'settings_promptpay_id_hint': 'Phone number / National ID / Tax ID',
  'settings_promptpay_not_configured_error':
      'The store has not set a PromptPay ID yet (set it under Settings)',

  'settings_printer_title': 'Receipt Printer',
  'settings_printer_subtitle':
      'Prints via a thermal printer on the same LAN/WiFi network (not supported on web yet)',
  'settings_printer_enable_title': 'Enable this printer',
  'settings_printer_enable_subtitle':
      'Off = show the receipt on screen as before',
  'settings_printer_ip_label': 'Printer IP',
  'settings_printer_ip_hint': 'e.g. 192.168.1.50',
  'settings_printer_port_label': 'Port',
  'settings_printer_paper_58mm': '58 mm',
  'settings_printer_paper_80mm': '80 mm',
  'settings_printer_test_button': 'Test print',
  'settings_printer_ip_required': 'Please enter the printer IP',
  'settings_printer_port_invalid': 'Invalid port',
  'settings_printer_saved_success': 'Printer settings saved',
  'settings_printer_test_success': 'Test print sent successfully',
  'settings_printer_web_not_supported':
      'Thermal printing is not supported on web yet. Use the on-screen receipt instead.',
  'settings_printer_not_configured':
      'The printer is not set up yet. Go to Settings > Receipt Printer.',
  'settings_printer_print_failed':
      'Print failed: could not reach the printer at @error — check it is on and on the same Wi-Fi',
  'settings_printer_platform_not_supported':
      'Printer connection is not supported on this platform',

  'settings_about_title': 'About',
  'settings_about_app_label': 'Application',
  'settings_about_version_label': 'Version',
  'settings_about_server_label': 'Server',

  'settings_language_title': 'Language',
  'settings_language_subtitle': 'Changes the app language immediately',
  'settings_language_th': 'ไทย',
  'settings_language_en': 'English',
  'settings_language_ko': '한국어',
  'settings_contrast_title': 'Screen contrast',
  'settings_contrast_subtitle':
      'Pick "High" for screens in sunlight or in the kitchen, or if text is hard to read',
  'settings_contrast_standard': 'Standard',
  'settings_contrast_high': 'High',

  'settings_loyalty_title': 'Loyalty points',
  'settings_loyalty_subtitle':
      'Exchange rate — applies to every order after this',
  'settings_points_earn_rate_label': 'Baht spent per 1 point earned',
  'settings_points_redeem_value_label': 'Value of 1 point when redeemed',
  'settings_points_baht_per_point': 'baht',
  'settings_points_earn_rate_error':
      'Baht spent per point must be at least 0.01',
  'settings_points_redeem_value_error':
      'The value of 1 point must be at least 0.01 baht',

  'settings_scale_title': 'Scale labels (weight barcodes)',
  'settings_scale_subtitle':
      'Match your label-printing scale — scanning a label gives both the item and its weight',
  'settings_scale_prefix_label': 'Prefix',
  'settings_scale_plu_digits_label': 'PLU digits',
  'settings_scale_example':
      'EAN-13 = prefix + @plu-digit PLU + weight (grams) + check digit',
  'settings_scale_label_invalid':
      'Scale label: prefix must start with 2 (1–3 digits) and leave 4–6 weight digits',
  'settings_receivable_title': 'Credit customers',
  'settings_receivable_subtitle':
      'Late-payment interest and e-mailing documents',
  'settings_late_fee_rate_label': 'Late-payment interest',
  'settings_late_fee_rate_suffix': '% per year',
  'settings_late_fee_rate_helper': 'Enter 0 to turn interest off',
  'settings_late_fee_grace_label': 'Grace after due date',
  'settings_late_fee_grace_suffix': 'days',
  'settings_late_fee_invalid':
      'Interest must be 0–15% per year and grace 0–365 days',
  'settings_email_enabled':
      'Billing notes and other documents can be e-mailed as PDF (SMTP configured)',
  'settings_email_disabled':
      'E-mail is off — the server admin must set SMTP_HOST in .env (PDF download still works)',
};

const Map<String, String> settingsTranslationsKo = {
  'settings_store_info_title': '매장 정보',
  'settings_store_info_subtitle': '매장명은 영수증에 표시됩니다',
  'settings_store_name_label': '매장명',
  'settings_bill_calc_title': '금액 계산',
  'settings_bill_calc_subtitle': '이후 새로 여는 주문부터 적용됩니다',
  'settings_vat_label': '부가가치세',
  'settings_service_charge_label': '서비스 차지',
  'settings_vat_included_title': '메뉴 가격에 부가세가 포함되어 있음',
  'settings_vat_included_subtitle': '켜면 가격에 더하지 않고 가격에서 부가세를 분리해 계산합니다',
  'settings_save_button': '설정 저장',
  'settings_vat_range_error': '부가가치세는 0~100 사이여야 합니다',
  'settings_service_charge_range_error': '서비스 차지는 0~100 사이여야 합니다',
  'settings_saved_success': '설정을 저장했습니다',
  'settings_tax_invoice_title': '세금계산서 정보',
  'settings_tax_invoice_subtitle': '세금계산서를 발행하려면 매장 사업자번호와 주소를 먼저 입력해야 합니다',
  'settings_store_tax_id_label': '사업자번호',
  'settings_store_tax_id_hint': '13자리',
  'settings_store_address_label': '매장 주소',
  'settings_store_branch_label': '지점',
  'settings_store_branch_hint': '예: 본점, 001지점',
  'settings_promptpay_title': '프롬프트페이',
  'settings_promptpay_subtitle': '입력해야 "QR" 결제 수단에서 실제로 스캔되는 프롬프트페이 QR이 표시됩니다',
  'settings_promptpay_id_label': '프롬프트페이 ID',
  'settings_promptpay_id_hint': '휴대폰 번호 / 주민등록번호 / 사업자번호',
  'settings_promptpay_not_configured_error':
      '매장에 프롬프트페이 ID가 아직 등록되지 않았습니다 (설정에서 입력하세요)',
  'settings_printer_title': '영수증 프린터',
  'settings_printer_subtitle':
      '같은 LAN/Wi-Fi 네트워크의 영수증 프린터로 출력합니다 (웹에서는 아직 지원되지 않습니다)',
  'settings_printer_enable_title': '이 프린터 사용',
  'settings_printer_enable_subtitle': '끄면 기존처럼 화면으로 영수증을 표시합니다',
  'settings_printer_ip_label': '프린터 IP',
  'settings_printer_ip_hint': '예: 192.168.1.50',
  'settings_printer_port_label': '포트',
  'settings_printer_paper_58mm': '58 mm',
  'settings_printer_paper_80mm': '80 mm',
  'settings_printer_test_button': '테스트 출력',
  'settings_printer_ip_required': '프린터 IP를 입력해 주세요',
  'settings_printer_port_invalid': '올바르지 않은 포트입니다',
  'settings_printer_saved_success': '프린터 설정을 저장했습니다',
  'settings_printer_test_success': '테스트 출력을 전송했습니다',
  'settings_printer_web_not_supported':
      '웹에서는 영수증 프린터 출력이 아직 지원되지 않습니다. 화면 영수증을 사용해 주세요.',
  'settings_printer_not_configured':
      '프린터가 아직 설정되지 않았습니다. 설정 > 영수증 프린터에서 등록해 주세요.',
  'settings_printer_print_failed':
      '출력 실패: 프린터(@error)에 연결할 수 없습니다 — 전원과 같은 Wi-Fi인지 확인하세요',
  'settings_printer_platform_not_supported': '이 플랫폼에서는 프린터 연결이 지원되지 않습니다',
  'settings_about_title': '정보',
  'settings_about_app_label': '애플리케이션',
  'settings_about_version_label': '버전',
  'settings_about_server_label': '서버',
  'settings_language_title': '언어',
  'settings_language_subtitle': '선택하면 앱 언어가 바로 바뀝니다',
  'settings_language_th': 'ไทย',
  'settings_language_en': 'English',
  'settings_language_ko': '한국어',
  'settings_contrast_title': '화면 대비',
  'settings_contrast_subtitle':
      '햇빛이 드는 자리나 주방에 두는 화면, 글씨가 잘 안 보일 때는 "높음"을 선택하세요',
  'settings_contrast_standard': '표준',
  'settings_contrast_high': '높음',
  'settings_loyalty_title': '적립금',
  'settings_loyalty_subtitle': '적립·사용 기준 — 이후 주문부터 적용됩니다',
  'settings_points_earn_rate_label': '1포인트 적립에 필요한 결제 금액',
  'settings_points_redeem_value_label': '1포인트 사용 시 금액',
  'settings_points_baht_per_point': '바트',
  'settings_points_earn_rate_error': '1포인트 적립에 필요한 결제 금액은 최소 0.01바트여야 합니다',
  'settings_points_redeem_value_error': '1포인트 사용 시 금액은 최소 0.01바트여야 합니다',

  'settings_scale_title': '저울 라벨 (무게 바코드)',
  'settings_scale_subtitle': '라벨 저울 설정과 맞추세요 — 라벨을 스캔하면 상품과 무게를 함께 읽습니다',
  'settings_scale_prefix_label': '접두어',
  'settings_scale_plu_digits_label': 'PLU 자릿수',
  'settings_scale_example': 'EAN-13 = 접두어 + PLU @plu자리 + 무게(그램) + 체크 디지트',
  'settings_scale_label_invalid':
      '저울 라벨: 접두어는 2로 시작(1–3자리)하고 무게 자릿수가 4–6자리 남아야 합니다',
  'settings_receivable_title': '외상 고객',
  'settings_receivable_subtitle': '연체 이자 및 문서 이메일 발송',
  'settings_late_fee_rate_label': '연체 이자',
  'settings_late_fee_rate_suffix': '% / 년',
  'settings_late_fee_rate_helper': '0을 입력하면 이자를 부과하지 않습니다',
  'settings_late_fee_grace_label': '만기 후 유예',
  'settings_late_fee_grace_suffix': '일',
  'settings_late_fee_invalid': '연체 이자는 연 0–15%, 유예는 0–365일이어야 합니다',
  'settings_email_enabled': '청구서 등 문서를 PDF로 이메일 발송할 수 있습니다 (SMTP 설정됨)',
  'settings_email_disabled':
      '이메일 사용 불가 — 서버 관리자가 .env에 SMTP_HOST를 설정해야 합니다 (PDF 다운로드는 가능)',
};
