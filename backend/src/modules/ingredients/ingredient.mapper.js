// Copyright 2026 Suruch Chakrapeesirisuk
// SPDX-License-Identifier: Apache-2.0

export const toIngredientDto = (row) => {
  if (!row) return null;
  return {
    id: row.id,
    name: row.name,
    unit: row.unit,
    currentStock: row.current_stock,
    lowStockThreshold: row.low_stock_threshold,
    isLowStock: row.current_stock <= row.low_stock_threshold,
    branchId: row.branch_id ?? null,
    // รหัสสินค้าใน PaynEat ERP ที่วัตถุดิบนี้จับคู่อยู่ และข้อมูลจาก ERP ที่ POS ไม่มีช่องเก็บเอง (ticket 25)
    itemCode: row.item_code ?? null,
    erpItem:
      row.erp_is_active === null || row.erp_is_active === undefined
        ? null
        : { nameEn: row.erp_name_en, active: Boolean(row.erp_is_active) },
    createdAt: row.created_at,
    updatedAt: row.updated_at,
  };
};

export default toIngredientDto;
