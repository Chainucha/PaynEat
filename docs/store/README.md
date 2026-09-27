# PaynEat POS บน Google Play — คู่มือเจ้าของ

คู่มือนี้พาจาก "ยังไม่มีบัญชี" ไปถึง "แอปอยู่ใน closed testing และกำลังนับ 14 วัน" (ticket
[29a](../tickets/29-android-google-play.md), `docs/DECISIONS.md` #75) ส่วนที่โค้ดทำให้แล้ว: build `.aab` ที่ลงนามใน CI จาก tag,
หน้านโยบายความเป็นส่วนตัว, คำตอบแบบฟอร์ม, ข้อความและภาพหน้า store — ส่วนที่เหลือต้องทำในบัญชีของเจ้าของเอง

**สถานะตอนนี้**: build ที่ได้เป็น**โหมดสาธิต** (`DEMO_MODE=true`) ข้อมูลร้านสมมติอยู่ในเครื่อง ยังต่อเซิร์ฟเวอร์ร้านจริงไม่ได้
จนกว่า ticket 29b จะเสร็จ — เอาขึ้น closed testing ได้ทันทีเพื่อเริ่มนับเวลา ไม่ต้องรอ 29b

## ในโฟลเดอร์นี้

| ไฟล์ | ใช้ทำอะไร |
|---|---|
| [`listing.th.md`](listing.th.md), [`listing.en.md`](listing.en.md) | ชื่อ คำอธิบายสั้น/ยาว หมวดหมู่ และตารางว่าภาพไหนลงช่องไหน |
| [`data-safety.md`](data-safety.md) | คำตอบแบบฟอร์ม Data safety และคำประกาศอื่นในหน้า "เนื้อหาแอป" |
| [`assets/`](assets/) | ไอคอน 512, feature graphic, ภาพหน้าจอมือถือ/แท็บเล็ต ภาษาไทยและอังกฤษ |

ภาพทั้งหมดสร้างจาก `docs/generator/store/build_store_assets.py` โดยใช้ภาพหน้าจอจาก golden test ใน `docs/screenshots`
(ไม่ถ่ายใหม่ด้วยมือ) — สคริปต์เดียวกันวาดไอคอนแอป Android ด้วย ถ้าหน้าจอเปลี่ยน ให้รันตัวถ่ายภาพหน้าจอก่อนแล้วรัน
`python3 docs/generator/store/build_store_assets.py` ซ้ำ

หน้านโยบายความเป็นส่วนตัว (ลิงก์ที่กรอกใน Play Console):
[ไทย](https://suruchboss.github.io/PaynEat/privacy.html) ·
[English](https://suruchboss.github.io/PaynEat/privacy.en.html) ·
[한국어](https://suruchboss.github.io/PaynEat/privacy.ko.html)
— แก้เนื้อหาที่ `docs/generator/landing/privacy_content.py` แล้วรัน `python3 docs/generator/landing/build_landing.py`

## ครั้งแรก — ทำตามลำดับ

### 1. ก่อนเริ่ม (ทำครั้งเดียว)

- **เปิดบัญชี [Google Play Console](https://play.google.com/console/signup)** (ค่าสมัครครั้งเดียว)
  - บัญชี**บุคคล**ที่เปิดหลัง 13 พ.ย. 2023 ต้องทดสอบแบบปิดกับผู้ทดสอบ**อย่างน้อย 12 คน ที่อยู่ในการทดสอบต่อเนื่องอย่างน้อย 14 วัน**
    ก่อนขอขึ้น production ([หน้าช่วยเหลือของ Google](https://support.google.com/googleplay/android-developer/answer/14151465),
    ตรวจเมื่อ 2026-09-27) — **หาผู้ทดสอบ 12 คนไว้ตั้งแต่ตอนนี้** ทุกคนต้องมีบัญชี Google และเครื่อง Android
  - บัญชี**องค์กร**ต้องมีหมายเลข D-U-N-S แต่ไม่ติดเงื่อนไข 12 คน/14 วัน
- **ตรวจเครื่องหมายการค้าชื่อ PaynEat** (ERP ADR-0015 ข้อ 10) ก่อนเปิดหน้า store สาธารณะ — closed testing ยังไม่สาธารณะ
  เริ่มได้เลย แต่ต้องเสร็จก่อนขอ production
- **ตัดสินใจ applicationId ให้จบก่อนอัปโหลดครั้งแรก**: ตอนนี้คือ `com.payneat.payneat_pos`
  (`app/android/app/build.gradle.kts`) **เปลี่ยนไม่ได้อีกเลยหลังอัปโหลด .aab แรก** — ถ้าอยากได้ชื่ออื่นต้องแก้ใน PR ก่อน

### 2. สร้าง upload key

upload key ใช้ลงนามไฟล์ที่ส่งให้ Google ส่วนกุญแจที่ลงนามแอปจริงบนเครื่องผู้ใช้ Google เก็บให้ (Play App Signing)
ถ้า upload key หาย ขอรีเซ็ตได้จาก Play Console → Test and release → App integrity

รันบนเครื่องตัวเอง (ต้องมี Java/JDK) **นอกโฟลเดอร์ repo**:

```bash
keytool -genkeypair -v -keystore payneat-upload.jks -storetype JKS \
  -alias upload -keyalg RSA -keysize 2048 -validity 10000
```

- ตั้งรหัสผ่านที่เดายาก จดเก็บใน password manager พร้อมสำรองไฟล์ `payneat-upload.jks` ไว้ที่ปลอดภัย
- **ห้าม commit ไฟล์ key หรือรหัสผ่านเข้า repo** และห้ามวางใน issue, PR หรือแชต — repo นี้เป็นสาธารณะ
  (`app/android/.gitignore` กัน `*.jks`, `*.keystore`, `key.properties` ไว้อีกชั้น)

### 3. ใส่ key ใน GitHub Secrets

GitHub → repo → **Settings → Secrets and variables → Actions → New repository secret** ใส่ 4 ตัว:

| ชื่อ secret | ค่า |
|---|---|
| `ANDROID_UPLOAD_KEYSTORE_BASE64` | ผลของ `base64 -w0 payneat-upload.jks` (macOS: `base64 -i payneat-upload.jks`) |
| `ANDROID_UPLOAD_STORE_PASSWORD` | รหัสผ่านของ keystore |
| `ANDROID_UPLOAD_KEY_ALIAS` | `upload` (หรือ alias ที่ตั้งในขั้น 2) |
| `ANDROID_UPLOAD_KEY_PASSWORD` | รหัสผ่านของ key (keytool รุ่นใหม่ใช้ค่าเดียวกับ keystore) |

### 4. ออก build ด้วย tag

```bash
git checkout main && git pull
git tag v1.0.0
git push origin v1.0.0
```

workflow **Android store bundle (Google Play)** (`.github/workflows/android-release.yml`) จะ build `.aab` โหมดสาธิต ลงนามด้วย
upload key ตรวจว่าไม่ใช่ debug key แล้วแนบไฟล์ `payneat-pos-1.0.0-demo.aab` ไว้ที่ GitHub Release ของ tag นั้น

- `versionCode` มาจาก tag: `vX.Y.Z` → `X×1,000,000 + Y×1,000 + Z` (v1.0.0 = 1000000, v1.0.1 = 1000001)
  Play ไม่รับ versionCode ซ้ำหรือต่ำกว่าเดิม **อัปโหลดใหม่ทุกครั้งต้องใช้ tag ใหม่ที่สูงขึ้น**
- ถ้ายังไม่ได้ใส่ secret ครบ งานจะหยุดพร้อมบอกชื่อ secret ที่ขาด — ไม่มีทางได้ไฟล์ debug ขึ้น store
- PR ที่แตะไฟล์ Android จะรัน workflow เดียวกันด้วย key ทิ้ง (ไม่ใช้ secret) เพื่อพิสูจน์ว่ายัง build และลงนามได้

### 5. สร้างแอปใน Play Console

**Create app** → ชื่อ `PaynEat POS` · ภาษาเริ่มต้น **ไทย – th-TH** · App · Free แล้วกรอก:

1. **หน้า store** (Grow users → Store presence → Main store listing) — จาก [`listing.th.md`](listing.th.md)
   แล้วเพิ่มคำแปล English (United States) จาก [`listing.en.md`](listing.en.md)
2. **เนื้อหาแอป** (Policy → App content) — ทุกหัวข้อจาก [`data-safety.md`](data-safety.md) ชุด A
3. **Closed testing** (Test and release → Testing → Closed testing → Create track)
   - Testers: ใส่อีเมลผู้ทดสอบ (หรือ Google Group) ให้ครบ 12 คนขึ้นไป
   - Create release → อัปโหลด `.aab` จาก GitHub Release → ใส่ release notes สั้นๆ เช่น "เวอร์ชันสาธิตสำหรับทดสอบ"
   - ส่งตรวจ (Send for review) — ครั้งแรกอาจใช้หลายวัน
4. ส่งลิงก์ opt-in ให้ผู้ทดสอบ ทุกคนต้องกดเข้าร่วมและ**ติดตั้งค้างไว้ต่อเนื่อง 14 วัน** ขอให้เปิดใช้จริงบ้าง
   Google ถามถึงการทดสอบตอนขอ production

### 6. หลังครบ 14 วัน

Dashboard → **Apply for production** ตอบคำถามเรื่องการทดสอบ (ผู้ทดสอบใช้อะไร พบปัญหาอะไร แก้อะไรไป)
— ควรรอ ticket 29b เสร็จก่อน เพื่อให้เวอร์ชัน production ต่อเซิร์ฟเวอร์ร้านจริงได้

## ออกเวอร์ชันถัดไป

1. merge งานเข้า `main`
2. `git tag vX.Y.Z` (สูงกว่าเดิม) แล้ว `git push origin vX.Y.Z`
3. ดาวน์โหลด `.aab` จาก GitHub Release → Play Console → track ที่ต้องการ → Create release

**build แรกหลัง ticket 29b** (แอปต่อเซิร์ฟเวอร์ร้านได้): ก่อนอัปโหลด ต้องกรอก Data safety ใหม่ตาม
[ชุด B](data-safety.md#ชุด-b--หลัง-ticket-29b-แอปต่อเซิร์ฟเวอร์ร้านได้) และแก้ย่อหน้า "สำคัญ" ในคำอธิบาย store — ทั้งสองอย่าง
ต้องตรงกับ build ที่เผยแพร่อยู่เสมอ
