// Copyright 2026 Suruch Chakrapeesirisuk
// SPDX-License-Identifier: Apache-2.0

/// คำแปลของฟีเจอร์ kitchen
const Map<String, String> kitchenTranslationsTh = {
  'kitchen_station_filter_all': 'ทุกสถานี',
  'kitchen_station_filter_label': 'กรองตามสถานีครัว',
  'kitchen_station_empty_queue_message':
      'ไม่มีรายการของสถานีนี้\nแตะ "ทุกสถานี" เพื่อดูทั้งครัว',
  'kitchen_header_title': 'คิวครัว',
  'kitchen_queue_count': '@count รายการ',
  'kitchen_late_count': 'ช้า @count',
  'kitchen_refresh_tooltip': 'รีเฟรช',
  'kitchen_new_badge': 'ใหม่',
  'kitchen_sound_unlock': 'แตะเพื่อเปิดเสียงแจ้งเตือนตั๋วใหม่',
  'kitchen_mute_tooltip': 'ปิดเสียงแจ้งเตือน',
  'kitchen_unmute_tooltip': 'เปิดเสียงแจ้งเตือน',
  'kitchen_loading_queue': 'กำลังโหลดคิวครัว...',
  'kitchen_offline_banner':
      'ขาดการเชื่อมต่อ — ตั๋วใหม่อาจยังไม่ขึ้น ระบบกำลังลองดึงข้อมูลเองทุก 30 วินาที',
  'kitchen_empty_queue_message':
      'ยังไม่มีออเดอร์เข้าครัว\nรายการใหม่จะเด้งขึ้นมาเองทันที',
  'kitchen_column_count_label': '@title (@count)',
  'kitchen_column_empty': 'ไม่มีรายการ@title',
  'kitchen_table_label': 'โต๊ะ @table',
  'kitchen_undo_message': '@item → @status',
  'kitchen_undo_button': 'เลิกทำ',
  'station_status_button': 'สถานะสถานี',
  'station_status_title': 'เปิด/ปิดสถานีครัว',
  'station_status_subtitle':
      'สถานีที่ปิด จานของสถานีนั้นสั่งไม่ได้จนกว่าจะเปิดคืน (เฉพาะสาขานี้)',
  'station_status_open': 'เปิดอยู่',
  'station_status_closed_by': 'ปิดตั้งแต่ @time โดย @name',
  'station_status_confirm_title': 'ปิด@station?',
  'station_status_confirm_pending':
      'ยังมี @count รายการค้าง — ครัวทำต่อจนเสร็จ แต่จะสั่งเพิ่มไม่ได้',
  'station_status_confirm_button': 'ปิดสถานี',
  'station_closed_banner': '@station ปิดตั้งแต่ @time โดย @name',
};

const Map<String, String> kitchenTranslationsEn = {
  'kitchen_station_filter_all': 'All stations',
  'kitchen_station_filter_label': 'Filter by kitchen station',
  'kitchen_station_empty_queue_message':
      'No tickets for this station\nTap "All stations" to see the whole kitchen',
  'kitchen_header_title': 'Kitchen Queue',
  'kitchen_queue_count': '@count items',
  'kitchen_late_count': 'Late @count',
  'kitchen_refresh_tooltip': 'Refresh',
  'kitchen_new_badge': 'NEW',
  'kitchen_sound_unlock': 'Tap to turn on the new-ticket sound',
  'kitchen_mute_tooltip': 'Mute alerts',
  'kitchen_unmute_tooltip': 'Unmute alerts',
  'kitchen_loading_queue': 'Loading kitchen queue...',
  'kitchen_offline_banner':
      'Disconnected — new tickets may not appear. Retrying every 30 seconds.',
  'kitchen_empty_queue_message':
      'No orders in the kitchen yet\nNew tickets will pop up automatically',
  'kitchen_column_count_label': '@title (@count)',
  'kitchen_column_empty': 'No @title items',
  'kitchen_table_label': 'Table @table',
  'kitchen_undo_message': '@item → @status',
  'kitchen_undo_button': 'Undo',
  'station_status_button': 'Station status',
  'station_status_title': 'Open/close kitchen stations',
  'station_status_subtitle':
      "A closed station's dishes can't be ordered until it reopens (this branch only)",
  'station_status_open': 'Open',
  'station_status_closed_by': 'Closed since @time by @name',
  'station_status_confirm_title': 'Close @station?',
  'station_status_confirm_pending':
      '@count tickets are still in the queue — the kitchen finishes them, but nothing new can be ordered',
  'station_status_confirm_button': 'Close station',
  'station_closed_banner': '@station closed since @time by @name',
};

const Map<String, String> kitchenTranslationsKo = {
  'kitchen_station_filter_all': '전체 스테이션',
  'kitchen_station_filter_label': '주방 스테이션으로 필터',
  'kitchen_station_empty_queue_message':
      '이 스테이션에는 항목이 없습니다\n전체 스테이션을 탭하면 주방 전체가 보입니다',
  'kitchen_header_title': '주방 대기열',
  'kitchen_queue_count': '@count개',
  'kitchen_late_count': '지연 @count',
  'kitchen_refresh_tooltip': '새로고침',
  'kitchen_new_badge': '신규',
  'kitchen_sound_unlock': '새 주문 알림음을 켜려면 탭하세요',
  'kitchen_mute_tooltip': '알림음 끄기',
  'kitchen_unmute_tooltip': '알림음 켜기',
  'kitchen_loading_queue': '주방 대기열을 불러오는 중...',
  'kitchen_offline_banner':
      '연결이 끊겼습니다 — 새 주문이 표시되지 않을 수 있습니다. 30초마다 자동으로 다시 시도합니다.',
  'kitchen_empty_queue_message': '아직 주방에 들어온 주문이 없습니다\n새 주문은 자동으로 표시됩니다',
  'kitchen_column_count_label': '@title (@count)',
  'kitchen_column_empty': '@title 항목이 없습니다',
  'kitchen_table_label': '테이블 @table',
  'kitchen_undo_message': '@item → @status',
  'kitchen_undo_button': '되돌리기',
  'station_status_button': '스테이션 상태',
  'station_status_title': '주방 스테이션 열기/닫기',
  'station_status_subtitle': '닫힌 스테이션의 메뉴는 다시 열 때까지 주문할 수 없습니다 (이 지점만)',
  'station_status_open': '열림',
  'station_status_closed_by': '@time부터 닫힘 · @name',
  'station_status_confirm_title': '@station을(를) 닫을까요?',
  'station_status_confirm_pending':
      '대기 중인 항목이 @count개 있습니다 — 주방은 마저 만들지만 새로 주문할 수 없습니다',
  'station_status_confirm_button': '스테이션 닫기',
  'station_closed_banner': '@station 닫힘 · @time부터 · @name',
};
