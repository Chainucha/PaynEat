#!/usr/bin/env bash
# Copyright 2026 Suruch Chakrapeesirisuk
# SPDX-License-Identifier: Apache-2.0
#
# สร้าง .env ที่รากของ repo สำหรับเครื่องเซิร์ฟเวอร์ในร้าน พร้อมรหัสลับที่สุ่มใหม่ (docs/DECISIONS.md #104)
#   bash deploy/shop/init-env.sh <ที่อยู่ในวง LAN> <โดเมนสาธารณะ> [จุด mount ดิสก์สำรอง]
#   bash deploy/shop/init-env.sh 192.168.1.10 order.example.com /mnt/backup
# ไม่เขียนทับ .env ที่มีอยู่แล้ว — รหัสผ่านพนักงานแสดงครั้งเดียว ให้จดเก็บไว้
set -euo pipefail

if [[ $# -lt 2 ]]; then
  echo "usage: bash deploy/shop/init-env.sh <lan-host> <public-host> [backup-mount]" >&2
  exit 2
fi
lan_host=$1
public_host=${2#https://}
public_host=${public_host%/}
backup_mount=${3:-/mnt/backup}

repo_root=$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)
env_file="$repo_root/.env"
if [[ -e $env_file ]]; then
  echo "$env_file already exists; not overwriting it." >&2
  exit 1
fi

# ไม่ใช้ `tr </dev/urandom | head` เพราะ tr โดน SIGPIPE แล้ว pipefail ทำให้สคริปต์หยุดกลางทาง
password() {
  local chars
  chars=$(openssl rand -base64 48 | LC_ALL=C tr -dc 'A-HJ-NP-Za-km-z2-9')
  echo "${chars:0:16}"
}

umask 077
{
  echo "COMPOSE_FILE=docker-compose.yml:deploy/shop/docker-compose.shop.yml"
  echo "SHOP_LAN_HOST=$lan_host"
  echo "PUBLIC_HOST=$public_host"
  echo "BACKUP_DISK_MOUNT=$backup_mount"
  echo "JWT_SECRET=$(openssl rand -hex 32)"
  echo "PAYNEAT_UID=$(id -u)"
  echo "PAYNEAT_GID=$(id -g)"
} >"$env_file"

echo "Staff passwords (also in $env_file). They only apply when the database is first created:"
for user in ADMIN MANAGER WAITER1 WAITER2 KITCHEN CASHIER; do
  pw=$(password)
  echo "SEED_${user}_PASSWORD=$pw" >>"$env_file"
  printf '  %-8s %s\n' "${user,,}" "$pw"
done
echo "Wrote $env_file (mode 600)."
