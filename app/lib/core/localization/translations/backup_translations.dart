// Copyright 2026 Suruch Chakrapeesirisuk
// SPDX-License-Identifier: Apache-2.0

/// คำแปลของส่วน "สำรองข้อมูล" ในหน้าตั้งค่าและแถบเตือนบนหน้าหลัก (ดู docs/tickets/33-automatic-backup.md)
const Map<String, String> backupTranslationsTh = {
  'backup_title': 'สำรองข้อมูล',
  'backup_subtitle':
      'เซิร์ฟเวอร์ร้านสำรองเองหลังปิดกะ ทุก 6 ชั่วโมงที่มีข้อมูลเปลี่ยน และก่อนอัปเดต',
  'backup_state_ok': 'ปกติ',
  'backup_state_attention': 'ต้องตรวจ',
  'backup_disabled':
      'เซิร์ฟเวอร์นี้ไม่ได้เก็บข้อมูลลงไฟล์ จึงไม่มีอะไรให้สำรอง',
  'backup_demo_note':
      'โหมดสาธิตแสดงสถานะตัวอย่าง ข้อมูลสาธิตอยู่ในเบราว์เซอร์นี้ ไม่มีไฟล์สำรองถูกสร้างจริง',
  'backup_low_disk':
      'พื้นที่ดิสก์ที่เก็บไฟล์สำรองเหลือน้อยกว่า 2 เท่าของขนาดฐานข้อมูล ลบไฟล์ที่ไม่ใช้หรือย้ายไปดิสก์ที่ใหญ่กว่า',
  'backup_last_success': 'สำรองสำเร็จล่าสุด',
  'backup_last_size': 'ขนาดไฟล์',
  'backup_never': 'ยังไม่เคย',
  'backup_primary_title': 'ที่เก็บหลัก (BACKUP_DIR)',
  'backup_copy_title': 'ที่เก็บชุดที่สอง (BACKUP_COPY_DIR)',
  'backup_copy_not_configured':
      'ยังไม่ได้ตั้ง ไฟล์สำรองอยู่บนดิสก์เดียวกับฐานข้อมูล ถ้าดิสก์เสียจะเสียทั้งคู่ '
      'ตั้ง BACKUP_COPY_DIR ไปที่ USB drive หรือ NAS ในร้านตามคู่มือติดตั้ง',
  'backup_folder': 'โฟลเดอร์',
  'backup_file_count': 'ไฟล์ที่เก็บอยู่',
  'backup_file_count_value': '@count ไฟล์',
  'backup_destination_last_success': 'สำเร็จล่าสุด',
  'backup_destination_failed': 'ล้มเหลวเมื่อ @time: @reason',
  'backup_now_button': 'สำรองข้อมูลตอนนี้',
  'backup_now_running': 'กำลังสำรอง…',
  'backup_now_done': 'สำรองแล้ว: @file',
  'backup_now_done_copy_failed':
      'สำรองในที่เก็บหลักแล้ว (@file) แต่คัดลอกไปที่เก็บชุดที่สองไม่สำเร็จ',
  'backup_now_failed': 'สำรองไม่สำเร็จ: @reason',
  'backup_restore_note':
      'กู้คืนทำบนเครื่องเซิร์ฟเวอร์ร้านเท่านั้น ด้วยคำสั่ง npm run db:restore ดูขั้นตอนในคู่มือติดตั้ง '
      'หัวข้อ "สำรองและกู้คืนข้อมูล" ไฟล์สำรองมีเบอร์โทรลูกค้าและรหัสผ่านที่เข้ารหัสแล้ว จึงดาวน์โหลดจากแอปไม่ได้',
  'backup_warning_failed':
      'สำรองข้อมูลครั้งล่าสุดไม่สำเร็จ (@time) ข้อมูลหลังสำรองสำเร็จครั้งก่อนยังไม่มีสำรอง',
  'backup_warning_never': 'ยังไม่เคยสำรองข้อมูลสำเร็จ',
  'backup_warning_stale':
      'ไม่ได้สำรองข้อมูลสำเร็จมาเกิน @hours ชั่วโมงแล้ว (ล่าสุด @time)',
  'backup_banner_tell_owner': 'แจ้งเจ้าของร้าน',
  'backup_banner_open_settings': 'ดูการสำรองข้อมูล',
  'backup_reason_shift_close': 'หลังปิดกะ',
  'backup_reason_scheduled': 'ตามรอบเวลา',
  'backup_reason_pre_migration': 'ก่อนอัปเดตฐานข้อมูล',
  'backup_reason_manual': 'กดสำรองเอง',
  'backup_reason_pre_restore': 'ก่อนกู้คืน',
};

