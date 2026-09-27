# Copyright 2026 Suruch Chakrapeesirisuk
# SPDX-License-Identifier: Apache-2.0
#
# เนื้อหาหน้า "นโยบายความเป็นส่วนตัว" ทั้ง 3 ภาษา (docs/landing/privacy*.html) — build_landing.py วาดจากโครงนี้
# ลิงก์หน้านี้คือ URL ที่กรอกในช่อง Privacy policy ของ Google Play Console (docs/store/README.md, ticket 29a)
#
# กติกาเนื้อหา (docs/DECISIONS.md #75):
# - ทุกประโยคต้องตรงกับโค้ดวันนี้: แอปไม่มี SDK โฆษณา/วิเคราะห์การใช้งาน/รายงานแอปค้าง (app/pubspec.yaml) ฟอนต์ฝังในแอป
#   โหมดสาธิตไม่เรียกเซิร์ฟเวอร์ใด (app/lib/app/di/bindings/data_source_bindings.dart) สิทธิ์ Android มีแค่อินเทอร์เน็ตกับกล้อง
#   ข้อยกเว้นเดียวคือ Google ML Kit ที่ mobile_scanner ใช้บน Android ซึ่งส่งข้อมูลวินิจฉัยให้ Google — ต้องบอกไว้ในหน้านี้เสมอ
#   — เพิ่ม dependency ที่ส่งข้อมูลออกนอกเครื่องหรือขอสิทธิ์ใหม่เมื่อไหร่ ต้องแก้หน้านี้และ docs/store/data-safety.md ใน PR เดียวกัน
# - แก้เนื้อหาเมื่อไหร่ให้เลื่อน 'updated' และบอกสิ่งที่เปลี่ยนใน PR — ประวัติทั้งหมดอยู่ใน git
# - ค่าที่ลงท้าย _html เป็น HTML ที่เขียนเอง ข้อความอื่นถูก escape

REPO = 'https://github.com/SuruchBoss/PaynEat'
EMAIL = 'mailto:bossxiii@gmail.com'
ISSUES = f'{REPO}/issues'
SOURCE = f'{REPO}/blob/main/docs/generator/landing/privacy_content.py'
MLKIT = 'https://developers.google.com/ml-kit/android-data-disclosure'

