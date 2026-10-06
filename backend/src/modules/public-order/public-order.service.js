// Copyright 2026 Suruch Chakrapeesirisuk
// SPDX-License-Identifier: Apache-2.0

import { env } from '../../config/env.js';
import { ApiError } from '../../core/ApiError.js';
import { tableRepository } from '../tables/table.repository.js';
import { branchRepository } from '../branches/branch.repository.js';
import { categoryService } from '../categories/category.service.js';
import { menuService } from '../menu/menu.service.js';
import { menuRepository } from '../menu/menu.repository.js';
import { orderService } from '../orders/order.service.js';

// ใช้แทน req.user ปกติ (ดู order.service.js#create/#addItems — เดิมรับ user ของพนักงานเสมอ) เพื่อให้
// audit log เห็นชัดว่ารายการนี้ลูกค้าสั่งเองผ่าน QR ไม่ใช่พนักงานคนไหนกดให้ (ดู
// docs/tickets/17-qr-self-order.md, docs/DECISIONS.md #36) — id เป็น null เสมอ ไม่ผูกกับ user จริง
const SELF_ORDER_ACTOR = { id: null, name: 'ลูกค้า (สแกน QR สั่งเอง)' };

// code ของ error เพดาน QR (DECISIONS #99) — แอปใช้แยกข้อความนี้ออกจาก error อื่น แสดงให้ลูกค้าตรงๆ
export const SELF_ORDER_LIMIT_CODE = 'SELF_ORDER_LIMIT';

/** จำนวนรวมของรายการที่ยังไม่ถูกยกเลิกในออเดอร์ (รวมที่พนักงานสั่งให้ด้วย) */
const activeQuantity = (order) =>
  (order?.items ?? [])
    .filter((item) => item.status !== 'cancelled')
    .reduce((sum, item) => sum + item.quantity, 0);

/**
 * เพดานของการสั่งผ่าน QR (DECISIONS #99): จำนวนต่อรายการ และจำนวนรวมของบิลหลังเพิ่มรอบนี้ — เกินข้อไหน
 * ปฏิเสธทั้งคำขอ ไม่ตัดเหลือบางส่วน ลูกค้าจะได้รู้ว่าต้องเรียกพนักงาน กฎนี้อยู่ที่ service นี้ที่เดียว
 * orderService ที่พนักงานใช้ไม่รู้จักเพดานนี้ พนักงานจึงสั่งเกินได้ตามปกติ
 */
const assertWithinSelfOrderLimits = (items, existingOrder) => {
  const { maxQuantityPerLine, maxOrderQuantity } = env.selfOrder;
  if (items.some((item) => item.quantity > maxQuantityPerLine)) {
    throw new ApiError(
      409,
      `สั่งผ่าน QR ได้ไม่เกิน ${maxQuantityPerLine} ที่ต่อรายการ ถ้าต้องการมากกว่านี้กรุณาเรียกพนักงาน`,
      { code: SELF_ORDER_LIMIT_CODE },
    );
  }
  const current = activeQuantity(existingOrder);
  const requested = items.reduce((sum, item) => sum + item.quantity, 0);
  if (current + requested > maxOrderQuantity) {
    throw new ApiError(
      409,
      `โต๊ะนี้สั่งผ่าน QR ได้รวมไม่เกิน ${maxOrderQuantity} ที่ต่อบิล (สั่งไปแล้ว ${current} ที่) ถ้าต้องการสั่งเพิ่มกรุณาเรียกพนักงาน`,
      { code: SELF_ORDER_LIMIT_CODE },
    );
  }
};

/**
 * โต๊ะต้อง active และถ้ามีสาขาผูกอยู่ สาขานั้นต้อง active ด้วย (เหมือนกฎที่ authenticate เช็คให้
 * พนักงานทุก request ดู middlewares/auth.js) — ปิดสาขา/ปิดโต๊ะแล้วต้องปิดจริง ลูกค้าสั่งเองต่อไม่ได้
 * ทันทีเหมือนกัน ไม่ต้องรอเปลี่ยน QR สติกเกอร์ทิ้ง
 */
