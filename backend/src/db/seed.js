// Copyright 2026 Suruch Chakrapeesirisuk
// SPDX-License-Identifier: Apache-2.0

import bcrypt from 'bcryptjs';
import { randomUUID } from 'node:crypto';
import { getDb } from './index.js';
import { migrate } from './migrate.js';
import { toSatang } from '../core/money.js';
import { logger } from '../core/telemetry/logger.js';

/**
 * ข้อมูลตัวอย่างสำหรับเดโม — รันซ้ำได้ (idempotent) เพราะเช็คก่อนว่ามีข้อมูลแล้วหรือยัง
 */
// prettier-ignore
const USERS = [
  { name: 'ผู้ดูแลระบบ', username: 'admin', password: 'admin123', role: 'admin' },
  { name: 'สมชาย (ผู้จัดการ)', username: 'manager', password: 'manager123', role: 'manager' },
  { name: 'น้องฝน (พนักงานเสิร์ฟ)', username: 'waiter1', password: 'waiter123', role: 'waiter' },
  { name: 'น้องมิ้น (พนักงานเสิร์ฟ)', username: 'waiter2', password: 'waiter123', role: 'waiter' },
  { name: 'เชฟต้น (ครัว)', username: 'kitchen', password: 'kitchen123', role: 'kitchen' },
  { name: 'พี่แอน (แคชเชียร์)', username: 'cashier', password: 'cashier123', role: 'cashier' },
];

// ชื่อ env var รหัสผ่านต่อบัญชีเดโม 1 ตัว — ใช้เฉพาะตอน NODE_ENV=production (ดู resolveSeedPassword
// ด้านล่าง และ SECURITY.md หัวข้อ "ข้อกำหนดก่อนนำไปใช้งานจริง")
const SEED_PASSWORD_ENV_KEYS = {
  admin: 'SEED_ADMIN_PASSWORD',
  manager: 'SEED_MANAGER_PASSWORD',
  waiter1: 'SEED_WAITER1_PASSWORD',
  waiter2: 'SEED_WAITER2_PASSWORD',
  kitchen: 'SEED_KITCHEN_PASSWORD',
  cashier: 'SEED_CASHIER_PASSWORD',
};

// รหัสผ่านเดโม (admin123 ฯลฯ) เผยแพร่อยู่ใน README/ซอร์สโค้ดสาธารณะ ใช้ได้เฉพาะตอนรันดูในเครื่อง/
// เดโมเท่านั้น — ใน production ต้องตั้งรหัสผ่านเองผ่าน env ให้ครบทุกบัญชีก่อนเสมอ ไม่งั้น seed()
// จะ throw แทนที่จะ fallback ไปใช้รหัสผ่านที่รู้กันอยู่แล้วอย่างเงียบๆ (fail-closed เหมือน
// JWT_SECRET ใน config/env.js — ดูรายงาน security review)
const resolveSeedPassword = (user) => {
  if (process.env.NODE_ENV !== 'production') return user.password;

  const envKey = SEED_PASSWORD_ENV_KEYS[user.username];
  const value = envKey ? process.env[envKey] : undefined;
  if (!value) {
    throw new Error(
      `ต้องตั้งค่า ${envKey} ก่อน seed บัญชี "${user.username}" ใน production ` +
        `(ห้ามใช้รหัสผ่านเดโม "${user.password}" ที่เผยแพร่อยู่ใน README/ซอร์สโค้ด) ` +
        'หรือตั้ง AUTO_SEED=false แล้วสร้างบัญชีจริงเอง — ดู SECURITY.md',
    );
  }
  return value;
};

// `station` = รหัสสถานีครัวตั้งต้นของหมวดหมู่ (ticket 34) เมนูรายตัวทับได้ ดู MENU ด้านล่าง
// prettier-ignore
const CATEGORIES = [
  { name: 'แนะนำ', nameEn: 'Recommended', icon: '⭐', sortOrder: 1, station: 'hot' },
  { name: 'อาหารจานเดียว', nameEn: 'Rice & Noodles', icon: '🍛', sortOrder: 2, station: 'hot' },
  { name: 'กับข้าว', nameEn: 'Main Dishes', icon: '🍲', sortOrder: 3, station: 'hot' },
  { name: 'ยำ / สลัด', nameEn: 'Salads', icon: '🥗', sortOrder: 4, station: 'cold' },
  { name: 'ของทานเล่น', nameEn: 'Appetizers', icon: '🍤', sortOrder: 5, station: 'hot' },
  { name: 'เครื่องดื่ม', nameEn: 'Drinks', icon: '🥤', sortOrder: 6, station: 'bar' },
  { name: 'ของหวาน', nameEn: 'Desserts', icon: '🍨', sortOrder: 7, station: 'bar' },
  // เคาน์เตอร์ขายเนื้อสด/ของฝากกลับบ้าน (ดู docs/tickets/18-sell-by-weight.md, 19-barcode-scale.md)
  { name: 'เนื้อสด & ของกลับบ้าน', nameEn: 'Fresh Meat & Take-home', icon: '🥩', sortOrder: 8, station: 'cold' },
];

