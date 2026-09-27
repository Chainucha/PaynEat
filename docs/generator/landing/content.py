# Copyright 2026 Suruch Chakrapeesirisuk
# SPDX-License-Identifier: Apache-2.0
#
# เนื้อหาหน้า Landing ทั้ง 3 ภาษา — โครงเดียวกันทุกภาษา (build_landing.py วาดจากโครงนี้)
#
# กติกาเนื้อหา (docs/DECISIONS.md #70):
# - เล่าเป็น "ปัญหาของร้าน → ชุดฟีเจอร์ที่แก้" ทุกข้ออ้างต้องมีในโค้ดจริงวันนี้ ห้ามเขียนตัวเลขผลลัพธ์ที่ไม่ได้วัด
# - ภาพ = golden test จาก app/tool/screenshots/story_test.dart เท่านั้น (ข้อมูลร้าน/ลูกค้าสมมติ)
# - ขั้น "ลองในเดโม" ต้องทำตามได้จริงบนเดโม /app/ — ใช้ชื่อปุ่ม/เมนูตามคำแปลในแอปของภาษานั้น
# - ไม่อ้างชื่อบริษัท/แบรนด์จริง
# - {tests} ถูกแทนด้วย TESTS ตอนสร้าง — อัปเดตพร้อม badge ใน README ทุกครั้งที่จำนวนเทสต์เปลี่ยน

# backend `npm test` + app `flutter test` + app `flutter test test_e2e` (นับจริงตอนแก้ล่าสุด)
TESTS = 388 + 492 + 49

REPO = 'https://github.com/SuruchBoss/PaynEat'
ERP = 'https://suruchboss.github.io/PaynEat-ERP/'
# ช่องทางติดต่อเจ้าของโปรเจกต์ในส่วนท้ายเว็บ — เจ้าของขอให้ใส่อีเมลเอง (docs/DECISIONS.md #73 แทนข้อเดิมใน #41)
EMAIL = 'mailto:bossxiii@gmail.com'
LINKEDIN = 'https://www.linkedin.com/in/suruchboss'

