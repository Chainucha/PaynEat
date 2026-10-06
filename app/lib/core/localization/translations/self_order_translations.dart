// Copyright 2026 Suruch Chakrapeesirisuk
// SPDX-License-Identifier: Apache-2.0

/// คำแปลของฟีเจอร์สั่งอาหารเองผ่าน QR (ดู docs/tickets/17-qr-self-order.md)
const Map<String, String> selfOrderTranslationsTh = {
  'self_order_title': 'สั่งอาหาร',
  'self_order_loading': 'กำลังโหลดเมนู...',
  'self_order_invalid_link': 'ลิงก์ไม่ถูกต้อง กรุณาสแกน QR ที่โต๊ะใหม่อีกครั้ง',
  'self_order_table_unavailable':
      'ไม่พบโต๊ะนี้ หรือโต๊ะนี้ปิดใช้งานอยู่ กรุณาเรียกพนักงาน',
  'self_order_menu_empty': 'ยังไม่มีเมนูให้สั่งในหมวดนี้',
  'self_order_hint': 'แตะเมนูเพื่อใส่ตะกร้า สั่งเองได้เลยไม่ต้องเรียกพนักงาน',
  'self_order_submit_success': 'ส่งออเดอร์เข้าครัวเรียบร้อยแล้ว',
  'self_order_current_order_title': 'ออเดอร์ของคุณ',
  'self_order_cart_title': 'ตะกร้าของคุณ',
  'self_order_cart_footnote':
      'ยอดนี้ยังไม่รวมค่าบริการและภาษี ระบบจะคำนวณให้ครบหลังกดส่งเข้าครัว',
  'self_order_send_to_kitchen': 'ส่งเข้าครัว',
  'self_order_view_cart_button': 'ตะกร้า (@count) · @total',

  // ขายตามน้ำหนัก/บาร์โค้ด/ขายเชื่อ (tickets 18–20)
  'self_order_error_weighed_item':
      '"@name" ขายตามน้ำหนัก ต้องให้พนักงานชั่งให้ กรุณาเรียกพนักงาน',
  'self_order_staff_only_hint': 'เนื้อสดชั่งกิโล สั่งกับพนักงานได้เลย',

  // เพดานของ QR (DECISIONS #99) — ข้อความ error ตรงกับของ backend (src/i18n/errorMessages.js)
  'self_order_error_line_limit':
      'สั่งผ่าน QR ได้ไม่เกิน @max ที่ต่อรายการ ถ้าต้องการมากกว่านี้กรุณาเรียกพนักงาน',
  'self_order_error_order_limit':
      'โต๊ะนี้สั่งผ่าน QR ได้รวมไม่เกิน @max ที่ต่อบิล (สั่งไปแล้ว @current ที่) ถ้าต้องการสั่งเพิ่มกรุณาเรียกพนักงาน',
  'self_order_line_limit_hint': 'สูงสุด @max ที่ · มากกว่านี้เรียกพนักงาน',
};

const Map<String, String> selfOrderTranslationsEn = {
  'self_order_title': 'Order food',
  'self_order_loading': 'Loading the menu...',
  'self_order_invalid_link':
      'Invalid link — please scan the QR code on your table again',
  'self_order_table_unavailable':
      'Table not found, or this table is deactivated. Please call a staff member.',
  'self_order_menu_empty': 'No items in this category yet',
  'self_order_hint':
      'Tap a dish to add it to your cart — no need to call staff',
  'self_order_submit_success': 'Your order has been sent to the kitchen',
  'self_order_current_order_title': 'Your order',
  'self_order_cart_title': 'Your cart',
  'self_order_cart_footnote':
      "This total doesn't include service charge and VAT yet — those are added once you send it to the kitchen",
  'self_order_send_to_kitchen': 'Send to kitchen',
  'self_order_view_cart_button': 'Cart (@count) · @total',

  'self_order_error_weighed_item':
      '"@name" is sold by weight and must be weighed by staff — please call a staff member',
  'self_order_staff_only_hint': 'Meat sold by weight — order it from staff',

  'self_order_error_line_limit':
      'QR orders are limited to @max per item — for more, please call a staff member',
  'self_order_error_order_limit':
      'QR orders for this table are limited to @max in total per bill (@current ordered so far) — to order more, please call a staff member',
  'self_order_line_limit_hint': 'Max @max · call staff for more',
};

const Map<String, String> selfOrderTranslationsKo = {
  'self_order_title': '주문하기',
  'self_order_loading': '메뉴를 불러오는 중...',
  'self_order_invalid_link': '유효하지 않은 링크입니다 — 테이블의 QR 코드를 다시 스캔해 주세요',
  'self_order_table_unavailable': '테이블을 찾을 수 없거나 사용이 중지된 테이블입니다. 직원을 불러 주세요.',
  'self_order_menu_empty': '이 카테고리에는 아직 메뉴가 없습니다',
  'self_order_hint': '메뉴를 눌러 담으세요 · 직원을 부르지 않아도 됩니다',
  'self_order_submit_success': '주문이 주방으로 전달되었습니다',
  'self_order_current_order_title': '내 주문',
  'self_order_cart_title': '장바구니',
  'self_order_cart_footnote':
      '이 금액에는 서비스 차지와 부가가치세가 아직 포함되지 않았습니다 — 주방으로 전달할 때 합산됩니다',
  'self_order_send_to_kitchen': '주방으로 전달',
  'self_order_view_cart_button': '장바구니 (@count) · @total',

  'self_order_error_weighed_item':
      '"@name" 은(는) 무게 단위 상품이라 직원이 계량해야 합니다 — 직원을 불러 주세요',
  'self_order_staff_only_hint': '무게로 파는 정육은 직원에게 주문해 주세요',

  'self_order_error_line_limit':
      'QR 주문은 메뉴당 @max개까지 가능합니다 — 더 필요하시면 직원을 불러 주세요',
  'self_order_error_order_limit':
      '이 테이블의 QR 주문은 계산서당 총 @max개까지 가능합니다 (지금까지 @current개 주문) — 더 주문하시려면 직원을 불러 주세요',
  'self_order_line_limit_hint': '최대 @max개 · 더 필요하면 직원 호출',
};
