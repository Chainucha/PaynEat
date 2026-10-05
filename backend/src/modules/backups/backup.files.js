// Copyright 2026 Suruch Chakrapeesirisuk
// SPDX-License-Identifier: Apache-2.0

/**
 * ชื่อไฟล์สำรองและกติกาการเก็บย้อนหลัง (ticket 33, DECISIONS #90) — ฟังก์ชันล้วน ไม่แตะดิสก์ ให้เทสต์ส่งเวลาเองได้
 *
 * ชื่อไฟล์บอกเวลาท้องถิ่นของร้านและเหตุผล เช่น `payneat-2026-09-29T221530+0700-shift-close.sqlite`
 * เจ้าของร้านเปิดโฟลเดอร์แล้วหาไฟล์ของวันที่ต้องการเจอโดยไม่ต้องแปลงเวลา
 */

/** เหตุผลที่สำรอง — อยู่ท้ายชื่อไฟล์ */
export const BACKUP_REASONS = Object.freeze([
  'shift-close',
  'scheduled',
  'pre-migration',
  'manual',
  'pre-restore',
]);

const HOUR = 60 * 60 * 1000;
const DAY = 24 * HOUR;

/** ไฟล์ใน 48 ชั่วโมงล่าสุดเก็บทุกไฟล์ */
export const KEEP_ALL_WITHIN_MS = 48 * HOUR;
/** ไฟล์ก่อน migration และก่อนกู้คืนเก็บ 90 วัน — เป็นทางถอยเวอร์ชัน (DECISIONS #79) */
export const KEEP_SAFETY_COPIES_DAYS = 90;
const SAFETY_REASONS = new Set(['pre-migration', 'pre-restore']);

const pad = (value, length = 2) => String(Math.abs(value)).padStart(length, '0');

/** `2026-09-29T221530+0700` ตามเวลาท้องถิ่นของเครื่อง (เวลาร้าน) */
export const formatStamp = (date) => {
  const offsetMinutes = -date.getTimezoneOffset();
  const sign = offsetMinutes >= 0 ? '+' : '-';
  return (
    `${date.getFullYear()}-${pad(date.getMonth() + 1)}-${pad(date.getDate())}` +
    `T${pad(date.getHours())}${pad(date.getMinutes())}${pad(date.getSeconds())}` +
    `${sign}${pad(Math.trunc(offsetMinutes / 60))}${pad(offsetMinutes % 60)}`
  );
};

export const backupFileName = (date, reason) => {
  if (!BACKUP_REASONS.includes(reason)) throw new Error(`Unknown backup reason: ${reason}`);
  return `payneat-${formatStamp(date)}-${reason}.sqlite`;
};

const NAME = new RegExp(
  '^payneat-(\\d{4})-(\\d{2})-(\\d{2})T(\\d{2})(\\d{2})(\\d{2})([+-])(\\d{2})(\\d{2})-' +
    `(${BACKUP_REASONS.join('|')})(?:-(\\d+))?\\.sqlite$`,
);

/**
 * อ่านเวลาและเหตุผลจากชื่อไฟล์ คืน null ถ้าไม่ใช่ไฟล์สำรองของ PaynEat (ไฟล์อื่นในโฟลเดอร์ไม่ถูกแตะ)
 * `localDay` คือวันที่ตามเวลาร้านตอนสำรอง ใช้หาไฟล์ล่าสุดของแต่ละวัน
 */
export const parseBackupFileName = (name) => {
  const match = NAME.exec(name);
  if (!match) return null;
  const [, y, mo, d, h, mi, s, sign, oh, om, reason] = match;
  const offsetMinutes = (sign === '+' ? 1 : -1) * (Number(oh) * 60 + Number(om));
  const at = new Date(
    Date.UTC(Number(y), Number(mo) - 1, Number(d), Number(h), Number(mi), Number(s)) -
      offsetMinutes * 60 * 1000,
  );
  return { name, at, reason, localDay: `${y}-${mo}-${d}` };
};

/**
 * ไฟล์ที่ลบได้ตามกติกาการเก็บย้อนหลัง จากรายชื่อไฟล์ในโฟลเดอร์ (ชื่อที่ไม่ใช่ไฟล์สำรองถูกข้าม)
 *
 * เก็บ: ทุกไฟล์ใน 48 ชั่วโมงล่าสุด, ไฟล์ล่าสุดของแต่ละวันย้อนหลัง `keepDays` วัน, ไฟล์ก่อน migration/ก่อนกู้คืน
 * 90 วัน และไฟล์ล่าสุดเสมอ ไม่ว่าตั้งค่าไว้อย่างไร — ห้ามเหลือ 0 ไฟล์
 */
export const filesToPrune = (names, { now, keepDays }) => {
  const backups = names
    .map(parseBackupFileName)
    .filter(Boolean)
    .sort((a, b) => b.at - a.at);
  if (backups.length === 0) return [];

  const keep = new Set([backups[0].name]);
  const newestOfDay = new Map();
  for (const backup of backups) {
    if (!newestOfDay.has(backup.localDay)) newestOfDay.set(backup.localDay, backup.name);
  }
  for (const backup of backups) {
    const age = now - backup.at;
    if (age <= KEEP_ALL_WITHIN_MS) keep.add(backup.name);
    if (SAFETY_REASONS.has(backup.reason) && age <= KEEP_SAFETY_COPIES_DAYS * DAY) {
      keep.add(backup.name);
    }
    if (newestOfDay.get(backup.localDay) === backup.name && age <= keepDays * DAY) {
      keep.add(backup.name);
    }
  }
  return backups.filter((backup) => !keep.has(backup.name)).map((backup) => backup.name);
};

/** ไฟล์สำรองล่าสุดในรายชื่อ หรือ null */
export const newestBackup = (names) =>
  names
    .map(parseBackupFileName)
    .filter(Boolean)
    .sort((a, b) => b.at - a.at)[0] ?? null;

export const countBackups = (names) => names.filter((name) => NAME.test(name)).length;
