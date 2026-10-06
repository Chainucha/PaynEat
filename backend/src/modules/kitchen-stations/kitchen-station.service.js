// Copyright 2026 Suruch Chakrapeesirisuk
// SPDX-License-Identifier: Apache-2.0

import { ApiError } from '../../core/ApiError.js';
import { getDb } from '../../db/index.js';
import { kitchenStationRepository } from './kitchen-station.repository.js';
import { toKitchenStationDto } from './kitchen-station.mapper.js';

export const kitchenStationService = {
  list(filters) {
    return kitchenStationRepository.findAll(filters).map(toKitchenStationDto);
  },

  getById(id) {
    const station = kitchenStationRepository.findById(id);
    if (!station) throw ApiError.notFound('ไม่พบสถานีครัวนี้');
    return toKitchenStationDto(station);
  },

  /** หาสถานีจากรหัสที่ส่งมาทาง query — 404 เพื่อให้จอครัวที่จำรหัสเก่าไว้รู้ว่าต้องกลับไป "ทุกสถานี" */
  getByCode(code) {
    const station = kitchenStationRepository.findByCode(code);
    if (!station) throw ApiError.notFound(`ไม่พบสถานีครัวรหัส "${code}"`);
    return toKitchenStationDto(station);
  },

  /** 400 เมื่อสถานีที่อ้างถึงไม่มีจริง — ปล่อยผ่านเมื่อไม่ได้ส่งมา (เมนู/หมวดหมู่ไม่ผูกสถานีก็ได้) */
  assertStationExists(stationId) {
    if (stationId === undefined || stationId === null) return;
    if (!kitchenStationRepository.findById(stationId)) {
      throw ApiError.badRequest('ไม่พบสถานีครัวที่ระบุ');
    }
  },

  /**
   * สถานีค่าเริ่มต้น — ปลายทางของจานที่ไม่ได้กำหนดสถานีไว้เลย (ticket 34)
   * ถ้าไม่มีแถวที่ติดธงไว้ (ฐานข้อมูลถูกแก้มือ) ถอยไปใช้สถานีที่เปิดใช้งานตัวแรกแทน ดีกว่าให้รับออเดอร์ไม่ได้
   */
  defaultStation() {
    const station =
      kitchenStationRepository.findDefault() ?? kitchenStationRepository.findFirstActive();
    if (!station) throw ApiError.conflict('ยังไม่มีสถานีครัวในระบบ กรุณาเพิ่มสถานีครัวก่อน');
    return station;
  },

  /**
   * กฎการตัดสินสถานีของหนึ่งจาน: เมนู → หมวดหมู่ → ค่าเริ่มต้น (docs/DECISIONS.md #94)
   * รับแถวจาก `menuRepository.findById` ที่ join หมวดหมู่มาให้แล้ว (`category_station_id`)
   * จึงเป็นฟังก์ชันบริสุทธิ์ของแถวเดียว ไม่ต้องยิง query เพิ่มต่อจาน
   */
  resolveForMenuItem(menuItemRow) {
    const stationId = menuItemRow.station_id ?? menuItemRow.category_station_id ?? null;
    const station = stationId ? kitchenStationRepository.findById(stationId) : null;
    const resolved = station ?? this.defaultStation();
    return { id: resolved.id, name: resolved.name };
  },

  create(payload) {
    if (kitchenStationRepository.findByCode(payload.code)) {
      throw ApiError.conflict(`รหัสสถานี "${payload.code}" ถูกใช้แล้ว`);
    }
    return toKitchenStationDto(kitchenStationRepository.create(payload));
  },

  update(id, payload) {
    const current = kitchenStationRepository.findById(id);
    if (!current) throw ApiError.notFound('ไม่พบสถานีครัวนี้');

    // ปลดธงค่าเริ่มต้นออกเฉย ๆ ไม่ได้ ไม่งั้นจานที่ไม่ได้กำหนดสถานีจะไม่มีปลายทาง
    if (payload.isDefault === false && current.is_default) {
      throw ApiError.conflict('ตั้งสถานีอื่นเป็นค่าเริ่มต้นก่อน แล้วค่อยปลดสถานีนี้');
    }
    if (payload.isActive === false && current.is_default) {
      throw ApiError.conflict(
        'ปิดใช้งานสถานีค่าเริ่มต้นไม่ได้ กรุณาตั้งสถานีอื่นเป็นค่าเริ่มต้นก่อน',
      );
    }

    const updated = getDb().transaction(() => {
      const row = kitchenStationRepository.update(id, payload);
      // ตั้งเป็นค่าเริ่มต้น = ปลดของเดิมก่อนเสมอ (partial unique index บังคับว่ามีได้ไม่เกินหนึ่ง)
      // และบังคับให้เปิดใช้งาน เพราะค่าเริ่มต้นที่ถูกปิดอยู่เท่ากับไม่มีค่าเริ่มต้น
      if (payload.isDefault === true && !row.is_default) {
        kitchenStationRepository.clearDefault();
        return kitchenStationRepository.setDefault(id);
      }
      return row;
    })();
    return toKitchenStationDto(updated);
  },

  /**
   * ลบได้เฉพาะสถานีที่ยังไม่เคยถูกใช้ — สถานีที่เคยอยู่บนตั๋วให้ "ปิดใช้งาน" แทน
   * ตรวจไว้ก่อนถึงฐานข้อมูลเพื่อให้ได้ 409 พร้อมเหตุผล ไม่ใช่ SQLITE_CONSTRAINT ดิบ ๆ
   */
  remove(id) {
    const station = kitchenStationRepository.findById(id);
    if (!station) throw ApiError.notFound('ไม่พบสถานีครัวนี้');
    if (station.is_default) {
      throw ApiError.conflict('ลบสถานีค่าเริ่มต้นไม่ได้ กรุณาตั้งสถานีอื่นเป็นค่าเริ่มต้นก่อน');
    }
    if (kitchenStationRepository.countMenuItems(id) > 0) {
      throw ApiError.conflict('ลบไม่ได้ เพราะยังมีเมนูผูกกับสถานีนี้ กรุณาย้ายเมนูออกก่อน');
    }
    if (kitchenStationRepository.countCategories(id) > 0) {
      throw ApiError.conflict('ลบไม่ได้ เพราะยังมีหมวดหมู่ผูกกับสถานีนี้ กรุณาย้ายหมวดหมู่ออกก่อน');
    }
    if (kitchenStationRepository.countOrderItems(id) > 0) {
      throw ApiError.conflict('สถานีนี้ถูกใช้ในบิลไปแล้ว ปิดใช้งานแทนการลบ');
    }
    kitchenStationRepository.remove(id);
  },
};

export default kitchenStationService;
