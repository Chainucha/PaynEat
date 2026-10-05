// Copyright 2026 Suruch Chakrapeesirisuk
// SPDX-License-Identifier: Apache-2.0

import { getDb } from '../../db/index.js';

const BASE_COLUMNS = 'id, name, username, role, is_active, created_at, updated_at';

export const userRepository = {
  /** `roles`/`branchIds` จำกัดรายการของผู้จัดการ (user.service.js) — ต้องมีสิทธิ์อย่างน้อยหนึ่งใน `branchIds` */
  findAll({ role, isActive, roles, branchIds } = {}) {
    const clauses = [];
    const params = [];
    if (role) {
      clauses.push('role = ?');
      params.push(role);
    }
    if (roles) {
      clauses.push(`role IN (${roles.map(() => '?').join(', ') || 'NULL'})`);
      params.push(...roles);
    }
    if (branchIds) {
      clauses.push(
        `EXISTS (SELECT 1 FROM user_branches ub WHERE ub.user_id = users.id
                  AND ub.branch_id IN (${branchIds.map(() => '?').join(', ') || 'NULL'}))`,
      );
      params.push(...branchIds);
    }
    if (isActive !== undefined) {
      clauses.push('is_active = ?');
      params.push(isActive ? 1 : 0);
    }
    const where = clauses.length ? `WHERE ${clauses.join(' AND ')}` : '';
    return getDb()
      .prepare(`SELECT ${BASE_COLUMNS} FROM users ${where} ORDER BY role, name`)
      .all(...params);
  },

  findById(id) {
    return getDb().prepare(`SELECT ${BASE_COLUMNS} FROM users WHERE id = ?`).get(id);
  },

  /** user คนนี้มีสิทธิ์เข้าอย่างน้อยหนึ่งสาขาใน `branchIds` ไหม */
  inBranches(id, branchIds) {
    if (branchIds.length === 0) return false;
    return Boolean(
      getDb()
        .prepare(
          `SELECT 1 FROM user_branches WHERE user_id = ? AND branch_id IN (${branchIds.map(() => '?').join(', ')})`,
        )
        .get(id, ...branchIds),
    );
  },

  /** สถานีครัวที่พนักงานคนนี้รับผิดชอบ (ticket 35) — ไม่มีแถว = ไม่ผูก = เห็นทุกสถานี */
  findStations(userId) {
    return getDb()
      .prepare(
        `SELECT s.id, s.code
           FROM user_stations us
           JOIN kitchen_stations s ON s.id = us.station_id
          WHERE us.user_id = ?
          ORDER BY s.sort_order, s.id`,
      )
      .all(userId);
  },

  /** แทนที่ชุดสถานีทั้งชุด (ส่ง [] = ถอดออกทั้งหมด) — ให้ผู้เรียกครอบ transaction เอง */
  replaceStations(userId, stationIds) {
    const db = getDb();
    db.prepare('DELETE FROM user_stations WHERE user_id = ?').run(userId);
    const insert = db.prepare('INSERT INTO user_stations (user_id, station_id) VALUES (?, ?)');
    for (const stationId of new Set(stationIds)) insert.run(userId, stationId);
  },

  findByUsername(username) {
    return getDb().prepare('SELECT * FROM users WHERE username = ?').get(username);
  },

  create({ name, username, passwordHash, role }) {
    const info = getDb()
      .prepare('INSERT INTO users (name, username, password_hash, role) VALUES (?, ?, ?, ?)')
      .run(name, username, passwordHash, role);
    return this.findById(info.lastInsertRowid);
  },

  update(id, { name, role, isActive }) {
    getDb()
      .prepare(
        `
        UPDATE users
           SET name       = COALESCE(?, name),
               role       = COALESCE(?, role),
               is_active  = COALESCE(?, is_active),
               updated_at = datetime('now')
         WHERE id = ?
      `,
      )
      .run(name ?? null, role ?? null, isActive === undefined ? null : Number(isActive), id);
    return this.findById(id);
  },

  updatePassword(id, passwordHash) {
    getDb()
      .prepare("UPDATE users SET password_hash = ?, updated_at = datetime('now') WHERE id = ?")
      .run(passwordHash, id);
    return this.findById(id);
  },

  remove(id) {
    return getDb().prepare('DELETE FROM users WHERE id = ?').run(id).changes > 0;
  },
};

export default userRepository;
