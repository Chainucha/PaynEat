// Copyright 2026 Suruch Chakrapeesirisuk
// SPDX-License-Identifier: Apache-2.0

import { toCsv } from '../../core/csv.js';
import { auditLogRepository } from './audit-log.repository.js';
import { toAuditLogDto } from './audit-log.mapper.js';

const CSV_COLUMNS = [
  { label: 'วันเวลา', value: (log) => log.createdAt },
  { label: 'ผู้ทำ', value: (log) => log.actorName },
  { label: 'การกระทำ', value: (log) => log.action },
  { label: 'ประเภท', value: (log) => log.entityType },
  { label: 'รหัสอ้างอิง', value: (log) => log.entityId ?? '' },
  { label: 'รายละเอียด', value: (log) => log.summary },
  { label: 'เหตุผล', value: (log) => log.reason ?? '' },
];

export const auditLogService = {
  /**
   * บันทึกเหตุการณ์ที่เสี่ยงต่อการทุจริตหน้าร้าน — เรียกจาก service อื่นเท่านั้น (ไม่มี endpoint
   * สร้าง log ตรงๆ ให้เรียกจากภายนอก) ผู้เรียกควรเรียกภายในทรานแซกชันเดียวกับการเปลี่ยนแปลงข้อมูล
   * จริงเสมอ เพื่อให้ atomic — ถ้าบันทึก log ไม่สำเร็จ การกระทำนั้นต้องล้มเหลวไปด้วย ไม่ใช่ปล่อยผ่าน
   *
   * `summary` คือประโยคภาษาไทยที่เก็บเป็นหลักฐาน (และลง CSV) ส่วน `summaryArgs` คือค่าที่ใช้ประกอบ
   * ประโยคนั้นแบบไม่ผูกภาษา — เก็บไว้ใน `metadata.summaryArgs` ให้แอปแสดงประโยคเป็นภาษาที่ผู้ดูเลือก
   * (ผู้ใช้แอปภาษาเกาหลี/อังกฤษอ่านไทยไม่ออก ดู DECISIONS #74) ไม่ต้องเพิ่มคอลัมน์หรือ migration
   */
  log({ actorUser, action, entityType, entityId, summary, summaryArgs, reason, metadata }) {
    return toAuditLogDto(
      auditLogRepository.create({
        actorUserId: actorUser?.id,
        actorName: actorUser?.name ?? 'ระบบ',
        action,
        entityType,
        entityId,
        summary,
        reason,
        metadata: summaryArgs ? { ...metadata, summaryArgs } : metadata,
      }),
    );
  },

  list(filters) {
    const { rows, total } = auditLogRepository.findAll(filters);
    return { items: rows.map(toAuditLogDto), total };
  },

  /** export ให้ฝ่ายบัญชี/ผู้ตรวจสอบภายนอก (ดู docs/tickets/14-financial-audit-trail.md) — reuse
   * filter เดียวกับหน้าจอ list (admin เท่านั้น ควบคุมที่ชั้น route) */
  exportCsv(filters) {
    const rows = auditLogRepository.findAllForExport(filters).map(toAuditLogDto);
    return toCsv(rows, CSV_COLUMNS);
  },
};

export default auditLogService;
