// Copyright 2026 Suruch Chakrapeesirisuk
// SPDX-License-Identifier: Apache-2.0

/// คำแปลของหัวข้อ "การเชื่อมต่อ" และโหมดเชื่อมต่อ PaynEat ERP (ดู docs/tickets/25-erp-connected-mode.md)
const Map<String, String> erpConnectionTranslationsTh = {
  'erp_connection_title': 'การเชื่อมต่อ',
  'erp_connection_subtitle': 'เซิร์ฟเวอร์ของร้าน และ PaynEat ERP ของเชน',
  'erp_store_server_title': 'เซิร์ฟเวอร์ร้าน',
  'erp_store_server_demo': 'โหมดสาธิต — ข้อมูลอยู่ในเครื่องนี้',
  'erp_section_title': 'PaynEat ERP',
  'erp_section_subtitle':
      'สำหรับเชนที่ใช้ PaynEat ERP ดูแลวัตถุดิบและสาขา — ร้านเดี่ยวไม่ต้องตั้งค่าส่วนนี้',
  'erp_mode_standalone': 'ใช้งานเดี่ยว',
  'erp_mode_connected': 'เชื่อมต่อแล้ว · @instance',
  'erp_demo_note':
      'โหมดสาธิตใช้งานเดี่ยวเสมอ — เชื่อมต่อ ERP ได้เมื่อใช้กับเซิร์ฟเวอร์ร้านจริง',
  'erp_url_label': 'ที่อยู่ของ PaynEat ERP',
  'erp_credential_label': 'Credential ของเครื่องนี้',
  'erp_credential_hint': 'pnepos_… (ERP แสดงครั้งเดียวตอนลงทะเบียน POS)',
  'erp_credential_saved': 'บันทึกไว้แล้ว (ไม่แสดงอีก)',
  'erp_connect_button': 'เชื่อมต่อ',
  'erp_save_credential_button': 'บันทึก credential ใหม่',
  'erp_change_credential_button': 'เปลี่ยน credential',
  'erp_pull_button': 'ดึงทันที',
  'erp_disconnect_button': 'ออกจากโหมดเชื่อมต่อ',
  'erp_disconnect_title': 'ออกจากโหมดเชื่อมต่อ?',
  'erp_disconnect_confirm':
      'credential จะถูกลบ วัตถุดิบและสาขาที่ดึงมาจาก ERP ยังอยู่และกลับมาแก้ในเครื่องได้ '
      'นับสต๊อกใหม่ก่อน เพราะเมนูจะกลับมาปิดขายอัตโนมัติตามยอดในเครื่อง',
  'erp_info_instance': 'POS ในระบบ ERP',
  'erp_info_contract': 'สัญญาเชื่อมต่อ',
  'erp_info_version': 'ข้อมูลล่าสุด',
  'erp_info_version_value': 'เวอร์ชัน @applied จาก @latest',
  'erp_info_last_pull': 'ดึงสำเร็จครั้งล่าสุด',
  'erp_info_never': 'ยังไม่เคย',
  'erp_branches_to_fix_title': 'แก้รหัสสาขาก่อนเชื่อมต่อ',
  'erp_branch_problem_missing': 'ยังไม่มีรหัส',
  'erp_branch_problem_invalid': 'รหัส "@code" ไม่ตรงรูปแบบ',
  'erp_branch_code_rule':
      'รหัสต้องตรงกับรหัสสาขาใน ERP: ตัวพิมพ์ใหญ่ A–Z ตัวเลข หรือ - ยาว 2–32 ตัว',
  'erp_branch_edit_code': 'แก้รหัส',
  'erp_branch_code_dialog_title': 'รหัสสาขา "@name"',
  'erp_branch_code_label': 'รหัสสาขา',
  'erp_branches_not_served_title':
      'สาขาในเครื่องที่ ERP ไม่ได้ให้เครื่องนี้ดูแล',
  'erp_branches_not_served_note':
      'ตรวจกับผู้ดูแล ERP ว่าลงทะเบียนสาขาให้ POS เครื่องนี้ครบหรือยัง',
  'erp_served_missing_title': 'สาขาที่ ERP ให้ดูแลแต่ในเครื่องยังไม่มี',
  'erp_served_missing_note':
      'กด "สร้างในเครื่อง" เพื่อเพิ่มสาขาด้วยรหัสและชื่อจาก ERP แล้วกำหนดพนักงานให้สาขาที่หน้าพนักงาน',
  'erp_branch_create_button': 'สร้างในเครื่อง',
  'erp_branch_create_title': 'สร้างสาขานี้ในเครื่อง?',
  'erp_branch_create_confirm':
      'สร้างสาขา "@name" (@code) ด้วยรหัสและชื่อจาก PaynEat ERP — ระบบดึงข้อมูลล่าสุดก่อน ถ้า ERP เพิ่งเปลี่ยนรหัสสาขาเดิมเป็นรหัสนี้ สาขาเดิมจะย้ายมาใช้รหัสนี้แทนการสร้างสาขาซ้ำ',
  'erp_branch_created_notice':
      'สร้างสาขา @name (@code) แล้ว — กำหนดพนักงานให้สาขานี้ที่หน้าพนักงาน',
  'erp_branch_superseded':
      'ERP เปลี่ยนเป็นรหัส @code แต่ในเครื่องมีสาขารหัสนั้นอยู่แล้ว',
  'erp_stock_note':
      'ยอดคงเหลือเป็นของ ERP — เมนูไม่ถูกปิดขายอัตโนมัติจากสต๊อกในเครื่อง ปิดขายด้วยมือที่หน้าเมนูแทน',
  'erp_connected_notice': 'เชื่อมต่อในนาม @instance แล้ว',
  'erp_disconnected_notice': 'ออกจากโหมดเชื่อมต่อแล้ว — กลับมาใช้งานเดี่ยว',
  'erp_pulled_notice': 'ดึงแล้ว @count รายการ ตอนนี้อยู่ที่เวอร์ชัน @version',
  'erp_error_url_required': 'กรอกที่อยู่ของ PaynEat ERP',
  'erp_error_credential_format': 'credential ต้องขึ้นต้นด้วย pnepos_',
  'erp_error_fix_branch_codes': 'แก้รหัสสาขาด้านบนก่อนเชื่อมต่อ',
  'erp_error_branch_code_format':
      'รหัสสาขาต้องเป็นตัวพิมพ์ใหญ่ A–Z ตัวเลข หรือ - ยาว 2–32 ตัว',
  'erp_error_demo_mode': 'โหมดสาธิตเชื่อมต่อ PaynEat ERP ไม่ได้',
  'erp_last_error_credential':
      'ERP ไม่รับ credential นี้แล้ว — หยุดดึงข้อมูลจนกว่าจะบันทึก credential ใหม่',
  'erp_last_error_network': 'ดึงครั้งล่าสุดติดต่อ ERP ไม่ได้ จะลองใหม่ตามรอบ',
  'erp_last_error_unavailable':
      'ERP ไม่พร้อมชั่วคราวตอนดึงครั้งล่าสุด จะลองใหม่ตามรอบ',
  'erp_last_error_rate_limited': 'ERP ขอให้รอก่อนดึงครั้งถัดไป',
  'erp_last_error_invalid_response':
      'คำตอบของ ERP ไม่ตรงกับสัญญาเชื่อมต่อ — แจ้งผู้ดูแล ERP',
  'erp_last_error_unsupported_contract':
      'ERP ใช้สัญญาเวอร์ชันที่ POS รุ่นนี้ไม่รองรับ — อัปเดต POS',
  'erp_last_error_refused': 'ERP ปฏิเสธคำขอ — ตรวจที่อยู่และ proxy',
  'erp_last_error_other': 'ดึงครั้งล่าสุดไม่สำเร็จ',
  'erp_pull_stopped_note':
      'หยุดดึงตามรอบเวลาไว้จนกว่าจะแก้ต้นเหตุ — แก้แล้วกด "ดึงทันที" ระบบจะกลับมาดึงตามรอบเอง',
  'erp_managed_badge': 'จัดการใน PaynEat ERP',
  'erp_managed_banner':
      'วัตถุดิบจัดการใน PaynEat ERP — แก้ที่ ERP แล้วดึงข้อมูลใหม่ ยอดคงเหลือดูที่ ERP',
  'erp_item_inactive': 'เลิกใช้ใน ERP',
  'erp_item_code_summary': 'รหัส @code · หน่วย @unit',
  'erp_unit_kg': 'กิโลกรัม',
  'erp_unit_g': 'กรัม',
  'erp_unit_l': 'ลิตร',
  'erp_unit_ml': 'มิลลิลิตร',
  'erp_unit_piece': 'ชิ้น',
  'erp_unit_pack': 'แพ็ก',
  'erp_unit_case': 'ลัง',
  'erp_unit_bag': 'ถุง',
  'erp_unit_sack': 'กระสอบ',
  'erp_unit_bottle': 'ขวด',
  'erp_unit_tin': 'ปี๊บ',
  'erp_unit_box': 'กล่อง',
  'erp_unit_tray': 'ถาด',
};

