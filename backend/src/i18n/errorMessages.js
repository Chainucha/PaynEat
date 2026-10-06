// Copyright 2026 Suruch Chakrapeesirisuk
// SPDX-License-Identifier: Apache-2.0

/**
 * แปลข้อความ error ที่ส่งกลับไปให้แอปตามภาษาที่แอปขอ (header `Accept-Language`) — DECISIONS #64
 *
 * ใช้แบบ gettext: ข้อความภาษาไทยในโค้ดเป็น "ต้นฉบับ" และเป็นกุญแจของแคตตาล็อกนี้เอง ที่เรียก
 * `ApiError.badRequest('...')` ทั้ง ~150 จุดจึงไม่ต้องแก้ ค่าที่แทรกในข้อความ (`${name}`) เขียนเป็น
 * `{ชื่อ}` แล้วถูกดึงกลับออกมาจากข้อความไทยตอนแปล ค่าที่เป็นศัพท์ภาษาไทยเอง (ชื่อเอกสาร) แปลต่อด้วย
 * `TERMS` — ชื่อเมนู/ลูกค้าที่ร้านพิมพ์เองคงไว้ตามที่พิมพ์
 *
 * เพิ่มข้อความ error ใหม่เมื่อไหร่ต้องเพิ่มที่นี่ด้วย `tests/error-i18n.test.js` สแกนซอร์สทุกไฟล์
 * แล้วล้มถ้ามีข้อความที่ไม่อยู่ในแคตตาล็อก
 */

export const SUPPORTED_LANGUAGES = ['th', 'en', 'ko'];

/** ศัพท์ที่ถูกแทรกเข้าไปในข้อความ (ไม่ใช่ข้อมูลที่ร้านพิมพ์เอง) */
export const TERMS = {
  ใบวางบิล: { en: 'billing note', ko: '청구서' },
  ใบเสร็จรับเงิน: { en: 'receipt', ko: '영수증' },
  ใบลดหนี้: { en: 'credit note', ko: '감액 전표' },
  ใบแจ้งดอกเบี้ยผิดนัด: { en: 'late-fee invoice', ko: '연체 이자 청구서' },
  บาร์โค้ด: { en: 'Barcode', ko: '바코드' },
  'รหัสบนตาชั่ง (PLU)': { en: 'Scale code (PLU)', ko: '저울 코드(PLU)' },
};