TH = {
    'code': 'th',
    'file': 'privacy.html',
    'home': 'index.html',
    'home_label': 'หน้าแรก',
    'title': 'นโยบายความเป็นส่วนตัว — PaynEat POS',
    'description': 'แอป PaynEat POS ไม่ส่งข้อมูลใดๆ มาหาผู้พัฒนา ไม่มีโฆษณาและตัวติดตาม ข้อมูลร้านอยู่บนเซิร์ฟเวอร์ของร้านเท่านั้น',
    'skip': 'ข้ามไปที่เนื้อหา',
    'kick': 'นโยบายความเป็นส่วนตัว',
    'heading': 'แอปนี้ไม่ส่งข้อมูลอะไรมาหาเรา',
    'lead': 'PaynEat POS เป็นซอฟต์แวร์โอเพนซอร์สฟรี ผู้พัฒนาไม่มีเซิร์ฟเวอร์ที่แอปคุยด้วย ไม่มีบัญชีผู้ใช้กับผู้พัฒนา '
    'และไม่เห็นข้อมูลของร้านคุณเลย ข้อมูลร้านอยู่บนเซิร์ฟเวอร์ที่ร้านตั้งเองเท่านั้น',
    'chips': ['ไม่มีโฆษณา', 'ไม่ส่งข้อมูลมาหาผู้พัฒนา', 'ไม่มีบัญชีกับผู้พัฒนา', 'โค้ดเปิดให้ตรวจได้'],
    'updated_label': 'มีผลตั้งแต่',
    'updated': '27 กันยายน 2026',
    'sections': [
        ('who', 'ใครเป็นผู้พัฒนา และนโยบายนี้ครอบคลุมอะไร', [
            'นโยบายนี้ครอบคลุมแอป <b>PaynEat POS</b> บน Android (Google Play) เว็บแอป และเดโมบนเว็บไซต์นี้ '
            'ผู้พัฒนาคือ Suruch Chakrapeesirisuk ซึ่งเผยแพร่โค้ดทั้งหมดภายใต้ Apache License 2.0 ที่ '
            f'<a href="{REPO}">github.com/SuruchBoss/PaynEat</a>',
            'แอปเป็นเครื่องมือของร้านอาหาร: พนักงานใช้รับออเดอร์ ส่งเข้าครัว และรับชำระเงิน ส่วนข้อมูลที่เกิดขึ้นเป็นของร้าน '
            '<b>ร้านที่ติดตั้งเซิร์ฟเวอร์ PaynEat เป็นผู้ควบคุมข้อมูลนั้น</b> ไม่ใช่ผู้พัฒนา',
        ]),
        ('never', 'สิ่งที่แอปไม่ทำ', [
            ['ไม่ส่งข้อมูลใดๆ มาหาผู้พัฒนา และผู้พัฒนาไม่มีเซิร์ฟเวอร์ที่แอปเชื่อมต่อ',
             'ไม่มีโฆษณา และไม่ได้ใส่เครื่องมือวิเคราะห์การใช้งานหรือรายงานแอปค้างใดๆ — โค้ดของบุคคลที่สามชิ้นเดียวที่ส่งข้อมูล'
             'ออกนอกเครื่องคือ Google ML Kit ในตัวสแกนบาร์โค้ด (หัวข้อถัดไป)',
             'ไม่ขอตำแหน่ง รายชื่อผู้ติดต่อ ไมโครโฟน หรือรหัสโฆษณาของเครื่อง',
             'ไม่ขายข้อมูล และไม่ใช้ข้อมูลเพื่อติดตามคุณข้ามแอปหรือเว็บไซต์',
             'ฟอนต์ทั้งหมดฝังมาในแอป ไม่โหลดจากอินเทอร์เน็ต'],
        ]),
        ('mlkit', 'ตัวสแกนบาร์โค้ดใช้ Google ML Kit (Android)', [
            'ตัวสแกนบาร์โค้ดและฉลากตาชั่งบน Android ใช้ Google ML Kit อ่านภาพจากกล้อง<b>ในเครื่อง</b> ภาพจากกล้องไม่ออกจากเครื่อง '
            'แต่เมื่อใช้ตัวสแกน ML Kit ส่งข้อมูลวินิจฉัยไปให้ Google ได้แก่ ข้อมูลรุ่นเครื่องและระบบปฏิบัติการ ชื่อและเวอร์ชันของแอป '
            'รหัสประจำการติดตั้ง ตัวเลขประสิทธิภาพ และรหัสข้อผิดพลาด ข้อมูลนี้เข้ารหัสระหว่างส่ง และ Google ใช้ดูแลและปรับปรุง ML Kit '
            f'ตามที่อธิบายไว้ใน<a href="{MLKIT}">หน้าการเปิดเผยข้อมูลของ ML Kit</a> ผู้พัฒนาไม่ได้รับข้อมูลนี้',
        ]),
        ('device', 'สิ่งที่เก็บไว้ในเครื่อง', [
            ['ภาษาและโหมดคอนทราสต์สูงที่เลือก',
             'ที่อยู่เครื่องพิมพ์ใบเสร็จที่ตั้งไว้',
             'token การเข้าสู่ระบบ ชื่อ และบทบาทของพนักงานที่เข้าสู่ระบบอยู่ — ลบเมื่อออกจากระบบ',
             'ออเดอร์ที่รับไว้ตอนเน็ตหลุด ระหว่างรอส่งเข้าเซิร์ฟเวอร์ของร้าน'],
            'ทั้งหมดอยู่ในพื้นที่ของแอปบนเครื่องนี้ และหายไปเมื่อถอนการติดตั้งแอป',
        ]),
        ('demo', 'โหมดสาธิต (build ที่ทดสอบบน Google Play ตอนนี้)', [
            'build ที่เปิดให้ทดสอบบน Google Play ตอนนี้เป็น<b>โหมดสาธิต</b>: ร้าน เมนู ลูกค้า และออเดอร์เป็นข้อมูลสมมติ '
            'สร้างและเก็บอยู่ในเครื่องของคุณเท่านั้น แอปไม่เรียกเซิร์ฟเวอร์ใดในโหมดนี้ (ยกเว้นข้อมูลวินิจฉัยของ ML Kit ด้านบน '
            'เมื่อใช้ตัวสแกน และใบเสร็จที่ส่งไปเครื่องพิมพ์ ถ้าคุณตั้งเครื่องพิมพ์เอง) '
            'ข้อมูลที่คุณลองพิมพ์ลงไปหายเมื่อปิดแอปหรือถอนการติดตั้ง',
        ]),
        ('shop', 'เมื่อต่อกับเซิร์ฟเวอร์ของร้าน', [
            'เมื่อแอปต่อกับเซิร์ฟเวอร์ PaynEat ของร้าน (ที่อยู่ที่ร้านเป็นผู้ตั้ง) แอปส่งข้อมูลไป<b>ที่เซิร์ฟเวอร์นั้นเท่านั้น</b> '
            'เพื่อให้ร้านทำงานได้ เช่น',
            ['ชื่อผู้ใช้และรหัสผ่านของพนักงานตอนเข้าสู่ระบบ (แอปไม่เก็บรหัสผ่านไว้ในเครื่อง)',
             'ออเดอร์ การชำระเงิน ใบเสร็จ และใบกำกับภาษี',
             'ชื่อ เบอร์โทร และแต้มสะสมของลูกค้าสมาชิก ถ้าร้านเลือกใช้ระบบสมาชิก',
             'รูปเมนูที่ถ่ายหรือเลือกจากเครื่อง เมื่อผู้ดูแลกดบันทึกเมนูเท่านั้น'],
            'ร้านเป็นผู้ตัดสินใจว่าจะเก็บข้อมูลเหล่านี้นานแค่ไหน ใครเข้าถึงได้ และจะลบเมื่อไหร่ '
            'ถ้าอยากขอดูหรือลบข้อมูลของคุณ (เช่น ข้อมูลสมาชิก) ให้ติดต่อร้านโดยตรง เพราะผู้พัฒนาไม่มีข้อมูลนี้',
            'ร้านอาจเปิดฟีเจอร์เสริมที่เซิร์ฟเวอร์ของร้านเอง ซึ่งส่งข้อมูลไปผู้ให้บริการที่ร้านเลือก ไม่ใช่ผู้พัฒนา: '
            'ผู้ช่วย AI (เซิร์ฟเวอร์ร้านส่งคำถามและตัวเลขยอดขายไปยัง Anthropic ด้วยคีย์ API ของร้าน) และการส่งเอกสารทางอีเมล '
            '(ผ่านเซิร์ฟเวอร์อีเมลของร้าน) ทั้งสองอย่างปิดอยู่จนกว่าร้านจะตั้งค่าเอง',
        ]),
        ('perm', 'สิทธิ์ที่แอปขอบน Android', [
            ['<b>อินเทอร์เน็ต</b> — ต่อเซิร์ฟเวอร์ของร้าน และส่งใบเสร็จไปเครื่องพิมพ์ในวงเครือข่ายของร้านตามที่อยู่ที่ร้านตั้งไว้',
             '<b>กล้อง</b> — สแกนบาร์โค้ดหรือฉลากตาชั่ง และถ่ายรูปเมนู ภาพจากการสแกนประมวลผลในเครื่อง ไม่ถูกส่งหรือเก็บไว้ '
             'ส่วนรูปเมนูถูกส่งไปเซิร์ฟเวอร์ของร้านเมื่อกดบันทึกเท่านั้น'],
            'แอปขอสิทธิ์กล้องตอนที่คุณกดใช้ครั้งแรกเท่านั้น และปฏิเสธได้โดยส่วนอื่นของแอปยังใช้ได้ตามปกติ',
        ]),
        ('security', 'ความปลอดภัย', [
            'เซิร์ฟเวอร์ในร้านมักใช้ที่อยู่แบบ http ในวง Wi-Fi ของร้าน ซึ่งไม่เข้ารหัส ถ้าเซิร์ฟเวอร์อยู่นอกร้าน ร้านควรใช้ https '
            f'รายละเอียดการตั้งค่าที่ปลอดภัยและวิธีแจ้งช่องโหว่อยู่ใน <a href="{REPO}/blob/main/SECURITY.md">SECURITY.md</a>',
        ]),
        ('children', 'เด็ก', [
            'แอปนี้ทำมาสำหรับพนักงานร้านอาหาร ไม่ได้ออกแบบมาสำหรับเด็ก และไม่ได้ตั้งใจเก็บข้อมูลของเด็ก',
        ]),
        ('changes', 'การเปลี่ยนแปลงนโยบาย', [
            'ถ้าแอปเปลี่ยนวิธีจัดการข้อมูล เราจะแก้หน้านี้ก่อนออกเวอร์ชันนั้น และเลื่อนวันที่มีผลด้านบน '
            f'ประวัติการแก้ไขทุกครั้งดูได้ใน <a href="{SOURCE}">ไฟล์ต้นฉบับของหน้านี้บน GitHub</a>',
        ]),
        ('contact', 'ติดต่อ', [
            f'ถามเรื่องนโยบายนี้ได้ที่ <a href="{EMAIL}">bossxiii@gmail.com</a> หรือ <a href="{ISSUES}">GitHub Issues</a> '
            '(อย่าโพสต์ข้อมูลส่วนตัวใน Issues เพราะเป็นที่สาธารณะ)',
        ]),
    ],
}

