// Copyright 2026 Suruch Chakrapeesirisuk
// SPDX-License-Identifier: Apache-2.0

import { ApiError } from '../../core/ApiError.js';
import { resolveBranchIdForWrite } from '../../core/branchScope.js';
import { getDb } from '../../db/index.js';
import { effectiveQuantity } from '../../core/weight.js';
import { auditLogService } from '../audit-logs/audit-log.service.js';
import { menuRepository } from '../menu/menu.repository.js';
import { ingredientRepository } from './ingredient.repository.js';
import { toIngredientDto } from './ingredient.mapper.js';

/** เศษทศนิยมจากการลบ REAL หลายครั้ง (1 − 0.485 − 0.515 ไม่ได้ 0 พอดี) ต่ำกว่านี้ถือว่าหมด */
const STOCK_EPSILON = 1e-9;

/**
 * ตัดสินว่าเมนู "สั่งได้" ไหมจากวัตถุดิบที่ผูกไว้ — ต้องเหลือวัตถุดิบพอสำหรับอย่างน้อย 1 ที่
 * (current_stock >= qty_per_unit) ครบทุกตัวที่ผูกไว้ ถ้าไม่ผูกวัตถุดิบเลยถือว่าไม่เกี่ยวกับระบบนี้
 *
 * เมนูขายตามน้ำหนักใช้เกณฑ์ "ยังเหลืออยู่" (> 0) แทน เพราะ qty_per_unit ของเมนูแบบนี้คือปริมาณต่อ 1 กก.
 * หมูเหลือ 0.6 กก. ยังขายถุงละ 3 ขีดได้อีกสองถุง ไม่ควรขึ้น "หมด" เพียงเพราะเหลือไม่ถึงกิโล
 * (ดู docs/DECISIONS.md #48)
 *
 * รับ ingredientId ที่เพิ่งเปลี่ยนสต๊อกมาเป็น list เพื่อ sync เฉพาะเมนูที่อาจได้รับผลกระทบจริง ๆ
 * ไม่ไล่ทุกเมนูในระบบทุกครั้งที่มีการตัด/คืนสต๊อก
 */
const syncMenuItemAvailabilityForIngredients = (ingredientIds) => {
  const menuItemIds = new Set();
  for (const ingredientId of ingredientIds) {
    for (const link of ingredientRepository.findMenuItemLinksForIngredient(ingredientId)) {
      menuItemIds.add(link.menu_item_id);
    }
  }

  for (const menuItemId of menuItemIds) {
    const links = menuRepository.findIngredientLinks(menuItemId);
    if (links.length === 0) continue;

    const ingredients = new Map(
      ingredientRepository
        .findByIds(links.map((link) => link.ingredient_id))
        .map((row) => [row.id, row]),
    );
    const menuItem = menuRepository.findById(menuItemId);
    if (!menuItem) continue;

    const isOrderable = links.every((link) => {
      const ingredient = ingredients.get(link.ingredient_id);
      if (!ingredient) return false;
      return menuItem.sold_by_weight
        ? ingredient.current_stock > STOCK_EPSILON
        : ingredient.current_stock >= link.qty_per_unit;
    });

    if (!isOrderable && menuItem.is_available) {
      menuRepository.setStockAvailability(menuItemId, false, true);
    } else if (isOrderable && !menuItem.is_available && menuItem.auto_disabled_by_stock) {
      menuRepository.setStockAvailability(menuItemId, true, false);
    }
  }
};

/** หัก/คืนสต๊อกของวัตถุดิบที่ผูกกับเมนูของ order item นี้ ตาม factor × qty_per_unit × จำนวนที่ขาย
 * (บรรทัดชั่งน้ำหนักนับเป็นกิโลกรัม — ดู core/weight.js#effectiveQuantity) */