export const ERROR_MESSAGES = [
  // ---------------------------------------------------------------- ทั่วไป / auth
  {
    th: 'ต้องเข้าสู่ระบบก่อนใช้งาน',
    en: 'Please sign in first',
    ko: '먼저 로그인해 주세요',
  },
  {
    th: 'สิทธิ์ไม่เพียงพอสำหรับการทำรายการนี้',
    en: "You don't have permission to do this",
    ko: '이 작업을 할 권한이 없습니다',
  },
  { th: 'ไม่พบข้อมูลที่ต้องการ', en: 'Not found', ko: '찾을 수 없습니다' },
  {
    th: 'ทำรายการถี่เกินไป กรุณาลองใหม่อีกครั้งในอีกสักครู่',
    en: 'Too many requests — please try again in a moment',
    ko: '요청이 너무 많습니다 — 잠시 후 다시 시도해 주세요',
  },
  {
    th: 'เกิดข้อผิดพลาดภายในระบบ',
    en: 'Something went wrong on the server',
    ko: '서버에서 오류가 발생했습니다',
  },
  {
    th: 'ข้อมูลที่ส่งมาไม่ถูกต้อง',
    en: 'Some of the information entered is invalid',
    ko: '입력한 정보가 올바르지 않습니다',
  },
  {
    th: 'ข้อมูลที่ส่งมาใหญ่เกินไป',
    en: 'The information sent is too large',
    ko: '전송한 정보가 너무 큽니다',
  },
  {
    th: 'ไม่พบเส้นทาง {method} {path}',
    en: 'Route not found: {method} {path}',
    ko: '경로를 찾을 수 없습니다: {method} {path}',
  },
  {
    th: 'ต้องระบุ branchId เพราะกำลังดูข้อมูลรวมทุกสาขาอยู่ (โหมดทุกสาขา)',
    en: 'Choose a branch — you are viewing all branches combined',
    ko: '지점을 선택해 주세요 — 지금은 전체 지점을 보고 있습니다',
  },
  {
    th: 'บัญชีนี้ถูกปิดการใช้งานหรือไม่มีอยู่แล้ว',
    en: 'This account has been deactivated or no longer exists',
    ko: '사용 중지되었거나 더 이상 없는 계정입니다',
  },
  { th: 'ไม่พบ access token', en: 'Missing access token', ko: '액세스 토큰이 없습니다' },
  {
    th: 'Token ไม่ถูกต้องหรือหมดอายุ',
    en: 'Your session is invalid or has expired — please sign in again',
    ko: '세션이 올바르지 않거나 만료되었습니다 — 다시 로그인해 주세요',
  },
  {
    th: 'ต้องเลือกสาขาก่อนใช้งาน (POST /auth/select-branch)',
    en: 'Please choose a branch first',
    ko: '먼저 지점을 선택해 주세요',
  },
  {
    th: 'ไม่มีสิทธิ์เข้าถึงสาขานี้แล้ว กรุณาเข้าสู่ระบบใหม่',
    en: 'You no longer have access to this branch — please sign in again',
    ko: '이 지점에 대한 권한이 없어졌습니다 — 다시 로그인해 주세요',
  },
  {
    th: 'ต้องมีสิทธิ์: {roles}',
    en: 'Requires role: {roles}',
    ko: '필요한 역할: {roles}',
  },
  {
    th: 'username หรือรหัสผ่านไม่ถูกต้อง',
    en: 'Incorrect username or password',
    ko: '아이디 또는 비밀번호가 올바르지 않습니다',
  },
  {
    th: 'บัญชีนี้ถูกปิดการใช้งาน กรุณาติดต่อผู้ดูแลระบบ',
    en: 'This account is deactivated — please contact your admin',
    ko: '사용 중지된 계정입니다 — 관리자에게 문의해 주세요',
  },
  {
    th: 'บัญชีนี้ยังไม่มีสิทธิ์เข้าสาขาใดเลย กรุณาติดต่อผู้ดูแลระบบให้เพิ่มสิทธิ์สาขาก่อน',
    en: "This account isn't assigned to any branch yet — ask your admin to add one",
    ko: '이 계정에 배정된 지점이 없습니다 — 관리자에게 지점 추가를 요청해 주세요',
  },
  {
    th: 'เฉพาะผู้ดูแลระบบเท่านั้นที่ดูได้ทุกสาขา',
    en: 'Only admins can view all branches',
    ko: '전체 지점은 관리자만 볼 수 있습니다',
  },
  {
    th: 'ไม่มีสิทธิ์เข้าถึงสาขานี้',
    en: "You don't have access to this branch",
    ko: '이 지점에 대한 권한이 없습니다',
  },
  { th: 'ไม่พบบัญชีผู้ใช้', en: 'Account not found', ko: '계정을 찾을 수 없습니다' },
  {
    th: 'รหัสผ่านปัจจุบันไม่ถูกต้อง',
    en: 'Your current password is incorrect',
    ko: '현재 비밀번호가 올바르지 않습니다',
  },
  {
    th: 'เปลี่ยนรหัสผ่านเรียบร้อยแล้ว',
    en: 'Password changed',
    ko: '비밀번호를 변경했습니다',
  },
  {
    th: 'เชื่อมต่อสำเร็จ ({name})',
    en: 'Connected ({name})',
    ko: '연결되었습니다 ({name})',
  },
  { th: 'ไม่พบสาขานี้', en: 'Branch not found', ko: '지점을 찾을 수 없습니다' },

  // ---------------------------------------------------------------- อีเมล / AI
  {
    th: 'ยังไม่ได้ตั้งค่าเซิร์ฟเวอร์อีเมล (SMTP_HOST) — ดาวน์โหลด PDF แล้วส่งให้ลูกค้าเองได้',
    en: "Email isn't set up on the server (SMTP_HOST) — download the PDF and send it yourself",
    ko: '서버에 이메일이 설정되지 않았습니다(SMTP_HOST) — PDF를 내려받아 직접 보내 주세요',
  },
  {
    th: 'ส่งอีเมลไม่สำเร็จ: {error}',
    en: "Couldn't send the email: {error}",
    ko: '이메일을 보내지 못했습니다: {error}',
  },
  {
    th: 'ผู้ช่วย AI ยังไม่ได้เปิดใช้งาน (ยังไม่ได้ตั้งค่า ANTHROPIC_API_KEY)',
    en: "The AI assistant isn't enabled (ANTHROPIC_API_KEY is not set)",
    ko: 'AI 어시스턴트가 켜져 있지 않습니다 (ANTHROPIC_API_KEY 미설정)',
  },
  {
    th: 'ถามผู้ช่วย AI ครบโควตาวันนี้แล้ว ({limit} คำถาม/วัน) กรุณาลองใหม่พรุ่งนี้',
    en: "You've used today's AI assistant quota ({limit} questions/day) — try again tomorrow",
    ko: '오늘 AI 어시스턴트 사용 한도를 모두 썼습니다 (하루 {limit}개) — 내일 다시 시도해 주세요',
  },
  {
    th: 'เรียกผู้ช่วย AI ไม่สำเร็จ กรุณาลองใหม่อีกครั้ง',
    en: "Couldn't reach the AI assistant — please try again",
    ko: 'AI 어시스턴트에 연결하지 못했습니다 — 다시 시도해 주세요',
  },

  // ---------------------------------------------------------------- สถานีครัว (ticket 34)
  {
    th: 'ไม่พบสถานีครัวนี้',
    en: 'Kitchen station not found',
    ko: '주방 스테이션을 찾을 수 없습니다',
  },
  {
    th: 'ไม่พบสถานีครัวรหัส "{code}"',
    en: 'No kitchen station with the code "{code}"',
    ko: '코드가 "{code}"인 주방 스테이션이 없습니다',
  },
  {
    th: 'ไม่พบสถานีครัวที่ระบุ',
    en: 'The selected kitchen station was not found',
    ko: '선택한 주방 스테이션을 찾을 수 없습니다',
  },
  {
    th: 'ยังไม่มีสถานีครัวในระบบ กรุณาเพิ่มสถานีครัวก่อน',
    en: 'There are no kitchen stations yet — please add one first',
    ko: '주방 스테이션이 아직 없습니다 — 먼저 추가해 주세요',
  },
  {
    th: 'รหัสสถานี "{code}" ถูกใช้แล้ว',
    en: 'The station code "{code}" is already taken',
    ko: '스테이션 코드 "{code}"은(는) 이미 사용 중입니다',
  },
  {
    th: 'รหัสสถานีใช้ a-z 0-9 - _ ยาว 2-20 ตัว',
    en: 'A station code uses a-z, 0-9, - and _, and is 2-20 characters long',
    ko: '스테이션 코드는 a-z, 0-9, -, _ 를 쓰고 2~20자여야 합니다',
  },
  {
    th: 'รหัสสถานีครัวไม่ถูกต้อง',
    en: 'Invalid kitchen station code',
    ko: '주방 스테이션 코드가 올바르지 않습니다',
  },
  {
    th: 'กรุณากรอกชื่อสถานีครัว',
    en: 'Please enter the kitchen station name',
    ko: '주방 스테이션 이름을 입력해 주세요',
  },
  {
    th: 'ตั้งสถานีอื่นเป็นค่าเริ่มต้นก่อน แล้วค่อยปลดสถานีนี้',
    en: 'Make another station the default first, then clear this one',
    ko: '먼저 다른 스테이션을 기본값으로 지정한 뒤 이 스테이션을 해제해 주세요',
  },
  {
    th: 'ปิดใช้งานสถานีค่าเริ่มต้นไม่ได้ กรุณาตั้งสถานีอื่นเป็นค่าเริ่มต้นก่อน',
    en: "The default station can't be deactivated — make another station the default first",
    ko: '기본 스테이션은 비활성화할 수 없습니다 — 먼저 다른 스테이션을 기본값으로 지정해 주세요',
  },
  {
    th: 'ลบสถานีค่าเริ่มต้นไม่ได้ กรุณาตั้งสถานีอื่นเป็นค่าเริ่มต้นก่อน',
    en: "The default station can't be deleted — make another station the default first",
    ko: '기본 스테이션은 삭제할 수 없습니다 — 먼저 다른 스테이션을 기본값으로 지정해 주세요',
  },
  {
    th: 'ลบไม่ได้ เพราะยังมีเมนูผูกกับสถานีนี้ กรุณาย้ายเมนูออกก่อน',
    en: "Can't delete — menu items are still assigned to this station. Move them out first",
    ko: '삭제할 수 없습니다 — 이 스테이션에 연결된 메뉴가 있습니다. 먼저 옮겨 주세요',
  },
  {
    th: 'ลบไม่ได้ เพราะยังมีหมวดหมู่ผูกกับสถานีนี้ กรุณาย้ายหมวดหมู่ออกก่อน',
    en: "Can't delete — categories are still assigned to this station. Move them out first",
    ko: '삭제할 수 없습니다 — 이 스테이션에 연결된 카테고리가 있습니다. 먼저 옮겨 주세요',
  },
  {
    th: 'สถานีนี้ถูกใช้ในบิลไปแล้ว ปิดใช้งานแทนการลบ',
    en: 'This station already appears on a bill — deactivate it instead of deleting',
    ko: '이 스테이션은 이미 청구서에 사용되었습니다 — 삭제하지 말고 비활성화해 주세요',
  },
  {
    th: 'กรุณาระบุสถานะอย่างน้อยหนึ่งสถานะ',
    en: 'Please give at least one status',
    ko: '상태를 최소 한 개 지정해 주세요',
  },
  {
    th: 'สถานะรายการอาหารต้องเป็นหนึ่งใน: {statuses}',
    en: 'An order item status must be one of: {statuses}',
    ko: '주문 항목 상태는 다음 중 하나여야 합니다: {statuses}',
  },

  // ---------------------------------------------------------------- เมนู / หมวด / วัตถุดิบ
  { th: 'ไม่พบหมวดหมู่นี้', en: 'Category not found', ko: '카테고리를 찾을 수 없습니다' },
  {
    th: 'ลบไม่ได้ เพราะยังมีเมนูอยู่ในหมวดหมู่นี้ กรุณาย้ายเมนูออกก่อน',
    en: "Can't delete — this category still has menu items. Move them out first",
    ko: '삭제할 수 없습니다 — 이 카테고리에 메뉴가 남아 있습니다. 먼저 옮겨 주세요',
  },
  { th: 'ไม่พบวัตถุดิบนี้', en: 'Ingredient not found', ko: '재료를 찾을 수 없습니다' },
  {
    th: 'ลบไม่ได้ เพราะวัตถุดิบนี้ถูกผูกกับเมนูอยู่',
    en: "Can't delete — this ingredient is used by a menu item",
    ko: '삭제할 수 없습니다 — 메뉴에 연결된 재료입니다',
  },
  {
    th: 'เลือกวัตถุดิบซ้ำกันในเมนูเดียวไม่ได้',
    en: "The same ingredient can't be added twice to one menu item",
    ko: '한 메뉴에 같은 재료를 두 번 넣을 수 없습니다',
  },
  {
    th: 'ไม่พบหมวดหมู่ที่ระบุ',
    en: 'The selected category was not found',
    ko: '선택한 카테고리를 찾을 수 없습니다',
  },
  {
    th: 'รหัสบนตาชั่ง (PLU) ใช้ได้เฉพาะเมนูที่ขายตามน้ำหนัก',
    en: 'A scale code (PLU) can only be set on items sold by weight',
    ko: '저울 코드(PLU)는 무게로 파는 메뉴에만 쓸 수 있습니다',
  },
  {
    th: '{field} {value} ถูกใช้กับเมนู "{menu}" แล้ว',
    en: '{field} {value} is already used by "{menu}"',
    ko: '{field} {value}은(는) 이미 "{menu}"에 쓰이고 있습니다',
  },
  {
    th: 'ไม่พบวัตถุดิบ id={id}',
    en: 'Ingredient id={id} not found',
    ko: '재료 id={id}을(를) 찾을 수 없습니다',
  },
  { th: 'ไม่พบเมนูนี้', en: 'Menu item not found', ko: '메뉴를 찾을 수 없습니다' },
  {
    th: 'ลบไม่ได้ เพราะเมนูนี้อยู่ในออเดอร์ที่ยังไม่ปิด',
    en: "Can't delete — this item is on an open order",
    ko: '삭제할 수 없습니다 — 아직 닫히지 않은 주문에 있는 메뉴입니다',
  },

  // ---------------------------------------------------------------- ออเดอร์
  {
    th: 'ออเดอร์แบบทานที่ร้านต้องระบุโต๊ะ',
    en: 'Dine-in orders need a table',
    ko: '매장 식사 주문은 테이블을 지정해야 합니다',
  },
  {
    th: 'ออเดอร์นี้ปิดแล้ว ไม่สามารถแก้ไขได้',
    en: "This order is closed and can't be changed",
    ko: '닫힌 주문이라 수정할 수 없습니다',
  },
  {
    th: 'ไม่พบเมนู id={id}',
    en: 'Menu item id={id} not found',
    ko: '메뉴 id={id}을(를) 찾을 수 없습니다',
  },
  {
    th: 'เมนู "{menu}" ปิดการขายอยู่',
    en: '"{menu}" is not available right now',
    ko: '"{menu}"은(는) 지금 판매하지 않습니다',
  },
  {
    th: 'ตัวเลือก id={id} ไม่ใช่ตัวเลือกของเมนู "{menu}"',
    en: 'Option id={id} does not belong to "{menu}"',
    ko: '옵션 id={id}은(는) "{menu}"의 옵션이 아닙니다',
  },
  {
    th: 'กรุณาเลือก "{group}" ของเมนู "{menu}"',
    en: 'Please choose "{group}" for "{menu}"',
    ko: '"{menu}"의 "{group}"을(를) 선택해 주세요',
  },
  {
    th: '"{group}" เลือกได้สูงสุด {max} รายการ',
    en: '"{group}" allows at most {max} choices',
    ko: '"{group}"은(는) 최대 {max}개까지 고를 수 있습니다',
  },
  {
    th: 'เมนู "{menu}" ขายตามน้ำหนัก ต้องระบุน้ำหนักที่ชั่งได้',
    en: '"{menu}" is sold by weight — enter the weighed amount',
    ko: '"{menu}"은(는) 무게로 팝니다 — 잰 무게를 입력해 주세요',
  },
  {
    th: 'เมนู "{menu}" ขายเป็นชิ้น ไม่ได้ขายตามน้ำหนัก',
    en: '"{menu}" is sold per piece, not by weight',
    ko: '"{menu}"은(는) 무게가 아니라 개수로 팝니다',
  },
  {
    th: 'สินค้าชั่งน้ำหนักใส่ได้บรรทัดละ 1 ถุง — ชั่งถุงถัดไปเป็นอีกบรรทัด',
    en: 'Weighed items are one bag per line — weigh the next bag as a new line',
    ko: '무게 상품은 한 줄에 한 봉지입니다 — 다음 봉지는 새 줄로 달아 주세요',
  },
  { th: 'ไม่พบออเดอร์นี้', en: 'Order not found', ko: '주문을 찾을 수 없습니다' },
  {
    th: 'ไม่พบโต๊ะที่ระบุ',
    en: 'The selected table was not found',
    ko: '선택한 테이블을 찾을 수 없습니다',
  },
  {
    th: 'โต๊ะนี้มีออเดอร์ที่เปิดอยู่แล้ว กรุณาเพิ่มรายการเข้าออเดอร์เดิม',
    en: 'This table already has an open order — add items to that order instead',
    ko: '이 테이블에는 이미 진행 중인 주문이 있습니다 — 기존 주문에 추가해 주세요',
  },
  {
    th: 'ไม่พบลูกค้าที่ระบุ',
    en: 'The selected customer was not found',
    ko: '선택한 고객을 찾을 수 없습니다',
  },
  {
    th: 'ไม่พบรายการนี้ในออเดอร์',
    en: 'This item is not on the order',
    ko: '주문에 없는 항목입니다',
  },
  {
    th: 'แก้ไขไม่ได้ เพราะครัวเริ่มทำรายการนี้แล้ว',
    en: "Can't change — the kitchen has already started this item",
    ko: '수정할 수 없습니다 — 주방에서 이미 조리를 시작했습니다',
  },
  {
    th: 'สินค้าชั่งน้ำหนักแก้จำนวนไม่ได้ — ลบรายการนี้แล้วชั่งใหม่',
    en: "A weighed item's quantity can't be changed — remove it and weigh again",
    ko: '무게 상품은 수량을 바꿀 수 없습니다 — 삭제 후 다시 달아 주세요',
  },
  {
    th: 'ลบไม่ได้ เพราะครัวเริ่มทำรายการนี้แล้ว กรุณาใช้การยกเลิกรายการแทน',
    en: "Can't remove — the kitchen has started it. Cancel the item instead",
    ko: '삭제할 수 없습니다 — 주방에서 조리를 시작했습니다. 항목 취소를 사용해 주세요',
  },
  {
    th: 'เปลี่ยนสถานะจาก "{from}" เป็น "{to}" ไม่ได้',
    en: 'Can\'t change the status from "{from}" to "{to}"',
    ko: '"{from}"에서 "{to}"(으)로 상태를 바꿀 수 없습니다',
  },
  {
    th: 'ยกเลิกรายการที่ครัวทำแล้วต้องใช้สิทธิ์ผู้จัดการ',
    en: 'Cancelling an item the kitchen has started needs a manager',
    ko: '조리가 시작된 항목의 취소는 매니저 권한이 필요합니다',
  },
  {
    th: 'ออเดอร์ยังไม่มีรายการอาหาร',
    en: 'The order has no items yet',
    ko: '주문에 아직 항목이 없습니다',
  },
  {
    th: 'ส่วนลดเกิน 100% ไม่ได้',
    en: "A discount can't exceed 100%",
    ko: '할인은 100%를 넘을 수 없습니다',
  },
  {
    th: 'ไม่พบโค้ดส่วนลดนี้',
    en: 'Discount code not found',
    ko: '할인 코드를 찾을 수 없습니다',
  },
  {
    th: 'ออเดอร์นี้ไม่ได้ผูกกับโต๊ะ ย้ายโต๊ะไม่ได้',
    en: "This order isn't at a table, so it can't be moved",
    ko: '테이블 주문이 아니라서 테이블을 옮길 수 없습니다',
  },
  {
    th: 'เลือกโต๊ะเดิม ไม่ต้องย้าย',
    en: "That's the same table — nothing to move",
    ko: '같은 테이블입니다 — 옮길 필요가 없습니다',
  },
  {
    th: 'โต๊ะปลายทางมีออเดอร์ที่เปิดอยู่แล้ว',
    en: 'The destination table already has an open order',
    ko: '옮길 테이블에 이미 진행 중인 주문이 있습니다',
  },
  {
    th: 'เลือกออเดอร์ปลายทางเดียวกับต้นทางไม่ได้',
    en: "An order can't be merged into itself",
    ko: '같은 주문끼리는 합칠 수 없습니다',
  },
  {
    th: 'ออเดอร์ที่ชำระเงินแล้วยกเลิกไม่ได้',
    en: "A paid order can't be cancelled",
    ko: '결제된 주문은 취소할 수 없습니다',
  },
  {
    th: 'ออเดอร์นี้ถูกยกเลิกไปแล้ว',
    en: 'This order has already been cancelled',
    ko: '이미 취소된 주문입니다',
  },
  {
    th: 'ออเดอร์นี้ถูกยกเลิกแล้ว',
    en: 'This order has been cancelled',
    ko: '취소된 주문입니다',
  },

  // ---------------------------------------------------------------- โปรโมชัน
  {
    th: 'โค้ดนี้ถูกปิดใช้งานแล้ว',
    en: 'This code has been turned off',
    ko: '사용이 중지된 코드입니다',
  },
  {
    th: 'โค้ดนี้หมดอายุหรือยังไม่เริ่มใช้งาน',
    en: 'This code has expired or has not started yet',
    ko: '기간이 끝났거나 아직 시작되지 않은 코드입니다',
  },
  {
    th: 'ไม่ใช่ช่วงเวลาที่ร่วมรายการของโค้ดนี้',
    en: "This code isn't valid at this time of day",
    ko: '지금은 이 코드를 쓸 수 있는 시간이 아닙니다',
  },
  {
    th: 'ยอดบิลยังไม่ถึงขั้นต่ำสำหรับโค้ดนี้',
    en: "The bill hasn't reached this code's minimum spend",
    ko: '이 코드의 최소 주문 금액에 아직 못 미칩니다',
  },
  {
    th: 'บิลนี้ไม่มีเมนูที่ร่วมรายการกับโค้ดนี้',
    en: 'None of the items on this bill are part of this code',
    ko: '이 계산서에는 이 코드에 해당하는 메뉴가 없습니다',
  },
  {
    th: 'ส่วนลดเปอร์เซ็นต์เกิน 100% ไม่ได้',
    en: "A percentage discount can't exceed 100%",
    ko: '퍼센트 할인은 100%를 넘을 수 없습니다',
  },
  {
    th: 'โค้ด "{code}" มีโปรโมชันอื่นใช้อยู่แล้ว',
    en: 'The code "{code}" is already used by another promotion',
    ko: '"{code}" 코드는 이미 다른 프로모션에서 쓰고 있습니다',
  },
  { th: 'ไม่พบโปรโมชันนี้', en: 'Promotion not found', ko: '프로모션을 찾을 수 없습니다' },

  // ---------------------------------------------------------------- ชำระเงิน / คืนเงิน
  {
    th: 'ต้องระบุ amount หรือ itemIds อย่างใดอย่างหนึ่ง',
    en: 'Enter an amount or choose items to pay for',
    ko: '결제할 금액이나 항목을 지정해 주세요',
  },
  {
    th: 'เงินที่รับมาต้องไม่น้อยกว่ายอดที่ชำระ',
    en: "Cash received can't be less than the amount paid",
    ko: '받은 금액은 결제 금액보다 적을 수 없습니다',
  },
  {
    th: 'มีรายการที่ไม่ได้อยู่ในออเดอร์นี้',
    en: 'Some items are not on this order',
    ko: '이 주문에 없는 항목이 있습니다',
  },
  {
    th: '"{item}" ถูกจ่ายไปแล้ว',
    en: '"{item}" has already been paid',
    ko: '"{item}"은(는) 이미 결제되었습니다',
  },
  {
    th: '"{item}" ถูกยกเลิกไปแล้ว เลือกจ่ายไม่ได้',
    en: '"{item}" was cancelled and can\'t be paid for',
    ko: '"{item}"은(는) 취소되어 결제할 수 없습니다',
  },
  {
    th: 'ออเดอร์นี้ชำระเงินครบแล้ว',
    en: 'This order is already fully paid',
    ko: '이미 결제가 끝난 주문입니다',
  },
  {
    th: 'ต้องเปิดกะก่อนจึงจะรับชำระเงินได้',
    en: 'Open a shift before taking payment',
    ko: '결제를 받으려면 먼저 근무를 시작해 주세요',
  },
  {
    th: 'ยอดชำระเกินยอดคงเหลือ (คงเหลือ {amount} บาท)',
    en: 'The amount is more than what is left to pay ({amount} THB left)',
    ko: '남은 금액보다 많습니다 (남은 금액 {amount} THB)',
  },
  {
    th: 'ขายเชื่อต้องให้แคชเชียร์หรือผู้จัดการเป็นคนทำรายการ',
    en: 'Credit sales must be made by a cashier or manager',
    ko: '외상 판매는 캐셔나 매니저만 할 수 있습니다',
  },
  {
    th: 'ขายเชื่อต้องผูกออเดอร์กับลูกค้าเครดิตก่อน',
    en: 'Link the order to a credit customer before selling on credit',
    ko: '외상 판매 전에 주문을 외상 거래처와 연결해 주세요',
  },
  {
    th: 'ขายเชื่อใช้แต้มสะสมแลกส่วนลดร่วมด้วยไม่ได้',
    en: "Loyalty points can't be redeemed on a credit sale",
    ko: '외상 판매에는 적립금을 함께 쓸 수 없습니다',
  },
  {
    th: 'ต้องผูกลูกค้ากับออเดอร์นี้ก่อนจึงใช้แต้มสะสมได้',
    en: 'Link a customer to this order to use points',
    ko: '적립금을 쓰려면 먼저 고객을 주문에 연결해 주세요',
  },
  {
    th: 'แต้มสะสมของลูกค้าไม่พอ',
    en: "The customer doesn't have enough points",
    ko: '고객의 적립금이 부족합니다',
  },
  {
    th: 'แต้มที่ใช้มีมูลค่าเกินยอดที่ต้องชำระรอบนี้',
    en: 'The points are worth more than this payment',
    ko: '사용하는 적립금이 이번 결제 금액보다 많습니다',
  },
  {
    th: 'ร้านยังไม่ได้ตั้งมูลค่าแต้ม จึงใช้แต้มแลกส่วนลดไม่ได้',
    en: "The store hasn't set what a point is worth, so points can't be redeemed",
    ko: '매장에서 포인트 가치를 설정하지 않아 적립금을 사용할 수 없습니다',
  },
  {
    th: 'ร้านยังไม่ได้ตั้งค่าเลขพร้อมเพย์ (ตั้งได้ที่หน้าตั้งค่าระบบ)',
    en: "The store's PromptPay ID isn't set (set it in Settings)",
    ko: '매장 프롬프트페이 번호가 설정되지 않았습니다 (설정 화면에서 설정)',
  },
  {
    th: 'ไม่พบรายการชำระเงินนี้',
    en: 'Payment not found',
    ko: '결제 내역을 찾을 수 없습니다',
  },
  {
    th: 'คืนเงินเกินยอดที่คืนได้ (คืนได้สูงสุด {amount} บาท)',
    en: 'That is more than can be refunded (up to {amount} THB)',
    ko: '환불 가능한 금액을 넘었습니다 (최대 {amount} THB)',
  },
  {
    th: 'บิลขายเชื่อนี้ค้างชำระอยู่ {amount} บาท ลดหนี้ได้ไม่เกินยอดนี้ (ส่วนที่ชำระแล้วต้องยกเลิกใบเสร็จรับชำระก่อน)',
    en: 'This credit bill has {amount} THB outstanding — you can reduce it by up to that (void the collection receipt first for paid amounts)',
    ko: '이 외상 계산서의 미수금은 {amount} THB입니다 — 그 이내로만 감액할 수 있습니다 (수금된 금액은 먼저 수금 영수증을 취소)',
  },
  {
    th: 'ต้องเปิดกะก่อนจึงจะคืนเงินสดได้',
    en: 'Open a shift before refunding cash',
    ko: '현금 환불 전에 먼저 근무를 시작해 주세요',
  },

  // ---------------------------------------------------------------- QR สั่งเอง
  {
    th: 'ไม่พบโต๊ะนี้ หรือโต๊ะนี้ปิดใช้งานอยู่ กรุณาเรียกพนักงาน',
    en: 'This table was not found or is closed — please call a staff member',
    ko: '테이블을 찾을 수 없거나 사용 중지되었습니다 — 직원을 불러 주세요',
  },
  {
    th: 'สาขานี้ปิดให้บริการอยู่ กรุณาเรียกพนักงาน',
    en: 'This branch is closed — please call a staff member',
    ko: '이 지점은 지금 영업하지 않습니다 — 직원을 불러 주세요',
  },
  {
    th: '"{menu}" ขายตามน้ำหนัก ต้องให้พนักงานชั่งให้ กรุณาเรียกพนักงาน',
    en: '"{menu}" is sold by weight and has to be weighed by staff — please call a staff member',
    ko: '"{menu}"은(는) 무게로 팔아 직원이 달아야 합니다 — 직원을 불러 주세요',
  },
  {
    th: 'สั่งผ่าน QR ได้ไม่เกิน {max} ที่ต่อรายการ ถ้าต้องการมากกว่านี้กรุณาเรียกพนักงาน',
    en: 'QR orders are limited to {max} per item — for more, please call a staff member',
    ko: 'QR 주문은 메뉴당 {max}개까지 가능합니다 — 더 필요하시면 직원을 불러 주세요',
  },
  {
    th: 'โต๊ะนี้สั่งผ่าน QR ได้รวมไม่เกิน {max} ที่ต่อบิล (สั่งไปแล้ว {current} ที่) ถ้าต้องการสั่งเพิ่มกรุณาเรียกพนักงาน',
    en: 'QR orders for this table are limited to {max} in total per bill ({current} ordered so far) — to order more, please call a staff member',
    ko: '이 테이블의 QR 주문은 계산서당 총 {max}개까지 가능합니다 (지금까지 {current}개 주문) — 더 주문하시려면 직원을 불러 주세요',
  },

  // ---------------------------------------------------------------- ลูกหนี้ / เอกสาร
  { th: 'ไม่พบลูกค้านี้', en: 'Customer not found', ko: '고객을 찾을 수 없습니다' },
  {
    th: 'เบอร์โทรนี้มีลูกค้าอยู่แล้วในระบบ',
    en: 'A customer with this phone number already exists',
    ko: '이 전화번호로 등록된 고객이 이미 있습니다',
  },
  {
    th: 'ใบลดหนี้ออกได้เฉพาะบิลขายเชื่อ — บิลที่จ่ายแล้วให้ใช้คืนเงินตามปกติ',
    en: 'Credit notes are only for credit sales — use a normal refund for paid bills',
    ko: '감액 전표는 외상 판매에만 발행합니다 — 결제된 계산서는 일반 환불을 사용하세요',
  },
  { th: 'ไม่พบใบลดหนี้นี้', en: 'Credit note not found', ko: '감액 전표를 찾을 수 없습니다' },
  {
    th: 'ไม่พบใบลดหนี้ของรายการนี้',
    en: 'No credit note for this entry',
    ko: '이 항목의 감액 전표가 없습니다',
  },
  {
    th: 'ยังไม่ได้ตั้งอัตราดอกเบี้ยผิดนัด — ตั้งได้ที่หน้าตั้งค่า',
    en: "The late-fee rate isn't set — set it in Settings",
    ko: '연체 이자율이 설정되지 않았습니다 — 설정 화면에서 설정해 주세요',
  },
  {
    th: 'ไม่มีบิลที่ต้องคิดดอกเบี้ยเพิ่ม ณ วันนี้',
    en: 'No bills need a late fee as of today',
    ko: '오늘 기준으로 이자를 매길 계산서가 없습니다',
  },
  {
    th: 'ไม่พบใบแจ้งดอกเบี้ยนี้',
    en: 'Late-fee invoice not found',
    ko: '이자 청구서를 찾을 수 없습니다',
  },
  {
    th: 'ใบแจ้งดอกเบี้ยนี้ถูกยกเลิกไปแล้ว',
    en: 'This late-fee invoice has already been voided',
    ko: '이미 발행 취소된 이자 청구서입니다',
  },
  {
    th: 'ดอกเบี้ยของบิล #{code} ถูกชำระไปแล้ว — ยกเลิกใบเสร็จรับชำระก่อนจึงยกเลิกใบแจ้งนี้ได้',
    en: 'The late fee on bill #{code} has been paid — void the collection receipt first',
    ko: '계산서 #{code}의 이자는 이미 수금되었습니다 — 먼저 수금 영수증을 취소해 주세요',
  },
  {
    th: '{document}นี้ถูกยกเลิกแล้ว ส่งให้ลูกค้าไม่ได้',
    en: "This {document} has been voided and can't be sent",
    ko: '발행 취소된 {document}라서 보낼 수 없습니다',
  },
  {
    th: 'ลูกค้ารายนี้ยังไม่มีอีเมล — ระบุอีเมลผู้รับ หรือบันทึกอีเมลไว้ในบัญชีเครดิตของลูกค้า',
    en: "This customer has no email — enter a recipient or save one on the customer's credit account",
    ko: '이 고객은 이메일이 없습니다 — 받는 사람을 입력하거나 고객 외상 계정에 저장해 주세요',
  },
  {
    th: 'ลูกค้า "{name}" ยังไม่มีวงเงินเครดิต — ผู้จัดการตั้งวงเงินได้ที่หน้าลูกค้า',
    en: '"{name}" has no credit limit yet — a manager can set one on the customer page',
    ko: '"{name}"은(는) 아직 신용 한도가 없습니다 — 매니저가 고객 화면에서 설정할 수 있습니다',
  },
  {
    th: 'เกินวงเงินเครดิตของ "{name}" — วงเงิน {limit} บาท ค้างอยู่ {outstanding} บาท ใช้ได้อีก {available} บาท',
    en: 'Over the credit limit for "{name}" — limit {limit} THB, owing {outstanding} THB, {available} THB available',
    ko: '"{name}"의 신용 한도 초과 — 한도 {limit} THB, 미수금 {outstanding} THB, 사용 가능 {available} THB',
  },
  {
    th: 'ใบวางบิลนี้ไม่ใช่ของลูกค้ารายนี้',
    en: 'This billing note belongs to another customer',
    ko: '다른 고객의 청구서입니다',
  },
  {
    th: 'ใบวางบิลนี้ถูกยกเลิกแล้ว',
    en: 'This billing note has been voided',
    ko: '발행 취소된 청구서입니다',
  },
  {
    th: 'ไม่มียอดค้างชำระให้รับชำระ',
    en: 'There is nothing outstanding to collect',
    ko: '받을 미수금이 없습니다',
  },
  {
    th: 'รับชำระเกินยอดค้าง (ค้างอยู่ {amount} บาท)',
    en: 'More than is owed ({amount} THB outstanding)',
    ko: '미수금보다 많습니다 (미수금 {amount} THB)',
  },
  {
    th: 'ต้องเปิดกะก่อนจึงจะรับชำระหนี้เป็นเงินสดได้',
    en: 'Open a shift before collecting cash',
    ko: '현금 수금 전에 먼저 근무를 시작해 주세요',
  },
  {
    th: 'ไม่พบใบเสร็จรับชำระนี้',
    en: 'Collection receipt not found',
    ko: '수금 영수증을 찾을 수 없습니다',
  },
  {
    th: 'ใบเสร็จนี้ถูกยกเลิกไปแล้ว',
    en: 'This receipt has already been voided',
    ko: '이미 발행 취소된 영수증입니다',
  },
  {
    th: 'กะที่รับเงินสดใบนี้ปิดไปแล้ว ยกเลิกย้อนหลังไม่ได้ — ให้คืนเงินลูกค้าเป็นรายการใหม่แทน',
    en: "The shift that took this cash is closed, so it can't be voided — refund the customer as a new entry instead",
    ko: '이 현금을 받은 근무가 마감되어 취소할 수 없습니다 — 새 환불로 처리해 주세요',
  },
  {
    th: 'บิล id={id} ไม่ใช่บิลค้างชำระของลูกค้ารายนี้',
    en: "Bill id={id} isn't an outstanding bill of this customer",
    ko: '계산서 id={id}은(는) 이 고객의 미수 계산서가 아닙니다',
  },
  {
    th: 'บิล #{code} อยู่ในใบวางบิล {note} แล้ว',
    en: 'Bill #{code} is already on billing note {note}',
    ko: '계산서 #{code}은(는) 이미 청구서 {note}에 들어 있습니다',
  },
  {
    th: 'ไม่มีบิลค้างชำระที่ยังไม่ได้วางบิล',
    en: 'Every outstanding bill is already on a billing note',
    ko: '청구서에 넣지 않은 미수 계산서가 없습니다',
  },
  { th: 'ไม่พบใบวางบิลนี้', en: 'Billing note not found', ko: '청구서를 찾을 수 없습니다' },
  {
    th: 'ใบวางบิลนี้ถูกยกเลิกไปแล้ว',
    en: 'This billing note has already been voided',
    ko: '이미 발행 취소된 청구서입니다',
  },

  // ---------------------------------------------------------------- ตั้งค่า / กะ / โต๊ะ
  {
    th: 'prefix + PLU ต้องเหลือหลักน้ำหนัก 4–6 หลัก',
    en: 'prefix + PLU must leave 4–6 digits for the weight',
    ko: 'prefix + PLU 뒤에 무게 자리 4–6자리가 남아야 합니다',
  },
  {
    th: 'รูปแบบฉลากตาชั่ง: prefix + PLU ต้องเหลือหลักน้ำหนัก 4–6 หลัก',
    en: 'Scale label format: prefix + PLU must leave 4–6 digits for the weight',
    ko: '저울 라벨 형식: prefix + PLU 뒤에 무게 자리 4–6자리가 남아야 합니다',
  },
  {
    th: 'ยอดซื้อต่อ 1 แต้มต้องอย่างน้อย 0.01 บาท',
    en: 'Baht spent per point must be at least 0.01',
    ko: '1포인트 적립에 필요한 결제 금액은 최소 0.01바트여야 합니다',
  },
  {
    th: 'มูลค่า 1 แต้มต้องอย่างน้อย 0.01 บาท',
    en: 'The value of 1 point must be at least 0.01 baht',
    ko: '1포인트 사용 시 금액은 최소 0.01바트여야 합니다',
  },
  { th: 'ไม่พบกะนี้', en: 'Shift not found', ko: '근무를 찾을 수 없습니다' },
  {
    th: 'มีกะที่เปิดอยู่แล้ว ต้องปิดกะเดิมก่อนเปิดกะใหม่',
    en: 'A shift is already open — close it before opening a new one',
    ko: '이미 진행 중인 근무가 있습니다 — 마감 후 새로 시작해 주세요',
  },
  { th: 'กะนี้ปิดไปแล้ว', en: 'This shift is already closed', ko: '이미 마감된 근무입니다' },
  { th: 'ไม่พบโต๊ะนี้', en: 'Table not found', ko: '테이블을 찾을 수 없습니다' },
  {
    th: 'มีโต๊ะชื่อนี้อยู่แล้ว',
    en: 'A table with this name already exists',
    ko: '같은 이름의 테이블이 이미 있습니다',
  },
  {
    th: 'โต๊ะนี้ยังมีออเดอร์ที่ยังไม่ปิด ไม่สามารถเปลี่ยนเป็นว่างได้',
    en: "This table still has an open order, so it can't be marked available",
    ko: '진행 중인 주문이 있어 빈 테이블로 바꿀 수 없습니다',
  },
  {
    th: 'ลบไม่ได้ เพราะโต๊ะนี้ยังมีออเดอร์ที่เปิดอยู่',
    en: "Can't delete — this table has an open order",
    ko: '삭제할 수 없습니다 — 진행 중인 주문이 있는 테이블입니다',
  },

  // ---------------------------------------------------------------- ใบกำกับภาษี
  {
    th: 'ใบกำกับภาษีเต็มรูปต้องระบุชื่อลูกค้า',
    en: 'A full tax invoice needs the customer name',
    ko: '정식 세금계산서에는 고객 이름이 필요합니다',
  },
  {
    th: 'ใบกำกับภาษีเต็มรูปต้องระบุที่อยู่ลูกค้า',
    en: 'A full tax invoice needs the customer address',
    ko: '정식 세금계산서에는 고객 주소가 필요합니다',
  },
  {
    th: 'ออเดอร์นี้ยังไม่มีใบกำกับภาษี',
    en: "This order doesn't have a tax invoice yet",
    ko: '이 주문에는 아직 세금계산서가 없습니다',
  },
  {
    th: 'ออกใบกำกับภาษีได้ก็ต่อเมื่อออเดอร์นี้ชำระเงินครบแล้ว',
    en: 'A tax invoice can only be issued once the order is fully paid',
    ko: '세금계산서는 결제가 끝난 주문에만 발행할 수 있습니다',
  },
  {
    th: 'ออเดอร์นี้มีใบกำกับภาษีที่ยังไม่ถูกยกเลิกอยู่แล้ว',
    en: 'This order already has a tax invoice that has not been voided',
    ko: '이 주문에는 이미 유효한 세금계산서가 있습니다',
  },
  {
    th: 'ร้านยังไม่ได้ตั้งค่าเลขประจำตัวผู้เสียภาษี/ที่อยู่ร้าน กรุณาตั้งค่าในหน้า Settings ก่อน',
    en: "The store's tax ID/address isn't set — set it in Settings first",
    ko: '매장 사업자번호/주소가 설정되지 않았습니다 — 먼저 설정 화면에서 설정해 주세요',
  },
  {
    th: 'ออเดอร์นี้ยังไม่มีใบกำกับภาษีที่ยกเลิกได้',
    en: 'This order has no tax invoice that can be voided',
    ko: '이 주문에는 발행 취소할 세금계산서가 없습니다',
  },

  // ---------------------------------------------------------------- พนักงาน
  {
    th: 'ผู้จัดการจัดการได้เฉพาะบัญชีพนักงานเสิร์ฟ ครัว และแคชเชียร์',
    en: 'Managers can only manage waiter, kitchen and cashier accounts',
    ko: '매니저는 홀 직원, 주방, 캐셔 계정만 관리할 수 있습니다',
  },
  { th: 'ไม่พบผู้ใช้งานนี้', en: 'User not found', ko: '사용자를 찾을 수 없습니다' },
  {
    th: 'username นี้ถูกใช้งานแล้ว',
    en: 'This username is already taken',
    ko: '이미 사용 중인 아이디입니다',
  },
  {
    th: 'ไม่สามารถเปลี่ยนบทบาทของบัญชีตัวเองได้',
    en: "You can't change your own role — ask another admin",
    ko: '본인 계정의 역할은 바꿀 수 없습니다 — 다른 관리자에게 요청하세요',
  },
  {
    th: 'ไม่สามารถปิดการใช้งานบัญชีตัวเองได้',
    en: "You can't deactivate your own account",
    ko: '본인 계정은 사용 중지할 수 없습니다',
  },
  {
    th: 'ไม่สามารถลบบัญชีของตัวเองได้',
    en: "You can't delete your own account",
    ko: '본인 계정은 삭제할 수 없습니다',
  },
  {
    th: 'บัญชีนี้มีประวัติการทำรายการแล้วจึงลบไม่ได้ ให้ปิดการใช้งานบัญชีแทน',
    en: 'This account has transaction history and cannot be deleted — deactivate it instead',
    ko: '이 계정은 거래 이력이 있어 삭제할 수 없습니다 — 대신 계정을 비활성화하십시오',
  },

  // ---------------------------------------------------------------- เชื่อมต่อ PaynEat ERP (ticket 25)
  {
    th: 'วัตถุดิบจัดการใน PaynEat ERP แก้ที่ ERP แล้วดึงข้อมูลใหม่',
    en: 'Ingredients are managed in PaynEat ERP — change them there, then pull again',
    ko: '재료는 PaynEat ERP에서 관리합니다 — ERP에서 수정한 뒤 다시 가져오세요',
  },
  {
    th: 'สาขาจัดการใน PaynEat ERP แก้ที่ ERP แล้วดึงข้อมูลใหม่',
    en: 'Branches are managed in PaynEat ERP — change them there, then pull again',
    ko: '지점은 PaynEat ERP에서 관리합니다 — ERP에서 수정한 뒤 다시 가져오세요',
  },
  {
    th: 'แก้รหัสสาขาให้ตรงรูปแบบก่อนเชื่อมต่อ PaynEat ERP',
    en: 'Fix the branch codes before connecting to PaynEat ERP',
    ko: 'PaynEat ERP에 연결하기 전에 지점 코드를 고쳐 주세요',
  },
  {
    th: 'สาขานี้ยังไม่มีรหัส ตั้งรหัสให้ตรงกับรหัสสาขาใน PaynEat ERP',
    en: "This branch has no code — give it the branch's code in PaynEat ERP",
    ko: '이 지점에는 코드가 없습니다 — PaynEat ERP의 지점 코드를 입력하세요',
  },
  {
    th: 'รหัสสาขาต้องเป็นตัวพิมพ์ใหญ่ A-Z ตัวเลข หรือ - ยาว 2-32 ตัว และขึ้นต้นด้วยตัวอักษรหรือตัวเลข',
    en: 'A branch code is 2–32 capital letters A–Z, digits or -, starting with a letter or digit',
    ko: '지점 코드는 대문자 A-Z, 숫자, - 로 2-32자이며 문자나 숫자로 시작해야 합니다',
  },
  {
    th: 'รหัสสินค้าต้องเป็นตัวพิมพ์ใหญ่ A-Z ตัวเลข หรือ - ยาว 2-32 ตัว และขึ้นต้นด้วยตัวอักษรหรือตัวเลข',
    en: 'An item code is 2–32 capital letters A–Z, digits or -, starting with a letter or digit',
    ko: '품목 코드는 대문자 A-Z, 숫자, - 로 2-32자이며 문자나 숫자로 시작해야 합니다',
  },
  {
    th: 'รหัสสินค้านี้ใช้กับวัตถุดิบอื่นในสาขานี้แล้ว',
    en: 'Another ingredient in this branch already has this item code',
    ko: '이 지점의 다른 재료가 이미 이 품목 코드를 쓰고 있습니다',
  },
  {
    th: 'รายการนี้ชำระเงินแล้ว ต้องคืนเงินก่อนจึงจะยกเลิกได้',
    en: 'This item has already been paid for — refund it before cancelling',
    ko: '이미 결제된 항목입니다 — 취소하려면 먼저 환불하세요',
  },
  {
    th: 'ยอดบิลจะเหลือ {total} บาท น้อยกว่าเงินที่รับไว้แล้ว {paid} บาท ต้องคืนเงิน {refund} บาทก่อน',
    en: 'The bill would drop to {total} THB, below the {paid} THB already received — refund {refund} THB first',
    ko: '계산서 금액이 {total} THB로 줄어 이미 받은 {paid} THB보다 적어집니다 — 먼저 {refund} THB를 환불하세요',
  },
  {
    th: 'บิลนี้รับเงินไว้เกินยอดบิล {amount} บาท ต้องคืนเงินส่วนเกินก่อน',
    en: 'This bill holds {amount} THB more than its total — refund the excess first',
    ko: '이 계산서는 총액보다 {amount} THB를 더 받았습니다 — 먼저 초과분을 환불하세요',
  },
  {
    th: 'ที่อยู่ของ PaynEat ERP ต้องเป็น URL แบบ https:// เช่น https://erp.example.com',
    en: "PaynEat ERP's address must be an https:// URL, for example https://erp.example.com",
    ko: 'PaynEat ERP 주소는 https:// URL이어야 합니다 (예: https://erp.example.com)',
  },
  {
    th: 'ที่อยู่ของ PaynEat ERP ต้องขึ้นต้นด้วย https:// เพื่อไม่ให้ credential ถูกส่งแบบไม่เข้ารหัส',
    en: "PaynEat ERP's address must start with https://, so the credential is never sent unencrypted",
    ko: 'PaynEat ERP 주소는 https://로 시작해야 합니다 — 자격 증명이 암호화되지 않은 채 전송되지 않도록 하기 위해서입니다',
  },
  {
    th: 'ใบรับรอง HTTPS ของ PaynEat ERP ไม่น่าเชื่อถือ ถ้าเชนใช้ CA ภายใน ให้ผู้ดูแลเซิร์ฟเวอร์ POS ตั้ง NODE_EXTRA_CA_CERTS',
    en: "PaynEat ERP's HTTPS certificate isn't trusted — if the chain uses its own internal CA, the POS server's administrator sets NODE_EXTRA_CA_CERTS",
    ko: 'PaynEat ERP의 HTTPS 인증서를 신뢰할 수 없습니다 — 체인이 내부 CA를 쓰는 경우 POS 서버 관리자가 NODE_EXTRA_CA_CERTS를 설정하세요',
  },
  {
    th: 'credential ต้องขึ้นต้นด้วย pnepos_ ตามที่ PaynEat ERP แสดงตอนลงทะเบียน POS',
    en: 'The credential starts with pnepos_, as PaynEat ERP showed it when the POS was registered',
    ko: '자격 증명은 POS 등록 시 PaynEat ERP가 보여 준 대로 pnepos_로 시작합니다',
  },
  {
    th: 'PaynEat ERP ไม่รับ credential นี้ (ถูกเพิกถอนหรือไม่มีอยู่) ขอ credential ใหม่จากผู้ดูแล ERP',
    en: "PaynEat ERP doesn't accept this credential (revoked or unknown) — ask the ERP administrator for a new one",
    ko: 'PaynEat ERP가 이 자격 증명을 받지 않습니다 (폐기되었거나 없음) — ERP 관리자에게 새로 요청하세요',
  },
  {
    th: 'PaynEat ERP ไม่รับ credential นี้แล้ว บันทึก credential ใหม่ก่อนดึงข้อมูล',
    en: 'PaynEat ERP no longer accepts this credential — save a new one before pulling',
    ko: 'PaynEat ERP가 더 이상 이 자격 증명을 받지 않습니다 — 가져오기 전에 새 자격 증명을 저장하세요',
  },
  {
    th: 'PaynEat ERP ใช้สัญญาเชื่อมต่อเวอร์ชัน {version} ซึ่ง POS รุ่นนี้ไม่รองรับ อัปเดต POS ก่อนเชื่อมต่อ',
    en: "PaynEat ERP uses integration contract {version}, which this POS version doesn't support — update the POS first",
    ko: 'PaynEat ERP가 이 POS 버전이 지원하지 않는 연동 규약 {version}을(를) 사용합니다 — 먼저 POS를 업데이트하세요',
  },
  {
    th: 'ติดต่อ PaynEat ERP ไม่ได้ ตรวจที่อยู่และการเชื่อมต่อเครือข่าย',
    en: "Couldn't reach PaynEat ERP — check the address and the network",
    ko: 'PaynEat ERP에 연결할 수 없습니다 — 주소와 네트워크를 확인하세요',
  },
  {
    th: 'PaynEat ERP ไม่พร้อมให้บริการชั่วคราว ลองใหม่อีกครั้งภายหลัง',
    en: 'PaynEat ERP is temporarily unavailable — try again later',
    ko: 'PaynEat ERP를 잠시 사용할 수 없습니다 — 나중에 다시 시도하세요',
  },
  {
    th: 'PaynEat ERP ขอให้รอสักครู่ก่อนเรียกอีกครั้ง',
    en: 'PaynEat ERP asked us to wait a moment before trying again',
    ko: 'PaynEat ERP가 잠시 후 다시 시도하라고 요청했습니다',
  },
  {
    th: 'คำตอบของ PaynEat ERP ไม่ตรงกับสัญญาเชื่อมต่อ POS v1',
    en: "PaynEat ERP's answer doesn't match the POS v1 integration contract",
    ko: 'PaynEat ERP의 응답이 POS v1 연동 규약과 맞지 않습니다',
  },
  {
    th: 'PaynEat ERP ตอบ HTTP {status} ตรวจว่าที่อยู่ชี้ไปที่ PaynEat ERP จริงและไม่มี proxy ขวางอยู่',
    en: 'PaynEat ERP answered HTTP {status} — check that the address points at PaynEat ERP and no proxy is in the way',
    ko: 'PaynEat ERP가 HTTP {status}로 응답했습니다 — 주소가 PaynEat ERP를 가리키는지, 중간에 프록시가 없는지 확인하세요',
  },
  {
    th: 'ยังไม่ได้เชื่อมต่อ PaynEat ERP',
    en: 'Not connected to PaynEat ERP',
    ko: 'PaynEat ERP에 연결되어 있지 않습니다',
  },
  {
    th: 'PaynEat ERP ไม่ได้ให้เครื่องนี้ดูแลสาขารหัสนี้',
    en: "PaynEat ERP doesn't assign the branch with this code to this POS",
    ko: 'PaynEat ERP가 이 코드의 지점을 이 POS에 맡기지 않았습니다',
  },
  {
    th: 'มีสาขารหัสนี้ในเครื่องแล้ว',
    en: 'A branch with this code already exists on this POS',
    ko: '이 코드의 지점이 이미 이 POS에 있습니다',
  },
];

