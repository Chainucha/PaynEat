// Copyright 2026 Suruch Chakrapeesirisuk
// SPDX-License-Identifier: Apache-2.0

import bcrypt from 'bcryptjs';
import { ApiError } from '../../core/ApiError.js';
import { getDb } from '../../db/index.js';
import { auditLogService } from '../audit-logs/audit-log.service.js';
import { branchRepository } from '../branches/branch.repository.js';
import { userRepository } from './user.repository.js';
import { toUserDto } from './user.mapper.js';

// เฉพาะ admin เท่านั้นที่แตะบัญชีระดับ admin ได้ (สร้างใหม่/แก้ไข/ตั้งรหัสใหม่ให้)
// กัน manager ยกระดับตัวเองเป็น admin ผ่าน role หรือ reset รหัสผ่านของ admin คนอื่นแล้วสวมรอย
// (ดูรายงาน security review — privilege escalation ผ่าน PATCH /users/:id และ reset-password)
const assertAdminBoundary = (actingUser, { targetRole, newRole } = {}) => {
  if (actingUser.role === 'admin') return;
  if (targetRole === 'admin' || newRole === 'admin') {
    throw ApiError.forbidden('ต้องมีสิทธิ์ admin สำหรับบัญชีนี้');
  }
};

export const userService = {
  list(filters) {
    return userRepository.findAll(filters).map(toUserDto);
  },

  getById(id) {
    const user = userRepository.findById(id);
    if (!user) throw ApiError.notFound('ไม่พบผู้ใช้งานนี้');
    return toUserDto(user);
  },

  // currentBranchId มาจาก req.branchId ของผู้สร้าง (null เฉพาะ admin โหมด "ทุกสาขา" ดู
  // docs/DECISIONS.md #36) — พนักงานใหม่ต้องมีสิทธิ์เข้าอย่างน้อย 1 สาขาเสมอ ไม่งั้นจะล็อกอินไม่ได้
  // เลย (สาขาว่างเปล่า) จึงต้องระบุ branchId มาทาง payload แทนตอนสร้างในโหมดนี้
  create({ name, username, password, role, branchId }, actingUser, currentBranchId) {
    assertAdminBoundary(actingUser, { newRole: role });
    if (userRepository.findByUsername(username)) {
      throw ApiError.conflict('username นี้ถูกใช้งานแล้ว');
    }
    const resolvedBranchId = currentBranchId ?? branchId;
    if (!resolvedBranchId) {
      throw ApiError.badRequest('ต้องระบุ branchId เพราะกำลังดูข้อมูลรวมทุกสาขาอยู่ (โหมดทุกสาขา)');
    }
    if (!branchRepository.findById(resolvedBranchId)) {
      throw ApiError.badRequest('ไม่พบสาขานี้');
    }

    const run = getDb().transaction(() => {
      const passwordHash = bcrypt.hashSync(password, 10);
      const created = userRepository.create({ name, username, passwordHash, role });
      branchRepository.addUser(created.id, resolvedBranchId);
      return created;
    });
    return toUserDto(run());
  },

  update(id, payload, actingUser) {
    const target = this.getById(id);
    assertAdminBoundary(actingUser, { targetRole: target.role, newRole: payload.role });
    // ห้ามลดสิทธิ์/ปิดบัญชีตัวเอง — กดพลาดครั้งเดียวแล้วล็อกตัวเองออกจากหน้าจัดการพนักงานทันที
    // (เหลือ admin คนเดียวในร้าน = ไม่มีใครเปิดคืนให้ได้) ดู docs/DECISIONS.md #62
    if (Number(id) === Number(actingUser.id)) {
      if (payload.role !== undefined && payload.role !== target.role) {
        throw ApiError.badRequest('ไม่สามารถเปลี่ยนบทบาทของบัญชีตัวเองได้');
      }
      if (payload.isActive === false) {
        throw ApiError.badRequest('ไม่สามารถปิดการใช้งานบัญชีตัวเองได้');
      }
    }

    const run = getDb().transaction(() => {
      const updated = userRepository.update(id, payload);
      // แก้ role กับปิดการใช้งานเป็นการกระทำที่เสี่ยง ต้อง log แยกจากกัน (แก้ชื่อเฉยๆ ไม่ต้อง log)
      // ดู docs/tickets/08-audit-log.md
      if (payload.role !== undefined && payload.role !== target.role) {
        auditLogService.log({
          actorUser: actingUser,
          action: 'user.role_change',
          summaryArgs: { name: target.name, from: target.role, to: payload.role },
          entityType: 'user',
          entityId: target.id,
          summary: `เปลี่ยนสิทธิ์บัญชี "${target.name}" จาก ${target.role} เป็น ${payload.role}`,
          metadata: { username: target.username, previousRole: target.role, newRole: payload.role },
        });
      }
      if (payload.isActive === false && target.isActive) {
        auditLogService.log({
          actorUser: actingUser,
          action: 'user.deactivate',
          summaryArgs: { name: target.name, username: target.username },
          entityType: 'user',
          entityId: target.id,
          summary: `ปิดการใช้งานบัญชี "${target.name}" (${target.username})`,
          metadata: { username: target.username },
        });
      }
      return updated;
    });
    return toUserDto(run());
  },

  resetPassword(id, password, actingUser) {
    const target = this.getById(id);
    assertAdminBoundary(actingUser, { targetRole: target.role });

    const run = getDb().transaction(() => {
      const updated = userRepository.updatePassword(id, bcrypt.hashSync(password, 10));
      auditLogService.log({
        actorUser: actingUser,
        action: 'user.password_reset',
        summaryArgs: { name: target.name, username: target.username },
        entityType: 'user',
        entityId: target.id,
        summary: `ตั้งรหัสผ่านใหม่ให้บัญชี "${target.name}" (${target.username})`,
        metadata: { username: target.username },
      });
      return updated;
    });
    return toUserDto(run());
  },

  remove(id, actingUser) {
    if (Number(id) === Number(actingUser.id)) {
      throw ApiError.badRequest('ไม่สามารถลบบัญชีของตัวเองได้');
    }
    const target = this.getById(id);

    const run = getDb().transaction(() => {
      userRepository.remove(id);
      auditLogService.log({
        actorUser: actingUser,
        action: 'user.delete',
        summaryArgs: { name: target.name, username: target.username },
        entityType: 'user',
        entityId: target.id,
        summary: `ลบบัญชี "${target.name}" (${target.username}) ออกจากระบบ`,
        metadata: { username: target.username, role: target.role },
      });
    });
    run();
  },
};

export default userService;