const Map<String, String> erpConnectionTranslationsEn = {
  'erp_connection_title': 'Connections',
  'erp_connection_subtitle': "The shop's server, and the chain's PaynEat ERP",
  'erp_store_server_title': 'Shop server',
  'erp_store_server_demo': 'Demo mode — data stays on this device',
  'erp_section_title': 'PaynEat ERP',
  'erp_section_subtitle':
      'For chains whose ingredients and branches are managed in PaynEat ERP — a single shop can skip this',
  'erp_mode_standalone': 'Standalone',
  'erp_mode_connected': 'Connected · @instance',
  'erp_demo_note':
      'Demo mode is always standalone — connect to an ERP when running against a real shop server',
  'erp_url_label': "PaynEat ERP's address",
  'erp_credential_label': "This POS's credential",
  'erp_credential_hint':
      'pnepos_… (shown once by the ERP when the POS is registered)',
  'erp_credential_saved': 'Saved (never shown again)',
  'erp_connect_button': 'Connect',
  'erp_save_credential_button': 'Save new credential',
  'erp_change_credential_button': 'Change credential',
  'erp_pull_button': 'Pull now',
  'erp_disconnect_button': 'Leave connected mode',
  'erp_disconnect_title': 'Leave connected mode?',
  'erp_disconnect_confirm':
      'The credential is deleted. Ingredients and branches pulled from the ERP stay and become editable here again. '
      'Count stock first: menu items go back to closing automatically on this device\'s stock.',
  'erp_info_instance': 'POS in the ERP',
  'erp_info_contract': 'Integration contract',
  'erp_info_version': 'Master data',
  'erp_info_version_value': 'version @applied of @latest',
  'erp_info_last_pull': 'Last successful pull',
  'erp_info_never': 'Never',
  'erp_branches_to_fix_title': 'Fix branch codes before connecting',
  'erp_branch_problem_missing': 'No code yet',
  'erp_branch_problem_invalid': 'Code "@code" has the wrong format',
  'erp_branch_code_rule':
      "The code must match the branch's code in the ERP: 2–32 capital letters A–Z, digits or -",
  'erp_branch_edit_code': 'Edit code',
  'erp_branch_code_dialog_title': 'Branch code of "@name"',
  'erp_branch_code_label': 'Branch code',
  'erp_branches_not_served_title':
      "Branches on this device the ERP doesn't assign to this POS",
  'erp_branches_not_served_note':
      'Check with the ERP administrator that every branch is registered for this POS',
  'erp_served_missing_title':
      'Branches the ERP assigns to this POS that are not on this device',
  'erp_served_missing_note':
      'Tap "Create here" to add the branch with the code and name from the ERP, then assign staff to it on the staff page',
  'erp_branch_create_button': 'Create here',
  'erp_branch_create_title': 'Create this branch on this device?',
  'erp_branch_create_confirm':
      'Create branch "@name" (@code) with the code and name from PaynEat ERP — the latest data is pulled first; if the ERP just moved an existing branch to this code, that branch takes the code instead of a duplicate being created',
  'erp_branch_created_notice':
      'Created branch @name (@code) — assign staff to it on the staff page',
  'erp_branch_superseded':
      'The ERP moved this branch to code @code, but a branch with that code already exists here',
  'erp_stock_note':
      "Stock on hand belongs to the ERP — menu items aren't closed automatically from this device's stock; close them by hand on the menu page",
  'erp_connected_notice': 'Connected as @instance',
  'erp_disconnected_notice': 'Left connected mode — back to standalone',
  'erp_pulled_notice': 'Pulled @count changes, now at version @version',
  'erp_error_url_required': "Enter PaynEat ERP's address",
  'erp_error_credential_format': 'The credential starts with pnepos_',
  'erp_error_fix_branch_codes': 'Fix the branch codes above before connecting',
  'erp_error_branch_code_format':
      'A branch code is 2–32 capital letters A–Z, digits or -',
  'erp_error_demo_mode': "Demo mode can't connect to PaynEat ERP",
  'erp_last_error_credential':
      'The ERP no longer accepts this credential — pulling has stopped until a new one is saved',
  'erp_last_error_network':
      "The last pull couldn't reach the ERP; it will try again on schedule",
  'erp_last_error_unavailable':
      'The ERP was briefly unavailable at the last pull; it will try again on schedule',
  'erp_last_error_rate_limited': 'The ERP asked to wait before the next pull',
  'erp_last_error_invalid_response':
      "The ERP's answer doesn't match the integration contract — tell the ERP administrator",
  'erp_last_error_unsupported_contract':
      "The ERP uses a contract version this POS doesn't support — update the POS",
  'erp_last_error_refused':
      'The ERP refused the request — check the address and any proxy',
  'erp_last_error_other': 'The last pull failed',
  'erp_pull_stopped_note':
      'Scheduled pulls are stopped until the cause is fixed — fix it, then tap "Pull now" and scheduled pulls resume',
  'erp_managed_badge': 'Managed in PaynEat ERP',
  'erp_managed_banner':
      'Ingredients are managed in PaynEat ERP — change them there, then pull again. Stock on hand is in the ERP',
  'erp_item_inactive': 'Retired in the ERP',
  'erp_item_code_summary': 'Code @code · unit @unit',
  'erp_unit_kg': 'kilogram',
  'erp_unit_g': 'gram',
  'erp_unit_l': 'litre',
  'erp_unit_ml': 'millilitre',
  'erp_unit_piece': 'piece',
  'erp_unit_pack': 'pack',
  'erp_unit_case': 'case',
  'erp_unit_bag': 'bag',
  'erp_unit_sack': 'sack',
  'erp_unit_bottle': 'bottle',
  'erp_unit_tin': 'tin',
  'erp_unit_box': 'box',
  'erp_unit_tray': 'tray',
};