const escapeRegex = (text) => text.replace(/[.*+?^${}()|[\]\\]/g, '\\$&');

/** แปลงแม่แบบ `ข้อความ {ชื่อ}` เป็น regex ที่ดึงค่าในช่องกลับออกมา */
const compile = (template) => {
  const names = [];
  const pattern = template
    .split(/(\{[a-zA-Z]+\})/)
    .map((part) => {
      const slot = part.match(/^\{([a-zA-Z]+)\}$/);
      if (slot) {
        names.push(slot[1]);
        return '(.+?)';
      }
      return escapeRegex(part);
    })
    .join('');
  return { regex: new RegExp(`^${pattern}$`, 's'), names };
};

const compiled = ERROR_MESSAGES.map((entry) => ({ entry, ...compile(entry.th) }));

const fill = (template, values) =>
  template.replace(/\{([a-zA-Z]+)\}/g, (whole, name) => values[name] ?? whole);

const translateTerm = (value, lang) => TERMS[value]?.[lang] ?? value;

/**
 * แปลข้อความไทยหนึ่งข้อความเป็นภาษาที่ขอ — ไม่รู้จักข้อความ/ภาษาไทย/ภาษาที่ไม่รองรับ = คืนตามเดิม
 * (ข้อความที่ไม่อยู่ในแคตตาล็อกยังอ่านได้เป็นภาษาไทย ดีกว่าหายไปเฉย ๆ)
 */
