// Copyright 2026 Suruch Chakrapeesirisuk
// SPDX-License-Identifier: Apache-2.0

import { ApiError } from '../../core/ApiError.js';
import { env } from '../../config/env.js';
import { getDb } from '../../db/index.js';
import { writeLog } from '../../core/telemetry/logger.js';
import { auditLogService } from '../audit-logs/audit-log.service.js';
import {
  erpClient,
  ErpCallError,
  failureSeverity,
  integrationReason,
  stopsUntilActedOn,
} from './erp.client.js';
import { LOCATION_CODE_PATTERN } from './erp.contract.js';
import { erpRepository } from './erp.repository.js';
import { erpTransport } from './erp.transport.js';

/**
 * โหมดเชื่อมต่อ PaynEat ERP (ticket 25, DECISIONS #80) — เข้า/ออกโหมด, ดึง master data ตามเวอร์ชัน และสถานะที่หน้า
 * ตั้งค่าแสดง ร้านที่ไม่ตั้งค่า ERP ไม่เคยเรียกโค้ดส่วนนี้ นอกจาก `status()` ที่ตอบว่า "ใช้งานเดี่ยว"
 *
 * การดึง: ถามด้วยเวอร์ชันล่าสุดที่นำไปใช้แล้ว (`since`) นำทั้งหน้าไปใช้ตามลำดับเวอร์ชันใน transaction เดียวพร้อมกับ
 * บันทึกเวอร์ชันใหม่ แล้วถามต่อจนกว่า `hasMore` เป็น false — ถ้าเน็ตหลุดกลางทาง หน้าที่นำไปใช้แล้วอยู่ครบ และรอบถัดไปถาม
 * ต่อจากหน้านั้นพอดี ไม่ข้ามและไม่ซ้ำ (`data` คือทั้งระเบียน นำไปใช้ซ้ำก็ได้ผลเดิม)
 */

// ------------------------------------------------------------------------------------------ log

/**
 * บรรทัด log เรื่องการคุยกับ ERP — มี `pos_instance` เสมอเมื่อรู้ค่า (สัญญา telemetry v1.2) และไม่มี credential
 * บรรทัดเรื่องการดึงใช้ event ของสัญญา (`PULL_COMPLETED`/`PULL_FAILED`) ที่เหลือ (เชื่อมต่อ/ออก) เป็น `app.log`
 */
const PULL_COMPLETED = 'master_data.pull.completed';
const PULL_FAILED = 'master_data.pull.failed';

const logErp = ({
  severity,
  message,
  event,
  instanceCode,
  requestId,
  reason,
  locationCode,
  error,
}) =>
  writeLog({
    severity,
    message,
    event,
    locationCode,
    labels: {
      ...(instanceCode ? { pos_instance: instanceCode } : {}),
      ...(reason ? { reason } : {}),
    },
    correlationId: requestId,
    error,
  });

const describeCall = (error) =>
  error instanceof ErpCallError
    ? {
        type: error.kind,
        message:
          [
            error.status ? `HTTP ${error.status}` : undefined,
            error.problems?.map((p) => `${p.path} ${p.message}`).join('; '),
            error.contractVersion ? `contract ${error.contractVersion}` : undefined,
          ]
            .filter(Boolean)
            .join(' · ') || error.kind,
      }
    : { type: error?.name ?? 'Error', message: String(error?.message ?? error) };

// ---------------------------------------------------------------------------------- สถานะ/สาขา

const codeProblem = (code) => {
  if (!code) return 'missing';
  return LOCATION_CODE_PATTERN.test(code) ? null : 'invalid';
};

const BRANCH_CODE_MESSAGES = {
  missing: 'สาขานี้ยังไม่มีรหัส ตั้งรหัสให้ตรงกับรหัสสาขาใน PaynEat ERP',
  invalid:
    'รหัสสาขาต้องเป็นตัวพิมพ์ใหญ่ A-Z ตัวเลข หรือ - ยาว 2-32 ตัว และขึ้นต้นด้วยตัวอักษรหรือตัวเลข',
};

const parseJson = (text) => {
  try {
    return text ? JSON.parse(text) : null;
  } catch {
    return null;
  }
};