EN = {
    'code': 'en',
    'file': 'privacy.en.html',
    'home': 'index.en.html',
    'home_label': 'Home',
    'title': 'Privacy policy — PaynEat POS',
    'description': 'The PaynEat POS app sends nothing to its developer. No ads, no trackers: restaurant data stays on '
    "the restaurant's own server.",
    'skip': 'Skip to content',
    'kick': 'Privacy policy',
    'heading': 'This app sends nothing to us',
    'lead': 'PaynEat POS is free, open-source software. Its developer runs no server the app talks to, holds no user '
    "accounts and never sees your restaurant's data. That data lives only on the server the restaurant sets up.",
    'chips': ['No ads', 'Nothing sent to the developer', 'No account with the developer', 'Open source'],
    'updated_label': 'Effective',
    'updated': '27 September 2026',
    'sections': [
        ('who', 'Who makes the app and what this covers', [
            'This policy covers the <b>PaynEat POS</b> Android app (Google Play), the web app and the demo on this site. '
            'The developer is Suruch Chakrapeesirisuk, who publishes all of the code under the Apache License 2.0 at '
            f'<a href="{REPO}">github.com/SuruchBoss/PaynEat</a>.',
            'The app is a tool for restaurants: staff take orders, send them to the kitchen and take payment. '
            '<b>The restaurant that runs the PaynEat server controls that data</b>, not the developer.',
        ]),
        ('never', 'What the app never does', [
            ['Send any data to the developer. The developer runs no server the app connects to.',
             'Show ads, or include any analytics or crash-reporting tool. The one piece of third-party code that sends '
             'anything off the device is Google ML Kit in the barcode scanner (next section).',
             'Ask for your location, contacts, microphone or advertising ID.',
             'Sell data, or track you across other apps and websites.',
             'Load fonts from the internet: every font ships inside the app.'],
        ]),
        ('mlkit', 'The barcode scanner uses Google ML Kit (Android)', [
            'On Android, the barcode and scale-label scanner uses Google ML Kit to read camera frames <b>on the device</b>. '
            'Camera images never leave the device. When the scanner is used, ML Kit sends Google diagnostic data: device '
            'model and OS version, the app\'s name and version, a per-installation identifier, performance figures and '
            'error codes. It is encrypted in transit, and Google uses it to maintain and improve ML Kit as described on '
            f'<a href="{MLKIT}">ML Kit\'s data disclosure page</a>. The developer does not receive it.',
        ]),
        ('device', 'What stays on the device', [
            ['The language and high-contrast mode you chose.',
             'The receipt printer address you set.',
             'The sign-in token, name and role of the signed-in staff member, removed on sign-out.',
             'Orders taken while the network was down, until they reach the restaurant\'s server.'],
            'All of it lives in the app\'s own storage on this device and is removed when the app is uninstalled.',
        ]),
        ('demo', 'Demo mode (the build now in testing on Google Play)', [
            'The build now in testing on Google Play runs in <b>demo mode</b>: the restaurant, menu, customers and orders '
            'are made up, created and kept on your device only. The app calls no server in this mode (apart from ML Kit\'s '
            'diagnostics above when the scanner is used, and receipts sent to a printer if you set one up yourself). '
            'Anything you type in is gone when you close or uninstall the app.',
        ]),
        ('shop', "When the app is connected to a restaurant's server", [
            "Connected to the restaurant's PaynEat server (at an address the restaurant sets), the app sends data "
            '<b>to that server only</b>, so the restaurant can work. For example:',
            ['Staff usernames and passwords when signing in (the app never keeps the password on the device).',
             'Orders, payments, receipts and tax invoices.',
             "Loyalty members' names, phone numbers and points, if the restaurant uses loyalty.",
             'Menu photos taken or picked on the device, only when an admin saves a menu item.'],
            'The restaurant decides how long this data is kept, who can see it and when it is deleted. To see or delete '
            'your data (for example your loyalty record), contact the restaurant: the developer does not have it.',
            "A restaurant may turn on optional features on its own server, which send data to providers the restaurant "
            "chooses, not to the developer: the AI assistant (the restaurant's server sends questions and sales figures to "
            "Anthropic with the restaurant's own API key) and emailing documents (through the restaurant's mail server). "
            'Both stay off until the restaurant sets them up.',
        ]),
        ('perm', 'Android permissions', [
            ["<b>Internet</b> — to reach the restaurant's server, and to send receipts to a printer on the restaurant's "
             'network at the address the restaurant set.',
             '<b>Camera</b> — to scan barcodes or scale labels and to photograph menu items. Scanning happens on the '
             "device; scanned images are neither sent nor kept. A menu photo goes to the restaurant's server only when it "
             'is saved.'],
            'The camera permission is asked for only the first time you use it. You can refuse it and the rest of the '
            'app keeps working.',
        ]),
        ('security', 'Security', [
            "Servers inside a restaurant usually use a plain http address on the restaurant's Wi-Fi, which is not "
            'encrypted. A server outside the restaurant should use https. Safe set-up and how to report a vulnerability '
            f'are in <a href="{REPO}/blob/main/SECURITY.md">SECURITY.md</a>.',
        ]),
        ('children', 'Children', [
            'The app is made for restaurant staff. It is not designed for children and does not knowingly collect data '
            'from children.',
        ]),
        ('changes', 'Changes to this policy', [
            'If the app changes how it handles data, this page is updated before that version ships and the effective '
            f'date above moves. Every change is visible in <a href="{SOURCE}">this page\'s source file on GitHub</a>.',
        ]),
        ('contact', 'Contact', [
            f'Questions about this policy: <a href="{EMAIL}">bossxiii@gmail.com</a> or <a href="{ISSUES}">GitHub Issues</a> '
            '(please do not post personal data in Issues; they are public).',
        ]),
    ],
}

