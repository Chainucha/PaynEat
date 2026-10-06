// Copyright 2026 Suruch Chakrapeesirisuk
// SPDX-License-Identifier: Apache-2.0

export const toCategoryDto = (row) => {
  if (!row) return null;
  return {
    id: row.id,
    name: row.name,
    nameEn: row.name_en,
    icon: row.icon,
    sortOrder: row.sort_order,
    isActive: Boolean(row.is_active),
    stationId: row.station_id ?? null,
    itemCount: row.item_count ?? undefined,
  };
};

export default toCategoryDto;