export const translateMessage = (message, lang) => {
  if (typeof message !== 'string' || !lang || lang === 'th') return message;
  const text = message.trim();
  for (const { entry, regex, names } of compiled) {
    const target = entry[lang];
    if (!target) continue;
    const match = text.match(regex);
    if (!match) continue;
    const values = Object.fromEntries(
      names.map((name, i) => [name, translateTerm(match[i + 1], lang)]),
    );
    return fill(target, values);
  }
  return message;
};

/**
 * แม่แบบภาษาอังกฤษของข้อความ (ช่องแทรกค่ายังเป็น `{ชื่อ}` ไม่มีค่าจริง) หรือ undefined ถ้าไม่อยู่ในแคตตาล็อก —
 * ใช้เขียนลง log แทนข้อความจริง ซึ่งอาจแทรกข้อมูลลูกค้า/ค่าจากภายนอกไว้ (สัญญา telemetry ห้าม, ticket 24)
 */
export const messageTemplate = (message) => {
  if (typeof message !== 'string') return undefined;
  const text = message.trim();
  return compiled.find(({ regex }) => regex.test(text))?.entry.en;
};

/** เลือกภาษาจาก header `Accept-Language` ของ request — ไม่ส่งมา = ไทย (พฤติกรรมเดิม) */
export const languageOf = (req) => {
  if (!req.headers?.['accept-language']) return 'th';
  const lang = req.acceptsLanguages(...SUPPORTED_LANGUAGES);
  return lang || 'th';
};

export default { translateMessage, messageTemplate, languageOf, ERROR_MESSAGES, TERMS };
