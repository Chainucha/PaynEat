// Copyright 2026 Suruch Chakrapeesirisuk
// SPDX-License-Identifier: Apache-2.0

export const toKitchenStationDto = (row) => {
  if (!row) return null;
  return {
    id: row.id,
    code: row.code,
    name: row.name,
    nameEn: row.name_en,
    nameKo: row.name_ko,
    icon: row.icon,
    sortOrder: row.sort_order,
    isActive: Boolean(row.is_active),
    isDefault: Boolean(row.is_default),
    itemCount: row.item_count ?? undefined,
  };
};

/** สถานะเปิด/ปิดของสถานีในสาขาหนึ่ง (ticket 36) */
export const toStationStatusDto = (row) => ({
  stationId: row.id,
  code: row.code,
  name: row.name,
  nameEn: row.name_en,
  nameKo: row.name_ko,
  icon: row.icon,
  isClosed: row.closed_at != null,
  closedAt: row.closed_at ?? null,
  closedByName: row.closed_by_name ?? null,
  pendingCount: row.pending_count ?? 0,
});

export default toKitchenStationDto;
