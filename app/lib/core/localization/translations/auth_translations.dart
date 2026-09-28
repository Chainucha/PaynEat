// Copyright 2026 Suruch Chakrapeesirisuk
// SPDX-License-Identifier: Apache-2.0

/// คำแปลของฟีเจอร์ auth
const Map<String, String> authTranslationsTh = {
  'auth_login_brand_headline': 'ระบบขายหน้าร้าน\nสำหรับร้านอาหาร',
  'auth_login_brand_subheadline':
      'รับออเดอร์บนแท็บเล็ต ส่งเข้าครัวทันที ปิดบิลและดูยอดขายได้ในที่เดียว',
  'auth_login_feature_tables': 'ผังโต๊ะเห็นสถานะแบบเรียลไทม์',
  'auth_login_feature_kds': 'จอครัว (KDS) อัปเดตทันทีที่กดสั่ง',
  'auth_login_feature_billing': 'ปิดบิล แยกจ่าย และออกใบเสร็จ',
  'auth_login_feature_reports': 'รายงานยอดขายและเมนูขายดี',
  'auth_login_title': 'เข้าสู่ระบบ',
  'auth_login_subtitle': 'ใช้บัญชีพนักงานที่ผู้จัดการออกให้',
  'auth_username_label': 'ชื่อผู้ใช้',
  'auth_username_hint': 'เช่น waiter1',
  'auth_password_label': 'รหัสผ่าน',
  'auth_demo_mode_banner':
      'โหมดสาธิต — ข้อมูลทั้งหมดอยู่ในเครื่องคุณ กดใช้งานได้ทุกฟีเจอร์ '
      'รีเฟรชหน้าเว็บเพื่อเริ่มใหม่',
  'auth_login_footer_demo': 'PaynEat POS · โหมดสาธิต',
  'auth_login_footer_connected': 'เชื่อมต่อ @url',
  'auth_demo_accounts_label': 'บัญชีทดลองใช้ — แตะเพื่อเข้าสู่ระบบ',
  'auth_profile_connection_title': 'การเชื่อมต่อ',
  'auth_profile_realtime_connected': 'เชื่อมต่อเรียลไทม์อยู่',
  'auth_profile_realtime_disconnected': 'ไม่ได้เชื่อมต่อเรียลไทม์',
  'auth_logout': 'ออกจากระบบ',
  'auth_logout_confirm_message': 'ต้องการออกจากระบบใช่หรือไม่?',
  'auth_session_expired_message': 'เซสชันหมดอายุ กรุณาเข้าสู่ระบบใหม่',
  'auth_username_required': 'กรุณากรอกชื่อผู้ใช้',
  'auth_password_required': 'กรุณากรอกรหัสผ่าน',
  'auth_invalid_credentials': 'username หรือรหัสผ่านไม่ถูกต้อง',
  'auth_demo_session_expired': 'เซสชันหมดอายุ',
  'auth_username_taken': 'username นี้ถูกใช้งานแล้ว',
  'auth_user_not_found': 'ไม่พบผู้ใช้งาน',
  'auth_user_has_history':
      'บัญชีนี้มีประวัติการทำรายการแล้วจึงลบไม่ได้ ให้ปิดการใช้งานบัญชีแทน',

  // เลือก/สลับสาขา (ดู docs/tickets/11-multi-branch.md)
  'branch_selection_title': 'เลือกสาขา',
  'branch_selection_subtitle':
      'บัญชีนี้มีสิทธิ์เข้าใช้งานได้มากกว่า 1 สาขา เลือกสาขาที่จะเข้าทำงานตอนนี้',
  'branch_switch_success': 'สลับไปยังสาขา @branch แล้ว',
  'branch_all_branches': 'ทุกสาขา',
  'branch_current_label': 'สาขาปัจจุบัน',
  'branch_switch_action': 'สลับสาขา',
  'auth_demo_account_tooltip': 'เข้าสู่ระบบเป็น @username',
};

