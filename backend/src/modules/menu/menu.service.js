// Copyright 2026 Suruch Chakrapeesirisuk
// SPDX-License-Identifier: Apache-2.0

import { ApiError } from '../../core/ApiError.js';
import { resolveBranchIdForWrite } from '../../core/branchScope.js';
import { toSatang } from '../../core/money.js';
import { getDb } from '../../db/index.js';
import { auditLogService } from '../audit-logs/audit-log.service.js';
import { categoryRepository } from '../categories/category.repository.js';
import { ingredientRepository } from '../ingredients/ingredient.repository.js';
import { menuRepository } from './menu.repository.js';
import { toMenuItemDto } from './menu.mapper.js';

const assertCategoryExists = (categoryId) => {
  if (categoryId === undefined) return;
  if (!categoryRepository.findById(categoryId)) {
    throw ApiError.badRequest('ไม่พบหมวดหมู่ที่ระบุ');
  }
};

/**
 * ตรวจ/จัดรูปบาร์โค้ดและ PLU ก่อนบันทึก (ดู docs/tickets/19-barcode-scale.md) — คืน patch ที่พร้อม
 * ส่งให้ repository ('' → null = ล้างค่า, undefined = ไม่แตะ)
 *
 * PLU เก็บแบบตัดเลข 0 นำหน้าออก เพราะฉลากตาชั่งพิมพ์เป็นช่องคงที่ ("00101") ส่วนคนพิมพ์ในฟอร์ม
 * มักพิมพ์ "101" — ฝั่งแอปแปลงค่าจากฉลากแบบเดียวกันก่อนจับคู่ (scale_barcode.dart)
 * PLU ใช้ได้เฉพาะเมนูขายตามน้ำหนัก ฉลากตาชั่งบอกน้ำหนัก ไม่มีความหมายกับสินค้าขายเป็นชิ้น
 */
const normalizeCodes = (payload, { id, branchId, soldByWeight }) => {
  const patch = {};
  if (payload.barcode !== undefined) patch.barcode = payload.barcode || null;
  if (payload.scalePlu !== undefined) {
    patch.scalePlu = payload.scalePlu ? String(Number(payload.scalePlu)) : null;
  }
  if (patch.scalePlu && !soldByWeight) {
    throw ApiError.badRequest('รหัสบนตาชั่ง (PLU) ใช้ได้เฉพาะเมนูที่ขายตามน้ำหนัก');
  }
  // เลิกขายตามน้ำหนักแล้ว PLU เดิมไม่มีความหมาย ล้างทิ้งให้เอง ฉลากเก่าจะได้ไม่ชี้มาที่เมนูนี้อีก
  if (!soldByWeight && patch.scalePlu === undefined && payload.soldByWeight === false) {
    patch.scalePlu = null;
  }

  for (const [field, column, label] of [
    ['barcode', 'barcode', 'บาร์โค้ด'],
    ['scalePlu', 'scale_plu', 'รหัสบนตาชั่ง (PLU)'],
  ]) {
    if (!patch[field]) continue;
    const other = menuRepository.findConflictingCode({
      column,
      value: patch[field],
      branchId,
      excludeId: id,
    });
    if (other)
      throw ApiError.conflict(`${label} ${patch[field]} ถูกใช้กับเมนู "${other.name}" แล้ว`);
  }
  return patch;
};

const assertIngredientsExist = (ingredients) => {
  if (!ingredients?.length) return;
  for (const link of ingredients) {
    if (!ingredientRepository.findById(link.ingredientId)) {
      throw ApiError.badRequest(`ไม่พบวัตถุดิบ id=${link.ingredientId}`);
    }
  }
};

const saveIngredientLinks = (menuItemId, ingredients) => {
  menuRepository.removeIngredientLinks(menuItemId);
  ingredients.forEach((link) => {
    menuRepository.createIngredientLink(menuItemId, {
      ingredientId: link.ingredientId,
      qtyPerUnit: link.qtyPerUnit,
    });
  });
};

const saveOptionGroups = (menuItemId, optionGroups) => {
  menuRepository.removeOptionGroups(menuItemId);
  optionGroups.forEach((group, groupIndex) => {
    const groupId = menuRepository.createOptionGroup(menuItemId, {
      name: group.name,
      minSelect: group.minSelect,
      maxSelect: group.maxSelect,
      isRequired: group.isRequired,
      sortOrder: groupIndex,
    });
    group.options.forEach((option, optionIndex) => {
      menuRepository.createOption(groupId, {
        name: option.name,
        priceDelta: toSatang(option.priceDelta ?? 0),
        isDefault: option.isDefault,
        sortOrder: optionIndex,
      });
    });
  });
};

