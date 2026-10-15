# เครื่องเซิร์ฟเวอร์ในร้าน + ลูกค้าสั่งผ่าน QR จากเน็ตมือถือ

คู่มือนี้คือทางเลือก B (Docker) ฉบับใช้งานจริงในร้าน: คอมเครื่องหนึ่งในร้านเปิดทิ้งไว้เป็นเซิร์ฟเวอร์ พนักงานใช้ผ่าน WiFi/LAN
ของร้าน และลูกค้าสแกน QR ที่โต๊ะได้ทั้งจาก WiFi ร้านและจากเน็ตมือถือ ผ่านโดเมนของร้านเองบน Cloudflare Tunnel
เหตุผลของการออกแบบอยู่ที่ [`docs/DECISIONS.md`](../../docs/DECISIONS.md) #104

```
พนักงาน (LAN)   http://<IP เซิร์ฟเวอร์>:8080 ──► web ──► api :3000 ◄── ทุกอย่างของพนักงาน
ลูกค้า (เน็ตใดก็ได้) https://<โดเมนร้าน> ──► Cloudflare ──► cloudflared ──┬─► web-public (ไฟล์แอป)
                                                                     └─► api เฉพาะ /api/v1/public/*
```

- **QR คงที่**: ลิงก์ใน QR คือ `https://<โดเมนร้าน>/#/order/<token ของโต๊ะ>` ใช้ได้ตลอดตราบที่โดเมนไม่เปลี่ยน ไม่กด
  "เปลี่ยน QR" ของโต๊ะนั้น และฐานข้อมูลไม่หาย — QR ที่พิมพ์จากจอพนักงาน (ที่อยู่ LAN) ก็พาลูกค้าไปโดเมนร้าน เพราะ build ด้วย
  `SELF_ORDER_BASE_URL`
- **เน็ตร้านล่ม**: สั่งผ่าน QR ไม่ได้ชั่วคราว แต่พนักงานรับออเดอร์ ส่งครัว และเก็บเงินต่อได้ เพราะทั้งหมดอยู่ในวง LAN
- **จากอินเทอร์เน็ตเข้าถึงได้แค่หน้าสั่งอาหาร**: tunnel ส่งเฉพาะ `/api/v1/public/*` ไปที่ API — การเข้าสู่ระบบของพนักงาน,
  API อื่นทั้งหมด, realtime, `/docs`, `/health` ตอบ 404 จากภายนอก ไม่ต้องเปิดพอร์ตที่ router และไม่ต้องมี IP สาธารณะคงที่
- **ขึ้นเองทุกครั้ง**: ทุก container เป็น `restart: unless-stopped` — ล่ม รีสตาร์ตเครื่อง หรือไฟดับแล้วกลับมา ระบบขึ้นเอง

## สิ่งที่ต้องมี

| อะไร | หมายเหตุ |
|---|---|
| คอมที่เปิดทิ้งไว้ได้ | Linux ที่ยังได้รับอัปเดตความปลอดภัย (ทดสอบกับ Ubuntu Server 26.04 LTS) RAM 4GB ขึ้นไป — build ครั้งแรกใช้ RAM และเวลามากกว่าตอนรัน |
| Docker Engine + compose plugin | จาก `download.docker.com` (ไม่ใช่ snap) |
| IP คงที่ในวง LAN | จองที่ router (DHCP reservation) — QR ไม่ได้ใช้ที่อยู่นี้ แต่แอปของพนักงานถูก build ให้ชี้ไปที่นี่ |
| ดิสก์ลูกที่สองสำหรับสำรองข้อมูล | อีกดิสก์ในเครื่อง หรือ USB drive ที่เสียบค้าง — ชุดแรกอยู่ดิสก์เดียวกับฐานข้อมูล ดู ticket 33 |
| โดเมนที่ใช้ DNS ของ Cloudflare | บัญชี Cloudflare ฟรีพอ |
| ตั้ง BIOS ให้เปิดเครื่องเองเมื่อไฟกลับ | "Restore on AC Power Loss = Power On" และไม่หยุดรอคีย์บอร์ดตอนบูต ถ้าวางเครื่องไว้โดยไม่มีจอ |

## 1. ดิสก์สำรองชุดที่สอง

format ดิสก์ลูกที่สองแล้ว mount ทุกครั้งที่บูตด้วย `nofail` (ดิสก์เสียแล้วเครื่องยังบูตได้) และ **ล็อกโฟลเดอร์จุด mount ตอนที่ยัง
ไม่ได้ mount** เพื่อให้ตอนดิสก์หาย การสำรองชุดที่สองล้มเหลวให้เห็นในหน้าสำรองข้อมูล ไม่ใช่เขียนลงดิสก์ระบบเงียบ ๆ:

```bash
sudo mkdir -p /mnt/backup && sudo chattr +i /mnt/backup        # ทำตอนยังไม่ได้ mount
echo "UUID=<uuid ของ partition> /mnt/backup ext4 defaults,nofail,x-systemd.device-timeout=10s 0 2" | sudo tee -a /etc/fstab
sudo systemctl daemon-reload && sudo mount /mnt/backup
sudo mkdir /mnt/backup/payneat && sudo chown 1000:1000 /mnt/backup/payneat && sudo chmod 700 /mnt/backup/payneat
```

## 2. โค้ดและไฟล์ `.env`

```bash
git clone https://github.com/<owner>/PaynEat.git && cd PaynEat
bash deploy/shop/init-env.sh <IP เซิร์ฟเวอร์> <โดเมนร้าน> /mnt/backup
```

