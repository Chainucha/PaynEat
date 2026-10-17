#!/usr/bin/env node
// Copyright 2026 Suruch Chakrapeesirisuk
// SPDX-License-Identifier: Apache-2.0

// สร้างเสียงเตือนตั๋วเข้าจอครัว (ticket 37) จากคลื่นไซน์ล้วน ๆ — สร้างเองจึงไม่มีเรื่องลิขสิทธิ์ของไฟล์เสียง
// สองโน้ตลงต่ำ (E6 → C6) แบบกระดิ่ง ยาวไม่ถึงวินาที ดังพอได้ยินข้ามเสียงพัดลมดูดควัน
// รันใหม่เมื่ออยากเปลี่ยนเสียง: node scripts/generate-chime.mjs (ไฟล์ผลลัพธ์ commit เข้า repo)

import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const SAMPLE_RATE = 22050;
const DURATION = 0.65;
const NOTES = [
  { freq: 1318.5, start: 0, length: 0.32 },
  { freq: 1046.5, start: 0.16, length: 0.45 },
];

const total = Math.round(SAMPLE_RATE * DURATION);
const samples = new Float32Array(total);
for (const note of NOTES) {
  const from = Math.round(note.start * SAMPLE_RATE);
  const count = Math.round(note.length * SAMPLE_RATE);
  for (let i = 0; i < count && from + i < total; i += 1) {
    const t = i / SAMPLE_RATE;
    const attack = Math.min(1, t / 0.005);
    const decay = Math.exp(-t * 7);
    // ฮาร์มอนิกที่สองเล็กน้อยให้เป็นเสียงกระดิ่ง ไม่ใช่เสียงบี๊ปของเครื่องมือวัด
    const wave =
      Math.sin(2 * Math.PI * note.freq * t) + 0.3 * Math.sin(2 * Math.PI * note.freq * 2 * t);
    samples[from + i] += 0.45 * attack * decay * wave;
  }
}

const data = Buffer.alloc(total * 2);
for (let i = 0; i < total; i += 1) {
  const clamped = Math.max(-1, Math.min(1, samples[i]));
  data.writeInt16LE(Math.round(clamped * 32767), i * 2);
}

const header = Buffer.alloc(44);
header.write('RIFF', 0);
header.writeUInt32LE(36 + data.length, 4);
header.write('WAVE', 8);
header.write('fmt ', 12);
header.writeUInt32LE(16, 16);
header.writeUInt16LE(1, 20); // PCM
header.writeUInt16LE(1, 22); // mono
header.writeUInt32LE(SAMPLE_RATE, 24);
header.writeUInt32LE(SAMPLE_RATE * 2, 28);
header.writeUInt16LE(2, 32);
header.writeUInt16LE(16, 34);
header.write('data', 36);
header.writeUInt32LE(data.length, 40);

const out = path.resolve(
  path.dirname(fileURLToPath(import.meta.url)),
  '../app/assets/sounds/ticket_chime.wav',
);
fs.mkdirSync(path.dirname(out), { recursive: true });
fs.writeFileSync(out, Buffer.concat([header, data]));
console.log(`wrote ${out} (${header.length + data.length} bytes)`);