// prettier-ignore
const MENU = [
  // อาหารจานเดียว
  { cat: 'อาหารจานเดียว', name: 'ข้าวผัดกุ้ง', nameEn: 'Shrimp Fried Rice', price: 90, prep: 10, recommended: true, desc: 'ข้าวผัดหอมกระทะ กุ้งสดตัวโต' },
  { cat: 'อาหารจานเดียว', name: 'ผัดกะเพราหมูสับ', nameEn: 'Basil Pork with Rice', price: 75, prep: 8, recommended: true, desc: 'เผ็ดร้อนแบบต้นตำรับ ราดข้าวสวยร้อน ๆ' },
  { cat: 'อาหารจานเดียว', name: 'ผัดไทยกุ้งสด', nameEn: 'Pad Thai with Shrimp', price: 95, prep: 12, desc: 'เส้นจันท์ผัดซอสมะขาม' },
  { cat: 'อาหารจานเดียว', name: 'ข้าวหมูกรอบ', nameEn: 'Crispy Pork with Rice', price: 85, prep: 8 },
  { cat: 'อาหารจานเดียว', name: 'ราดหน้าหมูหมัก', nameEn: 'Pork Noodles in Gravy', price: 80, prep: 10 },
  // กับข้าว
  { cat: 'กับข้าว', name: 'ต้มยำกุ้งน้ำข้น', nameEn: 'Tom Yum Goong', price: 220, prep: 15, recommended: true, desc: 'กุ้งแม่น้ำ น้ำข้นเข้มข้น' },
  { cat: 'กับข้าว', name: 'แกงเขียวหวานไก่', nameEn: 'Green Curry Chicken', price: 160, prep: 15 },
  { cat: 'กับข้าว', name: 'ปลาทับทิมนึ่งมะนาว', nameEn: 'Steamed Fish with Lime', price: 320, prep: 20 },
  { cat: 'กับข้าว', name: 'ผัดผักรวมมิตร', nameEn: 'Stir-fried Mixed Vegetables', price: 120, prep: 8 },
  { cat: 'กับข้าว', name: 'ไข่เจียวปู', nameEn: 'Crab Omelette', price: 180, prep: 10 },
  // ยำ / สลัด
  { cat: 'ยำ / สลัด', name: 'ส้มตำไทย', nameEn: 'Papaya Salad', price: 80, prep: 7, recommended: true },
  { cat: 'ยำ / สลัด', name: 'ยำวุ้นเส้นทะเล', nameEn: 'Seafood Glass Noodle Salad', price: 150, prep: 10 },
  { cat: 'ยำ / สลัด', name: 'ลาบหมู', nameEn: 'Spicy Minced Pork Salad', price: 110, prep: 10 },
  // ของทานเล่น
  { cat: 'ของทานเล่น', name: 'ปีกไก่ทอดน้ำปลา', nameEn: 'Fried Chicken Wings', price: 120, prep: 12 },
  { cat: 'ของทานเล่น', name: 'กุ้งชุบแป้งทอด', nameEn: 'Deep-fried Shrimp', price: 160, prep: 12 },
  { cat: 'ของทานเล่น', name: 'ปอเปี๊ยะทอด', nameEn: 'Spring Rolls', price: 90, prep: 8 },
  // เครื่องดื่ม
  { cat: 'เครื่องดื่ม', name: 'ชาไทยเย็น', nameEn: 'Thai Iced Tea', price: 55, prep: 3, recommended: true },
  { cat: 'เครื่องดื่ม', name: 'น้ำมะนาวโซดา', nameEn: 'Lime Soda', price: 60, prep: 3 },
  { cat: 'เครื่องดื่ม', name: 'น้ำเปล่า', nameEn: 'Drinking Water', price: 20, prep: 1 },
  { cat: 'เครื่องดื่ม', name: 'โค้ก', nameEn: 'Coke', price: 30, prep: 1 },
  { cat: 'เครื่องดื่ม', name: 'เบียร์สิงห์', nameEn: 'Singha Beer', price: 90, prep: 2 },
  // ของหวาน
  { cat: 'ของหวาน', name: 'ข้าวเหนียวมะม่วง', nameEn: 'Mango Sticky Rice', price: 120, prep: 6, recommended: true },
  { cat: 'ของหวาน', name: 'บัวลอยไข่หวาน', nameEn: 'Bua Loy', price: 70, prep: 6 },
  { cat: 'ของหวาน', name: 'ไอศกรีมกะทิ', nameEn: 'Coconut Ice Cream', price: 65, prep: 3 },
  // ขายตามน้ำหนัก — price คือราคาต่อกิโลกรัม, plu คือรหัสสินค้าบนฉลากตาชั่ง
  { cat: 'เนื้อสด & ของกลับบ้าน', name: 'หมูสามชั้นสไลซ์', nameEn: 'Sliced Pork Belly', price: 280, prep: 2, soldByWeight: true, plu: '101', desc: 'ราคาต่อกิโลกรัม ชั่งตามจริง' },
  { cat: 'เนื้อสด & ของกลับบ้าน', name: 'เนื้อวัวริบอาย', nameEn: 'Beef Ribeye', price: 1200, prep: 2, soldByWeight: true, plu: '102', desc: 'ราคาต่อกิโลกรัม ชั่งตามจริง' },
  { cat: 'เนื้อสด & ของกลับบ้าน', name: 'หมูหมักบุลโกกิ', nameEn: 'Bulgogi Marinated Pork', price: 320, prep: 2, soldByWeight: true, plu: '103', desc: 'ราคาต่อกิโลกรัม ชั่งตามจริง' },
  // สินค้าสำเร็จรูป มีบาร์โค้ด EAN-13 จริง (check digit ถูกต้อง) สแกนแล้วลงตะกร้า 1 ชิ้น
  { cat: 'เนื้อสด & ของกลับบ้าน', name: 'ซอสหมักบุลโกกิ (ขวด)', nameEn: 'Bulgogi Marinade (bottle)', price: 159, prep: 1, barcode: '8850999320014' },
  { cat: 'เนื้อสด & ของกลับบ้าน', name: 'กิมจิ 500 กรัม', nameEn: 'Kimchi 500 g', price: 129, prep: 1, barcode: '8850999320021' },
];

