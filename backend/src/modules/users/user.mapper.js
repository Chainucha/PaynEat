// Copyright 2026 Suruch Chakrapeesirisuk
// SPDX-License-Identifier: Apache-2.0

// branch: สาขาที่ "กำลังทำงานอยู่" ของ session/token นี้ (ดู docs/DECISIONS.md #36) — เป็น context
// ของ token ไม่ใช่ property ถาวรของ user (user คนเดียวมีได้หลายสาขา) จึงต้องส่งเข้ามาจาก caller เอง
// เสมอ ไม่ query จาก row ตรงๆ — null ได้ทั้งตอนที่ยังไม่รู้ (เช่น GET /users list ทั้งบริษัท) และ
// ตอน admin เลือกโหมด "ทุกสาขา"
/**
 * `stations` = สถานีครัวที่พนักงานคนนี้รับผิดชอบ (ticket 35) ส่งเข้ามาจาก caller เหมือน branch
 * เปิดออกเป็นสองรูป: `stationIds` ให้หน้าจัดการพนักงานติ๊กช่อง และ `stationCodes` ให้จอครัวใช้
 * เลือกชิปล่วงหน้า (ชิปทำงานด้วยรหัสสถานี) — ไม่ส่งมาเลย = ไม่รู้ จึงไม่ใส่ทั้งสองคีย์
 */
export const toUserDto = (row, branch = null, stations = null) => {
  if (!row) return null;
  return {
    id: row.id,
    name: row.name,
    username: row.username,
    role: row.role,
    isActive: Boolean(row.is_active),
    createdAt: row.created_at,
    updatedAt: row.updated_at,
    branchId: branch?.id ?? null,
    branchName: branch?.name ?? null,
    ...(stations === null
      ? {}
      : {
          stationIds: stations.map((station) => station.id),
          stationCodes: stations.map((station) => station.code),
        }),
  };
};

export default toUserDto;
