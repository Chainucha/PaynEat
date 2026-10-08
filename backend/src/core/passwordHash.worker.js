// Copyright 2026 Suruch Chakrapeesirisuk
// SPDX-License-Identifier: Apache-2.0

import { parentPort } from 'node:worker_threads';
import bcrypt from 'bcryptjs';

// งาน bcrypt ของ core/passwordHash.js — รันทีละงานบน thread นี้ thread หลักจึงรับคำขออื่นต่อได้
parentPort.on('message', ({ id, op, args }) => {
  try {
    const result = op === 'compare' ? bcrypt.compareSync(...args) : bcrypt.hashSync(...args);
    parentPort.postMessage({ id, result });
  } catch (error) {
    parentPort.postMessage({ id, error: error.message });
  }
});