// ตัวเลือกเสริมของบางเมนู (ระดับความเผ็ด / ท็อปปิ้ง / ระดับความหวาน)
const OPTION_TEMPLATES = {
  spicy: {
    name: 'ระดับความเผ็ด',
    required: 1,
    min: 1,
    max: 1,
    options: [
      { name: 'ไม่เผ็ด', delta: 0, isDefault: 1 },
      { name: 'เผ็ดน้อย', delta: 0 },
      { name: 'เผ็ดปกติ', delta: 0 },
      { name: 'เผ็ดมาก', delta: 0 },
    ],
  },
  extra: {
    name: 'เพิ่มพิเศษ',
    required: 0,
    min: 0,
    max: 3,
    options: [
      { name: 'ไข่ดาว', delta: 15 },
      { name: 'เพิ่มข้าว', delta: 10 },
      { name: 'พิเศษ (เพิ่มปริมาณ)', delta: 20 },
    ],
  },
  sweet: {
    name: 'ระดับความหวาน',
    required: 1,
    min: 1,
    max: 1,
    options: [
      { name: 'หวานปกติ', delta: 0, isDefault: 1 },
      { name: 'หวานน้อย', delta: 0 },
      { name: 'ไม่หวาน', delta: 0 },
    ],
  },
  ice: {
    name: 'น้ำแข็ง',
    required: 0,
    min: 0,
    max: 1,
    options: [
      { name: 'ปกติ', delta: 0, isDefault: 1 },
      { name: 'น้อย', delta: 0 },
      { name: 'ไม่ใส่', delta: 0 },
    ],
  },
};