export const menuService = {
  list(filters, currentBranchId) {
    const { items, total } = menuRepository.findAll({ ...filters, branchId: currentBranchId });
    const groupsByItem = menuRepository.findOptionGroupsForItems(items.map((item) => item.id));
    const ingredientsByItem = menuRepository.findIngredientLinksForItems(
      items.map((item) => item.id),
    );
    return {
      items: items.map((item) =>
        toMenuItemDto(item, groupsByItem.get(item.id) ?? [], ingredientsByItem.get(item.id) ?? []),
      ),
      total,
    };
  },

  getById(id) {
    const item = menuRepository.findById(id);
    if (!item) throw ApiError.notFound('ไม่พบเมนูนี้');
    return toMenuItemDto(
      item,
      menuRepository.findOptionGroups(id),
      menuRepository.findIngredientLinks(id),
    );
  },

  create(payload, currentBranchId) {
    assertCategoryExists(payload.categoryId);
    assertIngredientsExist(payload.ingredients);
    const branchId = resolveBranchIdForWrite(currentBranchId, payload.branchId);
    const codes = normalizeCodes(payload, {
      id: null,
      branchId,
      soldByWeight: Boolean(payload.soldByWeight),
    });
    const run = getDb().transaction(() => {
      const created = menuRepository.create({
        ...payload,
        ...codes,
        price: toSatang(payload.price),
        imageUrl: payload.imageUrl || null,
        branchId,
      });
      if (payload.optionGroups?.length) {
        saveOptionGroups(created.id, payload.optionGroups);
      }
      if (payload.ingredients?.length) {
        saveIngredientLinks(created.id, payload.ingredients);
      }
      return created.id;
    });
    return this.getById(run());
  },

  update(id, payload, actingUser) {
    const before = this.getById(id);
    assertCategoryExists(payload.categoryId);
    assertIngredientsExist(payload.ingredients);

    const newPriceSatang = payload.price === undefined ? undefined : toSatang(payload.price);
    const priceChanged = newPriceSatang !== undefined && newPriceSatang !== toSatang(before.price);
    const codes = normalizeCodes(payload, {
      id,
      branchId: before.branchId,
      soldByWeight: payload.soldByWeight ?? before.soldByWeight,
    });

    const run = getDb().transaction(() => {
      menuRepository.update(id, {
        ...payload,
        ...codes,
        price: newPriceSatang,
        imageUrl: payload.imageUrl === '' ? null : payload.imageUrl,
        // แก้ isAvailable ผ่านฟอร์มแก้ไขปกติ = พนักงานตั้งใจ override เอง เลยล้างสถานะ
        // "ปิดขายอัตโนมัติเพราะสต๊อกหมด" ทิ้งเหมือนกับตอนกดสลับผ่าน setAvailability
        autoDisabledByStock: payload.isAvailable === undefined ? undefined : false,
      });
      if (payload.optionGroups) {
        saveOptionGroups(id, payload.optionGroups);
      }
      if (payload.ingredients) {
        saveIngredientLinks(id, payload.ingredients);
      }
      // Audit สำหรับฝ่ายบัญชี (ดู docs/tickets/14-financial-audit-trail.md) — log เฉพาะตอนราคา
      // เปลี่ยนจริงเท่านั้น ไม่ log ทุก field ที่แก้ (หลักการเดียวกับ order.item.edit ใน ticket 13)
      if (priceChanged) {
        auditLogService.log({
          actorUser: actingUser,
          action: 'menu.price_change',
          summaryArgs: { name: before.name, from: before.price, to: payload.price },
          entityType: 'menu_item',
          entityId: id,
          summary: `แก้ราคาเมนู "${before.name}" ${before.price} → ${payload.price} บาท`,
          metadata: { previousPrice: before.price, newPrice: payload.price },
        });
      }
    });
    run();
    return this.getById(id);
  },

  setAvailability(id, isAvailable) {
    this.getById(id);
    menuRepository.setStockAvailability(id, isAvailable, false);
    return this.getById(id);
  },

  remove(id) {
    this.getById(id);
    const inUse = getDb()
      .prepare(
        `
        SELECT COUNT(*) AS c
          FROM order_items oi
          JOIN orders o ON o.id = oi.order_id
         WHERE oi.menu_item_id = ? AND o.status NOT IN ('paid', 'cancelled')
      `,
      )
      .get(id).c;
    if (inUse > 0) {
      throw ApiError.conflict('ลบไม่ได้ เพราะเมนูนี้อยู่ในออเดอร์ที่ยังไม่ปิด');
    }
    menuRepository.remove(id);
  },
};

export default menuService;