const toConnectionDto = (row) =>
  row
    ? {
        erpUrl: row.base_url,
        instanceCode: row.instance_code,
        instanceName: row.instance_name,
        contractVersion: row.contract_version,
        connectedAt: row.connected_at,
        appliedVersion: row.applied_version,
        latestVersion: row.latest_version,
        lastPullAt: row.last_pull_at,
        lastError: parseJson(row.last_error),
        credentialRejected: Boolean(row.credential_rejected),
        // ดึงตามรอบเวลาหยุดไว้จนกว่าจะมีคนมาจัดการ (reason ใน lastError) — กด "ดึงทันที" เพื่อลองใหม่
        pullStopped: Boolean(row.pull_stopped),
        retryAfter: row.retry_after,
        // ช่องทางของ credential (ticket 32): insecure_allowed = แสดงคำเตือนถาวร, insecure_blocked = ต้องเปลี่ยนเป็น https
        transport: erpTransport(row.base_url),
        // บอกแค่ว่ามี credential บันทึกไว้ — ตัว credential ไม่เคยถูกส่งกลับหลังบันทึก
        credentialSaved: true,
      }
    : null;

// ------------------------------------------------------------------------ นำการเปลี่ยนแปลงไปใช้

const applyItem = (item) => {
  erpRepository.upsertItem(item);
  // วัตถุดิบในทุกสาขา: ชื่อ = ชื่อไทยของ ERP, หน่วย = รหัสหน่วยฐาน (แอปแสดงเป็นชื่อหน่วยตามภาษา)
  erpRepository.upsertIngredientForAllBranches({
    itemCode: item.itemCode,
    name: item.nameTh,
    unit: item.baseUnitCode,
  });
};

/**
 * สาขาจับคู่ด้วยรหัสสถานที่กลาง — การดึงไม่สร้างสาขาใหม่ใน POS เอง (สาขาที่ยังไม่มีในเครื่องบอกไว้บนหน้าตั้งค่า
 * และ admin กด "สร้างสาขานี้ในเครื่อง" ได้ — `createServedBranch`)
 * สาขาที่ถูกแทนด้วยรหัสใหม่ (`supersededBy`) ย้ายไปใช้รหัสใหม่ทั้งแถว id เดิม ประวัติการขายจึงตามไปด้วย
 */
const applyLocation = (location) => {
  erpRepository.upsertLocation(location);
  const branch = erpRepository.findBranchByCode(location.locationCode);
  if (!branch) return;

  const successor = location.supersededBy?.locationCode;
  if (!successor) {
    erpRepository.updateBranchFromErp(branch.id, {
      code: branch.code,
      name: location.nameTh,
      isActive: location.active,
    });
    return;
  }

  const taken = erpRepository.findBranchByCode(successor);
  if (taken) {
    // มีสาขารหัสใหม่อยู่ในเครื่องแล้ว — รวมสองสาขาเองไม่ได้ ให้คนตัดสิน (สถานะบอกไว้ที่ supersededBy ของสาขา)
    logErp({
      severity: 'WARNING',
      message: `Branch ${location.locationCode} was superseded by ${successor}, which already exists on this POS; left as it is`,
      instanceCode: erpRepository.find()?.instance_code,
    });
    return;
  }
  const next = erpRepository.findLocation(successor);
  erpRepository.updateBranchFromErp(branch.id, {
    code: successor,
    name: next?.name_th ?? branch.name,
    isActive: next ? Boolean(next.is_active) : true,
  });
};

const APPLIERS = { item: applyItem, location: applyLocation };

/** หนึ่งหน้า: ตรวจว่าเวอร์ชันเรียงขึ้นต่อจาก since แล้วนำไปใช้ทั้งหน้าพร้อมบันทึกเวอร์ชันใน transaction เดียว */
const applyPage = (since, page) => {
  let previous = since;
  for (const change of page.changes) {
    if (change.version <= previous) {
      throw new ErpCallError('invalid_response', {
        problems: [{ path: '/changes', message: 'versions not in ascending order after since' }],
      });
    }
    previous = change.version;
  }
  if (page.hasMore && page.changes.length === 0) {
    throw new ErpCallError('invalid_response', {
      problems: [{ path: '/hasMore', message: 'hasMore with no changes' }],
    });
  }

  let applied = 0;
  let skipped = 0;
  getDb().transaction(() => {
    for (const change of page.changes) {
      const apply = APPLIERS[change.entityType];
      // entityType ที่ไม่รู้จัก (สัญญา 1.x เพิ่มได้) ข้ามไป แต่เวอร์ชันยังนับว่านำไปใช้แล้ว
      if (apply) {
        apply(change.data);
        applied += 1;
      } else {
        skipped += 1;
      }
    }
    erpRepository.setAppliedVersion(previous, page.latestVersion);
  })();
  return { applied, skipped, version: previous };
};

