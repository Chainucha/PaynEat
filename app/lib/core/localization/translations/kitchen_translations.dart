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
  'kitchen_loading_queue': '주방 대기열을 불러오는 중...',
  'kitchen_offline_banner':
      '연결이 끊겼습니다 — 새 주문이 표시되지 않을 수 있습니다. 30초마다 자동으로 다시 시도합니다.',
  'kitchen_empty_queue_message': '아직 주방에 들어온 주문이 없습니다\n새 주문은 자동으로 표시됩니다',
  'kitchen_column_count_label': '@title (@count)',
  'kitchen_column_empty': '@title 항목이 없습니다',
  'kitchen_table_label': '테이블 @table',
  'kitchen_undo_message': '@item → @status',
  'kitchen_undo_button': '되돌리기',
};
