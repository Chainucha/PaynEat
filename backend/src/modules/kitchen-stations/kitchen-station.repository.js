// Copyright 2026 Suruch Chakrapeesirisuk
// SPDX-License-Identifier: Apache-2.0

import { getDb } from '../../db/index.js';

export const kitchenStationRepository = {
  /**
   * `item_count` นับ "จานที่ตกลงสถานีนี้จริง" ตามกฎการตัดสิน (เมนู → หมวดหมู่ → ค่าเริ่มต้น)
   * ไม่ใช่แค่จานที่ผูกตรง ๆ เพราะคำถามเดียวที่ผู้จัดการถามคือ "บาร์ต้องทำกี่เมนู"
   * ไม่แยกตามสาขาเหมือน categories.itemCount (docs/DECISIONS.md #94)
   */
  findAll({ activeOnly = false } = {}) {
    const where = activeOnly ? 'WHERE s.is_active = 1' : '';
    return getDb()
      .prepare(
        `
        SELECT s.*, (
          SELECT COUNT(*)
            FROM menu_items m
            LEFT JOIN categories c ON c.id = m.category_id
           WHERE COALESCE(
                   m.station_id,
                   c.station_id,
                   (SELECT id FROM kitchen_stations WHERE is_default = 1)
                 ) = s.id
        ) AS item_count
        FROM kitchen_stations s ${where}
        ORDER BY s.sort_order, s.id
      `,
      )
      .all();
  },

  findById(id) {
    return getDb().prepare('SELECT * FROM kitchen_stations WHERE id = ?').get(id);
  },

  findByCode(code) {
    return getDb().prepare('SELECT * FROM kitchen_stations WHERE code = ?').get(code);
  },

  findDefault() {
    return getDb().prepare('SELECT * FROM kitchen_stations WHERE is_default = 1').get();
  },

  findFirstActive() {
    return getDb()
      .prepare('SELECT * FROM kitchen_stations WHERE is_active = 1 ORDER BY sort_order, id LIMIT 1')
      .get();
  },

  create({ code, name, nameEn, nameKo, icon, sortOrder }) {
    const info = getDb()
      .prepare(
        `INSERT INTO kitchen_stations (code, name, name_en, name_ko, icon, sort_order)
         VALUES (?, ?, ?, ?, ?, ?)`,
      )
      .run(code, name, nameEn ?? null, nameKo ?? null, icon ?? null, sortOrder ?? 0);
    return this.findById(info.lastInsertRowid);
  },

  update(id, { name, nameEn, nameKo, icon, sortOrder, isActive }) {
    getDb()
      .prepare(
        `
        UPDATE kitchen_stations
           SET name       = COALESCE(?, name),
               name_en    = COALESCE(?, name_en),
               name_ko    = COALESCE(?, name_ko),
               icon       = COALESCE(?, icon),
               sort_order = COALESCE(?, sort_order),
               is_active  = COALESCE(?, is_active),
               updated_at = datetime('now')
         WHERE id = ?
      `,
      )
      .run(
        name ?? null,
        nameEn ?? null,
        nameKo ?? null,
        icon ?? null,
        sortOrder ?? null,
        isActive === undefined ? null : Number(isActive),
        id,
      );
    return this.findById(id);
  },

  clearDefault() {
    getDb()
      .prepare("UPDATE kitchen_stations SET is_default = 0, updated_at = datetime('now')")
      .run();
  },

  setDefault(id) {
    getDb()
      .prepare(
        "UPDATE kitchen_stations SET is_default = 1, is_active = 1, updated_at = datetime('now') WHERE id = ?",
      )
      .run(id);
    return this.findById(id);
  },

  countMenuItems(id) {
    return getDb().prepare('SELECT COUNT(*) AS c FROM menu_items WHERE station_id = ?').get(id).c;
  },

  countCategories(id) {
    return getDb().prepare('SELECT COUNT(*) AS c FROM categories WHERE station_id = ?').get(id).c;
  },

  countOrderItems(id) {
    return getDb().prepare('SELECT COUNT(*) AS c FROM order_items WHERE station_id = ?').get(id).c;
  },

  remove(id) {
    return getDb().prepare('DELETE FROM kitchen_stations WHERE id = ?').run(id).changes > 0;
  },
};

export default kitchenStationRepository;