TH = {
    'code': 'th',
    'file': 'index.html',
    'shot': 'th',
    'og_image': 'og-image.png',
    'title': 'PaynEat POS — ระบบขายหน้าร้านสำหรับร้านอาหารขนาดใหญ่',
    'description': 'POS สำหรับร้านอาหารขนาดใหญ่ที่แก้ปัญหาจริงของหน้าร้าน: ออเดอร์ล้น คนไม่พอ จ่ายช้า เงินรั่ว ของหมด '
    'และเจ้าของมองไม่เห็นภาพรวม — โอเพนซอร์ส ฟรี ลองเดโมได้ทันที',
    'skip': 'ข้ามไปที่เมนูแก้ปัญหา',
    'promo': 'เดโมเต็มระบบเปิดในเบราว์เซอร์ได้ทันที · ไม่ต้องสมัคร · ข้อมูลร้านสมมติพร้อมให้กด',
    'promo_link': 'ลองเลย →',
    'nav_label': 'เมนูหลัก',
    'lang_label': 'เลือกภาษา',
    'nav': [('#menu', 'เมนูแก้ปัญหา'), ('#stories', 'หน้าจอจริง'), ('#ai', 'ผู้ช่วย AI'), ('#checkout', 'ราคา'), ('install.html', 'วิธีติดตั้ง')],
    'cart': 'เปิดเดโม',
    'nav_install_short': 'ติดตั้ง',
    'hero': {
        'eyebrow': '🍽 POS สำหรับร้านอาหารขนาดใหญ่ · โอเพนซอร์ส',
        'title_html': 'ร้านแน่นแค่ไหน<br>ก็<em>เสิร์ฟทัน</em><br>เงินไม่รั่ว',
        'lead': 'ตั้งแต่ลูกค้าสแกน QR สั่งเอง จอครัวเรียงคิวให้ จ่ายด้วยพร้อมเพย์ จนปิดกะแล้วเงินตรง — '
        'ระบบเดียวที่ออกแบบจากปัญหาจริงของร้านอาหารไทยช่วงที่ยุ่งที่สุด',
        'cta': 'เปิดเดโม สั่งได้เลย →',
        'cta2': 'ดูเมนูแก้ปัญหา',
        'facts': [
            ('⏱', 'พร้อมใน 0 นาที', 'เปิดเดโมในเบราว์เซอร์ ไม่ต้องสมัคร'),
            ('🛵', 'ค่าเช่า ฿0', 'ไม่มีแพ็กเกจรายเดือน'),
            ('✅', '{tests} เทสต์', 'ทดสอบอัตโนมัติก่อนปล่อยทุกครั้ง'),
            ('🌐', '3 ภาษา', 'ไทย · English · 한국어'),
        ],
        'floats': [
            ('🔔', 'โต๊ะ A1 · รอ 18 นาที', 'จอครัวเตือนเอง'),
            ('✅', 'พร้อมเพย์ ฿476.69', 'QR ตามยอดบิลจริง'),
        ],
    },
    'picker': {
        'kick': 'เลือกตามอาการ',
        'title': 'ร้านคุณเจ็บตรงไหน?',
        'sub': 'แตะปัญหาที่เจอ แล้วดูว่าระบบเสิร์ฟอะไรให้ — แต่ละข้อรวมหลายฟีเจอร์ที่ทำงานต่อกัน',
    },
    'menu': {
        'kick': 'เมนูแนะนำของร้าน',
        'title': 'เมนูแก้ปัญหา 9 ชุด',
        'sub': 'คัดจากปัญหาที่ร้านอาหารใหญ่เจอทุกวัน ภาพทุกใบถ่ายจากแอปจริง ไม่ใช่ภาพจำลอง',
    },
    'labels': {
        'tags': 'ส่วนประกอบ',
        'outcome': 'ได้อะไร',
        'more': 'ดูรายละเอียด',
        'problem': 'ปัญหาที่ร้านเจอ',
        'inside': 'ในชุดนี้มี',
        'try': 'ลองชิมในเดโม',
        'open_demo': 'เปิดเดโม →',
    },
    'stories_head': {
        'kick': 'ดูทีละจาน',
        'title': 'ปัญหาเดิม วิธีแก้ใหม่ หน้าจอจริง',
        'sub': 'ทุกชุดบอกว่าแก้อะไร ด้วยฟีเจอร์ไหน และกดลองในเดโมได้ตรงไหน',
    },
    'stories': [
        {
            'id': 'rush',
            'emoji': '🔥',
            'chip': 'ออเดอร์ล้น',
            'role': 'หน้าร้าน · ครัว',
            'title': 'ชุดชั่วโมงเร่งด่วน',
            'pain': 'ทุ่มหนึ่ง โต๊ะเต็มร้าน ใบสั่งกระดาษกองในครัว จานที่รอนานสุดถูกลืม',
            'tags': ['ผังโต๊ะ', 'จอครัวเรียลไทม์', 'เตือนเกิน 15 นาที', 'เลขคิวกลับบ้าน'],
            'outcome': 'จานที่รอนานสุดอยู่บนสุดเสมอ',
            'headline': 'ออเดอร์ล้นแค่ไหน ครัวก็รู้ว่าต้องทำอะไรก่อน',
            'problem': 'ช่วงพีค พนักงานวิ่งส่งใบสั่งเข้าครัว ใบหาย ลายมืออ่านไม่ออก ครัวทำตามใบที่หยิบได้ '
            'ไม่ใช่ตามลำดับที่ลูกค้ารอ โต๊ะที่รอนานสุดจึงโดนลืม',
            'features': [
                ('ผังโต๊ะบอกสถานะด้วยสี', 'ว่าง มีลูกค้า ยอดค้างบนโต๊ะ แยกโซนในร้าน ริมหน้าต่าง'),
                ('สั่งพร้อมตัวเลือกเสริมและหมายเหตุ', 'เผ็ดกลาง ไข่ดาว ไม่ใส่ผัก ส่งถึงครัวครบ ไม่ต้องตะโกนบอก'),
                ('จอครัวเรียลไทม์ 3 คอลัมน์', 'รอทำ → กำลังทำ → พร้อมเสิร์ฟ ตั๋วที่รอนานสุดอยู่บนสุด เกิน 15 นาทีขึ้นเตือนแดงเอง'),
                ('โต๊ะ กลับบ้าน เดลิเวอรี แยกด้วยไอคอน', 'ออเดอร์กลับบ้านได้เลขคิวรันต่อวันอัตโนมัติ'),
                ('กดผิดย้อนได้', 'แถบ "เลิกทำ" 8 วินาทีหลังกดเดินสถานะ ไม่ต้องตามผู้จัดการ'),
            ],
            'try': [
                'เข้าเดโม เลือก "พนักงานเสิร์ฟ"',
                'แตะโต๊ะว่าง เลือกเมนู แล้วส่งครัว',
                'ออกจากระบบ เลือก "ครัว" — ตั๋วที่เพิ่งสั่งขึ้นในคอลัมน์รอทำ',
            ],
            'shots': [
                ('rush-kitchen', 'tablet', 'จอครัวบนแท็บเล็ต ตั๋วโต๊ะ A1 รอ 18 นาทีขึ้นเตือนสีแดง', 'จอครัว: ตั๋วที่เกิน 15 นาทีขึ้นเตือนเอง'),
                ('rush-tables', 'phone', 'ผังโต๊ะบนมือถือพนักงานเสิร์ฟ แยกโต๊ะว่างกับโต๊ะที่มีลูกค้า', 'ผังโต๊ะบนมือถือพนักงาน'),
            ],
        },
        {
            'id': 'staff',
            'emoji': '🙋',
            'chip': 'คนไม่พอ',
            'role': 'ลูกค้า · หน้าร้าน',
            'title': 'ชุดลูกค้าสั่งเอง',
            'pain': 'พนักงานเสิร์ฟหายาก ลูกค้ายกมือเรียกสั่งแล้วต้องนั่งรอ',
            'tags': ['QR ประจำโต๊ะ', 'ไม่ต้องล็อกอิน', 'ขึ้นครัวทันที', 'ตัดสต๊อกเหมือนกัน'],
            'outcome': 'ลูกค้าสั่งได้ตั้งแต่นั่งลง',
            'headline': 'ลูกค้าสั่งเองจากมือถือ พนักงานไปทำงานที่ต้องใช้คนจริง ๆ',
            'problem': 'ร้านใหญ่ขาดพนักงานเสิร์ฟเกือบทุกกะ ลูกค้านั่งรอเมนู รอคนมารับออเดอร์ รอสั่งเพิ่ม '
            'ทุกนาทีที่รอคือโต๊ะที่หมุนช้าลง',
            'features': [
                ('สแกน QR ที่โต๊ะแล้วสั่งได้เลย', 'เปิดในเบราว์เซอร์มือถือ ไม่ต้องติดตั้งแอป ไม่ต้องสมัครหรือล็อกอิน'),
                ('เส้นทางเดียวกับพนักงานสั่ง', 'ขึ้นจอครัวและตัดสต๊อกวัตถุดิบเหมือนกันทุกประการ ไม่มีระบบแยกให้ตามกระทบยอด'),
                ('ลูกค้าเห็นออเดอร์ของโต๊ะตัวเอง', 'สั่งเพิ่มได้เรื่อย ๆ และดูได้ว่าสั่งอะไรไปแล้วบ้าง'),
                ('ลิงก์เสียบอกตรง ๆ', 'QR ผิดหรือโต๊ะถูกปิดใช้งาน ลูกค้าเห็นว่าใช้ไม่ได้ ไม่มีออเดอร์ลอยเข้าครัว'),
                ('ผู้จัดการเปลี่ยน QR ได้เอง', 'กดค้างที่โต๊ะบนผัง เปิด QR คัดลอกลิงก์ หรือสร้าง QR ใหม่แทนใบเก่า'),
            ],
            'try': [
                'เข้าเดโม เลือก "ผู้จัดการ" แล้วไปที่ผังโต๊ะ',
                'กดค้างที่โต๊ะใดก็ได้ → "ดู QR สั่งอาหารเอง" → คัดลอกลิงก์',
                'เปิดลิงก์ในแท็บใหม่ แล้วสั่งแบบลูกค้า',
            ],
            'shots': [
                ('staff-self-order', 'phone', 'หน้าเมนูที่ลูกค้าเห็นบนมือถือหลังสแกน QR โต๊ะ A1', 'หน้าที่ลูกค้าเห็นหลังสแกน QR'),
            ],
        },
        {
            'id': 'pay',
            'emoji': '💸',
            'chip': 'จ่ายช้า',
            'role': 'แคชเชียร์',
            'title': 'ชุดจ่ายไว ไม่ต้องคิดเลข',
            'pain': 'คิวรอจ่ายยาว โต๊ะใหญ่ขอแยกบิล ต้องคิดเลขกันทั้งโต๊ะ',
            'tags': ['พร้อมเพย์ QR', 'แยกบิล/รวมบิล', 'ใบเสร็จไทย', 'ใบกำกับภาษี'],
            'outcome': 'ยอดบน QR ตรงบิลทุกสตางค์',
            'headline': 'สแกนจ่ายตามยอดจริง แยกบิลให้ทั้งโต๊ะในไม่กี่แตะ',
            'problem': 'แคชเชียร์พิมพ์ยอดโอนเอง พิมพ์ผิดหลักเดียวต้องตามคืนเงิน กลุ่มเพื่อนขอจ่ายคนละส่วน '
            'ส่วนลดกับค่าบริการต้องมานั่งเฉลี่ยกันเองหน้าเคาน์เตอร์',
            'features': [
                ('QR พร้อมเพย์ตามมาตรฐาน EMV', 'ฝังยอดบิลลงใน QR ลูกค้าสแกนจากแอปธนาคารได้ทันที ไม่ต้องพิมพ์ยอดเอง'),
                ('แยกจ่ายหลายช่องทาง แยกบิลตามรายการ', 'เงินสด QR บัตร ในบิลเดียว เฉลี่ยส่วนลด ค่าบริการ และ VAT ตามสัดส่วนให้เอง'),
                ('ย้ายโต๊ะ รวมบิล', 'ลูกค้าย้ายที่นั่งหรือรวมโต๊ะ ออเดอร์ตามไปครบ'),
                ('ใบเสร็จไทยผ่านเครื่องพิมพ์ความร้อน', 'ESC/POS กระดาษ 58 และ 80 มม. ในวง LAN/Wi-Fi เดียวกัน'),
                ('ใบกำกับภาษีอย่างย่อ', 'เลขที่เรียงตามปี พ.ศ. ยกเลิกใบที่ออกผิดได้โดยเก็บประวัติไว้'),
            ],
            'try': [
                'เข้าเดโม เลือก "แคชเชียร์"',
                'แตะโต๊ะที่มีลูกค้า แล้วกดเก็บเงิน',
                'เลือก "พร้อมเพย์ / QR" — QR สร้างจากยอดของบิลนั้นทันที',
            ],
            'shots': [
                ('pay-promptpay', 'phone', 'หน้าเก็บเงินบนมือถือ เลือกพร้อมเพย์แล้วขึ้น QR ตามยอดบิลโต๊ะ C1', 'QR พร้อมเพย์ตามยอดบิล'),
            ],
        },
        {
            'id': 'cash',
            'emoji': '🔒',
            'chip': 'เงินรั่ว',
            'role': 'ผู้จัดการ · เจ้าของ',
            'title': 'ชุดปิดกะเงินตรง',
            'pain': 'ปิดร้านแล้วเงินในลิ้นชักไม่ตรง ไม่รู้ว่าหายตรงไหน ใครทำ',
            'tags': ['เปิด-ปิดกะ', 'Z-report', 'ประวัติแก้ไม่ได้', 'สิทธิ์ 5 บทบาท'],
            'outcome': 'ขาด 40 บาทก็เห็นตั้งแต่ปิดกะ',
            'headline': 'ทุกบาทในลิ้นชัก ตามย้อนได้ว่ามาจากไหน ใครแตะ',
            'problem': 'ยกเลิกบิลหลังรับเงิน ให้ส่วนลดเกินสิทธิ์ คืนเงินไม่มีเหตุผล ร้านใหญ่มีคนแตะเงินหลายมือ '
            'พอยอดไม่ตรงก็ไม่มีหลักฐานว่าเกิดอะไรขึ้น',
            'features': [
                ('ต้องเปิดกะก่อนรับเงิน', 'ใส่เงินทอนตั้งต้น ทุกการรับเงินผูกกับกะที่เปิดอยู่'),
                ('ปิดกะแล้วเทียบให้ทันที', 'นับเงินจริง ระบบคำนวณเงินที่ควรมีและส่วนต่างให้เอง'),
                ('Z-report ปิดกะและปิดวัน', 'ยอดขาย ภาษี ส่วนลดมือแยกจากโปรโมชัน ช่องทางชำระ รับชำระหนี้ ส่งออก CSV ให้ฝ่ายบัญชี'),
                ('ประวัติการทำรายการที่แก้ไม่ได้', 'ยกเลิกออเดอร์ ให้ส่วนลด คืนเงิน แก้ราคา เปลี่ยนสิทธิ์ บันทึกผู้ทำ เวลา และเหตุผลทุกครั้ง'),
                ('สิทธิ์ 5 บทบาท บังคับที่เซิร์ฟเวอร์', 'ไม่ใช่แค่ซ่อนปุ่ม ยิงคำขอตรง ๆ ก็ถูกปฏิเสธ'),
            ],
            'try': [
                'เข้าเดโม เลือก "ผู้จัดการ" แล้วไปที่เมนู "กะ"',
                'กด "ปิดกะ" กรอกเงินที่นับได้ให้ขาดสักนิด แล้วแตะกะนั้นในประวัติเพื่อดู Z-report',
                'เข้าใหม่เป็น "ผู้ดูแลระบบ" → "ประวัติการทำรายการ"',
            ],
            'shots': [
                ('cash-zreport', 'desktop', 'ใบสรุปปิดกะ (Z-report) แยกยอดขาย ส่วนลด ช่องทางชำระ และส่วนต่างเงินสด', 'Z-report ของกะที่นับเงินขาด 40 บาท'),
                ('cash-audit', 'desktop', 'ประวัติการทำรายการ บอกว่าใครทำอะไร เมื่อไร พร้อมตัวกรองประเภท', 'ประวัติการทำรายการ: ใคร ทำอะไร เมื่อไร'),
            ],
        },
        {
            'id': 'stock',
            'emoji': '📦',
            'chip': 'ของหมด',
            'role': 'ครัว · ผู้จัดการ',
            'title': 'ชุดสต๊อกไม่ขาดกลางเซอร์วิส',
            'pain': 'ลูกค้าสั่งไปแล้ว ครัวเพิ่งมาบอกว่าของหมด',
            'tags': ['ตัดสต๊อกอัตโนมัติ', 'ปิดขายเมนูเอง', 'เตือนใกล้หมด'],
            'outcome': 'ไม่ต้องมีใครคอยกดปิดเมนู',
            'headline': 'วัตถุดิบหมด เมนูปิดขายเอง ก่อนลูกค้าจะได้สั่ง',
            'problem': 'ปลาหมดตั้งแต่สองทุ่ม แต่เมนูยังขายอยู่ในเครื่อง พนักงานรับออเดอร์ไปสามโต๊ะ ครัวเพิ่งมาบอก '
            'เสียทั้งเวลาและความรู้สึกลูกค้า',
            'features': [
                ('ผูกเมนูกับวัตถุดิบ', 'ตัดสต๊อกตอนส่งครัว คืนให้เองเมื่อยกเลิกหรือลบรายการ ใช้หน่วยตามที่ครัวนับจริง'),
                ('หมดแล้วปิดขายเอง', 'วัตถุดิบไม่พอ เมนูนั้นปิดขายทันที เติมสต๊อกแล้วเปิดกลับให้เอง'),
                ('เตือนวัตถุดิบใกล้หมด', 'ตั้งจุดเตือนรายตัว กรองดูเฉพาะของที่ใกล้หมดก่อนเปิดร้าน'),
                ('ใช้กับ QR สั่งเองด้วย', 'ลูกค้าสั่งเองก็ตัดสต๊อกเส้นทางเดียวกัน'),
            ],
            'try': [
                'เข้าเดโม เลือก "ผู้ดูแลระบบ" → "วัตถุดิบ/สต๊อก"',
                'กด "ใกล้หมดเท่านั้น" — ปลาทับทิมถูกตั้งให้ต่ำกว่าจุดเตือนไว้แล้ว',
                'ลองปรับสต๊อกปลาทับทิมเป็นศูนย์ แล้วดูเมนูที่ใช้ปลาถูกปิดขาย',
            ],
            'shots': [
                ('stock-ingredients', 'desktop', 'หน้าวัตถุดิบ/สต๊อก ปลาทับทิมถูกไฮไลต์ว่าใกล้หมด', 'วัตถุดิบใกล้หมดถูกไฮไลต์ให้เห็นก่อน'),
            ],
        },
        {
            'id': 'b2b',
            'emoji': '🥩',
            'chip': 'ขายเนื้อ · ขายส่ง',
            'role': 'แคชเชียร์ · บัญชี',
            'title': 'ชุดเคาน์เตอร์เนื้อ + ขายส่ง',
            'pain': 'มีเคาน์เตอร์ขายเนื้อกลับบ้าน และส่งของให้ร้านอื่นแบบเครดิต ต้องใช้อีกโปรแกรมกับสมุดหนี้',
            'tags': ['ขายตามน้ำหนัก', 'ตาชั่งต่อสาย', 'ฉลาก EAN-13', 'ขายเชื่อ/วางบิล'],
            'outcome': '0.485 กก. × ฿1,200 = ฿582 ไม่ต้องกดเครื่องคิดเลข',
            'headline': 'ชั่ง ขาย วางบิล เก็บหนี้ ในระบบเดียวกับหน้าร้าน',
            'problem': 'น้ำหนักจดด้วยมือ คิดราคาด้วยเครื่องคิดเลข ลูกค้าขายส่งค้างจ่ายอยู่ในสมุด '
            'ถึงเวลาทวงก็ไม่รู้ว่าบิลไหนเกินกำหนดกี่วัน',
            'features': [
                ('ขายตามน้ำหนัก อ่านจากตาชั่งสด', 'ตั้งราคาต่อกิโล ตาชั่งที่ต่อเข้าเซิร์ฟเวอร์ร้านส่งน้ำหนักขึ้นจอเอง หรือกรอกเองก็ได้ เห็นราคาก่อนใส่ตะกร้า'),
                ('สแกนฉลากตาชั่งและบาร์โค้ด', 'เครื่องสแกน USB/บลูทูธ หรือกล้องมือถือ ฉลาก EAN-13 ได้ทั้งสินค้าและน้ำหนัก อ่านผิดระบบเตือน ไม่เดา'),
                ('ขายเชื่อตามวงเงินและเครดิตเทอม', 'ยอดเกินวงเงินกดจ่ายไม่ได้ ดูยอดค้างตามอายุหนี้ ออกใบวางบิล รับชำระแล้วตัดบิลเก่าสุดก่อน'),
                ('ดอกเบี้ยผิดนัด ใบลดหนี้ PDF ภาษาไทย', 'เอกสาร PDF ยอดเป็นตัวอักษร วันที่ พ.ศ. ส่งอีเมลถึงลูกค้าได้เลย'),
                ('เงินรับชำระหนี้กระทบยอดลิ้นชัก', 'Z-report แยกยอดรับชำระหนี้ออกจากยอดขายของวัน'),
            ],
            'try': [
                'เข้าเดโม เลือก "แคชเชียร์" → ปุ่ม "สั่งกลับบ้าน/เดลิเวอรี่" → หมวดเนื้อสด',
                'แตะเนื้อวัวริบอาย — ตาชั่งจำลองส่งน้ำหนักขึ้นจอ',
                'เข้าเป็น "ผู้จัดการ" → "ลูกหนี้/ขายเชื่อ" → บริษัท โซลบาร์บีคิว จำกัด',
            ],
            'label': {
                'store': 'ครัวคุณย่า (เดโม)',
                'item': 'หมูสามชั้นสไลซ์',
                'weight': 'น้ำหนัก (กก.)',
                'per_kg': 'ราคา/กก.',
                'total': 'ราคา (บาท)',
                'aria': 'ฉลากตาชั่งตัวอย่าง: หมูสามชั้นสไลซ์ น้ำหนัก 1.250 กิโลกรัม กิโลกรัมละ 280 บาท รวม 350 บาท รหัส 2000101012504',
                'caption_html': 'ฉลากจากตาชั่งพิมพ์ฉลาก บาร์โค้ดนี้สแกนจากจอได้จริง หรือพิมพ์ <code>2000101012504</code> ลงช่องสแกนในเดโม',
            },
            'shots': [
                ('b2b-scale', 'tablet', 'กล่องชั่งเนื้อวัวริบอาย อ่านน้ำหนัก 0.485 กก. จากตาชั่ง คิดเงิน 582 บาท', 'กล่องชั่งอ่านน้ำหนักสดจากตาชั่ง'),
                ('b2b-statement', 'desktop', 'บัญชีลูกหนี้ของลูกค้าขายส่ง ยอดค้างแยกตามอายุหนี้และบิลที่เกินกำหนด', 'บัญชีลูกหนี้ แยกยอดค้างตามอายุหนี้'),
            ],
        },
        {
            'id': 'owner',
            'emoji': '📊',
            'chip': 'มองไม่เห็นภาพรวม',
            'role': 'เจ้าของร้าน',
            'title': 'ชุดเจ้าของร้านดูยอดสด',
            'pain': 'ต้องรอปิดร้านถึงรู้ยอด หลายสาขาต้องโทรถามทีละที่',
            'tags': ['แดชบอร์ดสด', 'รายงาน CSV', 'หลายสาขา', 'ถาม AI'],
            'outcome': 'รู้ยอดระหว่างวัน ไม่ต้องรอปิดกะ',
            'headline': 'ยอดวันนี้ ชั่วโมงไหนขายดี จ่ายช่องทางไหน เห็นตั้งแต่ร้านยังเปิด',
            'problem': 'เจ้าของร้านใหญ่ตัดสินใจเรื่องคนและของทุกวัน แต่ตัวเลขมาถึงตอนร้านปิดไปแล้ว '
            'หรือต้องรอสรุปจากแต่ละสาขา',
            'features': [
                ('แดชบอร์ดอัปเดตสด', 'ยอดขาย จำนวนบิล เฉลี่ยต่อบิล ส่วนลด กราฟรายชั่วโมง และสัดส่วนช่องทางชำระ'),
                ('รายงานย้อนหลัง + CSV', 'เมนูขายดี ยอดรายวัน ยอดตามหมวด ส่งออก CSV เปิดใน Excel แล้วภาษาไทยไม่เพี้ยน'),
                ('หลายสาขาในระบบเดียว', 'โต๊ะ เมนู ออเดอร์ สต๊อก รายงาน แยกตามสาขา แอดมินดูยอดรวมทุกสาขาได้ (เดโมบนเว็บมีสาขาเดียว)'),
                ('ถามยอดเป็นประโยค', 'ผู้ช่วย AI ดึงตัวเลขจากข้อมูลร้านจริงมาตอบ ดูหัวข้อถัดไป'),
            ],
            'try': [
                'เข้าเดโม เลือก "ผู้ดูแลระบบ" — หน้าแรกคือภาพรวม',
                'ไปที่ "รายงาน" เลือกช่วงวันที่ แล้วกดส่งออก CSV',
            ],
            'shots': [
                ('owner-dashboard', 'desktop', 'แดชบอร์ดภาพรวม ยอดขายวันนี้ กราฟรายชั่วโมง และสัดส่วนช่องทางชำระ', 'แดชบอร์ดยอดวันนี้ อัปเดตสดระหว่างขาย'),
            ],
        },
        {
            'id': 'loyal',
            'emoji': '🎁',
            'chip': 'ลูกค้าไม่กลับมา',
            'role': 'การตลาด · หน้าร้าน',
            'title': 'ชุดโปรโมชัน + สะสมแต้ม',
            'pain': 'ทำโปรแล้วพนักงานจำเงื่อนไขไม่ได้ ลูกค้าประจำไม่มีเหตุผลให้กลับมา',
            'tags': ['โปรมีเงื่อนไข', 'โค้ดส่วนลด', 'ซื้อ 1 แถม 1', 'แต้มสะสม'],
            'outcome': 'พนักงานไม่ต้องจำเงื่อนไขโปร',
            'headline': 'ตั้งโปรครั้งเดียว ระบบจับคู่ให้ทุกบิล ลูกค้าประจำสะสมแต้มเอง',
            'problem': 'แฮปปี้อาวร์เฉพาะบ่าย โค้ดลูกค้าใหม่ ซื้อ 1 แถม 1 เฉพาะบางเมนู พอหน้าร้านยุ่ง '
            'พนักงานลืมให้ส่วนลดบ้าง ให้ผิดโปรบ้าง',
            'features': [
                ('โปรโมชันมีเงื่อนไข', 'วันและช่วงเวลา หมวดหรือเมนูที่ร่วม ยอดขั้นต่ำ โค้ดส่วนลด ซื้อ 1 แถม 1 ระบบจับคู่ให้บิลที่เข้าเงื่อนไขเอง'),
                ('สมาชิกสะสมแต้มอัตโนมัติ', 'ค้นลูกค้าด้วยชื่อหรือเบอร์โทรตอนรับออเดอร์ ได้แต้มตามยอดซื้อ แลกเป็นส่วนลดตอนจ่าย'),
                ('ประวัติการซื้อรายคน', 'รู้ว่าลูกค้าประจำสั่งอะไร มาบ่อยแค่ไหน'),
                ('ทุกการแก้โปรมีร่องรอย', 'สร้าง แก้ ปิดโปร บันทึกในประวัติการทำรายการ'),
            ],
            'try': [
                'เข้าเดโม เลือก "ผู้ดูแลระบบ" → "โปรโมชัน" → เพิ่มโปรโมชัน',
                'ตั้งช่วงเวลาให้ครอบคลุมตอนนี้ แล้วเปิดบิลใหม่ — ส่วนลดขึ้นเอง',
                'ดูแต้มสะสมรายคนที่ "ลูกค้า/แต้มสะสม"',
            ],
            'shots': [
                ('loyal-promotions', 'desktop', 'รายการโปรโมชัน 3 แบบ: แฮปปี้อาวร์ตามช่วงเวลา โค้ดลูกค้าใหม่ และโค้ดวันหยุด', 'ตัวอย่างโปรโมชัน 3 แบบ'),
                ('loyal-customers', 'desktop', 'รายชื่อลูกค้าพร้อมแต้มสะสมของแต่ละคน', 'ลูกค้าและแต้มสะสม'),
            ],
        },
        {
            'id': 'floor',
            'emoji': '🌧',
            'chip': 'หน้างานโหด',
            'role': 'ทุกคนในร้าน',
            'title': 'ชุดหน้างานจริง',
            'pain': 'แดดส่องจอ ไอน้ำในครัว มือเปื้อน เน็ตหลุด พนักงานหลายสัญชาติ',
            'tags': ['คอนทราสต์สูง', 'เน็ตหลุดยังขายได้', '3 ภาษา', 'ใช้เครื่องที่มีอยู่'],
            'outcome': 'ป้ายสถานะคมชัด 8.77:1 อ่านออกแม้แดดส่องจอ',
            'headline': 'ออกแบบจากสภาพหน้าร้านจริง ไม่ใช่จอสะอาดในห้องประชุม',
            'problem': 'จอสวยในห้องแอร์ แต่หน้าร้านจริงมีแดดส่องจอ ไอน้ำเกาะ มือถือกระทะ Wi-Fi หลุดกลางมื้อ '
            'และพนักงานที่อ่านภาษาไทยไม่คล่อง',
            'features': [
                ('โหมดคอนทราสต์สูง', 'ป้ายสถานะในครัวคมชัด 8.77:1 (เกณฑ์ WCAG AA คือ 4.5:1) ตั้งได้จากหน้าบัญชี จำค่าไว้กับเครื่อง'),
                ('ปุ่มใหญ่สำหรับมือไม่ว่าง', 'ปุ่มเดินสถานะในครัวใหญ่กว่าบนมือถือเกือบเท่าตัว'),
                ('เน็ตหลุดยังรับออเดอร์ได้', 'เก็บไว้ในเครื่องแล้วซิงค์เองเมื่อเน็ตกลับ จอครัวเตือนเต็มจอและดึงตั๋วสำรองทุก 30 วินาที'),
                ('ไทย · English · 한국어', 'สลับภาษาได้ทุกเครื่อง ชื่อเมนูเปลี่ยนตามภาษาที่เลือก'),
                ('มือถือ แท็บเล็ต คอมพิวเตอร์ ระบบเดียว', 'ใช้เครื่องที่ร้านมีอยู่ ไม่ต้องซื้อฮาร์ดแวร์เฉพาะยี่ห้อ'),
            ],
            'try': [
                'เข้าเดโมด้วยบทบาทใดก็ได้ แล้วไปที่ "บัญชี"',
                'ตั้ง "ความคมชัดของหน้าจอ" เป็น "สูง" และลองสลับภาษา',
            ],
            'shots': [
                ('floor-contrast', 'tablet', 'จอครัวในโหมดคอนทราสต์สูง ปุ่มและป้ายสถานะสีเข้มอ่านชัด', 'จอครัวโหมดคอนทราสต์สูง'),
            ],
        },
    ],
    'ai': {
        'kick': 'เมนูพิเศษของเชฟ',
        'title': 'ถามยอดขายเป็นประโยค ได้คำตอบจากข้อมูลร้านจริง',
        'text': 'พิมพ์ถามภาษาไทย อังกฤษ หรือเกาหลี ผู้ช่วย AI (ขับเคลื่อนด้วย Claude) เรียกเครื่องมือที่ต่อกับฐานข้อมูลร้าน '
        'เพื่อดึงตัวเลขมาตอบ ไม่ได้เดาจากความรู้ทั่วไปของโมเดล',
        'points': [
            ('🔎', 'ทุกคำตอบมีที่มา', 'ชิป "แหล่งข้อมูล" บอกว่าใช้เครื่องมือไหนตอบ ตรวจสอบย้อนกลับได้'),
            ('🙅', 'ไม่มีข้อมูลก็บอกว่าไม่มี', 'ห้ามแต่งตัวเลขเองเมื่อคำถามอยู่นอกข้อมูลที่ระบบมี'),
            ('🔐', 'เฉพาะเจ้าของร้านและผู้จัดการ', 'จำกัดจำนวนคำถามต่อวันเพื่อคุมค่าใช้จ่าย'),
        ],
        'alt': 'ภาพเคลื่อนไหวผู้ช่วย AI ตอบคำถามยอดขายพร้อมกราฟและชิปแหล่งข้อมูล',
        'caption': 'บันทึกจากการเรียก Claude API จริงครั้งเดียว — เดโมบนเว็บปิดผู้ช่วย AI ไว้เพราะไม่มี API key',
    },
    'standards': {
        'kick': 'มาตรฐานครัวหลังบ้าน',
        'title': 'สะอาดตั้งแต่ในครัว ไม่ใช่แค่หน้าร้าน',
        'sub': 'ระบบที่แตะเงินและข้อมูลลูกค้าต้องตรวจสอบได้ทุกชั้น',
        'items': [
            ('✅', '{tests} เทสต์อัตโนมัติ', 'ตั้งแต่กฎคิดเงิน ไปจนถึงแอปจริงคุยกับเซิร์ฟเวอร์จริงทั้งวันทำการ'),
            ('🛡', 'ตรวจ OWASP Top 10', 'พบ 7 จุด แก้ครบทุกจุด ค่าเริ่มต้นเป็นแบบปิดไว้ก่อน'),
            ('👥', 'สิทธิ์ 5 บทบาท', 'บังคับที่เซิร์ฟเวอร์ ปิดบัญชีหรือเปลี่ยนสิทธิ์แล้วมีผลทันที'),
            ('🏠', 'ข้อมูลอยู่ในร้านคุณ', 'รันบนเครื่องในร้าน ยอดขายและข้อมูลลูกค้าไม่ถูกส่งขึ้นเซิร์ฟเวอร์ของใคร'),
            ('📖', 'โอเพนซอร์ส Apache-2.0', 'ใช้เชิงพาณิชย์ แก้ไข และแจกจ่ายต่อได้'),
            ('📸', 'ภาพจากแอปจริง', 'ภาพหน้าจอทุกภาพในหน้านี้ถ่ายด้วย golden test ไม่ใช่ภาพจำลอง'),
        ],
    },
    'checkout': {
        'kick': 'ราคา',
        'title': 'สรุปตะกร้าของคุณ',
        'sub': 'ใช้ฟรี และจะไม่มีแพ็กเกจรายเดือนตามมาทีหลัง เพราะระบบไม่ได้รันบนเซิร์ฟเวอร์ของเราตั้งแต่แรก',
        'cart_title': 'ตะกร้า',
        'shop': 'ร้าน: ของคุณ · สาขา: กี่สาขาก็ได้',
        'lines': [
            ('PaynEat POS · ทุกฟีเจอร์ในหน้านี้', 'Apache License 2.0 · ใช้เชิงพาณิชย์ได้', '฿0.00'),
            ('ค่าเช่ารายเดือน', 'ติดตั้งครั้งเดียว รันในร้านของคุณเอง', '฿0.00'),
            ('เพิ่มเครื่อง เพิ่มสาขา', 'มือถือ แท็บเล็ต เพิ่มได้ไม่จำกัด', '฿0.00'),
            ('ฮาร์ดแวร์เฉพาะยี่ห้อ', 'ใช้เครื่องที่ร้านมีอยู่แล้ว', 'ไม่ต้องซื้อ'),
            ('VAT 7%', '', '฿0.00'),
        ],
        'total': 'รวมทั้งสิ้น',
        'pay': 'ชำระ ฿0.00 — เปิดเดโม →',
        'thanks': 'ขอบคุณที่อุดหนุน 🙏',
        'options_title': 'เลือกวิธีรับ',
        'options': [
            ('demo', '🖥', 'ลองในเบราว์เซอร์', 'เดโมเต็มระบบ ข้อมูลร้านสมมติ เลือกบทบาทแล้วเข้าได้เลย', 'app/'),
            ('docker', '🐳', 'ติดตั้งบนเครื่องของคุณ', 'Windows บรรทัดเดียว หรือ Docker ให้ทุกเครื่องในร้านใช้ร่วมกัน — ทำตามทีละขั้น', 'install.html'),
            ('src', '🏪', 'ใช้จริงในร้าน', 'เซิร์ฟเวอร์อยู่ในร้าน ดูสิ่งที่ต้องตั้งค่าก่อนใช้งานจริง', 'install.html#live'),
            ('erp', '🏭', 'มีครัวกลางหรือคลังหลายสาขา?', 'PaynEat ERP (อยู่ระหว่างพัฒนา) เชื่อมกับ POS แบบเลือกได้', ERP),
        ],
        'note_html': 'สนใจนำไปใช้หรืออยากถามอะไร <a href="https://github.com/SuruchBoss/PaynEat/issues">ถามผ่าน GitHub Issues</a> '
        'หรือ <a href="https://www.linkedin.com/in/suruchboss">LinkedIn</a>',
    },
    'footer': {
        'paras_html': [
            'PaynEat POS — Flutter (GetX) + Node.js/Express + SQLite · เผยแพร่ภายใต้ '
            '<a href="https://github.com/SuruchBoss/PaynEat/blob/main/LICENSE">Apache License 2.0</a>',
            'ภาพหน้าจอทุกภาพถ่ายจากแอปจริงด้วย golden test ยกเว้นภาพผู้ช่วย AI ที่บันทึกจากการเรียก Claude API จริง '
            '(<a href="https://github.com/SuruchBoss/PaynEat/blob/main/docs/DECISIONS.md">docs/DECISIONS.md</a> #33, #70)',
            'ร้าน ลูกค้า และเมนูในเดโมเป็นข้อมูลสมมติทั้งหมด',
        ],
        'links_title': 'เกี่ยวกับโปรเจกต์',
        'links': [
            ('ดูโค้ดบน GitHub', REPO),
            ('คู่มือติดตั้ง', 'install.html'),
            ('ความปลอดภัย (SECURITY.md)', f'{REPO}/blob/main/SECURITY.md'),
            ('บันทึกการตัดสินใจ', f'{REPO}/blob/main/docs/DECISIONS.md'),
            ('PaynEat ERP', ERP),
        ],
        'contact': {
            'title': 'ติดต่อผู้สร้าง',
            'lead': 'อยากนำไปใช้ในร้าน อยากได้ฟีเจอร์เพิ่ม หรือติดตั้งไม่ผ่าน — ทักมาได้เลย',
            'items': [
                ('mail', 'อีเมล', 'bossxiii@gmail.com', EMAIL),
                ('linkedin', 'LinkedIn', 'linkedin.com/in/suruchboss', LINKEDIN),
                ('issues', 'GitHub Issues', 'ถามหรือแจ้งปัญหาแบบสาธารณะ', f'{REPO}/issues'),
            ],
        },
    },
    'readme': {
        'file': 'README.md',
        'title': '🍽 เมนูแก้ปัญหาร้านอาหาร',
        'intro': 'ทุกข้อคือปัญหาที่ร้านอาหารขนาดใหญ่เจอจริงทุกวัน และแต่ละข้อแก้ด้วย**หลายฟีเจอร์ที่ทำงานต่อกัน** ไม่ใช่ปุ่มเดียว '
        '— ทั้งหมดผ่านเทสต์อัตโนมัติ {tests} เคสก่อนปล่อย ภาพทุกภาพถ่ายจากแอปจริงด้วย golden test '
        '([`story_test.dart`](app/tool/screenshots/story_test.dart)) ลองกดเองได้ที่ **[เดโมบนเว็บ](https://suruchboss.github.io/PaynEat/app/)** '
        'หรืออ่านแบบหน้าเว็บที่ **[หน้า Landing](https://suruchboss.github.io/PaynEat/)**',
        'cols': ('ปัญหาของร้าน', 'ชุดที่แก้', 'ได้อะไร'),
        'label_note': '> 🏷 ฉลากตาชั่งของเดโม `2000101012504` (หมูสามชั้นสไลซ์ 1.250 กก. × 280 = 350 บาท) — พิมพ์หรือยิงสแกนเข้าช่องสแกนในเดโมได้เลย '
        'หน้า Landing วาดบาร์โค้ดนี้เป็น EAN-13 จริงที่สแกนจากจอได้',
    },
    'mcart': {'label': 'ตะกร้า', 'sub': '฿0.00 · ฟรีทุกฟีเจอร์', 'cta': 'เปิดเดโม'},
}

