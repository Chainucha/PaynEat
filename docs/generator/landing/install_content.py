# Copyright 2026 Suruch Chakrapeesirisuk
# SPDX-License-Identifier: Apache-2.0
#
# เนื้อหาหน้า "คู่มือติดตั้ง" ทั้ง 3 ภาษา (docs/landing/install*.html) — build_landing.py วาดจากโครงนี้
#
# กติกาเนื้อหา (docs/DECISIONS.md #72):
# - เขียนให้เจ้าของร้านที่ไม่ใช่สาย IT ทำตามได้ โดยไม่ต้องเปิด GitHub — แต่ทุกคำสั่ง/ขั้นตอนต้องตรงกับ README
#   หัวข้อ "วิธีรัน", SECURITY.md และ deploy/demo/install-demo.ps1 ของจริงวันนี้ แก้ที่นั่นเมื่อไหร่ให้แก้ที่นี่ด้วย
# - ห้ามสัญญาสิ่งที่ตัวติดตั้งไม่ได้ทำ เช่น ตัวติดตั้งบรรทัดเดียวบน Windows เปิดได้แค่ในเครื่องนั้น (image build ด้วย
#   API_BASE_URL=http://localhost:3000) — ใช้หลายเครื่องต้องใช้ Docker จากโค้ดแล้วตั้ง API_BASE_URL เป็น IP ของเครื่อง
# - ค่าที่ลงท้าย _html, 'html' ของแต่ละขั้น, คำตอบใน help และค่าใน 'after' เป็น HTML ที่เขียนเอง ข้อความอื่นถูก escape

REPO = 'https://github.com/SuruchBoss/PaynEat'
DEMO_URL = 'app/'
ZIP = f'{REPO}/archive/refs/heads/main.zip'
WIN_ONE_LINER = (
    "[Net.ServicePointManager]::SecurityProtocol = 3072; iex ((New-Object Net.WebClient).DownloadString("
    "'https://github.com/SuruchBoss/PaynEat/releases/download/demo/install-demo.ps1'))"
)
INSTALLER = f'{REPO}/blob/main/deploy/demo/install-demo.ps1'
SECURITY = f'{REPO}/blob/main/SECURITY.md'
ISSUES = f'{REPO}/issues'
LINKEDIN = 'https://www.linkedin.com/in/suruchboss'

ACCOUNTS = [
    ('admin', 'admin123'),
    ('manager', 'manager123'),
    ('waiter1', 'waiter123'),
    ('kitchen', 'kitchen123'),
    ('cashier', 'cashier123'),
    ('waiter2', 'waiter123'),
]

