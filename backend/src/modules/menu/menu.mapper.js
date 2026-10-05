// Copyright 2026 Suruch Chakrapeesirisuk
// SPDX-License-Identifier: Apache-2.0

import { toBaht } from '../../core/money.js';

export const toOptionDto = (row) => ({
  id: row.id,
  groupId: row.group_id,
  name: row.name,
  priceDelta: toBaht(row.price_delta),
  isDefault: Boolean(row.is_default),
});

export const toOptionGroupDto = (row) => ({
  id: row.id,
  name: row.name,
  minSelect: row.min_select,
  maxSelect: row.max_select,
  isRequired: Boolean(row.is_required),
  options: (row.options ?? []).map(toOptionDto),
});

export const toIngredientLinkDto = (row) => ({
  ingredientId: row.ingredient_id,
  ingredientName: row.ingredient_name,
  unit: row.ingredient_unit,
  qtyPerUnit: row.qty_per_unit,
});

export const toMenuItemDto = (row, optionGroups = [], ingredientLinks = []) => {
  if (!row) return null;
  return {
    id: row.id,
    categoryId: row.category_id,
    categoryName: row.category_name,
    name: row.name,
    nameEn: row.name_en,
    description: row.description,
    price: toBaht(row.price),
    imageUrl: row.image_url,
    isAvailable: Boolean(row.is_available),
    isRecommended: Boolean(row.is_recommended),
    prepMinutes: row.prep_minutes,
    sortOrder: row.sort_order,
    branchId: row.branch_id ?? null,
    soldByWeight: Boolean(row.sold_by_weight),
    barcode: row.barcode ?? null,
    scalePlu: row.scale_plu ?? null,
    stationId: row.station_id ?? null,
    optionGroups: optionGroups.map(toOptionGroupDto),
    ingredients: ingredientLinks.map(toIngredientLinkDto),
  };
};