const MENU_OPTIONS = {
  ผัดกะเพราหมูสับ: ['spicy', 'extra'],
  ข้าวผัดกุ้ง: ['extra'],
  ผัดไทยกุ้งสด: ['spicy', 'extra'],
  ส้มตำไทย: ['spicy'],
  ลาบหมู: ['spicy'],
  ยำวุ้นเส้นทะเล: ['spicy'],
  ต้มยำกุ้งน้ำข้น: ['spicy'],
  ชาไทยเย็น: ['sweet', 'ice'],
  น้ำมะนาวโซดา: ['sweet', 'ice'],
};

// วัตถุดิบตัวอย่าง (ดู docs/tickets/06-inventory-stock.md) — หน่วยอิสระที่ร้านตั้งเอง ไม่ใช่เงิน
// "ปลาทับทิม" ตั้งใจให้ current_stock ต่ำกว่า low_stock_threshold ตั้งแต่ seed เพื่อให้เห็นตัวอย่าง
// การแจ้งเตือนของใกล้หมดได้ทันทีโดยไม่ต้องสั่งอาหารก่อน
// prettier-ignore
const INGREDIENTS = [
  { name: 'กุ้งสด', unit: 'กรัม', currentStock: 3000, lowStockThreshold: 500 },
  { name: 'หมูสับ', unit: 'กรัม', currentStock: 4000, lowStockThreshold: 800 },
  { name: 'ข้าวสวย', unit: 'จาน', currentStock: 100, lowStockThreshold: 20 },
  { name: 'ไข่ไก่', unit: 'ฟอง', currentStock: 60, lowStockThreshold: 12 },
  { name: 'เนื้อปู', unit: 'กรัม', currentStock: 500, lowStockThreshold: 300 },
  { name: 'ปลาทับทิม', unit: 'ตัว', currentStock: 3, lowStockThreshold: 5 },
  // วัตถุดิบของเมนูขายตามน้ำหนัก ตั้งหน่วยเป็นกิโลกรัม และผูกเมนู "1 ต่อ 1 กก." ขายไป 0.485 กก.
  // สต๊อกลด 0.485 พอดี (ดู docs/DECISIONS.md #48)
  { name: 'หมูสามชั้น', unit: 'กก.', currentStock: 25, lowStockThreshold: 5 },
  { name: 'เนื้อริบอาย', unit: 'กก.', currentStock: 8, lowStockThreshold: 2 },
];

// เมนู → วัตถุดิบที่ใช้ + ปริมาณต่อ 1 ที่ (ผูกไว้แค่บางเมนูเป็นตัวอย่าง ไม่ใช่ทุกเมนู)
const MENU_ITEM_INGREDIENTS = {
  ข้าวผัดกุ้ง: [
    { ingredient: 'กุ้งสด', qtyPerUnit: 80 },
    { ingredient: 'ข้าวสวย', qtyPerUnit: 1 },
  ],
  ผัดกะเพราหมูสับ: [
    { ingredient: 'หมูสับ', qtyPerUnit: 100 },
    { ingredient: 'ข้าวสวย', qtyPerUnit: 1 },
  ],
  ปลาทับทิมนึ่งมะนาว: [{ ingredient: 'ปลาทับทิม', qtyPerUnit: 1 }],
  หมูสามชั้นสไลซ์: [{ ingredient: 'หมูสามชั้น', qtyPerUnit: 1 }],
  หมูหมักบุลโกกิ: [{ ingredient: 'หมูสามชั้น', qtyPerUnit: 1 }],
  เนื้อวัวริบอาย: [{ ingredient: 'เนื้อริบอาย', qtyPerUnit: 1 }],
  ไข่เจียวปู: [
    { ingredient: 'ไข่ไก่', qtyPerUnit: 2 },
    { ingredient: 'เนื้อปู', qtyPerUnit: 50 },
  ],
};

// ข้อมูลผู้เสียภาษีของร้านตัวอย่าง (ดู docs/tickets/07-tax-invoice.md) — ไม่มี default จาก .env
// เหมือนค่าตั้งค่าอื่น เพราะร้านจริงที่ไม่ได้จด VAT ไม่ควรมีเลขผู้เสียภาษีปลอมขึ้นมาเอง จึง seed
// ไว้ตรงนี้เฉพาะโหมดเดโมเพื่อให้ลองออกใบกำกับภาษีได้ทันทีโดยไม่ต้องตั้งค่าเองก่อน
const STORE_TAX_INFO = {
  store_tax_id: '0105558000012',
  store_address: '123/45 ถนนสุขุมวิท แขวงคลองตัน เขตคลองเตย กรุงเทพมหานคร 10110',
  store_branch: 'สำนักงานใหญ่',
};