TH = {
    'code': 'th',
    'file': 'install.html',
    'home': 'index.html',
    'readme': f'{REPO}#readme',
    'title': 'คู่มือติดตั้ง PaynEat POS',
    'description': 'ติดตั้ง PaynEat POS ทีละขั้น — ลองในเบราว์เซอร์ทันที, ติดตั้งบน Windows ด้วยบรรทัดเดียว, '
    'รันด้วย Docker ให้หลายเครื่องในร้านใช้ร่วมกัน หรือรันจากโค้ดสำหรับนักพัฒนา',
    'skip': 'ข้ามไปที่การเลือกวิธีติดตั้ง',
    'nav': [('#choose', 'เลือกวิธี'), ('#accounts', 'บัญชีทดลอง'), ('#live', 'ก่อนใช้จริง'), ('#help', 'แก้ปัญหา')],
    'home_label': 'หน้าแรก',
    'copy': 'คัดลอก',
    'copied': 'คัดลอกแล้ว',
    'hero': {
        'kick': 'คู่มือติดตั้ง',
        'title': 'เปิดร้านบน PaynEat POS ใน 4 ทาง',
        'lead': 'เลือกทางที่ตรงกับคุณแล้วทำตามทีละขั้น ไม่ต้องสมัคร ไม่มีค่าใช้จ่าย และข้อมูลร้านอยู่บนเครื่องของคุณเอง',
        'chips': ['ฟรี · Apache 2.0', 'ไม่ต้องสมัครสมาชิก', 'ใช้เครื่องที่ร้านมีอยู่'],
    },
    'choose': {
        'kick': 'ขั้นแรก',
        'title': 'คุณอยากทำอะไร?',
        'sub': 'ยังไม่แน่ใจ เริ่มจากทางแรกก่อน — ลองกดดูจนพอใจแล้วค่อยติดตั้งจริงก็ได้',
        'labels': ('ใช้เวลา', 'ต้องมี', 'เหมาะกับ'),
        'recommended': 'แนะนำ',
    },
    'paths': [
        {
            'id': 'browser', 'icon': '🖥', 'name': 'ลองในเบราว์เซอร์',
            'time': 'ทันที', 'need': 'เบราว์เซอร์อะไรก็ได้', 'who': 'อยากดูหน้าตาและลองกดก่อนตัดสินใจ',
            'cta': 'เปิดเดโม', 'href': DEMO_URL,
        },
        {
            'id': 'windows', 'icon': '🪟', 'name': 'Windows บรรทัดเดียว', 'recommended': True,
            'time': '3–5 นาที', 'need': 'Windows + Docker Desktop', 'who': 'เจ้าของร้านที่อยากได้ระบบตัวจริงบนเครื่องตัวเอง',
            'cta': 'ดูวิธีติดตั้ง', 'href': '#windows',
        },
        {
            'id': 'docker', 'icon': '🐳', 'name': 'Docker ให้หลายเครื่องใช้ร่วมกัน',
            'time': '10–15 นาทีครั้งแรก', 'need': 'Docker Desktop (Windows / Mac / Linux)', 'who': 'ร้านที่อยากให้มือถือ แท็บเล็ต และจอครัวต่อเครื่องเดียวกัน',
            'cta': 'ดูวิธีติดตั้ง', 'href': '#docker',
        },
        {
            'id': 'dev', 'icon': '🧑‍💻', 'name': 'รันจากโค้ด',
            'time': 'ประมาณ 5 นาที', 'need': 'Node.js 22 + Flutter 3.35', 'who': 'นักพัฒนาที่อยากแก้หรือต่อยอดระบบ',
            'cta': 'ดูวิธีรัน', 'href': '#dev',
        },
    ],
    'sections': [
        {
            'id': 'windows', 'icon': '🪟', 'kick': 'ทางที่ 2 · แนะนำสำหรับเจ้าของร้าน',
            'title': 'ติดตั้งบน Windows ด้วยบรรทัดเดียว',
            'intro': 'ได้ระบบตัวจริงครบ ทั้งเซิร์ฟเวอร์ การอัปเดตสดข้ามหน้าต่าง ตาชั่งจำลอง และใบเสร็จ PDF '
            'โดยไม่ต้องดาวน์โหลดโค้ดหรือ build เอง เพราะตัวติดตั้งโหลดชุดที่ build ไว้แล้วมาให้',
            'facts': [('ใช้เวลา', '3–5 นาที (ดาวน์โหลดครั้งแรกราว 200 MB)'), ('ต้องมี', 'Windows 64 บิต + Docker Desktop'),
                      ('ได้อะไร', 'ระบบเปิดที่ http://localhost:8080 บนเครื่องนี้')],
            'steps': [
                {'title': 'ติดตั้งและเปิด Docker Desktop',
                 'html': 'ยังไม่มี ดาวน์โหลดได้ที่ <a href="https://www.docker.com/products/docker-desktop/">docker.com</a> '
                 'ติดตั้งแล้วเปิดโปรแกรม รอจนมุมซ้ายล่างขึ้นคำว่า <b>Engine running</b>'},
                {'title': 'เปิด PowerShell',
                 'html': 'กดปุ่ม <kbd>Windows</kbd> พิมพ์ <b>PowerShell</b> แล้วกด <kbd>Enter</kbd>'},
                {'title': 'วางบรรทัดนี้แล้วกด Enter',
                 'html': 'กดปุ่ม <b>คัดลอก</b> ที่มุมกล่อง แล้วคลิกขวาในหน้าต่าง PowerShell เพื่อวาง',
                 'code': WIN_ONE_LINER, 'lang': 'PowerShell'},
                {'title': 'รอสักครู่ แล้วเข้าสู่ระบบ',
                 'html': 'เบราว์เซอร์จะเปิด <b>http://localhost:8080</b> ให้เอง เข้าด้วย <code>admin</code> / <code>admin123</code> '
                 'หรือแตะปุ่มบัญชีทดลองบนหน้าเข้าสู่ระบบ'},
            ],
            'ok_html': 'PowerShell ขึ้นข้อความสีเขียว <b>PaynEat is ready: http://localhost:8080</b> และเบราว์เซอร์เปิดหน้าเข้าสู่ระบบ',
            'after_title': 'ใช้งานวันต่อไป',
            'after': [
                ('เปิด / ปิด / ล้างข้อมูล', 'ในโฟลเดอร์ PaynEat-Demo ของผู้ใช้ มีไฟล์ดับเบิลคลิก Start, Stop และ Reset PaynEat data '
                 '(Reset = ลบบิลที่ลองทำทั้งหมด กลับเป็นข้อมูลตัวอย่าง)'),
                ('เปิดเครื่องใหม่', 'เปิด Docker Desktop แล้วระบบขึ้นเอง'),
                ('อัปเดตเป็นรุ่นล่าสุด', 'วางบรรทัดเดิมซ้ำ ข้อมูลที่ทำไว้ยังอยู่'),
            ],
            'note_html': '⚠️ ตั้งค่าไว้สำหรับทดลองเท่านั้น (บัญชีทดลอง ตาชั่งจำลอง อีเมลไม่ส่งออกจริง) และเปิดได้บนเครื่องนี้เครื่องเดียว '
            '— ถ้าจะให้มือถือหรือแท็บเล็ตในร้านต่อเข้ามาด้วย ใช้<a href="#docker">ทางที่ 3</a> '
            '· อยากอ่านสิ่งที่สคริปต์ทำก่อนวาง: <a href="' + INSTALLER + '">install-demo.ps1</a>',
        },
        {
            'id': 'docker', 'icon': '🐳', 'kick': 'ทางที่ 3 · หลายเครื่องในร้าน',
            'title': 'รันด้วย Docker ให้ทุกเครื่องในร้านต่อเข้ามา',
            'intro': 'เซิร์ฟเวอร์อยู่บนคอมพิวเตอร์เครื่องเดียวในร้าน แล้วมือถือพนักงาน แท็บเล็ตแคชเชียร์ และจอครัวเปิดผ่านเบราว์เซอร์ '
            'ออเดอร์ที่สั่งจากเครื่องหนึ่งจะขึ้นจอครัวอีกเครื่องทันที',
            'facts': [('ใช้เวลา', '10–15 นาทีครั้งแรก (ครั้งต่อไปไม่ถึงนาที)'), ('ต้องมี', 'Docker Desktop บน Windows, Mac หรือ Linux'),
                      ('ได้อะไร', 'ระบบเปิดที่ http://<IP ของเครื่อง>:8080 จากทุกเครื่องใน Wi-Fi เดียวกัน')],
            'steps': [
                {'title': 'ดาวน์โหลดโค้ด',
                 'html': 'ง่ายสุด: <a href="' + ZIP + '">ดาวน์โหลดไฟล์ ZIP</a> แล้วแตกไฟล์ จะได้โฟลเดอร์ <code>PaynEat-main</code> '
                 '· ถ้ามี git ใช้คำสั่งนี้แทนได้',
                 'code': 'git clone https://github.com/SuruchBoss/PaynEat.git', 'lang': 'Terminal'},
                {'title': 'หา IP ของเครื่องนี้',
                 'html': 'Windows: เปิด PowerShell พิมพ์ <code>ipconfig</code> ดูบรรทัด <b>IPv4 Address</b> · '
                 'Mac/Linux: <code>ifconfig | grep inet</code> — จะได้เลขหน้าตาแบบ <code>192.168.1.15</code>'},
                {'title': 'ตั้งรหัสลับของเซิร์ฟเวอร์',
                 'html': 'สร้างไฟล์ชื่อ <code>.env</code> ไว้ในโฟลเดอร์โค้ด (ข้างไฟล์ <code>docker-compose.yml</code>) ที่มีบรรทัด '
                 '<code>JWT_SECRET=</code> ตามด้วยค่าสุ่มของร้าน — ถ้าไม่มีบรรทัดนี้ ระบบจะไม่เริ่มทำงานและบอกวิธีตั้ง · '
                 'Mac/Linux ใช้คำสั่งด้านล่าง · Windows PowerShell ใช้ <code>(&quot;JWT_SECRET=&quot; + [guid]::NewGuid().ToString(&quot;N&quot;) + [guid]::NewGuid().ToString(&quot;N&quot;)) | Out-File -Encoding ascii .env</code>',
                 'code': 'echo "JWT_SECRET=$(openssl rand -hex 32)" > .env', 'lang': 'Terminal (Mac/Linux)'},
                {'title': 'บอกแอปว่าเซิร์ฟเวอร์อยู่ที่ไหน',
                 'html': 'เพิ่มบรรทัดนี้ในไฟล์ <code>.env</code> เดิม โดยเปลี่ยนเลขเป็น IP ของคุณ — ข้ามขั้นนี้ได้ถ้าจะใช้แค่เครื่องนี้เครื่องเดียว',
                 'code': 'API_BASE_URL=http://192.168.1.15:3000', 'lang': '.env'},
                {'title': 'สั่งให้ระบบเริ่มทำงาน',
                 'html': 'เปิด Terminal (Windows: PowerShell) ในโฟลเดอร์โค้ด แล้วรันคำสั่งนี้ — ครั้งแรกรอ 5–10 นาทีเพราะต้อง build แอปให้',
                 'code': 'docker compose up --build', 'lang': 'Terminal'},
                {'title': 'เปิดจากทุกเครื่องในร้าน',
                 'html': 'ต่อ Wi-Fi เดียวกันแล้วเปิด <b>http://192.168.1.15:8080</b> (ใช้ IP ของคุณ) บนมือถือ แท็บเล็ต หรือจอครัว '
                 'บนเครื่องเซิร์ฟเวอร์เองเปิด <b>http://localhost:8080</b> ได้เลย'},
            ],
            'ok_html': 'Terminal ขึ้นชื่อ <b>payneat-api</b> และ <b>payneat-web</b> แล้วเปิด <b>http://localhost:3000/health</b> ได้ผลตอบกลับ',
            'after_title': 'ใช้งานวันต่อไป',
            'after': [
                ('ปิดระบบ', 'กด <kbd>Ctrl</kbd>+<kbd>C</kbd> ในหน้าต่าง Terminal แล้วรัน <code>docker compose down</code>'),
                ('ล้างข้อมูลเริ่มใหม่', '<code>docker compose down -v</code> (ลบบิลและข้อมูลทั้งหมด)'),
                ('เปิดตาชั่งจำลองและอีเมลทดสอบ', 'เพิ่ม <code>SCALE_DRIVER=simulator</code> และ <code>MAIL_TRANSPORT=json</code> ในไฟล์ <code>.env</code> เดิม '
                 'แล้วรัน <code>docker compose up --build</code> ใหม่ (อย่าใช้ simulator ในร้านจริง)'),
            ],
            'note_html': '💡 เครื่องอื่นเปิดไม่ขึ้น: ตรวจว่าอยู่ Wi-Fi เดียวกัน และไฟร์วอลล์ของเครื่องเซิร์ฟเวอร์ยอมให้เข้าพอร์ต 8080 กับ 3000 '
            '· ก่อนเปิดให้พนักงานใช้จริง ทำ<a href="#live">เช็คลิสต์ก่อนใช้จริง</a>ให้ครบ',
        },
        {
            'id': 'dev', 'icon': '🧑‍💻', 'kick': 'ทางที่ 4 · สำหรับนักพัฒนา',
            'title': 'รันจากโค้ดบนเครื่องตัวเอง',
            'intro': 'เหมาะกับการแก้โค้ด ดู log ทีละคำขอ หรือรันบนมือถือจริงผ่าน Flutter',
            'facts': [('ใช้เวลา', 'ประมาณ 5 นาที'), ('ต้องมี', 'Node.js 20 ขึ้นไป (แนะนำ 22) + Flutter 3.35 ขึ้นไป'),
                      ('ได้อะไร', 'API ที่ http://localhost:3000 และแอปใน Chrome')],
            'steps': [
                {'title': 'ดาวน์โหลดโค้ด', 'code': 'git clone https://github.com/SuruchBoss/PaynEat.git\ncd PaynEat', 'lang': 'Terminal'},
                {'title': 'หน้าต่างที่ 1 — เซิร์ฟเวอร์',
                 'html': 'ไฟล์ <code>.env</code> มี <code>JWT_SECRET</code> สำหรับรันในเครื่อง ไม่มีไฟล์นี้เซิร์ฟเวอร์จะไม่ยอมเริ่ม '
                 '(Windows ใช้ <code>copy</code> แทน <code>cp</code>) ฐานข้อมูลและข้อมูลตัวอย่างถูกสร้างให้เอง',
                 'code': 'cd backend\nnpm install\ncp .env.example .env\nnpm run dev', 'lang': 'Terminal 1'},
                {'title': 'หน้าต่างที่ 2 — แอป', 'html': 'เปิดหน้าต่างใหม่ อย่าปิดหน้าต่างแรก',
                 'code': 'cd app\nflutter pub get\nflutter run -d chrome', 'lang': 'Terminal 2'},
            ],
            'ok_html': 'หน้าต่างที่ 1 ขึ้นบรรทัดที่มี <b>PaynEat POS API listening on http://localhost:3000</b> และ Chrome เปิดหน้าเข้าสู่ระบบ',
            'after_title': 'ทางลัดที่ใช้บ่อย',
            'after': [
                ('ดูแอปอย่างเดียว ไม่ต้องมีเซิร์ฟเวอร์', '<code>flutter run -d chrome --dart-define=DEMO_MODE=true</code> (ข้อมูลจำลองในเครื่อง รีเซ็ตเมื่อรีเฟรช)'),
                ('รันบนมือถือจริงใน Wi-Fi เดียวกัน', '<code>flutter run --dart-define=API_BASE_URL=http://&lt;IP ของคอม&gt;:3000</code>'),
                ('Android emulator', 'ชี้ไปที่ <code>10.0.2.2:3000</code> ให้เอง ไม่ต้องตั้งค่า'),
                ('รันเทสต์', '<code>cd backend &amp;&amp; npm test</code> · <code>cd app &amp;&amp; flutter test</code>'),
            ],
            'note_html': 'รายละเอียดสถาปัตยกรรม API และเทสต์ทั้งหมดอยู่ใน <a href="' + REPO + '#readme">README</a>',
        },
    ],
    'accounts': {
        'kick': 'บัญชีทดลอง',
        'title': 'เข้าสู่ระบบด้วยบทบาทไหนก็ได้',
        'sub': 'หน้าเข้าสู่ระบบมีปุ่มบัญชีทดลองทุกบทบาท แตะครั้งเดียวเข้าได้เลย ไม่ต้องพิมพ์',
        'cols': ('บทบาท', 'ชื่อผู้ใช้', 'รหัสผ่าน', 'เห็นอะไรบ้าง'),
        'rows': [
            ('ผู้ดูแลระบบ', 'ทุกอย่าง — แดชบอร์ด เมนู พนักงาน รายงาน ตั้งค่า'),
            ('ผู้จัดการ', 'เหมือนผู้ดูแลระบบ แต่ลบบัญชีผู้ใช้ไม่ได้'),
            ('พนักงานเสิร์ฟ', 'ผังโต๊ะ ออเดอร์ จอครัว'),
            ('ครัว', 'จอครัวอย่างเดียว'),
            ('แคชเชียร์', 'ผังโต๊ะ ออเดอร์ รายงาน'),
            ('พนักงานเสิร์ฟ 2 สาขา', 'เหมือน waiter1 แต่เลือกสาขาได้ — ต้องพิมพ์เอง และใช้ได้เมื่อต่อเซิร์ฟเวอร์จริง (ทางที่ 2–4)'),
        ],
        'devices_title': 'ลองหลายเครื่องพร้อมกัน',
        'devices_html': 'เดโมในเบราว์เซอร์เก็บข้อมูลแยกในแต่ละเครื่อง — สั่งจากมือถือแล้วจอครัวบนแท็บเล็ตอีกเครื่องจะไม่เห็น '
        'ถ้าอยากเห็นออเดอร์วิ่งข้ามเครื่อง ใช้<a href="#docker">ทางที่ 3</a> หรือเปิดหลายหน้าต่างบนเครื่องเดียวกับ<a href="#windows">ทางที่ 2</a> '
        '· ปุ่มลูกโลกมุมขวาบนสลับ ไทย / English / 한국어 ได้ตั้งแต่ก่อนเข้าสู่ระบบ',
    },
    'live': {
        'kick': 'ก่อนใช้จริง',
        'title': 'เช็คลิสต์ก่อนเปิดให้พนักงานใช้งานจริง',
        'sub': 'บัญชีทดลองและรหัสผ่านข้างบนเผยแพร่อยู่บนอินเทอร์เน็ต ระบบจึงกันไว้ให้แล้ว: ถ้าตั้งเป็นโหมดใช้งานจริงแต่ยังใช้รหัสทดลอง เซิร์ฟเวอร์จะไม่ยอมเปิด',
        'items_html': [
            'ตั้ง <code>JWT_SECRET</code> เป็นค่าสุ่มของร้านเอง เช่นจากคำสั่ง <code>openssl rand -hex 32</code> — ถ้าตั้ง '
            '<code>NODE_ENV=production</code> แต่ใช้ค่าตัวอย่างหรือค่าที่สั้นกว่า 32 ตัวอักษร เซิร์ฟเวอร์จะไม่ยอมเปิด',
            'ตั้งรหัสผ่านบัญชีเริ่มต้นเองครบทั้ง 6 ตัว (<code>SEED_ADMIN_PASSWORD</code> … <code>SEED_CASHIER_PASSWORD</code>) '
            'หรือปิด <code>AUTO_SEED</code> แล้วสร้างบัญชีพนักงานจริงเอง',
            'ตั้ง <code>CORS_ORIGIN</code> เป็นที่อยู่จริงของร้านแทน <code>*</code>',
            'เก็บไฟล์ฐานข้อมูลและไฟล์ <code>.env</code> ไว้ในเครื่องร้าน อย่าอัปโหลดหรือแชร์ออกไป และสำรองข้อมูลสม่ำเสมอ',
            'ไม่ใช้ตัวติดตั้งบรรทัดเดียวบน Windows กับร้านจริง เพราะตั้งค่าไว้สำหรับทดลอง',
            'ถ้าเชื่อมต่อ PaynEat ERP ใช้ที่อยู่ <code>https://</code> — ระบบไม่ส่ง credential ของเครื่องผ่าน <code>http://</code> '
            'ยกเว้นไปเครื่องเดียวกัน และห้ามตั้ง <code>ERP_ALLOW_INSECURE_HTTP</code> นอกเครือข่ายปิด '
            '· ERP ใช้ใบรับรองจาก CA ภายในของเชน: ดูหัวข้อแก้ปัญหา "ใบรับรอง HTTPS ของ PaynEat ERP ไม่น่าเชื่อถือ"',
        ],
        'more_html': 'รายละเอียดทุกข้อและวิธีแจ้งช่องโหว่อยู่ใน <a href="' + SECURITY + '">SECURITY.md</a>',
    },
    'help': {
        'kick': 'แก้ปัญหา',
        'title': 'ติดตรงไหน กดดูวิธีแก้',
        'rows': [
            ('ขึ้นว่า "port is already allocated"', 'มีโปรแกรมอื่นใช้พอร์ต 3000 หรือ 8080 อยู่ ปิดโปรแกรมนั้น (หรือระบบ PaynEat ที่เปิดค้างไว้) แล้วลองใหม่'),
            ('ขึ้นว่า "Docker Desktop is not running" หรือ "is not installed"', 'ยังไม่ได้ติดตั้งหรือยังไม่ได้เปิด Docker Desktop — ติดตั้งจาก docker.com เปิดโปรแกรม รอจนมุมซ้ายล่างขึ้น <b>Engine running</b> แล้ววางบรรทัดเดิมอีกครั้ง'),
            ('ขึ้นว่า "PaynEat started but is not answering yet"', 'ระบบเปิดแล้วแต่ยังตอบไม่ทัน รออีกครู่แล้วเปิด http://localhost:8080 ถ้ายังไม่ขึ้น ดูสาเหตุที่ Docker Desktop → Containers → payneat'),
            ('Docker ค้างนานที่ขั้น Flutter', 'ครั้งแรกต้องดาวน์โหลด Flutter SDK ประมาณ 2 GB รอให้จบ 5–10 นาที ครั้งต่อไปใช้ของที่โหลดไว้'),
            ('เปิดหน้าเว็บได้ แต่เข้าสู่ระบบไม่ได้', 'เปิด <b>http://localhost:3000/health</b> ถ้าไม่ขึ้นแปลว่าเซิร์ฟเวอร์ยังไม่ทำงาน · '
             'ถ้าตั้ง <code>API_BASE_URL</code> ไว้ ตรวจว่า IP ถูกและรัน <code>docker compose up --build</code> ใหม่หลังแก้'),
            ('มือถือหรือแท็บเล็ตต่อไม่ได้', 'ต้องอยู่ Wi-Fi เดียวกับเครื่องเซิร์ฟเวอร์ ใช้ IP ไม่ใช่ <code>localhost</code> และไฟร์วอลล์ต้องยอมพอร์ต 8080 กับ 3000'),
            ('Docker ขึ้นว่า "required variable JWT_SECRET is missing a value"', 'ยังไม่ได้ตั้งรหัสลับของเซิร์ฟเวอร์ — '
             'สร้างไฟล์ <code>.env</code> ข้าง <code>docker-compose.yml</code> ตามขั้น "ตั้งรหัสลับของเซิร์ฟเวอร์" ใน<a href="#docker">ทางที่ 3</a> แล้วรันใหม่'),
            ('ขึ้นว่า "ต้องตั้งค่า JWT_SECRET"', 'ยังไม่ได้สร้างไฟล์ <code>.env</code> — รัน <code>cp .env.example .env</code> ในโฟลเดอร์ <code>backend</code> '
             '(Windows: <code>copy</code>) แล้ว <code>npm run dev</code> ใหม่'),
            ('หน้าตั้งค่าขึ้นว่า "ที่อยู่ของ PaynEat ERP ต้องขึ้นต้นด้วย https://"', 'credential ของเครื่องส่งผ่าน <code>https://</code> เท่านั้น '
             '— ขอที่อยู่ <code>https://</code> ของ ERP จากผู้ดูแล ERP · ที่อยู่ <code>http://</code> ใช้ได้เฉพาะ ERP ที่รันในเครื่องเดียวกัน '
             '(<code>localhost</code>) · ร้านที่เชื่อมต่อด้วย <code>http://</code> ไว้ก่อนอัปเดต ระบบหยุดส่ง credential แล้ว '
             'ให้บันทึกที่อยู่ <code>https://</code> ใหม่พร้อม credential ที่หน้าตั้งค่า'),
            ('หน้าตั้งค่าขึ้นว่า "ใบรับรอง HTTPS ของ PaynEat ERP ไม่น่าเชื่อถือ"', 'เครื่องเซิร์ฟเวอร์ POS ยังไม่เชื่อ CA ที่ออกใบรับรองให้ ERP ของเชน '
             '— ขอไฟล์ CA (PEM) จากผู้ดูแล ERP · ตรวจก่อนว่าต่อได้: <code>curl --cacert chain-ca.pem https://ที่อยู่ของ-erp/health</code> '
             'ต้องได้ <code>"status":"ok"</code> · จากนั้นเริ่มเซิร์ฟเวอร์ POS ใหม่โดยมี <code>NODE_EXTRA_CA_CERTS=/ที่อยู่/chain-ca.pem</code> '
             'ใน environment (ใส่ในไฟล์ <code>backend/.env</code> ไม่ได้ผล เพราะ Node อ่านค่านี้ตอนเริ่มก่อนโหลดไฟล์) · Docker: mount ไฟล์ CA '
             'เข้าคอนเทนเนอร์ <code>api</code> แล้วตั้งค่านี้ใน <code>docker-compose.override.yml</code> · ห้ามปิดการตรวจใบรับรอง'),
            ('<code>npm install</code> ล้มที่ better-sqlite3', 'ขาดเครื่องมือ build · macOS: <code>xcode-select --install</code> · '
             'Linux: <code>sudo apt install build-essential python3</code> · Windows: ติดตั้ง Visual Studio Build Tools'),
            ('อยากล้างข้อมูลเริ่มใหม่', 'ทางที่ 2: ดับเบิลคลิก Reset PaynEat data · ทางที่ 3: <code>docker compose down -v</code> · '
             'ทางที่ 4: <code>cd backend &amp;&amp; npm run db:reset</code>'),
        ],
        'stuck_title': 'ยังติดอยู่?',
        'stuck_html': 'ถามได้ที่ <a href="' + ISSUES + '">GitHub Issues</a> หรือ <a href="' + LINKEDIN + '">LinkedIn</a> '
        '— บอกทางที่ใช้ ระบบปฏิบัติการ และข้อความที่ขึ้นบนจอ',
    },
}