const Map<String, String> backupTranslationsEn = {
  'backup_title': 'Backups',
  'backup_subtitle':
      'The shop server backs up by itself after each shift close, every 6 hours when data changed, and before an update',
  'backup_state_ok': 'OK',
  'backup_state_attention': 'Needs attention',
  'backup_disabled':
      'This server does not keep its data in a file, so there is nothing to back up',
  'backup_demo_note':
      'The demo shows an example status. Demo data lives in this browser; no backup file is really written',
  'backup_low_disk':
      'Free disk space for backups is less than twice the database size. Remove unused files or move backups to a larger disk',
  'backup_last_success': 'Last successful backup',
  'backup_last_size': 'File size',
  'backup_never': 'Never',
  'backup_primary_title': 'Main location (BACKUP_DIR)',
  'backup_copy_title': 'Second location (BACKUP_COPY_DIR)',
  'backup_copy_not_configured':
      'Not set. Backups are on the same disk as the database, so a failed disk loses both. '
      'Point BACKUP_COPY_DIR at a USB drive or a NAS in the shop, as the install guide shows',
  'backup_folder': 'Folder',
  'backup_file_count': 'Files kept',
  'backup_file_count_value': '@count files',
  'backup_destination_last_success': 'Last success',
  'backup_destination_failed': 'Failed at @time: @reason',
  'backup_now_button': 'Back up now',
  'backup_now_running': 'Backing up…',
  'backup_now_done': 'Backed up: @file',
  'backup_now_done_copy_failed':
      'Backed up to the main location (@file), but copying it to the second location failed',
  'backup_now_failed': 'Backup failed: @reason',
  'backup_restore_note':
      'Restoring is done only on the shop server, with npm run db:restore. See "Back up and restore" in the install guide. '
      'A backup holds customer phone numbers and password hashes, so the app cannot download it',
  'backup_warning_failed':
      'The last backup failed (@time). Data since the previous successful backup has no backup yet',
  'backup_warning_never': 'No backup has succeeded yet',
  'backup_warning_stale':
      'No successful backup for more than @hours hours (last one @time)',
  'backup_banner_tell_owner': 'Tell the shop owner.',
  'backup_banner_open_settings': 'View backups',
  'backup_reason_shift_close': 'after shift close',
  'backup_reason_scheduled': 'scheduled',
  'backup_reason_pre_migration': 'before a database update',
  'backup_reason_manual': 'manual',
  'backup_reason_pre_restore': 'before a restore',
};

const Map<String, String> backupTranslationsKo = {
  'backup_title': '백업',
  'backup_subtitle': '매장 서버가 교대 마감 후, 데이터가 바뀐 경우 6시간마다, 그리고 업데이트 전에 자동으로 백업합니다',
  'backup_state_ok': '정상',
  'backup_state_attention': '확인 필요',
  'backup_disabled': '이 서버는 데이터를 파일에 저장하지 않으므로 백업할 것이 없습니다',
  'backup_demo_note':
      '데모는 예시 상태를 보여 줍니다. 데모 데이터는 이 브라우저에 있으며 실제 백업 파일은 만들어지지 않습니다',
  'backup_low_disk':
      '백업용 디스크의 남은 공간이 데이터베이스 크기의 2배보다 적습니다. 쓰지 않는 파일을 지우거나 더 큰 디스크로 옮기세요',
  'backup_last_success': '마지막 백업 성공',
  'backup_last_size': '파일 크기',
  'backup_never': '없음',
  'backup_primary_title': '기본 위치 (BACKUP_DIR)',
  'backup_copy_title': '두 번째 위치 (BACKUP_COPY_DIR)',
  'backup_copy_not_configured':
      '설정되지 않았습니다. 백업이 데이터베이스와 같은 디스크에 있어 디스크가 고장 나면 둘 다 잃습니다. '
      '설치 안내서대로 BACKUP_COPY_DIR을 매장의 USB 드라이브나 NAS로 지정하세요',
  'backup_folder': '폴더',
  'backup_file_count': '보관 중인 파일',
  'backup_file_count_value': '@count개',
  'backup_destination_last_success': '마지막 성공',
  'backup_destination_failed': '@time에 실패: @reason',
  'backup_now_button': '지금 백업',
  'backup_now_running': '백업 중…',
  'backup_now_done': '백업 완료: @file',
  'backup_now_done_copy_failed': '기본 위치에 백업했지만(@file) 두 번째 위치로 복사하지 못했습니다',
  'backup_now_failed': '백업 실패: @reason',
  'backup_restore_note':
      '복원은 매장 서버에서 npm run db:restore 명령으로만 합니다. 설치 안내서의 "백업과 복원"을 보세요. '
      '백업 파일에는 고객 전화번호와 비밀번호 해시가 있어 앱에서 내려받을 수 없습니다',
  'backup_warning_failed':
      '마지막 백업이 실패했습니다 (@time). 이전 백업 성공 이후의 데이터는 아직 백업되지 않았습니다',
  'backup_warning_never': '아직 성공한 백업이 없습니다',
  'backup_warning_stale': '@hours시간 넘게 백업에 성공하지 못했습니다 (마지막 @time)',
  'backup_banner_tell_owner': '매장 주인에게 알리세요.',
  'backup_banner_open_settings': '백업 보기',
  'backup_reason_shift_close': '교대 마감 후',
  'backup_reason_scheduled': '정기',
  'backup_reason_pre_migration': '데이터베이스 업데이트 전',
  'backup_reason_manual': '수동',
  'backup_reason_pre_restore': '복원 전',
};
