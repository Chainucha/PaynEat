// Copyright 2026 Suruch Chakrapeesirisuk
// SPDX-License-Identifier: Apache-2.0

import test from 'node:test';
import assert from 'node:assert/strict';
import { createFailedAttemptLimiter } from '../src/core/failedAttempts.js';
import { createWindowCounter, rateLimit } from '../src/core/rateLimit.js';

// ตัวนับในหน่วยความจำของ core/rateLimit.js และ core/failedAttempts.js — ใช้นาฬิกาจำลองแทนการรอจริง

const fakeClock = (start = 1_000_000) => {
  let at = start;
  return { now: () => at, advance: (ms) => (at += ms) };
};

const MINUTE = 60 * 1000;

test('createFailedAttemptLimiter — ครบเพดานแล้วพักจนหมด window และบอกเวลารอเป็นวินาที', () => {
  const clock = fakeClock();
  const limiter = createFailedAttemptLimiter({ maxFailures: 3, windowMs: 15 * MINUTE, ...clock });

  limiter.recordFailure(['k']);
  limiter.recordFailure(['k']);
  assert.equal(limiter.retryAfterSeconds(['k']), 0);
  limiter.recordFailure(['k']);
  assert.equal(limiter.retryAfterSeconds(['k']), 15 * 60);

  clock.advance(10 * MINUTE);
  assert.equal(limiter.retryAfterSeconds(['k']), 5 * 60);
  assert.equal(limiter.retryAfterSeconds(['other']), 0);

  clock.advance(5 * MINUTE + 1);
  assert.equal(limiter.retryAfterSeconds(['k']), 0);
});

test('createFailedAttemptLimiter — หลายคีย์รอตามคีย์ที่นานสุด และ reset ล้างตัวนับ', () => {
  const clock = fakeClock();
  const limiter = createFailedAttemptLimiter({ maxFailures: 2, windowMs: 10 * MINUTE, ...clock });

  limiter.recordFailure(['a']);
  limiter.recordFailure(['a']);
  clock.advance(4 * MINUTE);
  limiter.recordFailure(['b']);
  limiter.recordFailure(['b']);
  assert.equal(limiter.retryAfterSeconds(['a', 'b']), 10 * 60);

  limiter.reset(['a', 'b']);
  assert.equal(limiter.retryAfterSeconds(['a', 'b']), 0);
});

test('createFailedAttemptLimiter — ลบคีย์ที่หมด window ทิ้ง ไม่สะสมในหน่วยความจำ', () => {
  const clock = fakeClock();
  const limiter = createFailedAttemptLimiter({ maxFailures: 10, windowMs: MINUTE, ...clock });

  for (let i = 0; i < 1000; i += 1) limiter.recordFailure([`ip:${i}`, `user:${i}`]);
  assert.equal(limiter.size, 2000);

  clock.advance(MINUTE + 1);
  limiter.recordFailure(['ip:new']);
  assert.equal(limiter.size, 1);
});

test('createWindowCounter — กวาดอย่างมากรอบละครั้งต่อ window และเก็บคีย์ที่ยังไม่หมดอายุไว้', () => {
  const clock = fakeClock();
  const counter = createWindowCounter({ windowMs: MINUTE, ...clock });

  counter.hit('old');
  clock.advance(MINUTE / 2);
  counter.hit('recent');
  clock.advance(MINUTE / 2 + 1);
  counter.hit('new');
  // 'old' หมดอายุแล้ว 'recent' ยังอยู่ใน window
  assert.equal(counter.size, 2);
  assert.equal(counter.peek('old'), undefined);
  assert.equal(counter.peek('recent').count, 1);
});

test('rateLimit — เกิน max ภายใน window ได้ 429 แยกตามคีย์ (พฤติกรรมเดิมของ public-order)', () => {
  const limiter = rateLimit({ windowMs: MINUTE, max: 2, keyFn: (req) => req.key });
  const call = (key) => {
    let error;
    limiter({ key }, {}, (err) => (error = err));
    return error;
  };

  assert.equal(call('t1'), undefined);
  assert.equal(call('t1'), undefined);
  assert.equal(call('t1')?.statusCode, 429);
  assert.equal(call('t2'), undefined);
});