EN = {
    'code': 'en',
    'file': 'install.en.html',
    'home': 'index.en.html',
    'readme': f'{REPO}/blob/main/README.en.md',
    'title': 'Install PaynEat POS',
    'description': 'Set up PaynEat POS step by step: try it in the browser, install on Windows with one line, '
    'run it with Docker so every device in the restaurant shares it, or run it from source.',
    'skip': 'Skip to choosing how to install',
    'nav': [('#choose', 'Choose'), ('#accounts', 'Demo accounts'), ('#live', 'Before going live'), ('#help', 'Troubleshooting')],
    'home_label': 'Home',
    'copy': 'Copy',
    'copied': 'Copied',
    'hero': {
        'kick': 'Install guide',
        'title': 'Four ways to run your restaurant on PaynEat POS',
        'lead': 'Pick the one that fits and follow it step by step. No sign-up, no fees, and your restaurant’s data stays on your own machine.',
        'chips': ['Free · Apache 2.0', 'No sign-up', 'Runs on the devices you already have'],
    },
    'choose': {
        'kick': 'First',
        'title': 'What do you want to do?',
        'sub': 'Not sure yet? Start with the first one — tap around until you’re happy, then install it for real.',
        'labels': ('Time', 'You need', 'Best for'),
        'recommended': 'Recommended',
    },
    'paths': [
        {
            'id': 'browser', 'icon': '🖥', 'name': 'Try it in the browser',
            'time': 'Right now', 'need': 'Any browser', 'who': 'Seeing it and tapping around before you decide',
            'cta': 'Open the demo', 'href': DEMO_URL,
        },
        {
            'id': 'windows', 'icon': '🪟', 'name': 'Windows, one line', 'recommended': True,
            'time': '3–5 minutes', 'need': 'Windows + Docker Desktop', 'who': 'Owners who want the real system on their own PC',
            'cta': 'How to install', 'href': '#windows',
        },
        {
            'id': 'docker', 'icon': '🐳', 'name': 'Docker for every device',
            'time': '10–15 minutes the first time', 'need': 'Docker Desktop (Windows / Mac / Linux)',
            'who': 'Restaurants where phones, tablets and the kitchen screen share one server',
            'cta': 'How to install', 'href': '#docker',
        },
        {
            'id': 'dev', 'icon': '🧑‍💻', 'name': 'Run from source',
            'time': 'About 5 minutes', 'need': 'Node.js 22 + Flutter 3.35', 'who': 'Developers who want to change or extend it',
            'cta': 'How to run', 'href': '#dev',
        },
    ],
    'sections': [
        {
            'id': 'windows', 'icon': '🪟', 'kick': 'Way 2 · Recommended for owners',
            'title': 'Install on Windows with one line',
            'intro': 'The real system — server, live updates across windows, a simulated scale and PDF receipts — '
            'without downloading code or building anything: the installer fetches ready-built images.',
            'facts': [('Time', '3–5 minutes (about 200 MB the first time)'), ('You need', '64-bit Windows + Docker Desktop'),
                      ('You get', 'PaynEat at http://localhost:8080 on this PC')],
            'steps': [
                {'title': 'Install and open Docker Desktop',
                 'html': 'Don’t have it? Download it from <a href="https://www.docker.com/products/docker-desktop/">docker.com</a>, '
                 'install it and open it. Wait until the bottom-left corner says <b>Engine running</b>.'},
                {'title': 'Open PowerShell',
                 'html': 'Press the <kbd>Windows</kbd> key, type <b>PowerShell</b> and press <kbd>Enter</kbd>.'},
                {'title': 'Paste this line and press Enter',
                 'html': 'Press <b>Copy</b> in the corner of the box, then right-click inside PowerShell to paste.',
                 'code': WIN_ONE_LINER, 'lang': 'PowerShell'},
                {'title': 'Wait, then sign in',
                 'html': 'Your browser opens <b>http://localhost:8080</b> by itself. Sign in with <code>admin</code> / <code>admin123</code>, '
                 'or tap a demo account button on the sign-in screen.'},
            ],
            'ok_html': 'PowerShell prints <b>PaynEat is ready: http://localhost:8080</b> in green and the browser shows the sign-in screen.',
            'after_title': 'Day to day',
            'after': [
                ('Start / stop / reset', 'The PaynEat-Demo folder in your user folder has double-click files: Start, Stop and Reset PaynEat data '
                 '(Reset erases every bill you tried and restores the sample data).'),
                ('After a restart', 'Open Docker Desktop and PaynEat comes back by itself.'),
                ('Update to the latest version', 'Paste the same line again. Your data stays.'),
            ],
            'note_html': '⚠️ Set up for trying it out only (demo accounts, simulated scale, emails never really sent), and it opens on this PC only '
            '— to let the restaurant’s phones and tablets connect, use <a href="#docker">way 3</a>. '
            'Want to read what the script does first? <a href="' + INSTALLER + '">install-demo.ps1</a>',
        },
        {
            'id': 'docker', 'icon': '🐳', 'kick': 'Way 3 · Every device in the restaurant',
            'title': 'Run it with Docker so every device connects',
            'intro': 'The server lives on one computer in the restaurant; staff phones, the cashier’s tablet and the kitchen screen open it in a browser. '
            'An order placed on one device shows up on the kitchen screen at once.',
            'facts': [('Time', '10–15 minutes the first time (under a minute after that)'), ('You need', 'Docker Desktop on Windows, Mac or Linux'),
                      ('You get', 'PaynEat at http://<this computer’s IP>:8080 from every device on the same Wi-Fi')],
            'steps': [
                {'title': 'Download the code',
                 'html': 'Easiest: <a href="' + ZIP + '">download the ZIP</a> and extract it — you get a folder called <code>PaynEat-main</code>. '
                 'If you have git, this works too:',
                 'code': 'git clone https://github.com/SuruchBoss/PaynEat.git', 'lang': 'Terminal'},
                {'title': 'Find this computer’s IP address',
                 'html': 'Windows: open PowerShell, type <code>ipconfig</code> and look for <b>IPv4 Address</b>. '
                 'Mac/Linux: <code>ifconfig | grep inet</code>. It looks like <code>192.168.1.15</code>.'},
                {'title': 'Set the server secret',
                 'html': 'Create a file named <code>.env</code> in the code folder (next to <code>docker-compose.yml</code>) containing a '
                 '<code>JWT_SECRET=</code> line with your own random value. Without it the system does not start and explains how to set it. '
                 'On Mac/Linux use the command below; in Windows PowerShell use <code>(&quot;JWT_SECRET=&quot; + [guid]::NewGuid().ToString(&quot;N&quot;) + [guid]::NewGuid().ToString(&quot;N&quot;)) | Out-File -Encoding ascii .env</code>.',
                 'code': 'echo "JWT_SECRET=$(openssl rand -hex 32)" > .env', 'lang': 'Terminal (Mac/Linux)'},
                {'title': 'Tell the app where the server is',
                 'html': 'Add this line to the same <code>.env</code> file, using your own IP. Skip this step if only this computer will use it.',
                 'code': 'API_BASE_URL=http://192.168.1.15:3000', 'lang': '.env'},
                {'title': 'Start it',
                 'html': 'Open a terminal (Windows: PowerShell) in the code folder and run this. The first time takes 5–10 minutes while the app is built.',
                 'code': 'docker compose up --build', 'lang': 'Terminal'},
                {'title': 'Open it on every device',
                 'html': 'On the same Wi-Fi, open <b>http://192.168.1.15:8080</b> (your IP) on phones, tablets or the kitchen screen. '
                 'On the server itself, <b>http://localhost:8080</b> works.'},
            ],
            'ok_html': 'The terminal shows <b>payneat-api</b> and <b>payneat-web</b>, and <b>http://localhost:3000/health</b> answers.',
            'after_title': 'Day to day',
            'after': [
                ('Stop it', 'Press <kbd>Ctrl</kbd>+<kbd>C</kbd> in the terminal, then run <code>docker compose down</code>.'),
                ('Start over with fresh data', '<code>docker compose down -v</code> (erases every bill and all data).'),
                ('Turn on the simulated scale and test emails', 'Add <code>SCALE_DRIVER=simulator</code> and <code>MAIL_TRANSPORT=json</code> to the same <code>.env</code> file, '
                 'then run <code>docker compose up --build</code> again. Never use the simulator in a real shop.'),
            ],
            'note_html': '💡 Another device can’t open it? Check it’s on the same Wi-Fi and that the server’s firewall allows ports 8080 and 3000. '
            'Before staff use it for real, go through the <a href="#live">go-live checklist</a>.',
        },
        {
            'id': 'dev', 'icon': '🧑‍💻', 'kick': 'Way 4 · For developers',
            'title': 'Run it from source',
            'intro': 'For changing the code, reading the log request by request, or running on a real phone through Flutter.',
            'facts': [('Time', 'About 5 minutes'), ('You need', 'Node.js 20 or later (22 recommended) + Flutter 3.35 or later'),
                      ('You get', 'The API at http://localhost:3000 and the app in Chrome')],
            'steps': [
                {'title': 'Get the code', 'code': 'git clone https://github.com/SuruchBoss/PaynEat.git\ncd PaynEat', 'lang': 'Terminal'},
                {'title': 'Window 1 — the server',
                 'html': '<code>.env</code> holds a <code>JWT_SECRET</code> for local use; without it the server refuses to start '
                 '(on Windows use <code>copy</code> instead of <code>cp</code>). The database and sample data are created for you.',
                 'code': 'cd backend\nnpm install\ncp .env.example .env\nnpm run dev', 'lang': 'Terminal 1'},
                {'title': 'Window 2 — the app', 'html': 'Open a new window and keep the first one running.',
                 'code': 'cd app\nflutter pub get\nflutter run -d chrome', 'lang': 'Terminal 2'},
            ],
            'ok_html': 'Window 1 prints a line with <b>PaynEat POS API listening on http://localhost:3000</b> and Chrome opens the sign-in screen.',
            'after_title': 'Handy shortcuts',
            'after': [
                ('Just the app, no server', '<code>flutter run -d chrome --dart-define=DEMO_MODE=true</code> (sample data in the browser, reset on refresh)'),
                ('A real phone on the same Wi-Fi', '<code>flutter run --dart-define=API_BASE_URL=http://&lt;your computer’s IP&gt;:3000</code>'),
                ('Android emulator', 'Points at <code>10.0.2.2:3000</code> by itself, nothing to set.'),
                ('Run the tests', '<code>cd backend &amp;&amp; npm test</code> · <code>cd app &amp;&amp; flutter test</code>'),
            ],
            'note_html': 'Architecture, the API and every test are described in the <a href="' + REPO + '/blob/main/README.en.md">README</a>.',
        },
    ],
    'accounts': {
        'kick': 'Demo accounts',
        'title': 'Sign in as any role',
        'sub': 'The sign-in screen has a button for every demo account — one tap and you’re in, nothing to type.',
        'cols': ('Role', 'Username', 'Password', 'What it sees'),
        'rows': [
            ('Administrator', 'Everything — dashboard, menu, staff, reports, settings'),
            ('Manager', 'Same as the administrator, but can’t delete user accounts'),
            ('Waiter', 'Floor plan, orders, kitchen screen'),
            ('Kitchen', 'The kitchen screen only'),
            ('Cashier', 'Floor plan, orders, reports'),
            ('Waiter, two branches', 'Like waiter1 but can pick a branch — typed by hand, and only with a real server (ways 2–4)'),
        ],
        'devices_title': 'Trying several devices at once',
        'devices_html': 'The browser demo keeps its data on each device separately — an order from a phone won’t reach a kitchen screen on another tablet. '
        'To watch orders move between devices, use <a href="#docker">way 3</a>, or open several windows on the one PC of <a href="#windows">way 2</a>. '
        'The globe button top right switches ไทย / English / 한국어 even before you sign in.',
    },
    'live': {
        'kick': 'Before going live',
        'title': 'Checklist before staff use it for real',
        'sub': 'The demo accounts and passwords above are published on the internet, so the system guards against them: '
        'in production mode it refuses to start while they’re still in place.',
        'items_html': [
            'Set <code>JWT_SECRET</code> to your own random value, for example from <code>openssl rand -hex 32</code>. With '
            '<code>NODE_ENV=production</code>, the server refuses to start with a sample value or one shorter than 32 characters.',
            'Set your own passwords for all six starting accounts (<code>SEED_ADMIN_PASSWORD</code> … <code>SEED_CASHIER_PASSWORD</code>), '
            'or turn off <code>AUTO_SEED</code> and create real staff accounts yourself.',
            'Set <code>CORS_ORIGIN</code> to the restaurant’s real address instead of <code>*</code>.',
            'Keep the database file and <code>.env</code> on the restaurant’s machine — never upload or share them — and back up regularly.',
            'Don’t use the one-line Windows installer for a real shop: it is set up for trying things out.',
            'If you connect PaynEat ERP, use its <code>https://</code> address. The POS never sends its credential over '
            '<code>http://</code> except to the same machine, and <code>ERP_ALLOW_INSECURE_HTTP</code> is only for a closed network. '
            'If the ERP’s certificate comes from the chain’s own CA, see “PaynEat ERP’s HTTPS certificate isn’t trusted” under troubleshooting.',
        ],
        'more_html': 'Every item in detail, and how to report a vulnerability: <a href="' + SECURITY + '">SECURITY.md</a>',
    },
    'help': {
        'kick': 'Troubleshooting',
        'title': 'Stuck? Tap the problem',
        'rows': [
            ('It says "port is already allocated"', 'Something else is using port 3000 or 8080. Close it (or a PaynEat you left running) and try again.'),
            ('It says "Docker Desktop is not running" or "is not installed"', 'Install Docker Desktop from docker.com if needed, open it, wait for <b>Engine running</b> in the bottom-left corner, then paste the line again.'),
            ('It says "PaynEat started but is not answering yet"', 'It is up but slow to answer. Wait a moment and open http://localhost:8080; if it still doesn’t open, check Docker Desktop → Containers → payneat.'),
            ('Docker sits on the Flutter step for ages', 'The first time downloads the Flutter SDK, about 2 GB. Let it finish (5–10 minutes); next time it’s cached.'),
            ('The page opens but sign-in fails', 'Open <b>http://localhost:3000/health</b>; if nothing answers, the server isn’t running. '
             'If you set <code>API_BASE_URL</code>, check the IP and run <code>docker compose up --build</code> again after changing it.'),
            ('A phone or tablet can’t connect', 'It has to be on the server’s Wi-Fi, use the IP rather than <code>localhost</code>, and the firewall must allow ports 8080 and 3000.'),
            ('Docker says "required variable JWT_SECRET is missing a value"', 'The server secret is not set yet. Create the '
             '<code>.env</code> file next to <code>docker-compose.yml</code> as in the "Set the server secret" step of <a href="#docker">way 3</a>, then run it again.'),
            ('It says JWT_SECRET must be set', 'There is no <code>.env</code> yet: run <code>cp .env.example .env</code> in <code>backend</code> '
             '(Windows: <code>copy</code>), then <code>npm run dev</code> again.'),
            ('Settings say “PaynEat ERP’s address must start with https://”', 'The POS sends its credential only over <code>https://</code>. '
             'Ask the ERP administrator for the ERP’s <code>https://</code> address. A <code>http://</code> address works only for an ERP '
             'on the same machine (<code>localhost</code>). If you connected over <code>http://</code> before this update, the POS has '
             'stopped sending the credential: save the <code>https://</code> address with the credential in Settings.'),
            ('Settings say “PaynEat ERP’s HTTPS certificate isn’t trusted”', 'The POS server doesn’t trust the certificate authority '
             'that issued the chain’s ERP certificate. Ask the ERP administrator for the CA file (PEM), and check it first: '
             '<code>curl --cacert chain-ca.pem https://your-erp-address/health</code> must answer <code>"status":"ok"</code>. '
             'Then restart the POS server with <code>NODE_EXTRA_CA_CERTS=/path/to/chain-ca.pem</code> in its environment '
             '(putting it in <code>backend/.env</code> has no effect: Node reads it at startup, before that file). Docker: mount the CA '
             'file into the <code>api</code> container and set it in <code>docker-compose.override.yml</code>. Never turn certificate checks off.'),
            ('<code>npm install</code> fails on better-sqlite3', 'Build tools are missing. macOS: <code>xcode-select --install</code> · '
             'Linux: <code>sudo apt install build-essential python3</code> · Windows: install Visual Studio Build Tools.'),
            ('I want to start over with fresh data', 'Way 2: double-click Reset PaynEat data · way 3: <code>docker compose down -v</code> · '
             'way 4: <code>cd backend &amp;&amp; npm run db:reset</code>'),
        ],
        'stuck_title': 'Still stuck?',
        'stuck_html': 'Ask on <a href="' + ISSUES + '">GitHub Issues</a> or <a href="' + LINKEDIN + '">LinkedIn</a> '
        '— say which way you used, your operating system and the message on screen.',
    },
}

