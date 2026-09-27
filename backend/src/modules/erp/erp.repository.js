// Copyright 2026 Suruch Chakrapeesirisuk
// SPDX-License-Identifier: Apache-2.0

import { getDb } from '../../db/index.js';

/**
 * ตารางของโหมดเชื่อมต่อ PaynEat ERP (migration 0002, ticket 25) — คอลัมน์ `credential` ถูกอ่านที่เดียวคือ
 * `findCredentials()` ซึ่งใช้เรียก ERP เท่านั้น ส่วน `find()` ที่ใช้สร้างคำตอบให้แอปไม่ได้ SELECT คอลัมน์นี้เลย
 */
const PUBLIC_COLUMNS = `
  base_url, instance_code, instance_name, contract_version, connected_at, applied_version,
  latest_version, last_pull_at, last_error, credential_rejected, pull_stopped, retry_after`;

export const erpRepository = {
  find() {
    return getDb().prepare(`SELECT ${PUBLIC_COLUMNS} FROM erp_connection WHERE id = 1`).get();
  },

  /** URL + credential สำหรับเรียก ERP — ห้ามส่งค่านี้ออกไปนอก erp.client */
  findCredentials() {
    const row = getDb()
      .prepare('SELECT base_url, credential FROM erp_connection WHERE id = 1')
      .get();
    return row ? { baseUrl: row.base_url, credential: row.credential } : undefined;
  },

  save({ baseUrl, credential, instanceCode, instanceName, contractVersion, appliedVersion }) {
    getDb()
      .prepare(
        `INSERT INTO erp_connection
           (id, base_url, credential, instance_code, instance_name, contract_version, applied_version)
         VALUES (1, ?, ?, ?, ?, ?, ?)
         ON CONFLICT(id) DO UPDATE SET
           base_url = excluded.base_url,
           credential = excluded.credential,
           instance_code = excluded.instance_code,
           instance_name = excluded.instance_name,
           contract_version = excluded.contract_version,
           applied_version = excluded.applied_version,
           connected_at = strftime('%Y-%m-%dT%H:%M:%fZ', 'now'),
           last_error = NULL,
           credential_rejected = 0,
           pull_stopped = 0,
           retry_after = NULL`,
      )
      .run(baseUrl, credential, instanceCode, instanceName, contractVersion, appliedVersion);
  },

  remove() {
    const db = getDb();
    db.prepare('DELETE FROM erp_connection').run();
    db.prepare('DELETE FROM erp_instance_branches').run();
  },

  updateInstance({ instanceName, contractVersion }) {
    getDb()
      .prepare('UPDATE erp_connection SET instance_name = ?, contract_version = ? WHERE id = 1')
      .run(instanceName, contractVersion);
  },

  replaceInstanceBranches(branches) {
    const db = getDb();
    db.prepare('DELETE FROM erp_instance_branches').run();
    const insert = db.prepare(
      `INSERT INTO erp_instance_branches (location_code, name_th, name_en, is_active)
       VALUES (?, ?, ?, ?)`,
    );
    for (const branch of branches) {
      insert.run(branch.code, branch.nameTh, branch.nameEn, branch.active ? 1 : 0);
    }
  },

  findInstanceBranches() {
    return getDb().prepare('SELECT * FROM erp_instance_branches ORDER BY location_code').all();
  },

  setAppliedVersion(appliedVersion, latestVersion) {
    getDb()
      .prepare('UPDATE erp_connection SET applied_version = ?, latest_version = ? WHERE id = 1')
      .run(appliedVersion, latestVersion);
  },

  recordPullSuccess() {
    getDb()
      .prepare(
        `UPDATE erp_connection
            SET last_pull_at = strftime('%Y-%m-%dT%H:%M:%fZ', 'now'), last_error = NULL,
                pull_stopped = 0, retry_after = NULL
          WHERE id = 1`,
      )
      .run();
  },

  recordPullFailure({ error, credentialRejected, stopped, retryAfter }) {
    getDb()
      .prepare(
        `UPDATE erp_connection
            SET last_error = ?,
                credential_rejected = MAX(credential_rejected, ?),
                pull_stopped = MAX(pull_stopped, ?),
                retry_after = ?
          WHERE id = 1`,
      )
      .run(JSON.stringify(error), credentialRejected ? 1 : 0, stopped ? 1 : 0, retryAfter ?? null);
  },

  upsertItem(item) {
    getDb()
      .prepare(
        `INSERT INTO erp_items
           (item_code, erp_id, name_th, name_en, base_unit_code, is_active, version, data)
         VALUES (?, ?, ?, ?, ?, ?, ?, ?)
         ON CONFLICT(item_code) DO UPDATE SET
           erp_id = excluded.erp_id, name_th = excluded.name_th, name_en = excluded.name_en,
           base_unit_code = excluded.base_unit_code, is_active = excluded.is_active,
           version = excluded.version, data = excluded.data,
           updated_at = strftime('%Y-%m-%dT%H:%M:%fZ', 'now')`,
      )
      .run(
        item.itemCode,
        item.id,
        item.nameTh,
        item.nameEn,
        item.baseUnitCode,
        item.active ? 1 : 0,
        item.version,
        JSON.stringify(item),
      );
  },

  upsertLocation(location) {
    getDb()
      .prepare(
        `INSERT INTO erp_locations
           (location_code, erp_id, name_th, name_en, is_active, superseded_by, version, data)
         VALUES (?, ?, ?, ?, ?, ?, ?, ?)
         ON CONFLICT(location_code) DO UPDATE SET
           erp_id = excluded.erp_id, name_th = excluded.name_th, name_en = excluded.name_en,
           is_active = excluded.is_active, superseded_by = excluded.superseded_by,
           version = excluded.version, data = excluded.data,
           updated_at = strftime('%Y-%m-%dT%H:%M:%fZ', 'now')`,
      )
      .run(
        location.locationCode,
        location.id,
        location.nameTh,
        location.nameEn,
        location.active ? 1 : 0,
        location.supersededBy?.locationCode ?? null,
        location.version,
        JSON.stringify(location),
      );
  },

  findLocation(code) {
    return getDb().prepare('SELECT * FROM erp_locations WHERE location_code = ?').get(code);
  },

  findItems(codes) {
    if (!codes.length) return [];
    const marks = codes.map(() => '?').join(', ');
    return getDb()
      .prepare(`SELECT * FROM erp_items WHERE item_code IN (${marks})`)
      .all(...codes);
  },

  // --------------------------------------------------------------- ตารางของ POS ที่ mirror เขียนทับ

  allBranches() {
    return getDb().prepare('SELECT * FROM branches ORDER BY id').all();
  },

  findBranchByCode(code) {
    return getDb().prepare('SELECT * FROM branches WHERE code = ?').get(code);
  },

  updateBranchFromErp(id, { code, name, isActive }) {
    getDb()
      .prepare(
        `UPDATE branches SET code = ?, name = ?, is_active = ?, updated_at = datetime('now')
          WHERE id = ?`,
      )
      .run(code, name, isActive ? 1 : 0, id);
  },

  /** วัตถุดิบของรายการสินค้านี้ในทุกสาขา: เขียนทับชื่อและหน่วยของตัวที่มีอยู่ สร้างให้สาขาที่ยังไม่มี */
  upsertIngredientForAllBranches({ itemCode, name, unit }) {
    const db = getDb();
    const update = db.prepare(
      `UPDATE ingredients SET name = ?, unit = ?, updated_at = datetime('now')
        WHERE branch_id = ? AND item_code = ?`,
    );
    const insert = db.prepare(
      'INSERT INTO ingredients (name, unit, branch_id, item_code) VALUES (?, ?, ?, ?)',
    );
    for (const branch of this.allBranches()) {
      const { changes } = update.run(name, unit, branch.id, itemCode);
      if (changes === 0) insert.run(name, unit, branch.id, itemCode);
    }
  },

  /** สร้างสาขาในเครื่องจากสาขาที่ ERP ให้ดูแล (ปุ่ม "สร้างสาขานี้ในเครื่อง") คืน id ของสาขาใหม่ */
  createBranchFromErp({ code, name, isActive }) {
    return getDb()
      .prepare('INSERT INTO branches (name, code, is_active) VALUES (?, ?, ?)')
      .run(name, code, isActive ? 1 : 0).lastInsertRowid;
  },

  /** วัตถุดิบ mirror ของทุกรายการสินค้าที่ดึงมาแล้วให้สาขาใหม่ — กติกาเดียวกับ upsertIngredientForAllBranches */
  mirrorItemsIntoBranch(branchId) {
    return getDb()
      .prepare(
        `INSERT OR IGNORE INTO ingredients (name, unit, branch_id, item_code)
         SELECT name_th, base_unit_code, ?, item_code FROM erp_items`,
      )
      .run(branchId).changes;
  },

  /** เมนูที่ระบบสต๊อกปิดขายอัตโนมัติ → เปิดขายคืน (เข้าโหมดเชื่อมต่อ: ยอดในเครื่องไม่ใช่ความจริงแล้ว) */
  reopenMenusClosedByStock() {
    return getDb()
      .prepare(
        `UPDATE menu_items SET is_available = 1, auto_disabled_by_stock = 0, updated_at = datetime('now')
          WHERE auto_disabled_by_stock = 1`,
      )
      .run().changes;
  },
};

export default erpRepository;
