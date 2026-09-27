# ร่วมพัฒนา PaynEat POS

ขอบคุณที่สนใจร่วมพัฒนา! เอกสารนี้สรุปขั้นตอนตั้งแต่ตั้งค่าเครื่องจนถึงเปิด Pull Request

## เตรียมเครื่อง

ทำตาม [🚀 วิธีรัน ใน README](README.md#-วิธีรัน-สำหรับผู้ที่มาตรวจผลงาน) เพื่อรันทั้ง backend
และแอปในเครื่องให้ได้ก่อน — ใช้เวลาประมาณ 5 นาที

โครงสร้างโปรเจกต์เป็น monorepo 2 ส่วน:

- `app/` — Flutter (GetX + Clean Architecture) รันได้ทั้ง Android/iOS/Web
- `backend/` — Node.js/Express + SQLite + Socket.IO

## ก่อนเริ่มเขียนโค้ด

- อ่าน [`docs/CODING_STANDARDS.md`](docs/CODING_STANDARDS.md) — มาตรฐาน Clean Code, การใช้ GetX,
  ทิศทาง dependency ของ Clean Architecture และตำแหน่งไฟล์ตามชั้นสถาปัตยกรรม
- อ่าน [`docs/DECISIONS.md`](docs/DECISIONS.md) — เหตุผลเบื้องหลังการตัดสินใจเชิงออกแบบที่สำคัญ
  (เช่น ทำไมเก็บเงินเป็นสตางค์, ทำไมเลือก SQLite) กันเสนอเปลี่ยนสิ่งที่ตั้งใจทำแบบนี้อยู่แล้วโดยไม่รู้ตัว
- ถ้าจะทำฟีเจอร์ใหญ่หรือเปลี่ยนสถาปัตยกรรม แนะนำเปิด Issue คุยแนวทางก่อนลงมือ กันเสียเวลาทำแล้วไม่ตรงทิศทาง

## Workflow

1. Fork repo แล้ว clone เครื่องตัวเอง
2. สร้าง branch ใหม่จาก `main` ตั้งชื่อสื่อความหมาย เช่น `fix/split-bill-rounding` หรือ
   `feat/loyalty-points`
3. เขียนโค้ด + เทสต์คู่กัน (ดูหัวข้อเทสต์ด้านล่าง)
4. รันชุดตรวจสอบให้ผ่านครบก่อน commit (ดูหัวข้อถัดไป)
5. Commit ด้วยข้อความสื่อความหมาย — จะเขียนไทยหรืออังกฤษก็ได้ แต่ให้บอกว่า "ทำไม" ไม่ใช่แค่ "ทำอะไร"
   โปรเจกต์นี้ใช้รูปแบบ `type(scope): คำอธิบาย` เช่น `feat(app): ...`, `fix(backend): ...`,
   `docs: ...` — ไม่บังคับแต่แนะนำให้ตามเพื่อความสม่ำเสมอ
6. Push แล้วเปิด Pull Request เข้า `main` อธิบายว่าแก้อะไร ทำไม และทดสอบยังไง

## ก่อน commit / เปิด PR ต้องผ่านครบ — ไม่มีข้อยกเว้น

```bash
# Flutter (โฟลเดอร์ app/)
flutter analyze                                    # ต้องขึ้น "No issues found!"
dart format --output=none --set-exit-if-changed .  # ต้อง exit 0
flutter test                                        # ต้องขึ้น "All tests passed!"
flutter test test_e2e                               # ต้องขึ้น "All tests passed!" (แอปจริง ↔ backend จริง — ต้อง `npm ci` ใน backend ก่อน)

# Backend (โฟลเดอร์ backend/)
npm run format:check                                # ต้องขึ้น "All matched files use Prettier code style!"
npm run lint                                        # ต้อง 0 errors, 0 warnings
npm test                                            # ต้อง fail 0
```

CI (`.github/workflows/ci.yml`) รันชุดเดียวกันนี้อัตโนมัติทุก push/PR — PR ที่ CI ไม่ผ่านจะไม่ถูก merge

### แนวทางเขียนเทสต์

- เพิ่มฟีเจอร์ = ต้องมีเทสต์คู่กันเสมอ ทั้งสองฝั่งถ้าตรรกะซ้ำกัน (เช่นการคิดบิลที่เขียนไว้ทั้ง Dart
  และ JavaScript ดู [`docs/DECISIONS.md`](docs/DECISIONS.md) #2)
- Controller ฝั่ง Flutter ที่แตะ `Get.snackbar`/`Get.dialog`/`Get.offNamed` โดยไม่มี `GetMaterialApp`
  จริงจะ crash ในเทสต์ระดับ unit — ครอบคลุมเฉพาะ guard/early-return หรือ pure computation
  (ดูตัวอย่างและเหตุผลในหัวข้อ 6.2 ของ `docs/CODING_STANDARDS.md`)
- แก้ไฟล์ในชั้น domain/data → รันคำสั่งตรวจ layer violation ในหัวข้อ 4.3 ของ CODING_STANDARDS.md ด้วย

### เปลี่ยน schema ฐานข้อมูล — เพิ่ม migration ใหม่เท่านั้น

schema ของ backend อยู่ใน [`backend/src/db/migrations/`](backend/src/db/migrations/) เป็น migration มีเลขลำดับ
(T01 #80, [`docs/DECISIONS.md`](docs/DECISIONS.md) #79) ทุกฐานข้อมูลจดไว้ในตาราง `schema_migrations` ว่ารันเลขไหนไปแล้ว
พร้อม checksum ของไฟล์ แต่ละ migration รันครั้งเดียวใน transaction ของตัวเอง ถ้าล้มกลางทางจะ rollback ทั้งตัว

1. สร้าง `NNNN_ชื่อ.js` (และ `NNNN_ชื่อ.sql` ถ้าเขียน SQL แยก) ด้วยเลขถัดไป ใส่ header ลิขสิทธิ์เอง
   (สคริปต์ `license-headers.mjs` ข้ามโฟลเดอร์นี้) แล้ว export default `{ version, name, files, up(db) }`
   ดูตัวอย่างจาก `0001_baseline.js` ใส่ `foreignKeys: false` เฉพาะเมื่อต้องสร้างตารางใหม่แทนตารางเดิม
   ตัวรันจะตรวจ foreign key ให้ก่อน commit
2. เพิ่มในรายการ `DEFINITIONS` ใน `migrations/index.js`
3. รัน `npm test` แล้วเทสต์ `tests/migrations.test.js` จะแสดง checksum ที่ต้องใส่ใน `migrations/checksums.json`
   ให้คัดลอกค่านั้นไปใส่ ควรรัน `npm run format` ก่อน เพราะ Prettier เปลี่ยนเนื้อไฟล์ และ checksum ก็เปลี่ยนตาม
4. เขียนเทสต์ว่าฐานข้อมูลที่มีข้อมูลอยู่แล้วอัปเกรดได้โดยข้อมูลไม่หาย

**ห้ามแก้ migration ที่อยู่ใน `main` แล้ว** แม้แต่คอมเมนต์หรือการจัดรูปแบบ เซิร์ฟเวอร์ของร้านที่รันไปแล้วจะไม่ยอมเปิด
เพราะ checksum ไม่ตรง ถ้าต้องแก้ ให้เพิ่ม migration ใหม่แทน migration ใช้ได้แค่กับ schema และการย้ายข้อมูล
ค่าตั้งต้นของร้านจาก env อยู่ใน `ensureDefaultSettings` ของ `migrate.js` ซึ่งรันทุกครั้งที่ boot

## รายงานบั๊ก / เสนอฟีเจอร์

เปิด [Issue](https://github.com/SuruchBoss/PaynEat/issues) พร้อมข้อมูล:

- **บั๊ก**: ขั้นตอนทำซ้ำ, ผลที่คาดหวัง vs ที่เกิดจริง, เวอร์ชัน Flutter/Node ที่ใช้
- **เสนอฟีเจอร์**: ปัญหาที่อยากแก้ (ไม่ใช่แค่วิธีแก้ที่คิดไว้) จะได้คุยแนวทางที่เหมาะสมที่สุดร่วมกันได้

> ⚠️ **พบช่องโหว่ด้านความปลอดภัย?** ห้ามเปิดเป็น public Issue — ทำตาม [`SECURITY.md`](SECURITY.md) แทน

## มารยาท

ให้เกียรติกันในการรีวิวโค้ดและคอมเมนต์ — วิจารณ์ที่โค้ด ไม่ใช่ที่ตัวคน ทุกคนที่มีส่วนร่วมในโปรเจกต์นี้
ต้องปฏิบัติตาม [`CODE_OF_CONDUCT.md`](CODE_OF_CONDUCT.md)

## Developer Certificate of Origin (DCO)

> **สรุปภาษาไทย:** ทุก commit ใน Pull Request ที่ส่งมาจาก fork ต้อง sign-off ด้วย `git commit -s`
> (เพิ่มบรรทัด `Signed-off-by: ชื่อ <อีเมล>` ของผู้เขียน commit) เพื่อยืนยันตาม Developer Certificate of Origin 1.1
> ด้านล่างว่าคุณมีสิทธิ์ส่งโค้ดนั้นเข้ามาภายใต้สัญญาอนุญาตของโปรเจกต์ CI ตรวจให้อัตโนมัติ
> ส่วนไฟล์ซอร์สใหม่ทุกไฟล์ต้องขึ้นต้นด้วย header ลิขสิทธิ์ + SPDX — รัน `node scripts/license-headers.mjs --fix`
> แล้วสคริปต์จะใส่ให้ (ข้อความ DCO คงเป็นภาษาอังกฤษตามต้นฉบับ)

Contributions are accepted under the project's license (see [LICENSE](LICENSE) and, where a
directory has its own, that directory's license). So that the origin of every change is clear,
**each commit in a pull request from a fork must be signed off** under the Developer Certificate
of Origin 1.1. CI checks it (`.github/workflows/license-check.yml`).

Sign off with `git commit -s`. It adds a line with the name and email of the commit's author:

```
Signed-off-by: Your Name <you@example.com>
```

By signing off you certify the following (the full text of the DCO, from
<https://developercertificate.org/>):

```
Developer Certificate of Origin
Version 1.1

Copyright (C) 2004, 2006 The Linux Foundation and its contributors.

Everyone is permitted to copy and distribute verbatim copies of this
license document, but changing it is not allowed.


Developer's Certificate of Origin 1.1

By making a contribution to this project, I certify that:

(a) The contribution was created in whole or in part by me and I
    have the right to submit it under the open source license
    indicated in the file; or

(b) The contribution is based upon previous work that, to the best
    of my knowledge, is covered under an appropriate open source
    license and I have the right under that license to submit that
    work with modifications, whether created in whole or in part
    by me, under the same open source license (unless I am
    permitted to submit under a different license), as indicated
    in the file; or

(c) The contribution was provided directly to me by some other
    person who certified (a), (b) or (c) and I have not modified
    it.

(d) I understand and agree that this project and the contribution
    are public and that a record of the contribution (including all
    personal information I submit with it, including my sign-off) is
    maintained indefinitely and may be redistributed consistent with
    this project or the open source license(s) involved.
```

A sign-off is a statement made by a person. Automated tools and AI agents do not sign off on
anyone's behalf; the person who submits their work does.

## File headers

Every source file starts with its copyright and license identifier, for example:

```ts
// Copyright 2026 Suruch Chakrapeesirisuk
// SPDX-License-Identifier: Apache-2.0
```

`node scripts/license-headers.mjs --fix` adds it to new files; CI fails a file without it.
The script skips database migrations (`backend/src/db/migrations/`): every database records each applied
migration's checksum, so the script must never edit one. Write the header yourself when you create a migration.

## License

โค้ดที่ contribute เข้ามาจะอยู่ภายใต้สัญญาอนุญาต Apache License 2.0 เดียวกับโปรเจกต์ (ดู [`LICENSE`](LICENSE)
และ [`NOTICE`](NOTICE))