KO = {
    'code': 'ko',
    'file': 'install.ko.html',
    'home': 'index.ko.html',
    'readme': f'{REPO}/blob/main/README.ko.md',
    'title': 'PaynEat POS 설치 안내',
    'description': 'PaynEat POS를 단계별로 설치하세요 — 브라우저에서 바로 체험, Windows에 한 줄로 설치, '
    'Docker로 매장의 모든 기기가 함께 쓰기, 또는 소스에서 직접 실행.',
    'skip': '설치 방법 선택으로 건너뛰기',
    'nav': [('#choose', '방법 고르기'), ('#accounts', '데모 계정'), ('#live', '운영 전 확인'), ('#help', '문제 해결')],
    'home_label': '홈',
    'copy': '복사',
    'copied': '복사됨',
    'hero': {
        'kick': '설치 안내',
        'title': 'PaynEat POS로 매장을 여는 네 가지 방법',
        'lead': '맞는 방법을 골라 한 단계씩 따라 하세요. 가입도 비용도 없고, 매장 데이터는 사장님 기기에 그대로 있습니다.',
        'chips': ['무료 · Apache 2.0', '가입 불필요', '가지고 계신 기기 그대로'],
    },
    'choose': {
        'kick': '먼저',
        'title': '무엇을 하고 싶으세요?',
        'sub': '아직 모르겠다면 첫 번째부터 — 충분히 눌러 보신 뒤에 실제로 설치하셔도 됩니다.',
        'labels': ('소요 시간', '필요한 것', '이런 분께'),
        'recommended': '추천',
    },
    'paths': [
        {
            'id': 'browser', 'icon': '🖥', 'name': '브라우저에서 체험',
            'time': '바로', 'need': '브라우저만 있으면 됩니다', 'who': '결정 전에 화면을 보고 직접 눌러 보고 싶은 분',
            'cta': '데모 열기', 'href': DEMO_URL,
        },
        {
            'id': 'windows', 'icon': '🪟', 'name': 'Windows 한 줄 설치', 'recommended': True,
            'time': '3~5분', 'need': 'Windows + Docker Desktop', 'who': '내 PC에서 실제 시스템을 써 보고 싶은 사장님',
            'cta': '설치 방법 보기', 'href': '#windows',
        },
        {
            'id': 'docker', 'icon': '🐳', 'name': 'Docker로 모든 기기 연결',
            'time': '처음 10~15분', 'need': 'Docker Desktop (Windows / Mac / Linux)',
            'who': '휴대폰·태블릿·주방 화면이 한 서버를 함께 쓰는 매장',
            'cta': '설치 방법 보기', 'href': '#docker',
        },
        {
            'id': 'dev', 'icon': '🧑‍💻', 'name': '소스에서 실행',
            'time': '약 5분', 'need': 'Node.js 22 + Flutter 3.35', 'who': '고치거나 확장하고 싶은 개발자',
            'cta': '실행 방법 보기', 'href': '#dev',
        },
    ],
    'sections': [
        {
            'id': 'windows', 'icon': '🪟', 'kick': '방법 2 · 사장님께 추천',
            'title': 'Windows에 한 줄로 설치',
            'intro': '서버, 창 사이 실시간 반영, 가상 저울, PDF 영수증까지 갖춘 실제 시스템을 코드 다운로드나 빌드 없이 — '
            '설치 프로그램이 미리 빌드된 이미지를 받아 옵니다.',
            'facts': [('소요 시간', '3~5분 (처음에 약 200MB 다운로드)'), ('필요한 것', '64비트 Windows + Docker Desktop'),
                      ('결과', '이 PC의 http://localhost:8080 에서 PaynEat 실행')],
            'steps': [
                {'title': 'Docker Desktop 설치 후 실행',
                 'html': '없으시면 <a href="https://www.docker.com/products/docker-desktop/">docker.com</a>에서 받아 설치하고 실행하세요. '
                 '왼쪽 아래에 <b>Engine running</b>이 뜰 때까지 기다립니다.'},
                {'title': 'PowerShell 열기',
                 'html': '<kbd>Windows</kbd> 키를 누르고 <b>PowerShell</b>을 입력한 뒤 <kbd>Enter</kbd>를 누르세요.'},
                {'title': '이 한 줄을 붙여 넣고 Enter',
                 'html': '상자 모서리의 <b>복사</b>를 누르고, PowerShell 창에서 마우스 오른쪽 버튼으로 붙여 넣으세요.',
                 'code': WIN_ONE_LINER, 'lang': 'PowerShell'},
                {'title': '잠시 기다린 뒤 로그인',
                 'html': '브라우저가 <b>http://localhost:8080</b> 을 알아서 엽니다. <code>admin</code> / <code>admin123</code>으로 로그인하거나 '
                 '로그인 화면의 데모 계정 버튼을 누르세요.'},
            ],
            'ok_html': 'PowerShell에 초록색으로 <b>PaynEat is ready: http://localhost:8080</b>이 나오고 브라우저에 로그인 화면이 뜨면 성공입니다.',
            'after_title': '매일 쓰실 때',
            'after': [
                ('시작 / 중지 / 초기화', '사용자 폴더의 PaynEat-Demo에 더블클릭 파일 Start, Stop, Reset PaynEat data가 있습니다 '
                 '(Reset은 체험한 계산서를 모두 지우고 예시 데이터로 되돌립니다).'),
                ('PC를 다시 켰을 때', 'Docker Desktop을 열면 PaynEat이 저절로 올라옵니다.'),
                ('최신 버전으로 업데이트', '같은 한 줄을 다시 붙여 넣으세요. 데이터는 그대로 남습니다.'),
            ],
            'note_html': '⚠️ 체험용 설정입니다 (데모 계정, 가상 저울, 실제로 보내지지 않는 이메일). 또한 이 PC에서만 열립니다 '
            '— 매장의 휴대폰과 태블릿까지 연결하시려면 <a href="#docker">방법 3</a>을 쓰세요. '
            '붙여 넣기 전에 스크립트 내용을 보시려면: <a href="' + INSTALLER + '">install-demo.ps1</a>',
        },
        {
            'id': 'docker', 'icon': '🐳', 'kick': '방법 3 · 매장의 모든 기기',
            'title': 'Docker로 실행해 모든 기기 연결하기',
            'intro': '서버는 매장 컴퓨터 한 대에 두고, 직원 휴대폰·캐셔 태블릿·주방 화면은 브라우저로 엽니다. '
            '한 기기에서 넣은 주문이 다른 기기의 주방 화면에 바로 뜹니다.',
            'facts': [('소요 시간', '처음 10~15분 (그다음부터는 1분 이내)'), ('필요한 것', 'Windows, Mac 또는 Linux의 Docker Desktop'),
                      ('결과', '같은 와이파이의 모든 기기에서 http://<이 컴퓨터 IP>:8080')],
            'steps': [
                {'title': '코드 내려받기',
                 'html': '가장 쉬운 방법: <a href="' + ZIP + '">ZIP 파일 내려받기</a> 후 압축을 풀면 <code>PaynEat-main</code> 폴더가 생깁니다. '
                 'git이 있으시면 이렇게 하셔도 됩니다:',
                 'code': 'git clone https://github.com/SuruchBoss/PaynEat.git', 'lang': 'Terminal'},
                {'title': '이 컴퓨터의 IP 찾기',
                 'html': 'Windows: PowerShell에서 <code>ipconfig</code>를 입력하고 <b>IPv4 Address</b>를 보세요. '
                 'Mac/Linux: <code>ifconfig | grep inet</code>. <code>192.168.1.15</code> 같은 모양입니다.'},
                {'title': '서버 비밀 값 설정',
                 'html': '코드 폴더(<code>docker-compose.yml</code> 옆)에 <code>.env</code> 파일을 만들고 <code>JWT_SECRET=</code> 뒤에 '
                 '매장 고유의 무작위 값을 넣으세요. 이 줄이 없으면 시스템이 시작되지 않고 설정 방법을 안내합니다. '
                 'Mac/Linux는 아래 명령을, Windows PowerShell은 <code>(&quot;JWT_SECRET=&quot; + [guid]::NewGuid().ToString(&quot;N&quot;) + [guid]::NewGuid().ToString(&quot;N&quot;)) | Out-File -Encoding ascii .env</code>를 사용하세요.',
                 'code': 'echo "JWT_SECRET=$(openssl rand -hex 32)" > .env', 'lang': 'Terminal (Mac/Linux)'},
                {'title': '앱에 서버 위치 알려 주기',
                 'html': '같은 <code>.env</code> 파일에 이 줄을 추가하세요. 숫자는 사장님 IP로 바꿉니다. '
                 '이 컴퓨터에서만 쓰실 거라면 건너뛰셔도 됩니다.',
                 'code': 'API_BASE_URL=http://192.168.1.15:3000', 'lang': '.env'},
                {'title': '시작하기',
                 'html': '코드 폴더에서 터미널(Windows는 PowerShell)을 열고 실행하세요. 처음에는 앱을 빌드하느라 5~10분 걸립니다.',
                 'code': 'docker compose up --build', 'lang': 'Terminal'},
                {'title': '모든 기기에서 열기',
                 'html': '같은 와이파이에서 휴대폰·태블릿·주방 화면으로 <b>http://192.168.1.15:8080</b> (사장님 IP)을 여세요. '
                 '서버 컴퓨터에서는 <b>http://localhost:8080</b> 도 됩니다.'},
            ],
            'ok_html': '터미널에 <b>payneat-api</b>와 <b>payneat-web</b>이 보이고 <b>http://localhost:3000/health</b> 가 응답하면 성공입니다.',
            'after_title': '매일 쓰실 때',
            'after': [
                ('중지', '터미널에서 <kbd>Ctrl</kbd>+<kbd>C</kbd>를 누른 뒤 <code>docker compose down</code>을 실행하세요.'),
                ('데이터를 처음부터', '<code>docker compose down -v</code> (계산서와 모든 데이터가 지워집니다)'),
                ('가상 저울과 테스트 이메일 켜기', '같은 <code>.env</code> 파일에 <code>SCALE_DRIVER=simulator</code>와 <code>MAIL_TRANSPORT=json</code>을 추가하고 '
                 '<code>docker compose up --build</code>를 다시 실행하세요. 실제 매장에서는 simulator를 쓰지 마세요.'),
            ],
            'note_html': '💡 다른 기기에서 안 열리면: 같은 와이파이인지, 서버 컴퓨터 방화벽이 8080과 3000 포트를 허용하는지 확인하세요. '
            '직원이 실제로 쓰기 전에 <a href="#live">운영 전 체크리스트</a>를 모두 마쳐 주세요.',
        },
        {
            'id': 'dev', 'icon': '🧑‍💻', 'kick': '방법 4 · 개발자용',
            'title': '소스에서 직접 실행',
            'intro': '코드를 고치거나, 요청마다 로그를 보거나, Flutter로 실제 휴대폰에서 돌려 볼 때.',
            'facts': [('소요 시간', '약 5분'), ('필요한 것', 'Node.js 20 이상(22 권장) + Flutter 3.35 이상'),
                      ('결과', 'http://localhost:3000 의 API와 Chrome의 앱')],
            'steps': [
                {'title': '코드 받기', 'code': 'git clone https://github.com/SuruchBoss/PaynEat.git\ncd PaynEat', 'lang': 'Terminal'},
                {'title': '창 1 — 서버',
                 'html': '<code>.env</code>에는 로컬용 <code>JWT_SECRET</code>이 들어 있고, 없으면 서버가 시작되지 않습니다 '
                 '(Windows는 <code>cp</code> 대신 <code>copy</code>). 데이터베이스와 예시 데이터는 자동으로 만들어집니다.',
                 'code': 'cd backend\nnpm install\ncp .env.example .env\nnpm run dev', 'lang': 'Terminal 1'},
                {'title': '창 2 — 앱', 'html': '새 창을 여세요. 첫 번째 창은 닫지 마세요.',
                 'code': 'cd app\nflutter pub get\nflutter run -d chrome', 'lang': 'Terminal 2'},
            ],
            'ok_html': '창 1에 <b>PaynEat POS API listening on http://localhost:3000</b> 줄이 나오고 Chrome에 로그인 화면이 뜨면 성공입니다.',
            'after_title': '자주 쓰는 방법',
            'after': [
                ('서버 없이 앱만', '<code>flutter run -d chrome --dart-define=DEMO_MODE=true</code> (브라우저 안의 예시 데이터, 새로고침하면 초기화)'),
                ('같은 와이파이의 실제 휴대폰', '<code>flutter run --dart-define=API_BASE_URL=http://&lt;컴퓨터 IP&gt;:3000</code>'),
                ('Android 에뮬레이터', '<code>10.0.2.2:3000</code>을 자동으로 사용합니다. 설정할 것이 없습니다.'),
                ('테스트 실행', '<code>cd backend &amp;&amp; npm test</code> · <code>cd app &amp;&amp; flutter test</code>'),
            ],
            'note_html': '구조, API, 모든 테스트는 <a href="' + REPO + '/blob/main/README.en.md">README (영문)</a>에 있습니다.',
        },
    ],
    'accounts': {
        'kick': '데모 계정',
        'title': '어떤 역할로든 로그인',
        'sub': '로그인 화면에 모든 데모 계정 버튼이 있어 한 번 누르면 바로 들어갑니다. 입력하실 필요가 없습니다.',
        'cols': ('역할', '아이디', '비밀번호', '볼 수 있는 것'),
        'rows': [
            ('관리자', '전부 — 대시보드, 메뉴, 직원, 리포트, 설정'),
            ('매니저', '관리자와 같지만 계정 삭제는 불가'),
            ('홀 직원', '테이블 배치도, 주문, 주방 화면'),
            ('주방', '주방 화면만'),
            ('캐셔', '테이블 배치도, 주문, 리포트'),
            ('홀 직원 (2개 지점)', 'waiter1과 같지만 지점 선택 가능 — 직접 입력, 실제 서버에서만 (방법 2~4)'),
        ],
        'devices_title': '여러 기기로 함께 써 보기',
        'devices_html': '브라우저 데모는 기기마다 데이터를 따로 저장합니다 — 휴대폰에서 주문해도 다른 태블릿의 주방 화면에는 나타나지 않습니다. '
        '기기 사이로 주문이 오가는 걸 보시려면 <a href="#docker">방법 3</a>을 쓰시거나, <a href="#windows">방법 2</a>의 PC 한 대에서 창을 여러 개 여세요. '
        '오른쪽 위 지구본 버튼으로 로그인 전에도 ไทย / English / 한국어를 바꿀 수 있습니다.',
    },
    'live': {
        'kick': '운영 전 확인',
        'title': '직원이 실제로 쓰기 전 체크리스트',
        'sub': '위의 데모 계정과 비밀번호는 인터넷에 공개되어 있어서 시스템이 막아 두었습니다: '
        '운영 모드에서 데모 비밀번호가 남아 있으면 서버가 아예 켜지지 않습니다.',
        'items_html': [
            '<code>JWT_SECRET</code>을 매장 고유의 무작위 값으로 — 예: <code>openssl rand -hex 32</code>. <code>NODE_ENV=production</code>에서는 '
            '예시 값이나 32자보다 짧은 값이면 서버가 시작되지 않습니다.',
            '시작 계정 6개의 비밀번호를 모두 직접 정하거나(<code>SEED_ADMIN_PASSWORD</code> … <code>SEED_CASHIER_PASSWORD</code>), '
            '<code>AUTO_SEED</code>를 끄고 실제 직원 계정을 직접 만드세요.',
            '<code>CORS_ORIGIN</code>을 <code>*</code> 대신 매장의 실제 주소로.',
            '데이터베이스 파일과 <code>.env</code>는 매장 기기에만 — 업로드하거나 공유하지 말고, 정기적으로 백업하세요.',
            'Windows 한 줄 설치는 실제 매장에 쓰지 마세요. 체험용 설정입니다.',
            'PaynEat ERP에 연결한다면 <code>https://</code> 주소를 쓰세요. POS는 같은 기기가 아니면 자격 증명을 <code>http://</code>로 '
            '보내지 않으며, <code>ERP_ALLOW_INSECURE_HTTP</code>는 닫힌 네트워크에서만 씁니다. ERP 인증서를 체인의 내부 CA가 발급했다면 '
            '문제 해결의 “PaynEat ERP의 HTTPS 인증서를 신뢰할 수 없습니다”를 보세요.',
        ],
        'more_html': '항목별 자세한 내용과 취약점 신고 방법: <a href="' + SECURITY + '">SECURITY.md</a>',
    },
    'help': {
        'kick': '문제 해결',
        'title': '막히셨나요? 증상을 눌러 보세요',
        'rows': [
            ('"port is already allocated"가 나와요', '다른 프로그램이 3000 또는 8080 포트를 쓰고 있습니다. 그 프로그램(또는 켜 둔 PaynEat)을 닫고 다시 해 보세요.'),
            ('"Docker Desktop is not running" 또는 "is not installed"가 나와요', '필요하면 docker.com에서 Docker Desktop을 설치하고 실행한 뒤, 왼쪽 아래에 <b>Engine running</b>이 뜨면 한 줄을 다시 붙여 넣으세요.'),
            ('"PaynEat started but is not answering yet"가 나와요', '켜졌지만 응답이 늦는 중입니다. 잠시 뒤 http://localhost:8080 을 열어 보시고, 그래도 안 되면 Docker Desktop → Containers → payneat에서 원인을 확인하세요.'),
            ('Docker가 Flutter 단계에서 오래 멈춰 있어요', '처음에는 Flutter SDK 약 2GB를 받습니다. 5~10분 기다려 주세요. 다음부터는 캐시를 씁니다.'),
            ('화면은 열리는데 로그인이 안 돼요', '<b>http://localhost:3000/health</b> 를 열어 보세요. 응답이 없으면 서버가 아직 안 켜진 것입니다. '
             '<code>API_BASE_URL</code>을 설정하셨다면 IP를 확인하고, 바꾼 뒤 <code>docker compose up --build</code>를 다시 실행하세요.'),
            ('휴대폰이나 태블릿이 연결되지 않아요', '서버와 같은 와이파이여야 하고, <code>localhost</code> 대신 IP를 쓰고, 방화벽이 8080과 3000 포트를 허용해야 합니다.'),
            ('Docker에 "required variable JWT_SECRET is missing a value"가 나와요', '서버 비밀 값이 아직 없습니다. '
             '<a href="#docker">방법 3</a>의 "서버 비밀 값 설정" 단계대로 <code>docker-compose.yml</code> 옆에 <code>.env</code>를 만든 뒤 다시 실행하세요.'),
            ('JWT_SECRET을 설정하라고 나와요', '<code>.env</code>가 아직 없습니다. <code>backend</code>에서 <code>cp .env.example .env</code> '
             '(Windows: <code>copy</code>) 후 <code>npm run dev</code>를 다시 실행하세요.'),
            ('설정 화면에 “PaynEat ERP 주소는 https://로 시작해야 합니다”가 나와요', 'POS는 자격 증명을 <code>https://</code>로만 보냅니다. '
             'ERP 관리자에게 ERP의 <code>https://</code> 주소를 받으세요. <code>http://</code> 주소는 같은 기기에서 도는 ERP(<code>localhost</code>)에만 '
             '쓸 수 있습니다. 업데이트 전에 <code>http://</code>로 연결했다면 POS가 자격 증명 전송을 멈췄으니, 설정에서 <code>https://</code> 주소와 '
             '자격 증명을 다시 저장하세요.'),
            ('설정 화면에 “PaynEat ERP의 HTTPS 인증서를 신뢰할 수 없습니다”가 나와요', 'POS 서버가 체인의 ERP 인증서를 발급한 CA를 아직 신뢰하지 '
             '않습니다. ERP 관리자에게 CA 파일(PEM)을 받아 먼저 확인하세요: <code>curl --cacert chain-ca.pem https://ERP-주소/health</code>가 '
             '<code>"status":"ok"</code>를 돌려줘야 합니다. 그다음 환경에 <code>NODE_EXTRA_CA_CERTS=/경로/chain-ca.pem</code>을 두고 POS 서버를 '
             '다시 시작하세요(<code>backend/.env</code>에 넣으면 효과가 없습니다 — Node가 그 파일보다 먼저, 시작할 때 읽습니다). Docker: CA 파일을 '
             '<code>api</code> 컨테이너에 마운트하고 <code>docker-compose.override.yml</code>에서 설정하세요. 인증서 검사는 절대 끄지 마세요.'),
            ('<code>npm install</code>이 better-sqlite3에서 실패해요', '빌드 도구가 없습니다. macOS: <code>xcode-select --install</code> · '
             'Linux: <code>sudo apt install build-essential python3</code> · Windows: Visual Studio Build Tools 설치.'),
            ('데이터를 처음부터 다시 하고 싶어요', '방법 2: Reset PaynEat data 더블클릭 · 방법 3: <code>docker compose down -v</code> · '
             '방법 4: <code>cd backend &amp;&amp; npm run db:reset</code>'),
        ],
        'stuck_title': '그래도 안 되나요?',
        'stuck_html': '<a href="' + ISSUES + '">GitHub Issues</a> 또는 <a href="' + LINKEDIN + '">LinkedIn</a>으로 물어봐 주세요 '
        '— 쓰신 방법, 운영체제, 화면에 나온 메시지를 함께 알려 주세요.',
    },
}

INSTALL_LANGS = [TH, EN, KO]