const resolveTable = (qrToken) => {
  const table = tableRepository.findByQrToken(qrToken);
  if (!table || !table.is_active) {
    throw ApiError.notFound('ไม่พบโต๊ะนี้ หรือโต๊ะนี้ปิดใช้งานอยู่ กรุณาเรียกพนักงาน');
  }
  const branch = table.branch_id ? branchRepository.findById(table.branch_id) : null;
  if (table.branch_id && (!branch || !branch.is_active)) {
    throw ApiError.notFound('สาขานี้ปิดให้บริการอยู่ กรุณาเรียกพนักงาน');
  }
  return { table, branch };
};

/**
 * ตัดฟิลด์ที่ลูกค้าไม่จำเป็นต้องเห็น (ชื่อ/เบอร์โทรลูกค้าที่ผูกไว้, ชื่อพนักงานเสิร์ฟ) ออกจาก
 * order DTO เต็มที่พนักงานใช้ — คืนแค่รายการ/ยอดที่ลูกค้าต้องใช้ตรวจสอบออเดอร์ตัวเอง
 */
const toPublicOrderPreview = (order) => {
  if (!order) return null;
  return {
    id: order.id,
    code: order.code,
    status: order.status,
    subtotal: order.subtotal,
    discountAmount: order.discountAmount,
    promotionName: order.promotionName,
    promotionDiscountAmount: order.promotionDiscountAmount,
    serviceCharge: order.serviceCharge,
    vat: order.vat,
    total: order.total,
    items: order.items
      .filter((item) => item.status !== 'cancelled')
      .map((item) => ({
        id: item.id,
        menuItemId: item.menuItemId,
        name: item.name,
        quantity: item.quantity,
        unitPrice: item.unitPrice,
        options: item.options,
        optionsPrice: item.optionsPrice,
        lineTotal: item.lineTotal,
        note: item.note,
        status: item.status,
      })),
  };
};

/**
 * เมนูฝั่งลูกค้าเลือกฟิลด์ทีละตัวจาก DTO เมนูของพนักงาน (แทนการตัดบางฟิลด์ทิ้ง) ให้ตรงกับที่หน้า
 * QR ใช้จริง (app/lib/features/self_order/ → MenuItemModel.fromJson) — ฟิลด์ใหม่ที่เพิ่มเข้า DTO
 * ฝั่งพนักงานภายหลังจะไม่ติดมาในเมนูลูกค้าเอง ต้องตั้งใจเพิ่มตรงนี้ (เทสต์ล็อกชุดคีย์ไว้ใน
 * tests/public-order.test.js) ส่วน minSelect ของกลุ่มตัวเลือกส่งไปด้วยแม้หน้าจอยังไม่อ่าน เพราะเป็น
 * กฎที่ order.service.js ใช้ตรวจตอนลูกค้ากดสั่ง
 */
const toPublicMenuOption = (option) => ({
  id: option.id,
  name: option.name,
  priceDelta: option.priceDelta,
  isDefault: option.isDefault,
});

const toPublicMenuOptionGroup = (group) => ({
  id: group.id,
  name: group.name,
  minSelect: group.minSelect,
  maxSelect: group.maxSelect,
  isRequired: group.isRequired,
  options: group.options.map(toPublicMenuOption),
});

const toPublicMenuItem = (item) => ({
  id: item.id,
  categoryId: item.categoryId,
  name: item.name,
  nameEn: item.nameEn,
  description: item.description,
  price: item.price,
  imageUrl: item.imageUrl,
  isAvailable: item.isAvailable,
  isRecommended: item.isRecommended,
  optionGroups: item.optionGroups.map(toPublicMenuOptionGroup),
});

// แถบหมวดหมู่หน้า QR ใช้แค่ชื่อ/ไอคอน ลำดับมากับ array อยู่แล้ว (เรียง sort_order มาจาก repository)
const toPublicCategory = (category) => ({
  id: category.id,
  name: category.name,
  nameEn: category.nameEn,
  icon: category.icon,
});