const Map<String, String> authTranslationsEn = {
  'auth_login_brand_headline': 'Point of sale\nfor restaurants',
  'auth_login_brand_subheadline':
      'Take orders on a tablet, send them straight to the kitchen, '
      'close bills and check sales — all in one place.',
  'auth_login_feature_tables': 'Real-time table status at a glance',
  'auth_login_feature_kds':
      'Kitchen display (KDS) updates the instant an order is placed',
  'auth_login_feature_billing':
      'Close bills, split payments, and print receipts',
  'auth_login_feature_reports': 'Sales reports and best-selling menu items',
  'auth_login_title': 'Log in',
  'auth_login_subtitle': 'Sign in with the staff account your manager gave you',
  'auth_username_label': 'Username',
  'auth_username_hint': 'e.g. waiter1',
  'auth_password_label': 'Password',
  'auth_demo_mode_banner':
      'Demo mode — all data stays on your device. Every feature is usable; '
      'refresh the page to start over.',
  'auth_login_footer_demo': 'PaynEat POS · Demo mode',
  'auth_login_footer_connected': 'Connected to @url',
  'auth_demo_accounts_label': 'Demo accounts — tap to sign in',
  'auth_profile_connection_title': 'Connection',
  'auth_profile_realtime_connected': 'Real-time connection active',
  'auth_profile_realtime_disconnected': 'Not connected to real-time updates',
  'auth_logout': 'Log out',
  'auth_logout_confirm_message': 'Are you sure you want to log out?',
  'auth_session_expired_message':
      'Your session has expired. Please log in again.',
  'auth_username_required': 'Please enter your username',
  'auth_password_required': 'Please enter your password',
  'auth_invalid_credentials': 'Incorrect username or password',
  'auth_demo_session_expired': 'Session expired',
  'auth_username_taken': 'This username is already taken',
  'auth_user_not_found': 'User not found',
  'auth_user_has_history':
      'This account has transaction history and cannot be deleted — deactivate it instead',

  // Branch selection / switching (ticket 11)
  'branch_selection_title': 'Select branch',
  'branch_selection_subtitle':
      'This account has access to more than one branch. Choose which branch '
      'to work in now.',
  'branch_switch_success': 'Switched to @branch',
  'branch_all_branches': 'All branches',
  'branch_current_label': 'Current branch',
  'branch_switch_action': 'Switch branch',
  'auth_demo_account_tooltip': 'Sign in as @username',
};

const Map<String, String> authTranslationsKo = {
  'auth_login_brand_headline': '음식점을 위한\n포스 시스템',
  'auth_login_brand_subheadline':
      '태블릿으로 주문을 받아 주방으로 바로 전달하고, 결제와 매출 확인까지 한곳에서 처리합니다.',
  'auth_login_feature_tables': '테이블 상태를 실시간으로 한눈에',
  'auth_login_feature_kds': '주문을 넣는 즉시 주방 모니터(KDS)에 표시',
  'auth_login_feature_billing': '결제 마감, 분할 결제, 영수증 출력',
  'auth_login_feature_reports': '매출 리포트와 인기 메뉴 분석',
  'auth_login_title': '로그인',
  'auth_login_subtitle': '매니저에게 받은 직원 계정으로 로그인하세요',
  'auth_username_label': '아이디',
  'auth_username_hint': '예: waiter1',
  'auth_password_label': '비밀번호',
  'auth_demo_mode_banner':
      '데모 모드 — 모든 데이터는 기기에만 저장됩니다. 모든 기능을 사용할 수 있으며, 새로고침하면 처음 상태로 돌아갑니다.',
  'auth_login_footer_demo': 'PaynEat POS · 데모 모드',
  'auth_login_footer_connected': '@url 에 연결됨',
  'auth_demo_accounts_label': '데모 계정 — 누르면 바로 로그인',
  'auth_profile_connection_title': '연결 상태',
  'auth_profile_realtime_connected': '실시간 연결 사용 중',
  'auth_profile_realtime_disconnected': '실시간 연결이 끊겼습니다',
  'auth_logout': '로그아웃',
  'auth_logout_confirm_message': '로그아웃하시겠습니까?',
  'auth_session_expired_message': '로그인이 만료되었습니다. 다시 로그인해 주세요.',
  'auth_username_required': '아이디를 입력해 주세요',
  'auth_password_required': '비밀번호를 입력해 주세요',
  'auth_invalid_credentials': '아이디 또는 비밀번호가 올바르지 않습니다',
  'auth_demo_session_expired': '세션이 만료되었습니다',
  'auth_username_taken': '이미 사용 중인 아이디입니다',
  'auth_user_not_found': '사용자를 찾을 수 없습니다',
  'auth_user_has_history': '이 계정은 거래 이력이 있어 삭제할 수 없습니다 — 대신 계정을 비활성화하십시오',
  'branch_selection_title': '지점 선택',
  'branch_selection_subtitle':
      '이 계정은 두 곳 이상의 지점에 접근할 수 있습니다. 지금 근무할 지점을 선택하세요.',
  'branch_switch_success': '@branch(으)로 전환했습니다',
  'branch_all_branches': '전체 지점',
  'branch_current_label': '현재 지점',
  'branch_switch_action': '지점 전환',
  'auth_demo_account_tooltip': '@username(으)로 로그인',
};