KO = {
    'code': 'ko',
    'file': 'privacy.ko.html',
    'home': 'index.ko.html',
    'home_label': '홈',
    'title': '개인정보 처리방침 — PaynEat POS',
    'description': 'PaynEat POS 앱은 개발자에게 어떤 데이터도 보내지 않습니다. 광고와 추적 도구가 없으며, 매장 데이터는 '
    '매장 자체 서버에만 있습니다.',
    'skip': '본문으로 건너뛰기',
    'kick': '개인정보 처리방침',
    'heading': '이 앱은 저희에게 아무것도 보내지 않습니다',
    'lead': 'PaynEat POS는 무료 오픈소스 소프트웨어입니다. 개발자는 앱이 통신하는 서버를 운영하지 않고, 개발자 계정도 없으며, '
    '매장 데이터를 볼 수 없습니다. 데이터는 매장이 직접 설치한 서버에만 있습니다.',
    'chips': ['광고 없음', '개발자에게 전송 없음', '개발자 계정 없음', '오픈소스'],
    'updated_label': '시행일',
    'updated': '2026년 9월 27일',
    'sections': [
        ('who', '개발자와 적용 범위', [
            '이 방침은 Android 앱 <b>PaynEat POS</b>(Google Play), 웹 앱, 이 사이트의 데모에 적용됩니다. '
            '개발자는 Suruch Chakrapeesirisuk이며, 모든 코드를 Apache License 2.0으로 '
            f'<a href="{REPO}">github.com/SuruchBoss/PaynEat</a>에 공개합니다.',
            '앱은 식당용 도구입니다. 직원이 주문을 받고, 주방에 보내고, 결제를 받습니다. '
            '<b>그 데이터는 PaynEat 서버를 운영하는 매장이 관리하며</b> 개발자가 관리하지 않습니다.',
        ]),
        ('never', '앱이 하지 않는 일', [
            ['개발자에게 데이터를 보내지 않습니다. 개발자는 앱이 접속하는 서버를 운영하지 않습니다.',
             '광고가 없고, 사용 분석이나 충돌 보고 도구를 넣지 않았습니다. 기기 밖으로 데이터를 보내는 유일한 제3자 코드는 '
             '바코드 스캐너의 Google ML Kit입니다(다음 항목).',
             '위치, 연락처, 마이크, 광고 ID를 요청하지 않습니다.',
             '데이터를 판매하지 않으며, 다른 앱이나 웹사이트에 걸쳐 추적하지 않습니다.',
             '모든 글꼴이 앱에 포함되어 있어 인터넷에서 불러오지 않습니다.'],
        ]),
        ('mlkit', '바코드 스캐너는 Google ML Kit를 사용합니다 (Android)', [
            'Android에서 바코드와 저울 라벨 스캐너는 Google ML Kit로 카메라 화면을 <b>기기 안에서</b> 읽습니다. 카메라 이미지는 '
            '기기 밖으로 나가지 않습니다. 다만 스캐너를 쓰면 ML Kit가 Google에 진단 데이터를 보냅니다: 기기 모델과 OS 버전, '
            '앱 이름과 버전, 설치별 식별자, 성능 수치, 오류 코드. 전송 중 암호화되며, Google은 '
            f'<a href="{MLKIT}">ML Kit 데이터 공개 페이지</a>에 설명된 대로 ML Kit 유지·개선에 사용합니다. 개발자는 이 데이터를 받지 않습니다.',
        ]),
        ('device', '기기에 남는 것', [
            ['선택한 언어와 고대비 모드.',
             '설정한 영수증 프린터 주소.',
             '로그인한 직원의 로그인 토큰, 이름, 역할 — 로그아웃하면 삭제됩니다.',
             '네트워크가 끊긴 동안 받은 주문 — 매장 서버에 전송될 때까지.'],
            '모두 이 기기의 앱 전용 저장소에 있으며 앱을 삭제하면 함께 지워집니다.',
        ]),
        ('demo', '데모 모드 (현재 Google Play에서 테스트 중인 빌드)', [
            '현재 Google Play에서 테스트 중인 빌드는 <b>데모 모드</b>입니다. 매장, 메뉴, 고객, 주문은 가상의 데이터이며 '
            '기기 안에서만 만들어지고 보관됩니다. 이 모드에서 앱은 어떤 서버도 호출하지 않습니다(스캐너를 쓸 때 위의 ML Kit 진단 '
            '데이터, 직접 프린터를 설정했을 때 프린터로 보내는 영수증은 예외). 입력해 본 내용은 앱을 닫거나 삭제하면 사라집니다.',
        ]),
        ('shop', '매장 서버에 연결했을 때', [
            '매장의 PaynEat 서버(매장이 정한 주소)에 연결하면, 앱은 매장이 일할 수 있도록 <b>그 서버로만</b> 데이터를 보냅니다. 예:',
            ['로그인할 때 직원의 사용자 이름과 비밀번호(앱은 비밀번호를 기기에 저장하지 않습니다).',
             '주문, 결제, 영수증, 세금계산서.',
             '매장이 멤버십을 쓰는 경우 회원의 이름, 전화번호, 포인트.',
             '관리자가 메뉴를 저장할 때만, 기기에서 찍거나 고른 메뉴 사진.'],
            '이 데이터를 얼마나 보관할지, 누가 볼 수 있는지, 언제 삭제할지는 매장이 정합니다. 본인 데이터(예: 회원 정보)를 '
            '보거나 삭제하려면 매장에 직접 문의하세요. 개발자에게는 그 데이터가 없습니다.',
            '매장은 자체 서버에서 선택 기능을 켤 수 있으며, 이때 데이터는 개발자가 아닌 매장이 고른 제공자에게 갑니다: '
            'AI 어시스턴트(매장 서버가 매장의 API 키로 질문과 매출 수치를 Anthropic에 보냄)와 문서 이메일 발송(매장의 메일 서버 '
            '사용). 둘 다 매장이 직접 설정하기 전까지 꺼져 있습니다.',
        ]),
        ('perm', 'Android 권한', [
            ['<b>인터넷</b> — 매장 서버에 연결하고, 매장이 정한 주소의 매장 네트워크 프린터로 영수증을 보냅니다.',
             '<b>카메라</b> — 바코드나 저울 라벨을 스캔하고 메뉴 사진을 찍습니다. 스캔은 기기 안에서 처리되며 스캔한 이미지는 '
             '전송하거나 보관하지 않습니다. 메뉴 사진은 저장할 때만 매장 서버로 전송됩니다.'],
            '카메라 권한은 처음 사용할 때만 요청하며, 거부해도 앱의 나머지 기능은 그대로 쓸 수 있습니다.',
        ]),
        ('security', '보안', [
            '매장 안의 서버는 보통 매장 Wi-Fi에서 암호화되지 않는 http 주소를 씁니다. 서버가 매장 밖에 있다면 https를 써야 합니다. '
            f'안전한 설정과 취약점 신고 방법은 <a href="{REPO}/blob/main/SECURITY.md">SECURITY.md</a>에 있습니다.',
        ]),
        ('children', '아동', [
            '이 앱은 식당 직원용이며 아동을 위해 설계되지 않았고, 아동의 데이터를 의도적으로 수집하지 않습니다.',
        ]),
        ('changes', '방침 변경', [
            '앱의 데이터 처리 방식이 바뀌면 해당 버전을 내기 전에 이 페이지를 고치고 위의 시행일을 바꿉니다. '
            f'모든 변경 이력은 <a href="{SOURCE}">GitHub의 이 페이지 원본 파일</a>에서 볼 수 있습니다.',
        ]),
        ('contact', '문의', [
            f'이 방침에 대한 문의: <a href="{EMAIL}">bossxiii@gmail.com</a> 또는 <a href="{ISSUES}">GitHub Issues</a> '
            '(Issues는 공개되므로 개인정보를 올리지 마세요).',
        ]),
    ],
}

PRIVACY_LANGS = [TH, EN, KO]