EN = {
    'code': 'en',
    'file': 'index.en.html',
    'shot': 'en',
    'og_image': 'og-image-en.png',
    'title': 'PaynEat POS — point of sale for big, busy restaurants',
    'description': 'A restaurant POS built around the problems of a busy floor: order overload, short staff, slow payment, '
    'cash leakage, stock-outs and owners who cannot see the day. Open source, free, try the demo now.',
    'skip': 'Skip to the problem menu',
    'promo': 'The full demo runs in your browser · no sign-up · a fictional restaurant ready to tap',
    'promo_link': 'Try it →',
    'nav_label': 'Main menu',
    'lang_label': 'Choose language',
    'nav': [('#menu', 'Problem menu'), ('#stories', 'Real screens'), ('#ai', 'AI assistant'), ('#checkout', 'Pricing'), ('install.en.html', 'Install')],
    'cart': 'Open demo',
    'nav_install_short': 'Install',
    'hero': {
        'eyebrow': '🍽 POS for big restaurants · open source',
        'title_html': 'Full house?<br><em>Served on time.</em><br>Every baht counted.',
        'lead': 'From guests ordering by QR at the table, a kitchen screen that queues for you and PromptPay at the bill, '
        'to a shift that closes with the cash matching — one system designed from the real problems of Thai restaurants '
        'at their busiest.',
        'cta': 'Open the demo →',
        'cta2': 'See the problem menu',
        'facts': [
            ('⏱', 'Ready in 0 min', 'The demo opens in your browser, no sign-up'),
            ('🛵', '฿0 rent', 'No monthly plan'),
            ('✅', '{tests} tests', 'Automated, before every release'),
            ('🌐', '3 languages', 'ไทย · English · 한국어'),
        ],
        'floats': [
            ('🔔', 'Table A1 · waiting 18 min', 'The kitchen screen warns by itself'),
            ('✅', 'PromptPay ฿476.69', 'QR carries the real bill total'),
        ],
    },
    'picker': {
        'kick': 'Pick your symptom',
        'title': 'Where does your restaurant hurt?',
        'sub': 'Tap a problem and see what the system serves for it — each one is several features working together.',
    },
    'menu': {
        'kick': 'House recommendations',
        'title': 'Nine sets that fix real problems',
        'sub': 'Chosen from what big restaurants face every day. Every picture is taken from the real app, not a mock-up.',
    },
    'labels': {
        'tags': 'Ingredients',
        'outcome': 'What you get',
        'more': 'See details',
        'problem': 'The problem',
        'inside': 'In this set',
        'try': 'Taste it in the demo',
        'open_demo': 'Open the demo →',
    },
    'stories_head': {
        'kick': 'One dish at a time',
        'title': 'Old problem, new fix, real screens',
        'sub': 'Each set says what it fixes, with which features, and where to try it in the demo.',
    },
    'stories': [
        {
            'id': 'rush',
            'emoji': '🔥',
            'chip': 'Order overload',
            'role': 'Floor · Kitchen',
            'title': 'The rush-hour set',
            'pain': '7 pm, every table full, paper tickets piling up in the kitchen, the longest wait forgotten.',
            'tags': ['Table map', 'Live kitchen screen', '15-minute alert', 'Takeaway queue numbers'],
            'outcome': 'The longest wait is always on top',
            'headline': 'However full the house, the kitchen knows what to cook first',
            'problem': 'At peak, staff run paper tickets to the kitchen. Tickets get lost, handwriting is unreadable, and cooks '
            'work in the order they pick tickets up, not the order guests have waited — so the longest-waiting table is forgotten.',
            'features': [
                ('A colour-coded table map', 'Free, seated, the running bill on each table, grouped by indoor and window zones.'),
                ('Orders with options and notes', 'Medium spicy, fried egg, no vegetables — it reaches the kitchen complete, no shouting.'),
                ('A live three-column kitchen screen', 'To cook → cooking → ready. The oldest ticket is on top, and anything past 15 minutes turns red by itself.'),
                ('Dine-in, takeaway and delivery icons', 'Takeaway orders get a daily queue number automatically.'),
                ('Undo a wrong tap', 'An "Undo" bar for 8 seconds after each status change, no manager needed.'),
            ],
            'try': [
                'Open the demo and choose "Waiter"',
                'Tap a free table, pick dishes and send them to the kitchen',
                'Sign out and choose "Kitchen" — the new ticket is in the "to cook" column',
            ],
            'shots': [
                ('rush-kitchen', 'tablet', 'Kitchen screen on a tablet: the table A1 ticket has waited 18 minutes and is flagged red', 'Kitchen screen: tickets past 15 minutes warn by themselves'),
                ('rush-tables', 'phone', "Table map on a waiter's phone, free tables separate from seated ones", "Table map on a waiter's phone"),
            ],
        },
        {
            'id': 'staff',
            'emoji': '🙋',
            'chip': 'Short-staffed',
            'role': 'Guests · Floor',
            'title': 'The self-order set',
            'pain': 'Waiters are hard to hire, guests raise a hand to order and wait.',
            'tags': ['QR on every table', 'No login', 'Straight to the kitchen', 'Same stock deduction'],
            'outcome': 'Guests order the moment they sit down',
            'headline': 'Guests order from their own phones, staff do the work that needs a person',
            'problem': 'Big restaurants are short of waiters almost every shift. Guests wait for a menu, for someone to take '
            'the order, for someone to add more — and every minute of waiting is a table turning slower.',
            'features': [
                ('Scan the table QR and order', 'Opens in the phone browser. No app to install, no sign-up or login.'),
                ('The same path as a staff order', 'Reaches the kitchen screen and deducts ingredient stock exactly the same way. No second system to reconcile.'),
                ("Guests see their table's order", 'Add more at any time and see what has been ordered so far.'),
                ('Broken links say so', 'A wrong QR or a deactivated table tells the guest it cannot be used. No stray orders reach the kitchen.'),
                ('Managers can replace a QR', 'Long-press a table on the map to show its QR, copy the link, or issue a new QR in place of the old one.'),
            ],
            'try': [
                'Open the demo, choose "Manager" and go to Tables',
                'Long-press any table → "View self-order QR" → "Copy link"',
                'Open the link in a new tab and order as a guest',
            ],
            'shots': [
                ('staff-self-order', 'phone', "The menu a guest sees on their phone after scanning table A1's QR", 'What guests see after scanning the QR'),
            ],
        },
        {
            'id': 'pay',
            'emoji': '💸',
            'chip': 'Slow payment',
            'role': 'Cashier',
            'title': 'The fast-bill set',
            'pain': 'A long queue to pay, a big table wants to split, everyone doing sums.',
            'tags': ['PromptPay QR', 'Split/merge bills', 'Thai receipts', 'Tax invoices'],
            'outcome': 'The QR matches the bill to the satang',
            'headline': 'Scan to pay the real total, and split a whole table in a few taps',
            'problem': 'The cashier types the transfer amount by hand — one wrong digit and someone chases a refund. Friends '
            'want to pay their own share, and discounts and service charge get divided at the counter.',
            'features': [
                ('PromptPay QR to the EMV standard', 'The bill total is inside the QR. Guests scan with any banking app, nobody types an amount.'),
                ('Split by payment method or by item', 'Cash, QR and card on one bill, with discount, service charge and VAT shared out proportionally.'),
                ('Move and merge tables', 'When guests change seats or join tables, their orders follow.'),
                ('Thai receipts on thermal printers', 'ESC/POS on 58 mm and 80 mm paper, over the same LAN or Wi-Fi.'),
                ('Abbreviated tax invoices', 'Numbered by the Thai Buddhist-era year, voidable while keeping the history.'),
            ],
            'try': [
                'Open the demo and choose "Cashier"',
                'Tap a seated table and take payment',
                'Choose "PromptPay / QR" — the QR is built from that bill at once',
            ],
            'shots': [
                ('pay-promptpay', 'phone', "Checkout on a phone with PromptPay selected, showing a QR for table C1's total", 'A PromptPay QR for the bill total'),
            ],
        },
        {
            'id': 'cash',
            'emoji': '🔒',
            'chip': 'Cash leakage',
            'role': 'Manager · Owner',
            'title': 'The honest-drawer set',
            'pain': 'The drawer does not match at closing, and nobody knows where the money went or who.',
            'tags': ['Open and close shifts', 'Z-report', 'Tamper-proof history', 'Five roles'],
            'outcome': 'Even 40 baht short shows at shift close',
            'headline': 'Every baht in the drawer traces back to where it came from and who touched it',
            'problem': 'Bills voided after payment, discounts beyond someone\'s authority, refunds with no reason. In a big '
            'restaurant many hands touch the cash, and when the total is off there is no evidence of what happened.',
            'features': [
                ('No payment without an open shift', 'Starting float on opening; every payment is tied to the open shift.'),
                ('Instant reconciliation at close', 'Count the cash; the system works out what should be there and the difference.'),
                ('Z-report per shift and per day', 'Sales, tax, manual discounts apart from promotions, payment methods, debt collected. Export CSV for accounting.'),
                ('A history nobody can edit', 'Voids, discounts, refunds, price edits and permission changes, with who, when and why — every time.'),
                ('Five roles, enforced on the server', 'Not just hidden buttons: a direct request is refused too.'),
            ],
            'try': [
                'Open the demo, choose "Manager" and open "Shift"',
                'Press "Close shift" and enter a count a little short, then tap that shift in the history to see its Z-report',
                'Sign in again as "Admin" → "Audit Log"',
            ],
            'shots': [
                ('cash-zreport', 'desktop', 'The shift Z-report with sales, discounts, payment methods and the cash difference', 'The Z-report of a shift counted 40 baht short'),
                ('cash-audit', 'desktop', 'The audit log showing who did what and when, with type filters', 'Audit log: who did what, and when'),
            ],
        },
        {
            'id': 'stock',
            'emoji': '📦',
            'chip': 'Stock-outs',
            'role': 'Kitchen · Manager',
            'title': 'The never-run-out set',
            'pain': 'The guest has ordered; only then does the kitchen say it is sold out.',
            'tags': ['Automatic deduction', 'Auto sold-out', 'Low-stock alert'],
            'outcome': 'Nobody has to switch dishes off by hand',
            'headline': 'When an ingredient runs out, the dish stops selling before anyone orders it',
            'problem': 'The fish ran out at 8 pm but the dish is still on sale. Staff take three orders before the kitchen '
            'says so — wasted time and disappointed guests.',
            'features': [
                ('Dishes linked to ingredients', 'Stock is deducted when a dish goes to the kitchen and returned on a void or removal, in the units the kitchen counts in.'),
                ('Sold out means off sale', 'When an ingredient is short, its dishes stop selling at once and come back after a restock.'),
                ('Low-stock alerts', 'A threshold per ingredient, and a filter for only what is running low before you open.'),
                ('Works with QR self-order too', 'Guest orders deduct stock along the same path.'),
            ],
            'try': [
                'Open the demo, choose "Admin" → "Ingredients/Stock"',
                'Press "Low stock only" — red tilapia is already set below its threshold',
                'Set the tilapia stock to zero and watch the dish that uses it go off sale',
            ],
            'shots': [
                ('stock-ingredients', 'desktop', 'Ingredients/Stock with red tilapia highlighted as low stock', 'Low-stock ingredients are highlighted first'),
            ],
        },
        {
            'id': 'b2b',
            'emoji': '🥩',
            'chip': 'Butcher & wholesale',
            'role': 'Cashier · Accounts',
            'title': 'The butcher-counter + wholesale set',
            'pain': 'A take-home meat counter and credit sales to other restaurants mean another program and a debt notebook.',
            'tags': ['Sell by weight', 'Connected scale', 'EAN-13 labels', 'Credit sales/billing'],
            'outcome': '0.485 kg × ฿1,200 = ฿582, no calculator',
            'headline': 'Weigh, sell, bill and collect — in the same system as the floor',
            'problem': 'Weights are written by hand and priced on a calculator. Wholesale debts live in a notebook, and when '
            'it is time to chase them nobody knows which bill is how many days overdue.',
            'features': [
                ('Sell by weight, read live from the scale', 'Price per kilo. A scale connected to the shop server sends the weight to the screen, or type it; see the price before it goes in the cart.'),
                ('Scan scale labels and barcodes', 'USB or Bluetooth scanners, or the phone camera. EAN-13 labels carry item and weight together; a misread is flagged, never guessed.'),
                ('Credit within a limit and a term', 'Over the limit cannot be charged. Aged balances, billing notes, and payments that settle the oldest bill first.'),
                ('Late fees and credit notes as Thai PDFs', 'Amounts in words, Buddhist-era dates, and email to the customer directly.'),
                ('Debt collected reconciles with the drawer', 'The Z-report shows debt collected apart from the day\'s sales.'),
            ],
            'try': [
                'Open the demo, choose "Cashier" → "New takeaway/delivery" → Fresh Meat & Take-home',
                'Tap Beef Ribeye — the simulated scale sends a weight to the screen',
                'Sign in as "Manager" → "Receivables" → the wholesale customer Soul BBQ Co., Ltd.',
            ],
            'label': {
                'store': "Grandma's Kitchen (Demo)",
                'item': 'Sliced Pork Belly',
                'weight': 'Net wt (kg)',
                'per_kg': 'Price/kg',
                'total': 'Total (฿)',
                'aria': 'Sample scale label: Sliced Pork Belly, 1.250 kg at ฿280 per kg, total ฿350, code 2000101012504',
                'caption_html': 'A label from a label-printing scale. The barcode really scans off the screen, or type <code>2000101012504</code> into the demo\u2019s scan box.',
            },
            'shots': [
                ('b2b-scale', 'tablet', 'Weighing beef ribeye: 0.485 kg read from the scale, priced at 582 baht', 'The weight box reads the scale live'),
                ('b2b-statement', 'desktop', 'A wholesale customer statement with balances aged by due date and overdue bills', 'Receivables aged by due date'),
            ],
        },
        {
            'id': 'owner',
            'emoji': '📊',
            'chip': 'No overview',
            'role': 'Owner',
            'title': 'The live-numbers set',
            'pain': 'The owner learns the takings after closing, and phones each branch to ask.',
            'tags': ['Live dashboard', 'CSV reports', 'Multi-branch', 'Ask the AI'],
            'outcome': 'Know the day while it is happening',
            'headline': 'Today\'s sales, the busy hours and how people pay — while the doors are still open',
            'problem': 'Owners of big restaurants decide about people and stock every day, but the numbers arrive after closing, '
            'or wait on a summary from each branch.',
            'features': [
                ('A live dashboard', 'Sales, bill count, average bill, discounts, an hourly chart and the payment-method split.'),
                ('History reports + CSV', 'Best sellers, daily and per-category sales. CSV exports open in Excel with Thai intact.'),
                ('Many branches in one system', 'Tables, menus, orders, stock and reports per branch; admins can see all branches together (the web demo has one branch).'),
                ('Ask in a sentence', 'The AI assistant answers from the shop\'s real data — see the next section.'),
            ],
            'try': [
                'Open the demo and choose "Admin" — the first screen is the Overview',
                'Go to "Reports", pick a date range and export a CSV',
            ],
            'shots': [
                ('owner-dashboard', 'desktop', "Overview dashboard with today's sales, an hourly chart and the payment-method split", "Today's dashboard, live while you sell"),
            ],
        },
        {
            'id': 'loyal',
            'emoji': '🎁',
            'chip': 'Guests not returning',
            'role': 'Marketing · Floor',
            'title': 'The promotions + loyalty set',
            'pain': 'Staff forget promotion rules, and regulars have no reason to come back.',
            'tags': ['Conditional promotions', 'Discount codes', 'Buy 1 get 1', 'Loyalty points'],
            'outcome': 'Staff never memorise a promotion',
            'headline': 'Set a promotion once and every bill is matched; regulars collect points by themselves',
            'problem': 'An afternoon happy hour, a welcome code, buy-one-get-one on some dishes — and when the floor is busy '
            'staff forget a discount or apply the wrong one.',
            'features': [
                ('Conditional promotions', 'Days and hours, categories or dishes, a minimum spend, discount codes, buy one get one — matched to qualifying bills automatically.'),
                ('Automatic loyalty points', 'Find the guest by name or phone when taking the order; points by spend, redeemed as a discount at payment.'),
                ('Purchase history per guest', 'What your regulars order and how often they come.'),
                ('Every promotion change is traced', 'Creating, editing and switching off promotions is recorded in the audit log.'),
            ],
            'try': [
                'Open the demo, choose "Admin" → "Promotions" → add a promotion',
                'Cover the current time, then open a new bill — the discount appears by itself',
                'See each guest\'s points under "Customers/Loyalty"',
            ],
            'shots': [
                ('loyal-promotions', 'desktop', 'Three promotions: an afternoon happy hour, a welcome code and a weekend code', 'Three kinds of promotion'),
                ('loyal-customers', 'desktop', 'Customer list with each guest\'s loyalty points', 'Customers and their points'),
            ],
        },
        {
            'id': 'floor',
            'emoji': '🌧',
            'chip': 'Tough floor',
            'role': 'Everyone',
            'title': 'The real-floor set',
            'pain': 'Sun on the screen, steam in the kitchen, greasy hands, dropped Wi-Fi, staff of many nationalities.',
            'tags': ['High contrast', 'Works offline', '3 languages', 'Any device'],
            'outcome': 'Status labels at 8.77:1, readable in sunlight',
            'headline': 'Designed for the real floor, not a clean screen in a meeting room',
            'problem': 'Screens look good in an air-conditioned office. The real floor has sun on the glass, steam, a hand '
            'holding a wok, Wi-Fi dropping mid-service and staff who do not read Thai fluently.',
            'features': [
                ('High-contrast mode', 'Kitchen status labels at 8.77:1 (WCAG AA asks for 4.5:1). Set it on the Profile screen; each device remembers it.'),
                ('Big buttons for busy hands', 'Kitchen status buttons are almost twice the size of the phone ones.'),
                ('Keeps taking orders offline', 'Held on the device and synced when the network returns; the kitchen screen shows a full-width warning and polls for tickets every 30 seconds.'),
                ('ไทย · English · 한국어', 'Each device picks its language, and dish names follow it.'),
                ('Phone, tablet and computer, one system', 'Use the devices you already own — no brand-specific hardware.'),
            ],
            'try': [
                'Open the demo with any role and go to "Profile"',
                'Set "Screen contrast" to "High" and try switching language',
            ],
            'shots': [
                ('floor-contrast', 'tablet', 'The kitchen screen in high-contrast mode, with darker buttons and labels', 'Kitchen screen in high-contrast mode'),
            ],
        },
    ],
    'ai': {
        'kick': "Chef's special",
        'title': 'Ask about sales in a sentence, get answers from real shop data',
        'text': 'Ask in Thai, English or Korean. The AI assistant (powered by Claude) calls tools wired to the shop database '
        'to fetch the numbers — it does not guess from the model\'s general knowledge.',
        'points': [
            ('🔎', 'Every answer has a source.', 'A "Sources" chip names the tool behind it, so it can be checked.'),
            ('🙅', 'No data, no made-up numbers.', 'It says so when a question falls outside what the system holds.'),
            ('🔐', 'Owners and managers only.', 'A daily question limit keeps the cost in check.'),
        ],
        'alt': 'Animation of the AI assistant answering a sales question with a chart and source chips',
        'caption': 'Recorded once from real Claude API calls, in Thai. The web demo has the AI assistant switched off because it has no API key.',
    },
    'standards': {
        'kick': 'Back-of-house standards',
        'title': 'Clean in the kitchen, not just out front',
        'sub': 'A system that handles money and customer data has to be checkable at every layer.',
        'items': [
            ('✅', '{tests} automated tests', 'From pricing rules to the real app talking to the real server through a whole business day.'),
            ('🛡', 'OWASP Top 10 reviewed', 'Seven findings, all fixed, with safe defaults switched on.'),
            ('👥', 'Five roles', 'Enforced on the server. A disabled account or a role change takes effect at once.'),
            ('🏠', 'Your data stays in your shop', 'Runs on a machine in the restaurant; sales and customer data go to nobody\'s server.'),
            ('📖', 'Open source, Apache-2.0', 'Use it commercially, change it and redistribute it.'),
            ('📸', 'Real screenshots', 'Every screen on this page is captured from the app by golden tests, not mocked up.'),
        ],
    },
    'checkout': {
        'kick': 'Pricing',
        'title': 'Your basket',
        'sub': 'Free to use, and no monthly plan will follow later — the system never ran on our servers in the first place.',
        'cart_title': 'Basket',
        'shop': 'Restaurant: yours · Branches: as many as you like',
        'lines': [
            ('PaynEat POS · every feature on this page', 'Apache License 2.0 · commercial use allowed', '฿0.00'),
            ('Monthly rent', 'Install once, run it in your own restaurant', '฿0.00'),
            ('Extra devices and branches', 'Add as many phones and tablets as you need', '฿0.00'),
            ('Brand-specific hardware', 'Use the devices you already have', 'Not needed'),
            ('VAT 7%', '', '฿0.00'),
        ],
        'total': 'Total',
        'pay': 'Pay ฿0.00 — open the demo →',
        'thanks': 'Thank you for your order 🙏',
        'options_title': 'Choose how to get it',
        'options': [
            ('demo', '🖥', 'Try it in the browser', 'The full demo with a fictional restaurant — pick a role and go.', 'app/'),
            ('docker', '🐳', 'Install it on your own machine', 'One line on Windows, or Docker so every device in the restaurant shares it — step by step.', 'install.en.html'),
            ('src', '🏪', 'Run it in your restaurant', 'The server lives in your shop. See what to configure before going live.', 'install.en.html#live'),
            ('erp', '🏭', 'A central kitchen or multi-branch stock?', 'PaynEat ERP (in development) connects to the POS if you choose.', ERP),
        ],
        'note_html': 'Want to use it or have a question? <a href="https://github.com/SuruchBoss/PaynEat/issues">Ask on GitHub Issues</a> '
        'or <a href="https://www.linkedin.com/in/suruchboss">LinkedIn</a>.',
    },
    'footer': {
        'paras_html': [
            'PaynEat POS — Flutter (GetX) + Node.js/Express + SQLite · released under the '
            '<a href="https://github.com/SuruchBoss/PaynEat/blob/main/LICENSE">Apache License 2.0</a>',
            'Every screenshot is captured from the real app by golden tests, except the AI assistant animation, recorded from '
            'real Claude API calls (<a href="https://github.com/SuruchBoss/PaynEat/blob/main/docs/DECISIONS.md">docs/DECISIONS.md</a> #33, #70).',
            'The restaurant, customers and menu in the demo are fictional.',
        ],
        'links_title': 'The project',
        'links': [
            ('Code on GitHub', REPO),
            ('Install guide', 'install.en.html'),
            ('Security (SECURITY.md)', f'{REPO}/blob/main/SECURITY.md'),
            ('Design decisions', f'{REPO}/blob/main/docs/DECISIONS.md'),
            ('PaynEat ERP', ERP),
        ],
        'contact': {
            'title': 'Get in touch',
            'lead': 'Want it in your restaurant, need a feature, or stuck installing? Reach out.',
            'items': [
                ('mail', 'Email', 'bossxiii@gmail.com', EMAIL),
                ('linkedin', 'LinkedIn', 'linkedin.com/in/suruchboss', LINKEDIN),
                ('issues', 'GitHub Issues', 'Ask or report in public', f'{REPO}/issues'),
            ],
        },
    },
    'readme': {
        'file': 'README.en.md',
        'title': '🍽 The problem menu',
        'intro': 'Each item is a problem big restaurants really face every day, and each is fixed by **several features working together**, '
        'not a single button — all behind {tests} automated tests. Every picture is captured from the real app by golden tests '
        '([`story_test.dart`](app/tool/screenshots/story_test.dart)). Try it yourself in the **[web demo](https://suruchboss.github.io/PaynEat/app/)** '
        'or read it as a web page on the **[landing page](https://suruchboss.github.io/PaynEat/index.en.html)**.',
        'cols': ("The restaurant's problem", 'The set that fixes it', 'What you get'),
        'label_note': "> 🏷 The demo's scale label `2000101012504` (sliced pork belly, 1.250 kg × 280 = 350 baht) — type or scan it into the demo's "
        'scan box. The landing page draws it as a genuine EAN-13 barcode that scans off the screen.',
    },
    'mcart': {'label': 'Basket', 'sub': '฿0.00 · every feature free', 'cta': 'Open demo'},
}

