// Copyright 2026 Suruch Chakrapeesirisuk
// SPDX-License-Identifier: Apache-2.0

import bcrypt from 'bcryptjs';
import { ApiError } from '../../core/ApiError.js';
import { signToken, signPendingBranchSelectionToken } from '../../middlewares/auth.js';
import { userRepository } from '../users/user.repository.js';
import { toUserDto } from '../users/user.mapper.js';
import { branchRepository } from '../branches/branch.repository.js';
import { toBranchDto } from '../branches/branch.mapper.js';

/**
 * ผลลัพธ์ตอนเลือก/ยืนยันสาขาสำเร็จ (ใช้ทั้งตอน login ครั้งแรกที่มีสาขาเดียว/เป็น admin และตอน
 * เรียก POST /auth/select-branch สำเร็จ) — token ที่ได้พก branchId แล้วใช้เรียก endpoint อื่นได้ทันที
 */
const buildSessionResult = (user, branch) => ({
  token: signToken(user, branch?.id ?? null),
  // สถานีครัวที่ผูกไว้ติดไปกับ session ด้วย เพื่อให้จอครัวเลือกชิปสถานีให้ล่วงหน้าได้ทันทีที่ล็อกอิน
  // (ticket 35) ไม่ได้ใส่ใน token เพราะเปลี่ยนได้ตลอดและไม่ได้ใช้ตัดสินสิทธิ์
  user: toUserDto(user, branch, userRepository.findStations(user.id)),
});

export const authService = {
  login({ username, password }) {
    const user = userRepository.findByUsername(username);
    if (!user || !bcrypt.compareSync(password, user.password_hash)) {
      throw ApiError.unauthorized('username หรือรหัสผ่านไม่ถูกต้อง');
    }
    if (!user.is_active) {
      throw ApiError.forbidden('บัญชีนี้ถูกปิดการใช้งาน กรุณาติดต่อผู้ดูแลระบบ');
    }

    const branches = branchRepository.listForUser(user);
    if (branches.length === 0) {
      throw ApiError.forbidden(
        'บัญชีนี้ยังไม่มีสิทธิ์เข้าสาขาใดเลย กรุณาติดต่อผู้ดูแลระบบให้เพิ่มสิทธิ์สาขาก่อน',
      );
    }

    // admin ล็อกอินเข้าสาขาแรกอัตโนมัติเสมอ (branches[0] คือสาขาที่ id น้อยสุด/สร้างก่อน ดู
    // branch.repository.js#listForUser) ไม่ต้องเลือกก่อนแม้จะมีสิทธิ์เห็นได้ทุกสาขา — จะสลับไป
    // สาขาอื่นหรือโหมด "ทุกสาขา" (ดูรายงานรวมทุกสาขา) ทีหลังผ่าน POST /auth/select-branch ก็ได้
    // (ดู docs/DECISIONS.md #36) ผู้ใช้ role อื่นที่มีมากกว่า 1 สาขาต้องเลือกเองตั้งแต่ตอน login
    if (branches.length === 1 || user.role === 'admin') {
      return buildSessionResult(user, branches[0]);
    }

    return {
      needsBranchSelection: true,
      pendingToken: signPendingBranchSelectionToken(user),
      branches: branches.map(toBranchDto),
    };
  },

  /** ใช้ทั้งตอนแลก pendingToken ให้เป็น token ปกติครั้งแรก และตอน user ที่ login อยู่แล้วสลับสาขา
   * ภายหลัง (authenticateForBranchSelection รับ token ได้ทั้ง 2 แบบ ดู middlewares/auth.js) */
  selectBranch(actingUser, branchId) {
    const user = userRepository.findById(actingUser.id);
    if (!user || !user.is_active) throw ApiError.unauthorized();

    // branchId ว่าง (โหมด "ทุกสาขา") เลือกได้เฉพาะ admin เท่านั้น
    if (branchId === null) {
      if (user.role !== 'admin')
        throw ApiError.forbidden('เฉพาะผู้ดูแลระบบเท่านั้นที่ดูได้ทุกสาขา');
      return buildSessionResult(user, null);
    }

    if (!branchRepository.hasAccess(user, branchId)) {
      throw ApiError.forbidden('ไม่มีสิทธิ์เข้าถึงสาขานี้');
    }
    return buildSessionResult(user, branchRepository.findById(branchId));
  },

  me(userId, branchId) {
    const user = userRepository.findById(userId);
    if (!user) throw ApiError.unauthorized('ไม่พบบัญชีผู้ใช้');
    const branch = branchId === null ? null : branchRepository.findById(branchId);
    return toUserDto(user, branch, userRepository.findStations(user.id));
  },

  changePassword(userId, { currentPassword, newPassword }) {
    const user = userRepository.findById(userId);
    if (!user) throw ApiError.unauthorized();

    const full = userRepository.findByUsername(user.username);
    if (!bcrypt.compareSync(currentPassword, full.password_hash)) {
      throw ApiError.badRequest('รหัสผ่านปัจจุบันไม่ถูกต้อง');
    }
    userRepository.updatePassword(userId, bcrypt.hashSync(newPassword, 10));
  },
};

export default authService;
