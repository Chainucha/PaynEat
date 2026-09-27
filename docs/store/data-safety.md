# คำตอบแบบฟอร์มของ Google Play — Data safety และคำประกาศอื่นๆ

คัดลอกไปกรอกใน Play Console → **นโยบาย → เนื้อหาแอป** (App content) ขั้นตอนทั้งหมดอยู่ใน [README.md](README.md)
คำถามในแบบฟอร์มเขียนตามภาษาอังกฤษของ Play Console เพื่อให้เทียบช่องได้ตรง

> **ชุด A ใช้กับ build โหมดสาธิตของ ticket 29a เท่านั้น** ก่อนอัปโหลด build แรกที่ต่อเซิร์ฟเวอร์ร้านได้ (ticket 29b)
> ต้องกรอกใหม่ตาม [ชุด B](#ชุด-b--หลัง-ticket-29b-แอปต่อเซิร์ฟเวอร์ร้านได้) — Google ถือว่าแบบฟอร์มต้องตรงกับ build ที่เผยแพร่อยู่
>
> ตรวจกับโค้ดเมื่อ 2026-09-27: `app/pubspec.yaml` ไม่มี SDK โฆษณา วิเคราะห์การใช้งาน หรือรายงานแอปค้าง
> สิทธิ์ Android มีแค่ `INTERNET` (`app/android/app/src/main/AndroidManifest.xml`) กับ `CAMERA` (มากับ `mobile_scanner`)
> และโหมดสาธิตไม่เรียกเซิร์ฟเวอร์ใด (`app/lib/app/di/bindings/data_source_bindings.dart`) — เพิ่ม dependency ที่ส่งข้อมูล
> ออกนอกเครื่องหรือขอสิทธิ์ใหม่เมื่อไหร่ ต้องแก้ไฟล์นี้และหน้านโยบาย (`docs/generator/landing/privacy_content.py`) ใน PR เดียวกัน

## อะไรออกจากเครื่องบ้างใน build โหมดสาธิต

| ส่งอะไร | ไปที่ไหน | ใครเป็นคนส่ง |
|---|---|---|
| ข้อมูลวินิจฉัยของ ML Kit: รุ่นเครื่อง/ระบบปฏิบัติการ, ชื่อและเวอร์ชันแอป, รหัสประจำการติดตั้ง, ตัวเลขประสิทธิภาพ, รหัสข้อผิดพลาด | Google (HTTPS) | Google ML Kit ที่ `mobile_scanner` ใช้บน Android เมื่อเปิดตัวสแกนบาร์โค้ด |
| ใบเสร็จ (คำสั่ง ESC/POS) | เครื่องพิมพ์ในวงเครือข่ายตามที่อยู่ที่ผู้ใช้ตั้งเอง | แอป เมื่อผู้ใช้กดพิมพ์ |

ข้อมูลร้าน เมนู ออเดอร์ และลูกค้าในโหมดสาธิตเป็นข้อมูลสมมติที่สร้างและเก็บในเครื่อง ไม่ออกจากเครื่อง ภาพจากกล้องประมวลผลในเครื่อง

รายละเอียดข้อมูลของ ML Kit มาจาก [หน้าการเปิดเผยข้อมูลของ ML Kit](https://developers.google.com/ml-kit/android-data-disclosure)
ของ Google (ข้อมูลอุปกรณ์และแอป ตัวระบุ ตัวเลขประสิทธิภาพ การตั้งค่า API ประเภทเหตุการณ์ และรหัสข้อผิดพลาด ใช้เพื่อวินิจฉัยและวิเคราะห์
เข้ารหัสด้วย HTTPS ไม่แบ่งปันให้บุคคลที่สาม) — **เปิดหน้านั้นอ่านอีกครั้งตอนกรอก** เพราะ Google แก้หน้าได้โดยไม่แจ้ง และตอนเขียนไฟล์นี้
อ่านได้จากสรุปผลการค้นหาเท่านั้น (เครือข่ายของเครื่องที่เขียนเปิดหน้านั้นตรงๆ ไม่ได้)

ใบเสร็จที่ส่งไปเครื่องพิมพ์ของผู้ใช้เองไม่ต้องกรอก: ส่งไปอุปกรณ์ที่ผู้ใช้เลือกเองตามคำสั่งของผู้ใช้ ผู้พัฒนาไม่ได้รับข้อมูลนั้น

## ชุด A — build โหมดสาธิต (ticket 29a)

### Data collection and security

| คำถาม | คำตอบ |
|---|---|
| Does your app collect or share any of the required user data types? | **Yes** (เพราะข้อมูลวินิจฉัยของ ML Kit) |
| Is all of the user data collected by your app encrypted in transit? | **Yes** (ML Kit ส่งผ่าน HTTPS) |
| Which of the following methods of account creation does your app support? | **My app does not allow users to create an account** (บัญชีเดโมมีมาในแอป ไม่มีการสมัคร) |
| Do you provide a way for users to request that their data is deleted? | **No** (ผู้พัฒนาไม่ได้ถือข้อมูลนี้ Google เก็บตามนโยบายของ ML Kit) |

### Data types

เลือกเฉพาะสองประเภทนี้ ประเภทอื่นทั้งหมดเว้นว่าง

| ประเภท | Collected | Shared | Processed ephemerally | Required or optional | Purposes |
|---|---|---|---|---|---|
| App info and performance → **Diagnostics** | Yes | No | No | Required | Analytics |
| Device or other IDs → **Device or other IDs** | Yes | No | No | Required | Analytics |

"Shared = No" เพราะ Google รับข้อมูลในฐานะผู้ให้บริการ SDK ที่ประมวลผลแทนแอป ซึ่ง Google ไม่นับเป็นการแบ่งปัน
"Required" เพราะผู้ใช้ปิดการส่งข้อมูลวินิจฉัยของ ML Kit เองไม่ได้ (เลือกไม่ใช้ตัวสแกนได้ แต่ไม่ใช่สวิตช์ในแอป)

## คำประกาศอื่นในหน้าเนื้อหาแอป

| หัวข้อ | คำตอบ |
|---|---|
| Privacy policy | `https://suruchboss.github.io/PaynEat/privacy.html` (มีฉบับ `privacy.en.html` และ `privacy.ko.html`) |
| Ads | **No, my app does not contain ads** |
| App access | **All or some functionality is restricted** → ใส่คำแนะนำ: *"Demo mode, no credentials needed. On the sign-in screen, tap any account under the demo accounts (Waiter, Kitchen, Cashier, Manager, Admin) to sign in with one tap. Sign out from the Profile tab to try another role."* |
| Content rating | ตอบแบบสอบถาม IARC หมวด **Utility, Productivity, Communication, or Other** ตอบ No ทุกข้อเรื่องความรุนแรง เพศ ยาเสพติด การพนัน ฯลฯ — แอปไม่มีเนื้อหาจากผู้ใช้ที่แชร์ถึงกัน และไม่มีการซื้อในแอป |
| Target audience | **18 ขึ้นไป** อย่างเดียว (เครื่องมือของพนักงานร้าน) · ไม่ดึงดูดเด็ก |
| News app | No |
| COVID-19 contact tracing and status | ไม่ใช่แอปประเภทนี้ |
| Government app | No |
| Financial features | **My app doesn't provide any financial features** — แอปบันทึกการขายของร้าน ไม่ได้ให้บริการทางการเงิน ไม่ถือเงิน และไม่ประมวลผลการชำระเงินเอง (QR พร้อมเพย์เป็นแค่ภาพให้ลูกค้าสแกนด้วยแอปธนาคารของลูกค้าเอง) |
| Health apps | ไม่มีฟีเจอร์ด้านสุขภาพ |

## ชุด B — หลัง ticket 29b (แอปต่อเซิร์ฟเวอร์ร้านได้)

**ร่างไว้ให้ PR ของ 29b ตัดสินใจ — ยังไม่ใช้** เมื่อต่อเซิร์ฟเวอร์ร้าน แอปส่งข้อมูลต่อไปนี้ไปที่เซิร์ฟเวอร์ของร้าน (ผู้พัฒนาไม่ได้เป็นผู้ดูแล):
ชื่อผู้ใช้และรหัสผ่านของพนักงาน, ออเดอร์และการชำระเงิน, ชื่อ เบอร์โทร และแต้มของสมาชิก, รูปเมนู

นิยามของ Google คือ "collection = ส่งข้อมูลออกจากเครื่อง" จึงควรตอบแบบระวังไว้ก่อนดังนี้ แล้วตรวจกับหน้าช่วยเหลือของ Google
([Data safety](https://support.google.com/googleplay/android-developer/answer/10787469)) อีกครั้งตอนทำ 29b ว่าข้อมูลที่ส่งไปเซิร์ฟเวอร์
ที่ผู้ใช้กำหนดเองนับอย่างไร:

| ประเภท | Collected | Shared | Required or optional | Purposes |
|---|---|---|---|---|
| Personal info → Name | Yes | No | Optional (เฉพาะร้านที่ใช้สมาชิก) | App functionality |
| Personal info → Phone number | Yes | No | Optional | App functionality |
| Personal info → User IDs (ชื่อผู้ใช้ของพนักงาน) | Yes | No | Required | App functionality, Account management |
| Financial info → Purchase history (ออเดอร์) | Yes | No | Required | App functionality |
| Photos and videos → Photos (รูปเมนู) | Yes | No | Optional | App functionality |
| App info and performance → Diagnostics (ML Kit) | Yes | No | Required | Analytics |
| Device or other IDs (ML Kit) | Yes | No | Required | Analytics |

- **Encrypted in transit** ต้องตอบ **No** ถ้ายอมให้ต่อ `http://` ในร้าน (ticket 29 อนุญาตพร้อมคำเตือน) — ตอบ Yes ได้เฉพาะเมื่อบังคับ HTTPS ทุกการเชื่อมต่อ
- **Deletion**: ข้อมูลอยู่ที่ร้าน — ผู้ใช้ขอลบกับร้านโดยตรง (เขียนไว้ในนโยบายแล้ว)
- แก้หน้านโยบายส่วน "โหมดสาธิต" ให้เป็นอดีต และคำอธิบาย store ส่วน "สำคัญ" ใน PR เดียวกัน