// ------------------------------------------------------------------------------------ ดึงข้อมูล

let inFlight = null;

const retryAfterFrom = (error) =>
  error.retryAfterSeconds === undefined
    ? undefined
    : new Date(Date.now() + error.retryAfterSeconds * 1000).toISOString();

const runPull = async () => {
  const connection = erpRepository.find();
  const credentials = erpRepository.findCredentials();
  const instanceCode = connection.instance_code;
  let requestId;
  let applied = 0;
  let skipped = 0;
  let pages = 0;
  try {
    // อ่าน instance ใหม่ทุกรอบ: สาขาที่ ERP ให้ดูแลเปลี่ยนได้ และเวอร์ชันสัญญาอาจขึ้น (major ใหม่ = หยุด)
    const instance = await erpClient.getInstance(credentials);
    requestId = instance.requestId;
    getDb().transaction(() => {
      erpRepository.updateInstance({
        instanceName: instance.body.name,
        contractVersion: instance.body.contractVersion,
      });
      erpRepository.replaceInstanceBranches(instance.body.branches);
    })();

    let since = erpRepository.find().applied_version;
    for (;;) {
      const page = await erpClient.getChanges(credentials, since, env.erp.pageSize);
      requestId = page.requestId;
      const result = applyPage(since, page.body);
      applied += result.applied;
      skipped += result.skipped;
      pages += 1;
      since = result.version;
      if (!page.body.hasMore) break;
    }
    erpRepository.recordPullSuccess();
    const version = erpRepository.find().applied_version;
    logErp({
      severity: 'INFO',
      event: PULL_COMPLETED,
      message: `Pulled master data from PaynEat ERP: ${applied} changes applied, ${skipped} of unknown type skipped, in ${pages} pages; now at version ${version}`,
      instanceCode,
      requestId,
    });
    return { applied, skipped, appliedVersion: version };
  } catch (error) {
    const kind = error instanceof ErpCallError ? error.kind : 'internal';
    const reason = integrationReason(error);
    const stopped = stopsUntilActedOn(error);
    erpRepository.recordPullFailure({
      error: {
        kind,
        status: error.status ?? null,
        reason: reason ?? null,
        at: new Date().toISOString(),
      },
      credentialRejected: kind === 'credential_rejected',
      stopped,
      retryAfter: error instanceof ErpCallError ? retryAfterFrom(error) : undefined,
    });
    logErp({
      severity: failureSeverity(error),
      event: PULL_FAILED,
      message: `Pulling master data from PaynEat ERP failed after ${applied} changes: ${kind}${stopped ? '; scheduled pulls stopped until someone acts' : ''}`,
      instanceCode,
      requestId,
      reason,
      error: describeCall(error),
    });
    throw error;
  }
};