// prettier-ignore
const B2B_CUSTOMER = [
  'บริษัท โซลบาร์บีคิว จำกัด', '021234567', toSatang(50000), 30, '0105561234567',
  '88 ถนนสุขุมวิท 24 แขวงคลองตัน เขตคลองเตย กรุงเทพมหานคร 10110',
];

// prettier-ignore
const TABLES = [
  ...Array.from({ length: 8 }, (_, i) => ({ name: `A${i + 1}`, zone: 'โซนในร้าน', seats: i < 4 ? 2 : 4 })),
  ...Array.from({ length: 6 }, (_, i) => ({ name: `B${i + 1}`, zone: 'โซนริมหน้าต่าง', seats: 4 })),
  ...Array.from({ length: 4 }, (_, i) => ({ name: `C${i + 1}`, zone: 'โซนสวน', seats: 6 })),
  { name: 'VIP1', zone: 'ห้องส่วนตัว', seats: 10 },
  { name: 'VIP2', zone: 'ห้องส่วนตัว', seats: 12 },
];

// สาขาตัวอย่าง (ดู docs/tickets/11-multi-branch.md) — สาขาแรก ("สุขุมวิท") คือข้อมูลเดิมทั้งหมดที่
// เคยมีอยู่แล้วก่อนทิกเก็ตนี้ (เมนู/โต๊ะ/วัตถุดิบชุดใหญ่ด้านบน) ส่วนสาขาที่สอง ("ทองหล่อ") ตั้งใจให้
// มีเมนู/โต๊ะ/วัตถุดิบเป็นชุดของตัวเองแยกต่างหาก (ธีมซีฟู้ด) เพื่อให้เห็นชัดว่าข้อมูลแยกกันจริงเวลา
// สลับสาขาดู ไม่ใช่แค่ label เฉยๆ
// prettier-ignore
const BRANCHES = [
  { name: 'สาขาสุขุมวิท', code: 'SUKHUMVIT', address: STORE_TAX_INFO.store_address },
  { name: 'สาขาทองหล่อ', code: 'THONGLOR', address: '99 ซอยทองหล่อ 10 แขวงคลองตันเหนือ เขตวัฒนา กรุงเทพมหานคร 10110' },
];

// สิทธิ์เข้าถึงสาขาของผู้ใช้แต่ละคน (ดู docs/DECISIONS.md #36) — ทุกคนได้แค่สาขาสุขุมวิทเหมือนเดิม
// (ไม่กระทบพฤติกรรม login เดิมที่เทสต์ทั้งหมดพึ่งอยู่) ยกเว้น waiter2 ที่ตั้งใจให้มีสิทธิ์ 2 สาขา
// เป็นตัวอย่างเดียวที่จะเห็นหน้าเลือกสาขาตอน login (admin ไม่ต้องมีแถวในนี้ก็เข้าได้ทุกสาขาอยู่แล้ว)
const USER_BRANCH_CODES = {
  manager: ['SUKHUMVIT'],
  waiter1: ['SUKHUMVIT'],
  waiter2: ['SUKHUMVIT', 'THONGLOR'],
  kitchen: ['SUKHUMVIT'],
  cashier: ['SUKHUMVIT'],
};

// เมนูเฉพาะสาขาทองหล่อ (ธีมซีฟู้ด/ปิ้งย่าง) — ไม่มีตัวเลือกเสริม (option groups) เพื่อให้ seed ง่าย
// prettier-ignore
const MENU_BRANCH_2 = [
  { cat: 'อาหารจานเดียว', name: 'ข้าวผัดปู', nameEn: 'Crab Fried Rice', price: 110, prep: 10, recommended: true },
  { cat: 'กับข้าว', name: 'กุ้งเผา', nameEn: 'Grilled Prawns', price: 280, prep: 15, recommended: true, desc: 'กุ้งแม่น้ำตัวโตเผาเตาถ่าน' },
  { cat: 'กับข้าว', name: 'หอยแมลงภู่อบสมุนไพร', nameEn: 'Herb-steamed Mussels', price: 190, prep: 15 },
  { cat: 'ยำ / สลัด', name: 'ยำทะเลรวม', nameEn: 'Mixed Seafood Salad', price: 180, prep: 10 },
  { cat: 'ของทานเล่น', name: 'ปลาหมึกทอดกระเทียม', nameEn: 'Garlic Fried Squid', price: 140, prep: 10 },
  { cat: 'เครื่องดื่ม', name: 'น้ำมะพร้าวปั่น', nameEn: 'Coconut Smoothie', price: 70, prep: 3 },
  { cat: 'ของหวาน', name: 'ทับทิมกรอบ', nameEn: 'Red Rubies', price: 65, prep: 5 },
];