export const publicOrderService = {
  getTable(qrToken) {
    const { table, branch } = resolveTable(qrToken);
    const order = orderService.getOpenByTable(table.id);
    return {
      table: { id: table.id, name: table.name, zone: table.zone },
      branchName: branch?.name ?? null,
      order: toPublicOrderPreview(order),
    };
  },

  getMenu(qrToken) {
    const { table } = resolveTable(qrToken);
    const categories = categoryService.list({ activeOnly: true }).map(toPublicCategory);
    const { items } = menuService.list({ availableOnly: true }, table.branch_id);
    // สินค้าขายตามน้ำหนักต้องให้พนักงานชั่งจริงก่อนถึงรู้ราคา ลูกค้าสั่งเองจากโต๊ะไม่ได้ จึงไม่แสดง
    // ในเมนูฝั่งลูกค้าเลย (ดู docs/tickets/18-sell-by-weight.md)
    const orderable = items.filter((item) => !item.soldByWeight).map(toPublicMenuItem);
    // บอกจำนวนที่ซ่อนไว้ด้วย หน้า QR จะได้บอกลูกค้าว่ามีของที่ต้องสั่งกับพนักงาน แทนที่จะหายเงียบ
    // (DECISIONS #64) — ส่งแค่จำนวน ไม่ส่งชื่อ/ราคา เพราะราคาขึ้นกับน้ำหนักที่ชั่งจริง
    const staffOnlyCount = items.length - orderable.length;
    // เพดานของ QR (DECISIONS #99) — หน้า QR ใช้ค่านี้จำกัดปุ่มเพิ่มจำนวน ตามค่าที่ร้านตั้งไว้จริง
    const { maxQuantityPerLine, maxOrderQuantity } = env.selfOrder;
    return {
      categories,
      items: orderable,
      staffOnlyCount,
      limits: { maxQuantityPerLine, maxOrderQuantity },
    };
  },

  /**
   * เพิ่มรายการเข้าออเดอร์ปัจจุบันของโต๊ะนี้ — เปิดออเดอร์ใหม่ให้อัตโนมัติถ้ายังไม่มีออเดอร์เปิดอยู่
   * (ลูกค้าคนแรกของโต๊ะ) ใช้ orderService ตัวเดียวกับที่พนักงานใช้ทุกประการ (ไม่มี code path แยก)
   * จึงได้ผลข้างเคียงที่ถูกต้องครบฟรี: ตัดสต๊อกถ้าส่งครัวไปแล้ว, ประเมินโปรโมชันอัตโนมัติใหม่,
   * บันทึก audit log, และแจ้งเตือนแบบเรียลไทม์เข้าจอครัว/ผังโต๊ะของพนักงานทันที
   */
  addItems(qrToken, items) {
    const { table } = resolveTable(qrToken);
    // กันยิง API ตรงด้วย id ของเมนูชั่งน้ำหนักที่ถูกซ่อนจากเมนูลูกค้าไว้แล้ว (getMenu ด้านบน)
    for (const item of items) {
      const menuItem = menuRepository.findById(item.menuItemId);
      if (menuItem?.sold_by_weight) {
        throw ApiError.conflict(
          `"${menuItem.name}" ขายตามน้ำหนัก ต้องให้พนักงานชั่งให้ กรุณาเรียกพนักงาน`,
        );
      }
    }
    const existingOrder = orderService.getOpenByTable(table.id);
    assertWithinSelfOrderLimits(items, existingOrder);

    const order = existingOrder
      ? orderService.addItems(existingOrder.id, items, SELF_ORDER_ACTOR)
      : orderService.create(
          { type: 'dine_in', tableId: table.id, guestCount: 1, items },
          SELF_ORDER_ACTOR,
          table.branch_id,
        );

    // ปุ่มฝั่งลูกค้าคือ "ส่งเข้าครัว" และหน้าจอบอกว่า "ส่งออเดอร์เข้าครัวเรียบร้อยแล้ว" แต่ออเดอร์ที่
    // เพิ่งเปิดยังเป็นร่าง ('open') ซึ่งคิวครัวไม่ดึงมาแสดงเลย (ดูแค่ in_kitchen/served) — ลูกค้าจะ
    // นั่งรออาหารที่ไม่มีใครทำ จึงส่งเข้าครัวต่อทันทีด้วย sendToKitchen ตัวเดียวกับที่พนักงานกด
    // (ตัดสต๊อก + ยิง KITCHEN_TICKET ครบ) ออเดอร์ที่อยู่ในครัวอยู่แล้วไม่ต้องส่งซ้ำ เพราะ addItems
    // ตัดสต๊อกให้รายการใหม่และครัวเห็นทันทีอยู่แล้ว (ดู docs/DECISIONS.md #46)
    const sent = order.status === 'open' ? orderService.sendToKitchen(order.id) : order;
    return toPublicOrderPreview(sent);
  },
};

export default publicOrderService;