const ERP_FAILURES = {
  credential_rejected: () =>
    new ApiError(
      422,
      'PaynEat ERP ไม่รับ credential นี้ (ถูกเพิกถอนหรือไม่มีอยู่) ขอ credential ใหม่จากผู้ดูแล ERP',
      {
        code: 'ERP_CREDENTIAL_REJECTED',
      },
    ),
  unsupported_contract: (error) =>
    new ApiError(
      422,
      `PaynEat ERP ใช้สัญญาเชื่อมต่อเวอร์ชัน ${error.contractVersion} ซึ่ง POS รุ่นนี้ไม่รองรับ อัปเดต POS ก่อนเชื่อมต่อ`,
      { code: 'ERP_CONTRACT_UNSUPPORTED' },
    ),
  network: () =>
    new ApiError(502, 'ติดต่อ PaynEat ERP ไม่ได้ ตรวจที่อยู่และการเชื่อมต่อเครือข่าย', {
      code: 'ERP_UNREACHABLE',
    }),
  unavailable: () =>
    new ApiError(502, 'PaynEat ERP ไม่พร้อมให้บริการชั่วคราว ลองใหม่อีกครั้งภายหลัง', {
      code: 'ERP_UNAVAILABLE',
    }),
  rate_limited: () =>
    new ApiError(502, 'PaynEat ERP ขอให้รอสักครู่ก่อนเรียกอีกครั้ง', { code: 'ERP_RATE_LIMITED' }),
  invalid_response: () =>
    new ApiError(502, 'คำตอบของ PaynEat ERP ไม่ตรงกับสัญญาเชื่อมต่อ POS v1', {
      code: 'ERP_BAD_RESPONSE',
    }),
  // การเชื่อมต่อที่บันทึกไว้ด้วย http:// ก่อน ticket 32 — ไม่มีคำขอออกไป ต้องบันทึกที่อยู่ https:// ใหม่
  insecure_transport: () =>
    new ApiError(
      409,
      'ที่อยู่ของ PaynEat ERP ต้องขึ้นต้นด้วย https:// เพื่อไม่ให้ credential ถูกส่งแบบไม่เข้ารหัส',
      { code: 'ERP_URL_NOT_HTTPS' },
    ),
  untrusted_certificate: () =>
    new ApiError(
      502,
      'ใบรับรอง HTTPS ของ PaynEat ERP ไม่น่าเชื่อถือ ถ้าเชนใช้ CA ภายใน ให้ผู้ดูแลเซิร์ฟเวอร์ POS ตั้ง NODE_EXTRA_CA_CERTS',
      { code: 'ERP_CERTIFICATE_UNTRUSTED' },
    ),
  refused: (error) =>
    new ApiError(
      502,
      `PaynEat ERP ตอบ HTTP ${error.status} ตรวจว่าที่อยู่ชี้ไปที่ PaynEat ERP จริงและไม่มี proxy ขวางอยู่`,
      { code: 'ERP_REFUSED' },
    ),
};

/** ErpCallError → ApiError ที่แอปแสดงได้ (error อื่นส่งต่อไปตามเดิม) */
const toApiError = (error) =>
  error instanceof ErpCallError && ERP_FAILURES[error.kind]
    ? ERP_FAILURES[error.kind](error)
    : error;

// ---------------------------------------------------------------------------------- service

