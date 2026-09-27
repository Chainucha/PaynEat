// Copyright 2026 Suruch Chakrapeesirisuk
// SPDX-License-Identifier: Apache-2.0

import { getDb } from '../../db/index.js';

// วัตถุดิบพร้อมข้อมูลของรายการสินค้าใน ERP ที่จับคู่ด้วยรหัสสินค้า (ถ้ามี — ticket 25)
const WITH_ERP_ITEM = `
  SELECT i.*, e.name_en AS erp_name_en, e.is_active AS erp_is_active
    FROM ingredients i
    LEFT JOIN erp_items e ON e.item_code = i.item_code`;

export const ingredientRepository = {
  findAll({ lowStockOnly, branchId } = {}) {
    const clauses = [];
    const params = [];
    // branchId เป็น null/undefined เฉพาะ admin โหมด "ทุกสาขา" (ดู docs/DECISIONS.md #36)
    if (branchId) {
      clauses.push('i.branch_id = ?');
      params.push(branchId);
    }
    if (lowStockOnly) clauses.push('i.current_stock <= i.low_stock_threshold');
    const where = clauses.length ? `WHERE ${clauses.join(' AND ')}` : '';
    return getDb()
      .prepare(`${WITH_ERP_ITEM} ${where} ORDER BY i.name`)
      .all(...params);
  },

  findById(id) {
    return getDb().prepare(`${WITH_ERP_ITEM} WHERE i.id = ?`).get(id);
  },

  /** วัตถุดิบอื่นในสาขาเดียวกันที่ใช้รหัสสินค้านี้แล้ว (รหัสหนึ่งมีได้ตัวเดียวต่อสาขา) */
  findByItemCode(branchId, itemCode, exceptId) {
    return getDb()
      .prepare('SELECT id FROM ingredients WHERE branch_id IS ? AND item_code = ? AND id IS NOT ?')
      .get(branchId ?? null, itemCode, exceptId ?? null);
  },

  findByIds(ids) {
    if (ids.length === 0) return [];
    const placeholders = ids.map(() => '?').join(',');
    return getDb()
      .prepare(`SELECT * FROM ingredients WHERE id IN (${placeholders})`)
      .all(...ids);
  },

  /** เมนูทั้งหมดที่ผูกกับวัตถุดิบนี้ — ใช้ตอน sync สถานะเปิด/ปิดขายเมนูเมื่อสต๊อกเปลี่ยน */
  findMenuItemLinksForIngredient(ingredientId) {
    return getDb()
      .prepare('SELECT * FROM menu_item_ingredients WHERE ingredient_id = ?')
      .all(ingredientId);
  },

  countMenuItemLinks(ingredientId) {
    return getDb()
      .prepare('SELECT COUNT(*) AS c FROM menu_item_ingredients WHERE ingredient_id = ?')
      .get(ingredientId).c;
  },

  create({ name, unit, currentStock, lowStockThreshold, branchId, itemCode }) {
    const info = getDb()
      .prepare(
        'INSERT INTO ingredients (name, unit, current_stock, low_stock_threshold, branch_id, item_code) VALUES (?, ?, ?, ?, ?, ?)',
      )
      .run(name, unit, currentStock ?? 0, lowStockThreshold ?? 0, branchId, itemCode ?? null);
    return this.findById(info.lastInsertRowid);
  },

  update(id, { name, unit, lowStockThreshold, itemCode }) {
    // itemCode: undefined = ไม่แตะ, null = ล้างรหัส
    if (itemCode !== undefined) {
      getDb().prepare('UPDATE ingredients SET item_code = ? WHERE id = ?').run(itemCode, id);
    }
    getDb()
      .prepare(
        `
        UPDATE ingredients
           SET name                = COALESCE(?, name),
               unit                = COALESCE(?, unit),
               low_stock_threshold = COALESCE(?, low_stock_threshold),
               updated_at          = datetime('now')
         WHERE id = ?
      `,
      )
      .run(name ?? null, unit ?? null, lowStockThreshold ?? null, id);
    return this.findById(id);
  },

  /** บวก/ลบสต๊อก (delta ติดลบ = หัก, บวก = เติม) — ทางเดียวที่แก้ current_stock ได้ */
  adjustStock(id, delta) {
    getDb()
      .prepare(
        `
        UPDATE ingredients
           SET current_stock = current_stock + ?,
               updated_at    = datetime('now')
         WHERE id = ?
      `,
      )
      .run(delta, id);
    return this.findById(id);
  },

  remove(id) {
    return getDb().prepare('DELETE FROM ingredients WHERE id = ?').run(id).changes > 0;
  },
};

export default ingredientRepository;