const Map<String, String> erpConnectionTranslationsKo = {
  'erp_connection_title': '연결',
  'erp_connection_subtitle': '매장 서버와 체인의 PaynEat ERP',
  'erp_store_server_title': '매장 서버',
  'erp_store_server_demo': '데모 모드 — 데이터가 이 기기에 있습니다',
  'erp_section_title': 'PaynEat ERP',
  'erp_section_subtitle': 'PaynEat ERP로 재료와 지점을 관리하는 체인용 — 단독 매장은 설정하지 않아도 됩니다',
  'erp_mode_standalone': '단독 사용',
  'erp_mode_connected': '연결됨 · @instance',
  'erp_demo_note': '데모 모드는 항상 단독 사용입니다 — 실제 매장 서버에서 ERP에 연결할 수 있습니다',
  'erp_url_label': 'PaynEat ERP 주소',
  'erp_credential_label': '이 POS의 자격 증명',
  'erp_credential_hint': 'pnepos_… (POS 등록 시 ERP가 한 번만 보여 줍니다)',
  'erp_credential_saved': '저장됨 (다시 표시되지 않음)',
  'erp_connect_button': '연결',
  'erp_save_credential_button': '새 자격 증명 저장',
  'erp_change_credential_button': '자격 증명 변경',
  'erp_pull_button': '지금 가져오기',
  'erp_disconnect_button': '연결 모드 해제',
  'erp_disconnect_title': '연결 모드를 해제할까요?',
  'erp_disconnect_confirm':
      '자격 증명이 삭제됩니다. ERP에서 가져온 재료와 지점은 남아 있고 이 기기에서 다시 수정할 수 있습니다. '
      '메뉴가 다시 이 기기의 재고로 자동 판매 중지되므로 먼저 재고를 세어 주세요.',
  'erp_info_instance': 'ERP의 POS',
  'erp_info_contract': '연동 규약',
  'erp_info_version': '마스터 데이터',
  'erp_info_version_value': '@latest 중 버전 @applied',
  'erp_info_last_pull': '마지막으로 가져온 시각',
  'erp_info_never': '없음',
  'erp_branches_to_fix_title': '연결 전에 지점 코드를 고쳐 주세요',
  'erp_branch_problem_missing': '코드 없음',
  'erp_branch_problem_invalid': '코드 "@code" 형식이 맞지 않음',
  'erp_branch_code_rule': '코드는 ERP의 지점 코드와 같아야 합니다: 대문자 A–Z, 숫자, - 로 2–32자',
  'erp_branch_edit_code': '코드 수정',
  'erp_branch_code_dialog_title': '"@name" 지점 코드',
  'erp_branch_code_label': '지점 코드',
  'erp_branches_not_served_title': 'ERP가 이 POS에 맡기지 않은 이 기기의 지점',
  'erp_branches_not_served_note': 'ERP 관리자에게 이 POS의 지점이 모두 등록되었는지 확인하세요',
  'erp_served_missing_title': 'ERP가 맡겼지만 이 기기에 없는 지점',
  'erp_served_missing_note':
      '"이 기기에 만들기"를 눌러 ERP의 코드와 이름으로 지점을 추가한 뒤 직원 화면에서 직원을 배정하세요',
  'erp_branch_create_button': '이 기기에 만들기',
  'erp_branch_create_title': '이 지점을 이 기기에 만들까요?',
  'erp_branch_create_confirm':
      'PaynEat ERP의 코드와 이름으로 "@name"(@code) 지점을 만듭니다 — 먼저 최신 데이터를 가져오며, ERP가 기존 지점을 방금 이 코드로 옮겼다면 중복 지점을 만들지 않고 기존 지점이 이 코드를 씁니다',
  'erp_branch_created_notice': '@name(@code) 지점을 만들었습니다 — 직원 화면에서 직원을 배정하세요',
  'erp_branch_superseded': 'ERP가 코드를 @code(으)로 바꿨지만 이 기기에 그 코드의 지점이 이미 있습니다',
  'erp_stock_note':
      '재고는 ERP가 관리합니다 — 이 기기의 재고로 메뉴가 자동 판매 중지되지 않으니 메뉴 화면에서 직접 중지하세요',
  'erp_connected_notice': '@instance(으)로 연결했습니다',
  'erp_disconnected_notice': '연결 모드를 해제했습니다 — 단독 사용으로 돌아갑니다',
  'erp_pulled_notice': '@count건을 가져왔습니다. 현재 버전 @version',
  'erp_error_url_required': 'PaynEat ERP 주소를 입력하세요',
  'erp_error_credential_format': '자격 증명은 pnepos_로 시작합니다',
  'erp_error_fix_branch_codes': '연결하기 전에 위의 지점 코드를 고쳐 주세요',
  'erp_error_branch_code_format': '지점 코드는 대문자 A–Z, 숫자, - 로 2–32자입니다',
  'erp_error_demo_mode': '데모 모드에서는 PaynEat ERP에 연결할 수 없습니다',
  'erp_last_error_credential':
      'ERP가 더 이상 이 자격 증명을 받지 않습니다 — 새 자격 증명을 저장할 때까지 가져오기를 멈춥니다',
  'erp_last_error_network': '마지막 가져오기에서 ERP에 연결하지 못했습니다. 주기에 맞춰 다시 시도합니다',
  'erp_last_error_unavailable':
      '마지막 가져오기 때 ERP를 잠시 사용할 수 없었습니다. 주기에 맞춰 다시 시도합니다',
  'erp_last_error_rate_limited': 'ERP가 다음 가져오기 전에 기다려 달라고 했습니다',
  'erp_last_error_invalid_response':
      'ERP의 응답이 연동 규약과 맞지 않습니다 — ERP 관리자에게 알려 주세요',
  'erp_last_error_unsupported_contract':
      'ERP가 이 POS 버전이 지원하지 않는 규약을 사용합니다 — POS를 업데이트하세요',
  'erp_last_error_refused': 'ERP가 요청을 거부했습니다 — 주소와 프록시를 확인하세요',
  'erp_last_error_other': '마지막 가져오기에 실패했습니다',
  'erp_pull_stopped_note':
      '원인을 고칠 때까지 주기적 가져오기를 멈췄습니다 — 고친 뒤 "지금 가져오기"를 누르면 주기적 가져오기가 다시 시작됩니다',
  'erp_managed_badge': 'PaynEat ERP에서 관리',
  'erp_managed_banner':
      '재료는 PaynEat ERP에서 관리합니다 — ERP에서 수정한 뒤 다시 가져오세요. 재고는 ERP에서 확인하세요',
  'erp_item_inactive': 'ERP에서 사용 중지',
  'erp_item_code_summary': '코드 @code · 단위 @unit',
  'erp_unit_kg': '킬로그램',
  'erp_unit_g': '그램',
  'erp_unit_l': '리터',
  'erp_unit_ml': '밀리리터',
  'erp_unit_piece': '개',
  'erp_unit_pack': '팩',
  'erp_unit_case': '케이스',
  'erp_unit_bag': '봉지',
  'erp_unit_sack': '자루',
  'erp_unit_bottle': '병',
  'erp_unit_tin': '통',
  'erp_unit_box': '박스',
  'erp_unit_tray': '트레이',
};