export const erpService = {
  /** โหมดปัจจุบัน — ทุกคนที่ล็อกอินอ่านได้ (หน้าวัตถุดิบต้องรู้ว่าเป็นอ่านอย่างเดียวไหม) ไม่มีที่อยู่หรือ credential */
  mode() {
    const row = erpRepository.find();
    return { mode: row ? 'connected' : 'standalone', instanceCode: row?.instance_code ?? null };
  },

  /** สถานะเต็มสำหรับหน้าตั้งค่าของ admin */
  status() {
    const row = erpRepository.find();
    const served = row ? erpRepository.findInstanceBranches() : [];
    const servedCodes = new Set(served.map((b) => b.location_code));
    const branches = erpRepository.allBranches();
    const localByCode = new Map(branches.filter((b) => b.code).map((b) => [b.code, b]));

    return {
      mode: row ? 'connected' : 'standalone',
      connection: toConnectionDto(row),
      branches: branches.map((branch) => {
        const problem = codeProblem(branch.code);
        const location = branch.code ? erpRepository.findLocation(branch.code) : undefined;
        return {
          id: branch.id,
          name: branch.name,
          code: branch.code,
          isActive: Boolean(branch.is_active),
          codeProblem: problem,
          servedByErp: row ? servedCodes.has(branch.code) : null,
          supersededBy: location?.superseded_by ?? null,
        };
      }),
      servedBranches: served.map((branch) => ({
        code: branch.location_code,
        nameTh: branch.name_th,
        nameEn: branch.name_en,
        isActive: Boolean(branch.is_active),
        localBranchId: localByCode.get(branch.location_code)?.id ?? null,
      })),
    };
  },

  /**
   * เข้าโหมดเชื่อมต่อ (หรือเปลี่ยน credential/ที่อยู่ของการเชื่อมต่อเดิม): ตรวจรหัสสาขาในเครื่อง → ถาม ERP ว่า
   * credential นี้เป็น instance ไหน → บันทึก → ดึง master data รอบแรก (ดึงไม่สำเร็จไม่ทำให้การเชื่อมต่อล้ม
   * สถานะบอกเหตุผลไว้ และกดดึงใหม่ได้)
   */
  async connect({ erpUrl, credential }, actingUser) {
    // credential ไปได้ทาง https, loopback หรือ http ที่ผู้ดูแลเซิร์ฟเวอร์อนุญาตเองเท่านั้น (ticket 32, DECISIONS #82)
    if (erpTransport(erpUrl) === 'insecure_blocked') {
      throw new ApiError(
        400,
        'ที่อยู่ของ PaynEat ERP ต้องขึ้นต้นด้วย https:// เพื่อไม่ให้ credential ถูกส่งแบบไม่เข้ารหัส',
        { code: 'ERP_URL_NOT_HTTPS' },
      );
    }

    const invalid = erpRepository
      .allBranches()
      .filter((branch) => branch.is_active && codeProblem(branch.code))
      .map((branch) => {
        const problem = codeProblem(branch.code);
        return {
          branchId: branch.id,
          name: branch.name,
          code: branch.code,
          problem,
          message: BRANCH_CODE_MESSAGES[problem],
        };
      });
    if (invalid.length) {
      throw new ApiError(409, 'แก้รหัสสาขาให้ตรงรูปแบบก่อนเชื่อมต่อ PaynEat ERP', {
        code: 'BRANCH_CODES_INVALID',
        details: invalid,
      });
    }

    let instance;
    try {
      instance = await erpClient.getInstance({ baseUrl: erpUrl, credential });
    } catch (error) {
      // การดึงรอบแรกล้มตั้งแต่ถาม instance — ยังไม่รู้ว่า credential นี้เป็น instance ไหน จึงไม่มี pos_instance
      // (สัญญาห้ามเดา) และไม่มีอะไรถูกบันทึก ผู้ดูแลเห็นเหตุผลบนหน้าจอทันที
      logErp({
        severity: failureSeverity(error),
        event: PULL_FAILED,
        message: `Connecting to PaynEat ERP failed: ${error.kind ?? 'internal'}`,
        reason: integrationReason(error),
        error: describeCall(error),
      });
      throw toApiError(error);
    }

    const previous = erpRepository.find();
    const { code, name, contractVersion, branches } = instance.body;
    // ต่อ instance เดิมที่ ERP เดิม (เช่นบันทึก credential ใหม่หลังถูกเพิกถอน) = ดึงต่อจากเวอร์ชันเดิม
    // อย่างอื่นเริ่มจาก 0 ใหม่ทั้งหมด เพราะข้อมูลในเครื่องอาจถูกแก้ระหว่างใช้งานเดี่ยว
    const sameInstance =
      previous && previous.base_url === erpUrl && previous.instance_code === code;

    getDb().transaction(() => {
      erpRepository.save({
        baseUrl: erpUrl,
        credential,
        instanceCode: code,
        instanceName: name,
        contractVersion,
        appliedVersion: sameInstance ? previous.applied_version : 0,
      });
      erpRepository.replaceInstanceBranches(branches);
      // ยอดวัตถุดิบในเครื่องไม่ใช่ความจริงแล้ว (ERP ADR-0003) — เมนูที่ระบบสต๊อกปิดไว้เปิดคืน ปิดขายด้วยมือแทน
      const reopened = erpRepository.reopenMenusClosedByStock();
      auditLogService.log({
        actorUser: actingUser,
        action: 'erp.connect',
        summaryArgs: { instance: code },
        entityType: 'erp_connection',
        entityId: null,
        summary: `เชื่อมต่อ PaynEat ERP ในนาม POS ${code}`,
        metadata: { erpUrl, instanceCode: code, contractVersion, reopenedMenus: reopened },
      });
    })();
    logErp({
      severity: 'INFO',
      message: `Connected to PaynEat ERP as ${code} (contract ${contractVersion})`,
      instanceCode: code,
      requestId: instance.requestId,
    });

    try {
      await this.pull();
    } catch {
      // บันทึกไว้ที่ lastError แล้ว — หน้าตั้งค่าแสดงเหตุผลและมีปุ่มดึงใหม่
    }
    return this.status();
  },

  /** ออกจากโหมดเชื่อมต่อ: ลบ credential; ข้อมูลที่ mirror ไว้ยังอยู่และกลับมาแก้ได้ในโหมดเดี่ยว */
  disconnect(actingUser) {
    const row = erpRepository.find();
    if (!row) return this.status();
    getDb().transaction(() => {
      erpRepository.remove();
      auditLogService.log({
        actorUser: actingUser,
        action: 'erp.disconnect',
        summaryArgs: { instance: row.instance_code },
        entityType: 'erp_connection',
        entityId: null,
        summary: `ออกจากการเชื่อมต่อ PaynEat ERP (POS ${row.instance_code})`,
        metadata: { erpUrl: row.base_url, instanceCode: row.instance_code },
      });
    })();
    logErp({
      severity: 'INFO',
      message: `Disconnected from PaynEat ERP; mirrored master data kept for standalone use`,
      instanceCode: row.instance_code,
    });
    return this.status();
  },

  /**
   * ดึง master data หนึ่งรอบ (ตามรอบเวลา หรือเมื่อกด "ดึงทันที") — รอบที่กำลังดึงอยู่ถูกใช้ร่วมกัน ไม่ดึงซ้อนกัน
   * `manual`: ผู้ใช้กดเอง ได้เหตุผลกลับไปเป็น ApiError; ตามรอบเวลาข้ามเงียบ ๆ เมื่อยังไม่ถึงเวลาหรือต้องรอคน
   * (`pull_stopped`: รอบก่อนล้มด้วยเหตุที่ลองใหม่เองไม่ช่วย — กดดึงเองได้ ถ้าสำเร็จรอบเวลากลับมาทำงาน)
   */
  async pull({ manual = false } = {}) {
    const row = erpRepository.find();
    if (!row) {
      if (manual) throw ApiError.conflict('ยังไม่ได้เชื่อมต่อ PaynEat ERP');
      return undefined;
    }
    if (row.credential_rejected) {
      if (manual) {
        throw new ApiError(
          409,
          'PaynEat ERP ไม่รับ credential นี้แล้ว บันทึก credential ใหม่ก่อนดึงข้อมูล',
          { code: 'ERP_CREDENTIAL_REJECTED' },
        );
      }
      return undefined;
    }
    if (!manual && row.pull_stopped) return undefined;
    if (!manual && row.retry_after && Date.parse(row.retry_after) > Date.now()) return undefined;

    inFlight ??= runPull().finally(() => {
      inFlight = null;
    });
    try {
      return await inFlight;
    } catch (error) {
      throw toApiError(error);
    }
  },

  /**
   * ปุ่ม "สร้างสาขานี้ในเครื่อง" (ข้อ 3 ที่ POS PO ตัดสินใน PR #121, DECISIONS #80) — สร้างสาขาที่ ERP ให้เครื่องนี้ดูแล
   * แต่ในเครื่องยังไม่มี ด้วยรหัสและชื่อไทยของ ERP
   *
   * ดึง master data ให้ครบก่อนเสมอ: ถ้า ERP เพิ่งเปลี่ยนรหัสสาขาเดิมเป็นรหัสนี้ (`supersededBy`) การดึงย้ายสาขาเดิมไปใช้
   * รหัสใหม่ก่อน แล้วค่อยเช็คว่ารหัสนี้มีในเครื่องหรือยัง จึงไม่ได้สาขาซ้ำที่ประวัติการขายแยกกันสองแถว
   * สร้างได้เฉพาะรหัสที่ ERP ให้ instance นี้ดูแล — สาขาอื่นยังสร้างเองไม่ได้ (`MANAGED_BY_ERP`)
   */
  async createServedBranch({ code }, actingUser) {
    await this.pull({ manual: true });

    const served = erpRepository.findInstanceBranches().find((b) => b.location_code === code);
    if (!served) {
      throw new ApiError(409, 'PaynEat ERP ไม่ได้ให้เครื่องนี้ดูแลสาขารหัสนี้', {
        code: 'BRANCH_NOT_SERVED',
      });
    }
    const existing = erpRepository.findBranchByCode(code);
    if (existing) {
      throw new ApiError(409, 'มีสาขารหัสนี้ในเครื่องแล้ว', {
        code: 'BRANCH_ALREADY_LOCAL',
        details: { branchId: existing.id, name: existing.name },
      });
    }

    // ชื่อ/สถานะจาก change log ของสถานที่ถ้าดึงมาแล้ว (ใหม่กว่า) ไม่งั้นจากรายการสาขาของ instance
    const location = erpRepository.findLocation(code);
    const name = location?.name_th ?? served.name_th;
    const isActive = Boolean(location ? location.is_active : served.is_active);
    const instanceCode = erpRepository.find().instance_code;

    let branchId;
    let ingredients;
    getDb().transaction(() => {
      branchId = Number(erpRepository.createBranchFromErp({ code, name, isActive }));
      ingredients = erpRepository.mirrorItemsIntoBranch(branchId);
      auditLogService.log({
        actorUser: actingUser,
        action: 'erp.branch_create',
        summaryArgs: { name, code },
        entityType: 'branch',
        entityId: branchId,
        summary: `สร้างสาขา "${name}" (${code}) จาก PaynEat ERP`,
        metadata: { instanceCode, code, name, isActive, mirroredIngredients: ingredients },
      });
    })();
    logErp({
      severity: 'INFO',
      message: `Created local branch ${code} from PaynEat ERP with ${ingredients} mirrored ingredients`,
      instanceCode,
      locationCode: code,
    });
    return { branchId, status: this.status() };
  },
};