KO = {
    'code': 'ko',
    'file': 'index.ko.html',
    'shot': 'ko',
    'og_image': 'og-image-ko.png',
    'title': 'PaynEat POS — 대형 식당을 위한 POS',
    'description': '주문 폭주, 일손 부족, 느린 결제, 현금 누수, 재료 품절, 한눈에 보이지 않는 매출 — 바쁜 식당의 실제 문제에서 '
    '출발한 POS. 오픈소스, 무료, 지금 바로 데모를 열어 보세요.',
    'skip': '문제 해결 메뉴로 건너뛰기',
    'promo': '브라우저에서 바로 여는 전체 데모 · 가입 불필요 · 가상의 식당 데이터가 준비되어 있어요',
    'promo_link': '열어 보기 →',
    'nav_label': '주 메뉴',
    'lang_label': '언어 선택',
    'nav': [('#menu', '문제 해결 메뉴'), ('#stories', '실제 화면'), ('#ai', 'AI 어시스턴트'), ('#checkout', '가격'), ('install.ko.html', '설치 방법')],
    'cart': '데모 열기',
    'nav_install_short': '설치',
    'hero': {
        'eyebrow': '🍽 대형 식당을 위한 POS · 오픈소스',
        'title_html': '만석이어도<br><em>제때 서빙</em>,<br>현금은 한 푼도 새지 않게',
        'lead': '손님이 테이블 QR로 직접 주문하고, 주방 화면이 순서를 정리하고, 프롬프트페이로 결제하고, 근무 마감 때 현금이 딱 맞기까지 '
        '— 가장 바쁜 시간대 태국 식당의 실제 문제에서 출발해 설계한 하나의 시스템입니다.',
        'cta': '데모 바로 열기 →',
        'cta2': '문제 해결 메뉴 보기',
        'facts': [
            ('⏱', '준비 시간 0분', '브라우저에서 바로, 가입 없이'),
            ('🛵', '월 이용료 ฿0', '월 구독 요금제 없음'),
            ('✅', '테스트 {tests}개', '배포 전마다 자동 테스트'),
            ('🌐', '3개 언어', 'ไทย · English · 한국어'),
        ],
        'floats': [
            ('🔔', '테이블 A1 · 18분 대기', '주방 화면이 알아서 경고'),
            ('✅', '프롬프트페이 ฿476.69', '계산서 금액 그대로 QR에'),
        ],
    },
    'picker': {
        'kick': '증상별로 고르기',
        'title': '우리 가게, 어디가 아프세요?',
        'sub': '겪고 있는 문제를 누르면 시스템이 무엇을 내놓는지 보여 드려요. 각 항목은 함께 움직이는 여러 기능의 묶음입니다.',
    },
    'menu': {
        'kick': '오늘의 추천 메뉴',
        'title': '문제를 해결하는 9가지 세트',
        'sub': '대형 식당이 매일 겪는 문제에서 골랐습니다. 모든 이미지는 목업이 아니라 실제 앱에서 캡처했어요.',
    },
    'labels': {
        'tags': '구성',
        'outcome': '얻는 것',
        'more': '자세히 보기',
        'problem': '가게가 겪는 문제',
        'inside': '이 세트에 들어 있는 것',
        'try': '데모에서 맛보기',
        'open_demo': '데모 열기 →',
    },
    'stories_head': {
        'kick': '한 접시씩 자세히',
        'title': '익숙한 문제, 새로운 해결, 실제 화면',
        'sub': '세트마다 무엇을, 어떤 기능으로 해결하는지, 데모 어디서 눌러 볼 수 있는지 알려 드려요.',
    },
    'stories': [
        {
            'id': 'rush',
            'emoji': '🔥',
            'chip': '주문 폭주',
            'role': '홀 · 주방',
            'title': '피크 타임 세트',
            'pain': '저녁 7시 만석, 주방엔 종이 주문서가 쌓이고 가장 오래 기다린 테이블은 잊힙니다.',
            'tags': ['테이블 배치도', '실시간 주방 화면', '15분 경고', '포장 대기번호'],
            'outcome': '가장 오래 기다린 요리가 늘 맨 위에',
            'headline': '주문이 아무리 몰려도 주방은 무엇부터 할지 압니다',
            'problem': '피크 때 직원이 종이 주문서를 들고 주방으로 뛰어갑니다. 주문서는 사라지고 글씨는 알아보기 힘들고, 주방은 손님이 기다린 순서가 '
            '아니라 집어 든 순서대로 요리해요. 그래서 가장 오래 기다린 테이블이 잊힙니다.',
            'features': [
                ('색으로 상태를 보여 주는 테이블 배치도', '빈 테이블, 이용 중, 테이블별 미결제 금액, 실내·창가 구역별 구분.'),
                ('옵션과 메모까지 담은 주문', '보통 맵기, 계란 프라이 추가, 야채 빼기 — 소리칠 필요 없이 주방에 그대로 전달.'),
                ('실시간 3열 주방 화면', '조리 대기 → 조리 중 → 서빙 준비. 가장 오래된 주문이 맨 위, 15분을 넘기면 자동으로 빨간 경고.'),
                ('매장·포장·배달을 아이콘으로 구분', '포장 주문에는 하루 단위 대기번호가 자동으로 붙어요.'),
                ('잘못 누른 건 되돌리기', '상태를 바꾼 뒤 8초 동안 "실행 취소" 바가 떠요. 매니저를 부를 필요가 없습니다.'),
            ],
            'try': [
                '데모를 열고 "홀 직원"을 선택',
                '빈 테이블을 눌러 메뉴를 고르고 주방으로 전송',
                '로그아웃 후 "주방" 선택 — 방금 보낸 주문이 조리 대기 열에 떠요',
            ],
            'shots': [
                ('rush-kitchen', 'tablet', '태블릿의 주방 화면. 테이블 A1 주문이 18분 대기로 빨간 경고 표시', '주방 화면: 15분이 지난 주문은 알아서 경고'),
                ('rush-tables', 'phone', '홀 직원 휴대폰의 테이블 배치도. 빈 테이블과 이용 중인 테이블 구분', '홀 직원 휴대폰의 테이블 배치도'),
            ],
        },
        {
            'id': 'staff',
            'emoji': '🙋',
            'chip': '일손 부족',
            'role': '손님 · 홀',
            'title': '셀프 주문 세트',
            'pain': '홀 직원은 구하기 어렵고, 손님은 손을 들고 주문을 기다립니다.',
            'tags': ['테이블별 QR', '로그인 없음', '바로 주방으로', '재고 차감도 동일'],
            'outcome': '앉자마자 주문 시작',
            'headline': '손님은 자기 휴대폰으로 주문하고, 직원은 사람이 꼭 필요한 일에 집중합니다',
            'problem': '대형 식당은 거의 매 근무마다 홀 직원이 부족합니다. 손님은 메뉴판을, 주문 받을 사람을, 추가 주문을 기다리고 — '
            '기다리는 1분 1분이 테이블 회전을 늦춥니다.',
            'features': [
                ('테이블 QR을 찍고 바로 주문', '휴대폰 브라우저에서 열려요. 앱 설치도, 가입이나 로그인도 필요 없습니다.'),
                ('직원 주문과 같은 경로', '주방 화면에 올라가고 재료 재고도 똑같이 차감돼요. 따로 맞춰 볼 두 번째 시스템이 없습니다.'),
                ('손님이 자기 테이블 주문을 확인', '언제든 추가 주문하고 지금까지 주문한 내역을 볼 수 있어요.'),
                ('끊긴 링크는 솔직하게', '잘못된 QR이나 사용 중지된 테이블이면 손님에게 쓸 수 없다고 알려요. 떠도는 주문이 주방에 들어가지 않습니다.'),
                ('매니저가 QR 교체', '배치도에서 테이블을 길게 눌러 QR을 보고, 링크를 복사하거나 새 QR로 바꿀 수 있어요.'),
            ],
            'try': [
                '데모를 열고 "매니저"를 선택한 뒤 테이블 화면으로',
                '아무 테이블이나 길게 누르기 → "셀프 주문 QR 보기" → "링크 복사"',
                '새 탭에서 링크를 열고 손님처럼 주문',
            ],
            'shots': [
                ('staff-self-order', 'phone', '테이블 A1 QR을 스캔한 뒤 손님 휴대폰에 보이는 메뉴 화면', 'QR을 스캔한 손님이 보는 화면'),
            ],
        },
        {
            'id': 'pay',
            'emoji': '💸',
            'chip': '느린 결제',
            'role': '캐셔',
            'title': '빠른 계산 세트',
            'pain': '계산 줄은 길고, 단체 테이블은 나눠 내겠다며 다 같이 계산기를 두드립니다.',
            'tags': ['프롬프트페이 QR', '분할/합치기', '태국어 영수증', '세금계산서'],
            'outcome': 'QR 금액이 계산서와 사땅(1/100바트) 단위까지 일치',
            'headline': '실제 금액 그대로 스캔 결제, 테이블 전체 나눠 내기도 몇 번의 터치로',
            'problem': '캐셔가 이체 금액을 손으로 입력하다 한 자리만 틀려도 환불을 쫓아다녀야 합니다. 친구들은 각자 낼 몫을 원하고, '
            '할인과 봉사료는 카운터 앞에서 직접 나눠야 하죠.',
            'features': [
                ('EMV 표준 프롬프트페이 QR', '계산서 금액이 QR에 담겨요. 손님은 은행 앱으로 스캔만 하면 되고, 아무도 금액을 입력하지 않아요.'),
                ('결제 수단별·품목별 분할', '한 계산서에 현금, QR, 카드. 할인·봉사료·VAT는 비율대로 자동 배분.'),
                ('테이블 이동과 합치기', '손님이 자리를 옮기거나 테이블을 합쳐도 주문이 그대로 따라가요.'),
                ('감열 프린터로 태국어 영수증', '같은 LAN/Wi-Fi의 ESC/POS 프린터, 58mm·80mm 용지.'),
                ('간이 세금계산서', '태국 불기 연도 기준 일련번호. 잘못 발행한 건 이력을 남긴 채 취소.'),
            ],
            'try': [
                '데모를 열고 "캐셔"를 선택',
                '손님이 있는 테이블을 눌러 결제로',
                '"프롬프트페이 / QR" 선택 — 그 계산서 금액으로 QR이 바로 생성돼요',
            ],
            'shots': [
                ('pay-promptpay', 'phone', '휴대폰 결제 화면에서 프롬프트페이를 고르자 테이블 C1 금액의 QR이 표시됨', '계산서 금액 그대로의 프롬프트페이 QR'),
            ],
        },
        {
            'id': 'cash',
            'emoji': '🔒',
            'chip': '현금 누수',
            'role': '매니저 · 사장님',
            'title': '정직한 현금 서랍 세트',
            'pain': '마감 때 서랍 현금이 맞지 않는데, 어디서 누가 그랬는지 알 수 없습니다.',
            'tags': ['근무 시작·마감', 'Z 리포트', '수정 불가 이력', '5가지 역할'],
            'outcome': '40바트만 모자라도 마감 때 바로 보임',
            'headline': '서랍 속 1바트까지 어디서 왔고 누가 손댔는지 추적됩니다',
            'problem': '결제 후 취소, 권한을 넘는 할인, 사유 없는 환불. 대형 식당은 현금을 만지는 손이 많아서, 금액이 안 맞아도 '
            '무슨 일이 있었는지 증거가 없습니다.',
            'features': [
                ('근무를 열어야 결제 가능', '시작 시재를 넣고, 모든 결제가 열려 있는 근무에 묶여요.'),
                ('마감하면 즉시 대조', '실제 현금을 세면 있어야 할 금액과 차액을 시스템이 계산해요.'),
                ('근무별·일별 Z 리포트', '매출, 세금, 프로모션과 구분된 수동 할인, 결제 수단, 외상 회수액. 회계용 CSV 내보내기.'),
                ('누구도 고칠 수 없는 이력', '주문 취소, 할인, 환불, 가격 수정, 권한 변경을 누가, 언제, 왜 했는지 매번 기록.'),
                ('서버에서 강제하는 5가지 역할', '버튼만 숨기는 게 아니라, 요청을 직접 보내도 거절됩니다.'),
            ],
            'try': [
                '데모를 열고 "매니저" 선택 후 "근무" 메뉴로',
                '"근무 마감"을 누르고 센 금액을 조금 모자라게 입력한 뒤, 이력에서 그 근무를 눌러 Z 리포트 확인',
                '"관리자"로 다시 들어가 "변경 이력" 확인',
            ],
            'shots': [
                ('cash-zreport', 'desktop', '매출, 할인, 결제 수단, 현금 차액을 보여 주는 근무 마감 Z 리포트', '40바트 부족으로 마감한 근무의 Z 리포트'),
                ('cash-audit', 'desktop', '누가 언제 무엇을 했는지 보여 주는 변경 이력과 유형 필터', '변경 이력: 누가, 무엇을, 언제'),
            ],
        },
        {
            'id': 'stock',
            'emoji': '📦',
            'chip': '재료 품절',
            'role': '주방 · 매니저',
            'title': '품절 걱정 없는 세트',
            'pain': '손님이 주문한 뒤에야 주방에서 재료가 떨어졌다고 알려 옵니다.',
            'tags': ['자동 재고 차감', '자동 판매 중지', '재고 부족 알림'],
            'outcome': '메뉴를 손으로 끌 사람이 필요 없음',
            'headline': '재료가 떨어지면 손님이 주문하기 전에 메뉴가 알아서 판매 중지',
            'problem': '생선은 저녁 8시에 떨어졌는데 메뉴는 여전히 판매 중. 직원이 세 테이블 주문을 받은 뒤에야 주방이 알려 옵니다 — '
            '시간도 손님 기분도 잃어요.',
            'features': [
                ('메뉴와 재료 연결', '주방으로 보낼 때 차감, 취소나 삭제 시 자동 복원. 주방이 실제로 세는 단위 그대로.'),
                ('떨어지면 판매 중지', '재료가 부족하면 그 메뉴는 바로 판매 중지, 재고를 채우면 다시 판매.'),
                ('재고 부족 알림', '재료별 경고 기준을 두고, 오픈 전에 부족한 것만 걸러 보기.'),
                ('셀프 주문에도 동일하게', '손님이 직접 주문해도 같은 경로로 재고가 차감돼요.'),
            ],
            'try': [
                '데모를 열고 "관리자" → "재료/재고"',
                '"재고 부족만"을 누르면 틸라피아가 이미 경고 기준 아래로 설정되어 있어요',
                '틸라피아 재고를 0으로 바꾸고, 이 생선을 쓰는 메뉴가 판매 중지되는 걸 확인',
            ],
            'shots': [
                ('stock-ingredients', 'desktop', '재료/재고 화면에서 틸라피아가 재고 부족으로 강조됨', '재고가 부족한 재료가 먼저 눈에 띄게'),
            ],
        },
        {
            'id': 'b2b',
            'emoji': '🥩',
            'chip': '정육 · 도매',
            'role': '캐셔 · 회계',
            'title': '정육 코너 + 도매 세트',
            'pain': '포장 정육 코너와 다른 식당에 외상으로 납품하는 일 때문에 프로그램 하나와 외상 장부가 더 필요합니다.',
            'tags': ['무게 판매', '연결형 저울', 'EAN-13 라벨', '외상/청구서'],
            'outcome': '0.485kg × ฿1,200 = ฿582, 계산기 없이',
            'headline': '계량, 판매, 청구, 수금까지 — 홀과 같은 시스템에서',
            'problem': '무게는 손으로 적고 가격은 계산기로. 도매 외상은 장부에 있고, 받으러 갈 때가 되면 어느 계산서가 며칠 연체됐는지 '
            '아무도 모릅니다.',
            'features': [
                ('무게 판매, 저울에서 실시간으로', 'kg당 가격. 매장 서버에 연결된 저울이 무게를 화면으로 보내고, 직접 입력도 가능. 담기 전에 가격 확인.'),
                ('저울 라벨과 바코드 스캔', 'USB·블루투스 스캐너나 휴대폰 카메라. EAN-13 라벨은 품목과 무게를 함께 담고, 잘못 읽으면 추측하지 않고 경고.'),
                ('한도와 결제 기한 안에서 외상', '한도를 넘으면 결제 불가. 연령별 미수금, 청구서, 오래된 계산서부터 정산.'),
                ('연체 이자와 대변표를 태국어 PDF로', '금액은 글자로, 날짜는 불기로, 고객에게 바로 이메일.'),
                ('외상 회수액도 서랍 현금과 대조', 'Z 리포트가 외상 회수액을 그날 매출과 따로 보여 줘요.'),
            ],
            'try': [
                '데모를 열고 "캐셔" → "포장/배달 주문" → 정육 · 포장',
                '소고기 꽃등심을 누르면 가상 저울이 무게를 화면에 보내요',
                '"매니저"로 들어가 "외상 매출" → 도매 고객 소울바비큐 주식회사',
            ],
            'label': {
                'store': '할머니 부엌 (데모)',
                'item': '삼겹살 슬라이스',
                'weight': '중량(kg)',
                'per_kg': 'kg당 가격',
                'total': '금액(฿)',
                'aria': '저울 라벨 예시: 삼겹살 슬라이스, 1.250kg, kg당 280바트, 합계 350바트, 코드 2000101012504',
                'caption_html': '라벨 저울에서 출력한 라벨입니다. 이 바코드는 화면에서 실제로 스캔되고, 데모의 스캔 칸에 <code>2000101012504</code>를 입력해도 됩니다.',
            },
            'shots': [
                ('b2b-scale', 'tablet', '소고기 꽃등심 계량. 저울에서 0.485kg을 읽어 582바트로 계산', '저울 무게를 실시간으로 읽는 계량 창'),
                ('b2b-statement', 'desktop', '도매 고객 외상 내역. 미수금을 기간별로 나누고 연체 계산서 표시', '기간별로 나눈 외상 미수금'),
            ],
        },
        {
            'id': 'owner',
            'emoji': '📊',
            'chip': '전체가 안 보임',
            'role': '사장님',
            'title': '실시간 매출 세트',
            'pain': '문을 닫아야 매출을 알고, 지점마다 전화해서 물어봅니다.',
            'tags': ['실시간 대시보드', 'CSV 리포트', '다지점', 'AI에게 질문'],
            'outcome': '영업 중에 오늘을 파악',
            'headline': '오늘 매출, 붐비는 시간, 결제 방식 — 아직 영업 중일 때 보입니다',
            'problem': '대형 식당 사장님은 매일 사람과 재료를 결정하지만, 숫자는 문을 닫은 뒤에야 오거나 지점별 요약을 기다려야 합니다.',
            'features': [
                ('실시간 대시보드', '매출, 계산서 수, 객단가, 할인, 시간대별 그래프, 결제 수단 비율.'),
                ('기간 리포트 + CSV', '인기 메뉴, 일별·카테고리별 매출. CSV는 엑셀에서 태국어가 깨지지 않게.'),
                ('여러 지점을 하나의 시스템에서', '테이블, 메뉴, 주문, 재고, 리포트를 지점별로. 관리자는 전 지점 합계도 확인 (웹 데모는 지점 하나).'),
                ('문장으로 묻기', 'AI 어시스턴트가 실제 매장 데이터로 답해요 — 다음 섹션 참고.'),
            ],
            'try': [
                '데모를 열고 "관리자" 선택 — 첫 화면이 전체 현황',
                '"리포트"에서 기간을 고르고 CSV 내보내기',
            ],
            'shots': [
                ('owner-dashboard', 'desktop', '오늘 매출, 시간대별 그래프, 결제 수단 비율을 보여 주는 전체 현황', '영업 중 실시간으로 보는 오늘의 대시보드'),
            ],
        },
        {
            'id': 'loyal',
            'emoji': '🎁',
            'chip': '재방문이 없음',
            'role': '마케팅 · 홀',
            'title': '프로모션 + 적립 세트',
            'pain': '프로모션 조건은 직원이 기억하지 못하고, 단골은 다시 올 이유가 없습니다.',
            'tags': ['조건부 프로모션', '할인 코드', '1+1', '적립 포인트'],
            'outcome': '직원이 프로모션 조건을 외울 필요 없음',
            'headline': '프로모션은 한 번만 설정, 계산서마다 자동 적용. 단골은 알아서 적립',
            'problem': '오후 해피아워, 첫 방문 코드, 일부 메뉴 1+1 — 홀이 바빠지면 직원이 할인을 빠뜨리거나 잘못 적용합니다.',
            'features': [
                ('조건부 프로모션', '요일과 시간대, 카테고리나 메뉴, 최소 금액, 할인 코드, 1+1 — 조건에 맞는 계산서에 자동 적용.'),
                ('자동 포인트 적립', '주문 받을 때 이름이나 전화번호로 손님을 찾고, 구매 금액만큼 적립, 결제 때 할인으로 사용.'),
                ('손님별 구매 이력', '단골이 무엇을 얼마나 자주 주문하는지.'),
                ('프로모션 변경도 모두 기록', '생성, 수정, 중지가 변경 이력에 남아요.'),
            ],
            'try': [
                '데모를 열고 "관리자" → "프로모션" → 프로모션 추가',
                '지금 시간이 포함되게 설정한 뒤 새 계산서를 열면 할인이 알아서 붙어요',
                '"고객/적립"에서 손님별 포인트 확인',
            ],
            'shots': [
                ('loyal-promotions', 'desktop', '오후 해피아워, 첫 방문 코드, 주말 코드 세 가지 프로모션', '세 가지 유형의 프로모션'),
                ('loyal-customers', 'desktop', '손님별 적립 포인트가 보이는 고객 목록', '고객과 적립 포인트'),
            ],
        },
        {
            'id': 'floor',
            'emoji': '🌧',
            'chip': '험한 현장',
            'role': '매장 전원',
            'title': '진짜 현장 세트',
            'pain': '화면에 비치는 햇빛, 주방 수증기, 기름 묻은 손, 끊기는 Wi-Fi, 여러 국적의 직원.',
            'tags': ['고대비 모드', '오프라인 주문', '3개 언어', '가진 기기 그대로'],
            'outcome': '상태 라벨 대비 8.77:1, 햇빛 아래서도 또렷',
            'headline': '회의실의 깨끗한 화면이 아니라 진짜 매장을 기준으로 설계했습니다',
            'problem': '에어컨 나오는 사무실에서는 화면이 멋져 보여요. 하지만 실제 매장에는 유리에 비치는 햇빛, 수증기, 웍을 든 손, '
            '영업 중 끊기는 Wi-Fi, 그리고 태국어가 서툰 직원이 있습니다.',
            'features': [
                ('고대비 모드', '주방 상태 라벨 대비 8.77:1 (WCAG AA 기준은 4.5:1). 내 정보 화면에서 설정하고 기기마다 기억.'),
                ('바쁜 손을 위한 큰 버튼', '주방의 상태 버튼은 휴대폰 버튼보다 거의 두 배 커요.'),
                ('인터넷이 끊겨도 주문 접수', '기기에 보관했다가 연결되면 자동 동기화. 주방 화면은 전체 폭 경고를 띄우고 30초마다 주문을 다시 가져와요.'),
                ('ไทย · English · 한국어', '기기마다 언어를 고르고, 메뉴 이름도 그 언어로.'),
                ('휴대폰, 태블릿, 컴퓨터를 하나의 시스템으로', '이미 가진 기기를 그대로. 특정 브랜드 하드웨어가 필요 없어요.'),
            ],
            'try': [
                '아무 역할로 데모를 열고 "내 정보"로',
                '"화면 대비"를 "높음"으로 바꾸고 언어도 바꿔 보기',
            ],
            'shots': [
                ('floor-contrast', 'tablet', '고대비 모드의 주방 화면. 버튼과 라벨이 더 진하고 또렷함', '고대비 모드의 주방 화면'),
            ],
        },
    ],
    'ai': {
        'kick': '셰프 특선',
        'title': '매출을 문장으로 묻고, 실제 매장 데이터로 답을 받으세요',
        'text': '태국어, 영어, 한국어로 물어보세요. AI 어시스턴트(Claude 기반)가 매장 데이터베이스에 연결된 도구를 호출해 숫자를 가져옵니다 — '
        '모델의 일반 지식으로 추측하지 않아요.',
        'points': [
            ('🔎', '모든 답에 출처가 있어요.', '"데이터 출처" 칩이 어떤 도구로 답했는지 알려 줘서 확인할 수 있어요.'),
            ('🙅', '데이터가 없으면 없다고 해요.', '시스템에 없는 질문에는 숫자를 지어내지 않아요.'),
            ('🔐', '사장님과 매니저만.', '하루 질문 수를 제한해 비용을 관리해요.'),
        ],
        'alt': 'AI 어시스턴트가 그래프와 데이터 출처 칩과 함께 매출 질문에 답하는 애니메이션',
        'caption': '실제 Claude API 호출을 태국어로 한 번 녹화했어요. 웹 데모에는 API 키가 없어서 AI 어시스턴트가 꺼져 있습니다.',
    },
    'standards': {
        'kick': '주방 뒤편의 기준',
        'title': '홀만이 아니라 주방까지 깨끗하게',
        'sub': '돈과 고객 데이터를 다루는 시스템은 모든 층에서 검증할 수 있어야 합니다.',
        'items': [
            ('✅', '자동 테스트 {tests}개', '계산 규칙부터 실제 앱이 실제 서버와 영업일 하루를 통째로 주고받는 것까지.'),
            ('🛡', 'OWASP Top 10 점검', '7건을 찾아 모두 수정, 안전한 기본값.'),
            ('👥', '5가지 역할', '서버에서 강제. 계정을 막거나 역할을 바꾸면 즉시 적용.'),
            ('🏠', '데이터는 우리 가게에', '매장 안 기기에서 실행. 매출과 고객 데이터가 누구의 서버로도 가지 않아요.'),
            ('📖', '오픈소스 Apache-2.0', '상업적 사용, 수정, 재배포 가능.'),
            ('📸', '실제 앱 화면', '이 페이지의 모든 화면은 목업이 아니라 골든 테스트로 캡처했어요.'),
        ],
    },
    'checkout': {
        'kick': '가격',
        'title': '장바구니 요약',
        'sub': '무료이고, 나중에 월 구독 요금제가 생기지도 않아요. 처음부터 저희 서버에서 돌아가는 시스템이 아니니까요.',
        'cart_title': '장바구니',
        'shop': '매장: 사장님 가게 · 지점: 몇 개든',
        'lines': [
            ('PaynEat POS · 이 페이지의 모든 기능', 'Apache License 2.0 · 상업적 사용 가능', '฿0.00'),
            ('월 이용료', '한 번 설치하고 우리 가게에서 실행', '฿0.00'),
            ('기기·지점 추가', '휴대폰, 태블릿을 제한 없이', '฿0.00'),
            ('특정 브랜드 하드웨어', '이미 가진 기기를 그대로', '필요 없음'),
            ('VAT 7%', '', '฿0.00'),
        ],
        'total': '합계',
        'pay': '฿0.00 결제 — 데모 열기 →',
        'thanks': '주문해 주셔서 감사합니다 🙏',
        'options_title': '받는 방법 선택',
        'options': [
            ('demo', '🖥', '브라우저에서 체험', '가상의 식당으로 전체 데모 — 역할을 고르고 바로 시작.', 'app/'),
            ('docker', '🐳', '내 컴퓨터에 설치', 'Windows 한 줄 설치, 또는 Docker로 매장의 모든 기기가 함께 — 단계별 안내.', 'install.ko.html'),
            ('src', '🏪', '우리 가게에서 실제로 사용', '서버는 매장 안에. 실사용 전에 설정할 것을 확인하세요.', 'install.ko.html#live'),
            ('erp', '🏭', '센트럴 키친이나 다지점 재고가 있나요?', 'PaynEat ERP (개발 중)를 원하면 POS와 연결할 수 있어요.', ERP),
        ],
        'note_html': '도입하고 싶거나 궁금한 점이 있다면 <a href="https://github.com/SuruchBoss/PaynEat/issues">GitHub Issues</a> '
        '또는 <a href="https://www.linkedin.com/in/suruchboss">LinkedIn</a>으로 연락 주세요.',
    },
    'footer': {
        'paras_html': [
            'PaynEat POS — Flutter (GetX) + Node.js/Express + SQLite · '
            '<a href="https://github.com/SuruchBoss/PaynEat/blob/main/LICENSE">Apache License 2.0</a>',
            '모든 스크린샷은 골든 테스트로 실제 앱에서 캡처했습니다. 단, AI 어시스턴트 애니메이션은 실제 Claude API 호출을 녹화한 것입니다 '
            '(<a href="https://github.com/SuruchBoss/PaynEat/blob/main/docs/DECISIONS.md">docs/DECISIONS.md</a> #33, #70).',
            '데모의 식당, 고객, 메뉴는 모두 가상의 데이터입니다.',
        ],
        'links_title': '프로젝트',
        'links': [
            ('GitHub에서 코드 보기', REPO),
            ('설치 안내', 'install.ko.html'),
            ('보안 (SECURITY.md)', f'{REPO}/blob/main/SECURITY.md'),
            ('설계 결정 기록', f'{REPO}/blob/main/docs/DECISIONS.md'),
            ('PaynEat ERP', ERP),
        ],
        'contact': {
            'title': '문의하기',
            'lead': '매장 도입, 기능 요청, 설치 문제 — 편하게 연락 주세요.',
            'items': [
                ('mail', '이메일', 'bossxiii@gmail.com', EMAIL),
                ('linkedin', 'LinkedIn', 'linkedin.com/in/suruchboss', LINKEDIN),
                ('issues', 'GitHub Issues', '공개적으로 질문하거나 문제 신고', f'{REPO}/issues'),
            ],
        },
    },
    'readme': {
        'file': 'README.ko.md',
        'title': '🍽 문제 해결 메뉴',
        'intro': '대형 식당이 매일 실제로 겪는 문제들이고, 각각 버튼 하나가 아니라 **함께 움직이는 여러 기능**으로 해결합니다 — 모두 자동 테스트 '
        '{tests}개를 통과한 뒤 배포됩니다. 모든 이미지는 골든 테스트로 실제 앱에서 캡처했습니다 '
        '([`story_test.dart`](app/tool/screenshots/story_test.dart)). **[웹 데모](https://suruchboss.github.io/PaynEat/app/)**에서 직접 눌러 보시거나 '
        '**[랜딩 페이지](https://suruchboss.github.io/PaynEat/index.ko.html)**에서 웹 페이지로 보실 수 있습니다.',
        'cols': ('가게의 문제', '해결하는 세트', '얻는 것'),
        'label_note': '> 🏷 데모의 저울 라벨 `2000101012504` (삼겹살 슬라이스 1.250kg × 280 = 350바트) — 데모의 스캔 칸에 입력하거나 스캔해 보세요. '
        '랜딩 페이지에는 화면에서 바로 스캔되는 실제 EAN-13 바코드로 그려져 있습니다.',
    },
    'mcart': {'label': '장바구니', 'sub': '฿0.00 · 모든 기능 무료', 'cta': '데모 열기'},
}

LANGS = [TH, EN, KO]