// วัตถุดิบเฉพาะสาขาทองหล่อ — แยกสต๊อกจากสาขาสุขุมวิทโดยสิ้นเชิง (คนละร้าน คนละตู้เย็น)
// prettier-ignore
const INGREDIENTS_BRANCH_2 = [
  { name: 'กุ้งแม่น้ำ', unit: 'กรัม', currentStock: 2000, lowStockThreshold: 400 },
  { name: 'ปลาหมึก', unit: 'กรัม', currentStock: 1500, lowStockThreshold: 300 },
  { name: 'หอยแมลงภู่', unit: 'กรัม', currentStock: 1000, lowStockThreshold: 200 },
];

const MENU_ITEM_INGREDIENTS_BRANCH_2 = {
  กุ้งเผา: [{ ingredient: 'กุ้งแม่น้ำ', qtyPerUnit: 250 }],
  ปลาหมึกทอดกระเทียม: [{ ingredient: 'ปลาหมึก', qtyPerUnit: 150 }],
  หอยแมลงภู่อบสมุนไพร: [{ ingredient: 'หอยแมลงภู่', qtyPerUnit: 300 }],
};

// prettier-ignore
const TABLES_BRANCH_2 = [
  ...Array.from({ length: 6 }, (_, i) => ({ name: `D${i + 1}`, zone: 'โซนในร้าน', seats: 4 })),
  { name: 'TL-VIP', zone: 'ห้องส่วนตัว', seats: 8 },
];