// ---------------------------------------------------------------------------- ตอนเปิดเซิร์ฟเวอร์

/**
 * ตรวจช่องทางของ credential ตอนเปิดเซิร์ฟเวอร์ (ticket 32, server.js เรียก):
 * - `ERP_ALLOW_INSECURE_HTTP=true` → log `WARNING` หนึ่งบรรทัด ให้คนที่ดู log เห็นว่า credential อาจไปทาง http
 * - การเชื่อมต่อที่บันทึกไว้ด้วย http:// ก่อนกติกานี้ → ดึงหนึ่งรอบทันที ซึ่งล้มก่อนมีคำขอออกไป: บันทึกเหตุผลให้หน้าตั้งค่า,
 *   หยุดดึงตามรอบ และ log `master_data.pull.failed` ระดับ `ERROR` โดยไม่ต้องรอรอบเวลาแรก (หรือรอคนกดดึงถ้าปิดรอบไว้)
 */
export const checkErpTransportOnStartup = async () => {
  const row = erpRepository.find();
  if (env.erp.allowInsecureHttp) {
    logErp({
      severity: 'WARNING',
      message:
        'ERP_ALLOW_INSECURE_HTTP=true: the PaynEat ERP credential may travel over plain HTTP; allow this only on a closed network',
      instanceCode: row?.instance_code,
    });
  }
  if (row && erpTransport(row.base_url) === 'insecure_blocked') {
    await erpService.pull().catch(() => {
      // เหตุผลถูกบันทึกและ log ไว้แล้ว
    });
  }
};

// ------------------------------------------------------------------------------- ดึงตามรอบเวลา

let timer = null;

/** เริ่มดึงตามรอบเวลา (server.js เรียกตอนเปิดเซิร์ฟเวอร์) — ใช้งานเดี่ยวก็ตั้งไว้ได้ ไม่มีการเชื่อมต่อ = ไม่ทำอะไร */
export const startErpPullSchedule = () => {
  const seconds = env.erp.pullIntervalSeconds;
  if (!seconds || timer) return;
  timer = setInterval(() => {
    erpService.pull().catch(() => {
      // เหตุผลถูกบันทึกและ log ไว้แล้ว รอบถัดไปลองใหม่
    });
  }, seconds * 1000);
  timer.unref();
};

export const stopErpPullSchedule = () => {
  if (timer) clearInterval(timer);
  timer = null;
};

export default erpService;