`init-env.sh` สร้าง `.env` ที่รากของ repo (สิทธิ์ 600) สุ่ม `JWT_SECRET` และรหัสผ่านพนักงาน 6 บัญชี แล้วแสดงรหัสผ่านครั้งเดียว
ให้จดเก็บไว้ — ใช้ตอนสร้างฐานข้อมูลครั้งแรกเท่านั้น เปลี่ยนภายหลังในแอป ค่าทั้งหมดดูได้ที่ [`.env.example`](.env.example)
`COMPOSE_FILE` ในไฟล์นั้นทำให้ทุกคำสั่ง `docker compose` ใช้ `docker-compose.yml` ซ้อนกับ `docker-compose.shop.yml` ให้เอง

## 3. Cloudflare Tunnel

ทำบนเครื่องไหนก็ได้ที่ติดตั้ง [cloudflared](https://developers.cloudflare.com/cloudflare-one/connections/connect-networks/downloads/)
(เช่นโน้ตบุ๊กของเจ้าของร้าน):

```bash
cloudflared tunnel login                                  # เลือกโดเมนร้านในเบราว์เซอร์
cloudflared tunnel create payneat-shop                    # ได้ <TUNNEL_ID> และไฟล์ ~/.cloudflared/<TUNNEL_ID>.json
cloudflared tunnel route dns payneat-shop <โดเมนร้าน>      # สร้าง DNS record ให้
```

คัดลอก `<TUNNEL_ID>.json` ไปไว้ที่ `deploy/shop/cloudflared/` บนเซิร์ฟเวอร์ แล้วบนเซิร์ฟเวอร์:

```bash
cd deploy/shop/cloudflared
chmod 600 <TUNNEL_ID>.json
cp config.example.yml config.yml      # แทน <TUNNEL_ID> (2 ที่) และ order.example.com (3 ที่) ด้วยค่าจริง
```

ไฟล์ `.json` และ `config.yml` ไม่ถูก commit (`.gitignore` ในโฟลเดอร์นั้น) — ไฟล์ `.json` คือกุญแจของ tunnel ใครได้ไปก็รับ
traffic ของโดเมนร้านได้

## 4. เปิดระบบ

```bash
docker compose up -d --build
docker compose ps        # ทุก service เป็น running, api เป็น healthy
```

build ครั้งแรกนาน (ดาวน์โหลด Flutter SDK และ build เว็บ 2 ชุด: ชุดพนักงานกับชุดลูกค้า) — คอมรุ่นเก่าอาจ 15–30 นาที
ครั้งถัดไปเร็วขึ้นมากเพราะมี cache

ตรวจ:

| จากไหน | เปิด | ควรได้ |
|---|---|---|
| เครื่องในร้าน | `http://<IP เซิร์ฟเวอร์>:8080` | หน้าเข้าสู่ระบบ → admin ด้วยรหัสผ่านจาก `init-env.sh` |
| เครื่องในร้าน | `http://<IP เซิร์ฟเวอร์>:3000/health` | `"status":"ok"` และ `"env":"production"` |
| มือถือ (ปิด WiFi) | `https://<โดเมนร้าน>/api/v1/auth/login` | 404 — API ของพนักงานไม่ออกนอกร้าน |
| มือถือ (ปิด WiFi) | สแกน QR ที่พิมพ์จากหน้าผังโต๊ะของพนักงาน | หน้าเมนูของโต๊ะนั้น สั่งแล้วขึ้นจอครัว |

## งานประจำ

- **อัปเดต**: `git pull && docker compose up -d --build` — เซิร์ฟเวอร์สำรองฐานข้อมูลเองก่อน migration ทุกครั้ง
- **ดู log**: `docker compose logs -f api` (log ของ Docker ถูกจำกัดขนาดถ้าตั้ง `log-opts` ใน `/etc/docker/daemon.json`)
- **สถานะการสำรองข้อมูล**: หน้าสำรองข้อมูลของ admin แสดงชุดแรกและชุดที่สองแยกกัน
- **กู้คืน**: `docker compose stop api` แล้ว `docker compose run --rm api npm run db:restore -- data/backups/<ไฟล์>.sqlite`
  (ไฟล์ชุดที่สองอยู่ที่ `/backup-copy/payneat/<ไฟล์>.sqlite` ใน container)
- **ห้าม** `docker compose down -v` — `-v` ลบ volume ฐานข้อมูล รวมทั้ง token ของ QR ทุกโต๊ะ (QR ที่พิมพ์ไว้ใช้ไม่ได้ทั้งหมด)

## ข้อควรรู้

- พอร์ตที่ Docker เปิด (3000, 8080) ไม่ผ่าน `ufw` — ปลอดภัยเพราะ router ไม่ได้ forward พอร์ตเข้ามา อย่า forward พอร์ตเหล่านี้
- `TRUST_PROXY` เชื่อ `X-Forwarded-For` เฉพาะจาก IP ของ container cloudflared (172.30.0.10) ถ้าใช้ subnet `172.30.0.0/24`
  ชนกับเครือข่ายอื่นในเครื่อง ให้เปลี่ยนทั้ง subnet, `ipv4_address` และ `TRUST_PROXY` ใน `docker-compose.shop.yml` พร้อมกัน
- แอปเว็บของพนักงานถูก build ให้คุยกับ `http://<IP เซิร์ฟเวอร์>:3000` — เปลี่ยน IP ต้อง `docker compose up -d --build` ใหม่
