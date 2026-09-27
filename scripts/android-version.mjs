#!/usr/bin/env node
// Copyright 2026 Suruch Chakrapeesirisuk
// SPDX-License-Identifier: Apache-2.0
//
// versionName และ versionCode ของ build ที่ขึ้น Google Play มาจาก git tag (ticket 29a, docs/store/README.md)
// tag `vX.Y.Z` → versionName `X.Y.Z`, versionCode `X*1_000_000 + Y*1_000 + Z` ซึ่งเพิ่มขึ้นเสมอเมื่อเวอร์ชัน
// เพิ่มขึ้นแบบ semver — Play ปฏิเสธ versionCode ที่ไม่มากกว่าเดิม จึงห้ามให้คนพิมพ์เลขเอง
// ref อื่น (PR) ได้เวอร์ชันทดสอบ `0.0.0-ci` / 1 ซึ่งไม่มีวันขึ้น store
// ใช้: node scripts/android-version.mjs <GITHUB_REF>  → พิมพ์ `name=...` และ `code=...` สำหรับ $GITHUB_OUTPUT

const PART_MAX = 999;
const MAJOR_MAX = 2099; // versionCode ของ Play ต้องไม่เกิน 2,100,000,000

export function androidVersion(ref) {
  if (!ref.startsWith('refs/tags/')) return { name: '0.0.0-ci', code: 1 };
  const tag = ref.slice('refs/tags/'.length);
  const match = /^v(\d+)\.(\d+)\.(\d+)$/.exec(tag);
  if (!match) {
    throw new Error(`tag "${tag}" is not vMAJOR.MINOR.PATCH — the store build needs one`);
  }
  const [major, minor, patch] = match.slice(1).map(Number);
  if (minor > PART_MAX || patch > PART_MAX || major > MAJOR_MAX) {
    throw new Error(`tag "${tag}" is out of range: minor and patch up to ${PART_MAX}, major up to ${MAJOR_MAX}`);
  }
  const code = major * 1_000_000 + minor * 1_000 + patch;
  if (code < 1) throw new Error(`tag "${tag}" gives versionCode 0; Play needs 1 or more`);
  return { name: `${major}.${minor}.${patch}`, code };
}

if (import.meta.url === `file://${process.argv[1]}`) {
  try {
    const { name, code } = androidVersion(process.argv[2] ?? '');
    console.log(`name=${name}`);
    console.log(`code=${code}`);
  } catch (error) {
    console.error(error.message);
    process.exit(1);
  }
}
