// Copyright 2026 Suruch Chakrapeesirisuk
// SPDX-License-Identifier: Apache-2.0

import { getDb } from '../../db/index.js';

export const kitchenStationRepository = {
  /**
   * `item_count` นับ "จานที่ตกลงสถานีนี้จริง" ตามกฎการตัดสิน (เมนู → หมวดหมู่ → ค่าเริ่มต้น)
   * ไม่ใช่แค่จานที่ผูกตรง ๆ เพราะคำถามเดียวที่ผู้จัดการถามคือ "บาร์ต้องทำกี่เมนู"
   * ไม่แยกตามสาขาเหมือน categories.itemCount (docs/DECISIONS.md #97)
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

  /** แถวสถานีล้วน ๆ ไม่นับเมนู — ใช้ทำตารางค้นชื่อสถานีตอนประกอบรายการเมนู */
  findAllBasic() {
    return getDb().prepare('SELECT * FROM kitchen_stations').all();
  },

  /**
   * สถานะปิดทั้งหมดของสถานีที่เปิดใช้งาน (ticket 36) — สถานีที่ถูกปิดใช้งานภายหลังแต่ยังมีแถวปิดค้าง
   * ไม่ถูกนับ เพราะ "ปิดใช้งาน" เป็นค่าตั้งของเครือร้านที่ทับทุกอย่างอยู่แล้ว (CONTEXT.md)
   */
  findClosures() {
    return getDb()
      .prepare(
        `SELECT sc.* FROM station_closures sc
           JOIN kitchen_stations s ON s.id = sc.station_id
          WHERE s.is_active = 1`,
      )
      .all();
  },

  findClosure(branchId, stationId) {
    return getDb()
      .prepare(
        `SELECT sc.* FROM station_closures sc
           JOIN kitchen_stations s ON s.id = sc.station_id
          WHERE s.is_active = 1 AND sc.branch_id = ? AND sc.station_id = ?`,
      )
      .get(branchId, stationId);
  },

  /**
   * สถานะของทุกสถานีที่เปิดใช้งานในสาขาหนึ่ง พร้อมจำนวนรายการที่ยังค้างในครัว (pending/cooking)
   * นับแบบเดียวกับคิวครัว: เฉพาะออเดอร์ที่ส่งครัวแล้ว และตั๋วที่ไม่มีสถานีถือเป็นของสถานีค่าเริ่มต้น
   */
  findStatuses(branchId, stationId = null) {
    return getDb()
      .prepare(
        `
        SELECT s.*, sc.closed_at, sc.closed_by_name, (
          SELECT COUNT(*)
            FROM order_items oi
            JOIN orders o ON o.id = oi.order_id
           WHERE oi.status IN ('pending', 'cooking')
             AND o.status IN ('in_kitchen', 'served')
             AND o.branch_id = @branchId
             AND COALESCE(oi.station_id, (SELECT id FROM kitchen_stations WHERE is_default = 1)) = s.id
        ) AS pending_count
          FROM kitchen_stations s
          LEFT JOIN station_closures sc ON sc.station_id = s.id AND sc.branch_id = @branchId
         WHERE s.is_active = 1 AND (@stationId IS NULL OR s.id = @stationId)
         ORDER BY s.sort_order, s.id
      `,
      )
      .all({ branchId, stationId });
  },

  findStatus(branchId, stationId) {
    return this.findStatuses(branchId, stationId)[0];
  },

  /** คืน true เมื่อสถานะเปลี่ยนจริง (ปิดซ้ำ = false) — service ใช้ตัดสินว่าต้องลง audit/ส่ง event ไหม */
  close(branchId, stationId, user) {
    return (
      getDb()
        .prepare(
          `INSERT OR IGNORE INTO station_closures (branch_id, station_id, closed_by, closed_by_name)
           VALUES (?, ?, ?, ?)`,
        )
        .run(branchId, stationId, user?.id ?? null, user?.name ?? null).changes > 0
    );
  },

  open(branchId, stationId) {
    return (
      getDb()
        .prepare('DELETE FROM station_closures WHERE branch_id = ? AND station_id = ?')
        .run(branchId, stationId).changes > 0
    );
  },

  remove(id) {
    return getDb().prepare('DELETE FROM kitchen_stations WHERE id = ?').run(id).changes > 0;
  },
};

export default kitchenStationRepository;
