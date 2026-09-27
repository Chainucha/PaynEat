// Copyright 2026 Suruch Chakrapeesirisuk
// SPDX-License-Identifier: Apache-2.0

import { ApiError } from '../../core/ApiError.js';
import { branchRepository } from './branch.repository.js';
import { toBranchDto } from './branch.mapper.js';
import { assertNotManagedByErp } from '../erp/erp.mode.js';

export const branchService = {
  list() {
    return branchRepository.findAll().map(toBranchDto);
  },

  /** สาขาที่ user คนที่ล็อกอินอยู่ตอนนี้เข้าถึงได้ — ใช้ตอน login (เลือกสาขา) และหน้าสลับสาขา */
  listForUser(user) {
    return branchRepository.listForUser(user).map(toBranchDto);
  },

  getById(id) {
    const branch = branchRepository.findById(id);
    if (!branch) throw ApiError.notFound('ไม่พบสาขานี้');
    return toBranchDto(branch);
  },

  create(payload) {
    assertNotManagedByErp('สาขาจัดการใน PaynEat ERP แก้ที่ ERP แล้วดึงข้อมูลใหม่');
    return toBranchDto(branchRepository.create(payload));
  },

  update(id, payload) {
    assertNotManagedByErp('สาขาจัดการใน PaynEat ERP แก้ที่ ERP แล้วดึงข้อมูลใหม่');
    this.getById(id);
    return toBranchDto(branchRepository.update(id, payload));
  },
};

export default branchService;