const applyDeltaForOrderItem = (item, factor) => {
  if (!item.menu_item_id) return;
  const links = menuRepository.findIngredientLinks(item.menu_item_id);
  if (links.length === 0) return;

  const sold = effectiveQuantity(item);
  for (const link of links) {
    ingredientRepository.adjustStock(link.ingredient_id, factor * link.qty_per_unit * sold);
  }
  syncMenuItemAvailabilityForIngredients(links.map((link) => link.ingredient_id));
};

export const ingredientService = {
  list(filters, currentBranchId) {
    return ingredientRepository
      .findAll({ ...filters, branchId: currentBranchId })
      .map(toIngredientDto);
  },

  getById(id) {
    const ingredient = ingredientRepository.findById(id);
    if (!ingredient) throw ApiError.notFound('ไม่พบวัตถุดิบนี้');
    return toIngredientDto(ingredient);
  },

  create(payload, currentBranchId) {
    const branchId = resolveBranchIdForWrite(currentBranchId, payload.branchId);
    return toIngredientDto(ingredientRepository.create({ ...payload, branchId }));
  },

  update(id, payload) {
    this.getById(id);
    return toIngredientDto(ingredientRepository.update(id, payload));
  },

  /** ปรับสต๊อกมือโดยแอดมิน/ผู้จัดการ (ต่างจาก deductForOrderItem/restoreForOrderItem ที่ตัดอัตโนมัติ
   * ตามออเดอร์) — ดู docs/tickets/14-financial-audit-trail.md: กระทบต้นทุน/สต๊อกโดยตรงจึงต้อง log */
  adjustStock(id, delta, note, actingUser) {
    const before = this.getById(id);
    const run = getDb().transaction(() => {
      ingredientRepository.adjustStock(id, delta);
      syncMenuItemAvailabilityForIngredients([id]);
      const direction = delta > 0 ? 'รับเข้า' : 'ตัดออก';
      auditLogService.log({
        actorUser: actingUser,
        action: 'ingredient.stock_adjust',
        summaryArgs: {
          name: before.name,
          delta,
          unit: before.unit,
          from: before.currentStock,
          to: before.currentStock + delta,
        },
        entityType: 'ingredient',
        entityId: id,
        summary: `ปรับสต๊อก "${before.name}" ${direction} ${Math.abs(delta)} ${before.unit} (${before.currentStock} → ${before.currentStock + delta})`,
        reason: note,
        metadata: {
          delta,
          previousStock: before.currentStock,
          newStock: before.currentStock + delta,
        },
      });
      return toIngredientDto(ingredientRepository.findById(id));
    });
    return run();
  },

  remove(id) {
    this.getById(id);
    if (ingredientRepository.countMenuItemLinks(id) > 0) {
      throw ApiError.conflict('ลบไม่ได้ เพราะวัตถุดิบนี้ถูกผูกกับเมนูอยู่');
    }
    ingredientRepository.remove(id);
  },

  /** ตัดสต๊อกตอนรายการอาหารถูกส่งครัว (หรือถูกเพิ่มเข้าออเดอร์ที่ส่งครัวไปแล้ว) */
  deductForOrderItem(item) {
    applyDeltaForOrderItem(item, -1);
  },

  /** คืนสต๊อกตอนยกเลิก/ลบรายการอาหารที่เคยตัดสต๊อกไปแล้ว */
  restoreForOrderItem(item) {
    applyDeltaForOrderItem(item, 1);
  },

  /** ปรับสต๊อกตามส่วนต่างจำนวนที่แก้ไข — ใช้เฉพาะรายการที่ตัดสต๊อกไปแล้วเท่านั้น */
  adjustForQuantityChange(item, oldQuantity, newQuantity) {
    if (!item.menu_item_id || oldQuantity === newQuantity) return;
    const links = menuRepository.findIngredientLinks(item.menu_item_id);
    if (links.length === 0) return;

    const deltaQty = newQuantity - oldQuantity;
    for (const link of links) {
      ingredientRepository.adjustStock(link.ingredient_id, -deltaQty * link.qty_per_unit);
    }
    syncMenuItemAvailabilityForIngredients(links.map((link) => link.ingredient_id));
  },
};

export default ingredientService;