/** `migrations`: ใช้เฉพาะเทสต์ที่ต้องการฐานข้อมูลรุ่นเก่า (seed บน schema ถึง migration ที่กำหนด) */
export const seed = ({ migrations } = {}) => {
  migrate({ migrations });
  const db = getDb();

  const run = db.transaction(() => {
    const userCount = db.prepare('SELECT COUNT(*) AS c FROM users').get().c;
    if (userCount === 0) {
      const insertUser = db.prepare(
        'INSERT INTO users (name, username, password_hash, role) VALUES (?, ?, ?, ?)',
      );
      for (const user of USERS) {
        insertUser.run(
          user.name,
          user.username,
          bcrypt.hashSync(resolveSeedPassword(user), 10),
          user.role,
        );
      }
    }

    // ticket 11 (multi-branch) — สิทธิ์เข้าถึงสาขาของผู้ใช้ (ดู USER_BRANCH_CODES ด้านบน) ต้องรอทั้ง
    // user และ branches มีอยู่ก่อน (ดูด้านล่าง) — ทำแยกทีหลัง — ต้องสร้างสาขาก่อนเมนู/โต๊ะ/วัตถุดิบเสมอ เพราะต้องใช้ branch_id
    const branchCount = db.prepare('SELECT COUNT(*) AS c FROM branches').get().c;
    if (branchCount === 0) {
      const insertBranch = db.prepare(
        'INSERT INTO branches (name, code, address) VALUES (?, ?, ?)',
      );
      for (const branch of BRANCHES) insertBranch.run(branch.name, branch.code, branch.address);
    }
    const branchIdByCode = new Map(
      db
        .prepare('SELECT id, code FROM branches')
        .all()
        .map((row) => [row.code, row.id]),
    );

    const membershipCount = db.prepare('SELECT COUNT(*) AS c FROM user_branches').get().c;
    if (membershipCount === 0) {
      const insertMembership = db.prepare(
        'INSERT OR IGNORE INTO user_branches (user_id, branch_id) VALUES (?, ?)',
      );
      const userIdByUsername = new Map(
        db
          .prepare('SELECT id, username FROM users')
          .all()
          .map((row) => [row.username, row.id]),
      );
      for (const [username, codes] of Object.entries(USER_BRANCH_CODES)) {
        const userId = userIdByUsername.get(username);
        if (!userId) continue;
        for (const code of codes) insertMembership.run(userId, branchIdByCode.get(code));
      }
    }

    const categoryCount = db.prepare('SELECT COUNT(*) AS c FROM categories').get().c;
    if (categoryCount === 0) {
      const insertCategory = db.prepare(
        'INSERT INTO categories (name, name_en, icon, sort_order) VALUES (?, ?, ?, ?)',
      );
      for (const category of CATEGORIES) {
        insertCategory.run(category.name, category.nameEn, category.icon, category.sortOrder);
      }
    }

    // สถานีครัวมาพร้อม migration 0006 ไม่ใช่ seed — ที่นี่แค่ผูก id เข้ากับหมวดหมู่ (ticket 34)
    // ผูกเป็นขั้นแยกหลัง INSERT เพราะ seed() ถูกเรียกกับ schema รุ่นเก่าด้วย (tests/migrations.test.js
    // seed บน migration 0001 เพื่อจำลองฐานข้อมูลของร้านก่อน T01) ตอนนั้นยังไม่มีทั้งตารางและคอลัมน์นี้
    const hasStations = db
      .prepare("SELECT 1 FROM sqlite_master WHERE type = 'table' AND name = 'kitchen_stations'")
      .get();
    if (hasStations) {
      const stationIdByCode = new Map(
        db
          .prepare('SELECT id, code FROM kitchen_stations')
          .all()
          .map((row) => [row.code, row.id]),
      );
      const setCategoryStation = db.prepare(
        'UPDATE categories SET station_id = ? WHERE name = ? AND station_id IS NULL',
      );
      for (const category of CATEGORIES) {
        setCategoryStation.run(stationIdByCode.get(category.station) ?? null, category.name);
      }
    }

    const menuCount = db.prepare('SELECT COUNT(*) AS c FROM menu_items').get().c;
    if (menuCount === 0) {
      const categoryIdByName = new Map(
        db
          .prepare('SELECT id, name FROM categories')
          .all()
          .map((row) => [row.name, row.id]),
      );
      const insertMenu = db.prepare(`
        INSERT INTO menu_items (category_id, name, name_en, description, price, is_recommended, prep_minutes, sort_order, branch_id,
                                sold_by_weight, barcode, scale_plu)
        VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
      `);
      const insertGroup = db.prepare(`
        INSERT INTO option_groups (menu_item_id, name, min_select, max_select, is_required, sort_order)
        VALUES (?, ?, ?, ?, ?, ?)
      `);
      const insertOption = db.prepare(`
        INSERT INTO options (group_id, name, price_delta, is_default, sort_order) VALUES (?, ?, ?, ?, ?)
      `);

      const menuItemIdByName = new Map();
      const seedMenu = (items, branchId) => {
        items.forEach((item, index) => {
          const result = insertMenu.run(
            categoryIdByName.get(item.cat),
            item.name,
            item.nameEn,
            item.desc ?? null,
            toSatang(item.price),
            item.recommended ? 1 : 0,
            item.prep,
            index,
            branchId,
            item.soldByWeight ? 1 : 0,
            item.barcode ?? null,
            item.plu ?? null,
          );
          const menuItemId = result.lastInsertRowid;
          menuItemIdByName.set(item.name, menuItemId);

          (MENU_OPTIONS[item.name] ?? []).forEach((templateKey, groupIndex) => {
            const template = OPTION_TEMPLATES[templateKey];
            const groupId = insertGroup.run(
              menuItemId,
              template.name,
              template.min,
              template.max,
              template.required,
              groupIndex,
            ).lastInsertRowid;
            template.options.forEach((option, optionIndex) => {
              insertOption.run(
                groupId,
                option.name,
                toSatang(option.delta),
                option.isDefault ?? 0,
                optionIndex,
              );
            });
          });
        });
      };
      seedMenu(MENU, branchIdByCode.get('SUKHUMVIT'));
      seedMenu(MENU_BRANCH_2, branchIdByCode.get('THONGLOR'));

      const ingredientCount = db.prepare('SELECT COUNT(*) AS c FROM ingredients').get().c;
      if (ingredientCount === 0) {
        const insertIngredient = db.prepare(`
          INSERT INTO ingredients (name, unit, current_stock, low_stock_threshold, branch_id)
          VALUES (?, ?, ?, ?, ?)
        `);
        for (const ingredient of INGREDIENTS) {
          insertIngredient.run(
            ingredient.name,
            ingredient.unit,
            ingredient.currentStock,
            ingredient.lowStockThreshold,
            branchIdByCode.get('SUKHUMVIT'),
          );
        }
        for (const ingredient of INGREDIENTS_BRANCH_2) {
          insertIngredient.run(
            ingredient.name,
            ingredient.unit,
            ingredient.currentStock,
            ingredient.lowStockThreshold,
            branchIdByCode.get('THONGLOR'),
          );
        }

        const ingredientIdByName = new Map(
          db
            .prepare('SELECT id, name FROM ingredients')
            .all()
            .map((row) => [row.name, row.id]),
        );
        const insertLink = db.prepare(`
          INSERT INTO menu_item_ingredients (menu_item_id, ingredient_id, qty_per_unit)
          VALUES (?, ?, ?)
        `);
        const seedLinks = (linkMap) => {
          for (const [menuItemName, links] of Object.entries(linkMap)) {
            const menuItemId = menuItemIdByName.get(menuItemName);
            if (!menuItemId) continue;
            for (const link of links) {
              insertLink.run(menuItemId, ingredientIdByName.get(link.ingredient), link.qtyPerUnit);
            }
          }
        };
        seedLinks(MENU_ITEM_INGREDIENTS);
        seedLinks(MENU_ITEM_INGREDIENTS_BRANCH_2);
      }
    }

    const tableCount = db.prepare('SELECT COUNT(*) AS c FROM dining_tables').get().c;
    if (tableCount === 0) {
      const insertTable = db.prepare(
        'INSERT INTO dining_tables (name, zone, seats, branch_id, qr_token) VALUES (?, ?, ?, ?, ?)',
      );
      for (const table of TABLES) {
        insertTable.run(
          table.name,
          table.zone,
          table.seats,
          branchIdByCode.get('SUKHUMVIT'),
          randomUUID(),
        );
      }
      for (const table of TABLES_BRANCH_2) {
        insertTable.run(
          table.name,
          table.zone,
          table.seats,
          branchIdByCode.get('THONGLOR'),
          randomUUID(),
        );
      }
    }

    const hasStoreTaxId = db.prepare("SELECT 1 FROM settings WHERE key = 'store_tax_id'").get();
    if (!hasStoreTaxId) {
      const upsertSetting = db.prepare(
        'INSERT INTO settings (key, value) VALUES (?, ?) ON CONFLICT(key) DO NOTHING',
      );
      for (const [key, value] of Object.entries(STORE_TAX_INFO)) upsertSetting.run(key, value);
    }

    // ลูกค้าเครดิตตัวอย่าง (ดู docs/tickets/20-b2b-credit.md) — ร้านอาหาร/ร้านเนื้อที่ซื้อส่งแล้ววางบิล
    // เก็บเงินปลายเดือน ใส่เฉพาะตอนยังไม่มีลูกค้าเลย ฐานข้อมูลที่ใช้งานจริงอยู่แล้วจะไม่มีลูกค้าปลอมโผล่
    const customerCount = db.prepare('SELECT COUNT(*) AS c FROM customers').get().c;
    if (customerCount === 0) {
      db.prepare(
        `INSERT INTO customers (name, phone, credit_limit, credit_term_days, tax_id, address)
         VALUES (?, ?, ?, ?, ?, ?)`,
      ).run(...B2B_CUSTOMER);
    }

    // เปิดกะแรกให้พร้อมใช้งานทันที (ร้านจริงจะเปิด/ปิดกะเองทุกวันหลังจากนี้)
    const shiftCount = db.prepare('SELECT COUNT(*) AS c FROM shifts').get().c;
    if (shiftCount === 0) {
      const cashier = db.prepare("SELECT id FROM users WHERE username = 'cashier'").get();
      if (cashier) {
        db.prepare('INSERT INTO shifts (opened_by, opening_cash) VALUES (?, ?)').run(
          cashier.id,
          toSatang(2000),
        );
      }
    }
  });

  run();
  return db;
};

if (import.meta.url === `file://${process.argv[1]}`) {
  seed();
  // ไม่พิมพ์รหัสผ่านบัญชีเดโมลง log (สัญญา telemetry ห้ามรหัสผ่านใน log ทุกกรณี) — ดูบัญชีเดโมได้ใน README
  logger.info('Sample data seeded; demo accounts are listed in README');
}

export default seed;
