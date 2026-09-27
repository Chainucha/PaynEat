// Copyright 2026 Suruch Chakrapeesirisuk
// SPDX-License-Identifier: Apache-2.0

import 'package:flutter_test/flutter_test.dart';
import 'package:payneat_pos/core/constants/app_constants.dart';
import 'package:payneat_pos/core/demo/demo_data_sources.dart';
import 'package:payneat_pos/core/demo/demo_names.dart';
import 'package:payneat_pos/core/demo/demo_store.dart';
import 'package:payneat_pos/core/errors/exceptions.dart';
import 'package:payneat_pos/core/utils/app_clock.dart';
import 'package:payneat_pos/features/order/domain/entities/order_item_payload.dart';

import '../helpers/audit_summary_expectations.dart';

/// เทสต์ตรงต่อ DemoStore เอง (ไม่ผ่าน data source/repository) เพื่อยืนยันว่าเมธอด
/// ที่ถูกแยกออกไปหลายไฟล์ตามโดเมนด้วย part/part of (auth, menu, tables, orders,
/// payments, reports, seed history) ยังทำงานร่วมกันถูกต้องเหมือนตอนเป็นไฟล์เดียว —
/// โดยเฉพาะจุดที่โดเมนหนึ่งเรียกใช้ private helper ของอีกโดเมน เช่น orders เรียก
/// _findTable ของ tables และ _findUser ของ auth
void main() {
  late DemoStore store;

  setUp(() => store = DemoStore());
  // ทุก audit log ที่เทสต์ในไฟล์นี้ทำให้เกิด ต้องแสดงเป็นทุกภาษาได้ ไม่ใช่แค่ประโยคไทย (DECISIONS #74)
  tearDown(() => expectAuditSummariesRenderable(store.auditLogs));

  group('DemoStore auth', () {
    test('login ด้วยบัญชีที่ถูกต้องได้ token และ user', () {
      final result = store.login('admin', 'admin123');
      expect(result['token'], isNotEmpty);
      expect((result['user'] as Map)['username'], 'admin');
    });

    test('login ผิดรหัสผ่านโยน ApiException 401', () {
      expect(
        () => store.login('admin', 'ผิดแน่นอน'),
        throwsA(
          isA<Exception>().having(
            (e) => e.toString(),
            'message',
            contains('ไม่ถูกต้อง'),
          ),
        ),
      );
    });

    test('profile คืนข้อมูลตรงกับ token ที่ login ได้มา', () {
      final login = store.login('admin', 'admin123');
      final profile = store.profile(login['token'] as String);
      expect(profile['username'], 'admin');
    });
  });

  group('DemoStore menu + tables', () {
    test('menuList และ tableList มีข้อมูลตัวอย่างพร้อมใช้ทันที', () {
      expect(store.menuList(), isNotEmpty);
      expect(store.tableList(), isNotEmpty);
    });

    test('deleteCategory ล้มเหลวถ้ายังมีเมนูอยู่ในหมวดนั้น', () {
      final menu = store.menuList().first;
      expect(
        () => store.deleteCategory(menu['categoryId'] as int),
        throwsException,
      );
    });
  });

  group('DemoStore orders — ทำงานข้ามโดเมน (tables/auth) ได้ถูกต้อง', () {
    test('createOrder ผูก tableName/tableZone จากโดเมน tables ให้ถูกต้อง', () {
      final table = store.tableList().firstWhere(
        (t) => t['status'] == 'available',
      );
      final item = store.menuList().first;

      final order = store.createOrder(
        type: 'dine_in',
        tableId: table['id'] as int,
        guestCount: 2,
        items: [
          {'menuItemId': item['id'], 'quantity': 1, 'optionIds': []},
        ],
      );

      expect(order['tableName'], table['name']);
      expect(order['tableZone'], table['zone']);
      // โต๊ะต้องถูกตั้งเป็นไม่ว่างทันทีที่เปิดออเดอร์ (แก้ state ใน tables ผ่าน orders)
      expect(
        store.tableList().firstWhere((t) => t['id'] == table['id'])['status'],
        'occupied',
      );
    });

    test('เปิดออเดอร์ซ้ำที่โต๊ะซึ่งมีออเดอร์เปิดอยู่แล้วต้องถูกปฏิเสธ', () {
      final table = store.tableList().firstWhere(
        (t) => t['status'] == 'available',
      );
      final item = store.menuList().first;
      final items = [
        {'menuItemId': item['id'], 'quantity': 1, 'optionIds': []},
      ];

      store.createOrder(
        type: 'dine_in',
        tableId: table['id'] as int,
        guestCount: 2,
        items: items,
      );

      expect(
        () => store.createOrder(
          type: 'dine_in',
          tableId: table['id'] as int,
          guestCount: 2,
          items: items,
        ),
        throwsException,
      );
    });

    test('ครัวเดินสถานะครบทุกจานแล้วออเดอร์เปลี่ยนเป็น served อัตโนมัติ', () {
      final table = store.tableList().firstWhere(
        (t) => t['status'] == 'available',
      );
      final item = store.menuList().first;

      final order = store.createOrder(
        type: 'dine_in',
        tableId: table['id'] as int,
        guestCount: 2,
        items: [
          {'menuItemId': item['id'], 'quantity': 1, 'optionIds': []},
        ],
      );
      store.sendToKitchen(order['id'] as int);

      final itemId =
          (store.findOrder(order['id'] as int)['items'] as List).first['id']
              as int;
      store.updateItemStatus(order['id'] as int, itemId, 'cooking');
      store.updateItemStatus(order['id'] as int, itemId, 'ready');
      final result = store.updateItemStatus(
        order['id'] as int,
        itemId,
        'served',
      );

      expect(result['status'], 'served');
    });
  });

  group(
    'DemoStore payments — ใช้ _findUser ของ auth และ _freeTable ของ tables',
    () {
      test('จ่ายเต็มจำนวนแล้วปิดออเดอร์และคืนโต๊ะให้ว่าง', () {
        final table = store.tableList().firstWhere(
          (t) => t['status'] == 'available',
        );
        final item = store.menuList().first;

        final order = store.createOrder(
          type: 'dine_in',
          tableId: table['id'] as int,
          guestCount: 2,
          items: [
            {'menuItemId': item['id'], 'quantity': 2, 'optionIds': []},
          ],
        );
        final total = (order['total'] as num).toDouble();

        final result = store.pay(
          orderId: order['id'] as int,
          method: 'cash',
          amount: total,
          received: total,
          cashierId: 6, // พี่แอน — ยืนยันว่า _findUser ข้ามไฟล์ยังทำงาน
        );

        expect(result['isFullyPaid'], isTrue);
        expect((result['payment'] as Map)['cashierName'], isNotNull);
        expect(store.findOrder(order['id'] as int)['status'], 'paid');
        expect(
          store.tableList().firstWhere((t) => t['id'] == table['id'])['status'],
          'available',
        );
      });

      test('จ่ายเกินยอดคงเหลือต้องถูกปฏิเสธ', () {
        final table = store.tableList().firstWhere(
          (t) => t['status'] == 'available',
        );
        final item = store.menuList().first;
        final order = store.createOrder(
          type: 'dine_in',
          tableId: table['id'] as int,
          guestCount: 1,
          items: [
            {'menuItemId': item['id'], 'quantity': 1, 'optionIds': []},
          ],
        );
        final total = (order['total'] as num).toDouble();

        expect(
          () => store.pay(
            orderId: order['id'] as int,
            method: 'cash',
            amount: total + 1000,
          ),
          throwsException,
        );
      });
    },
  );

  group('DemoStore promotions — auto apply / โค้ด / ลบ / eligible list', () {
    Map<String, dynamic> openOrder() {
      final table = store.tableList().firstWhere(
        (t) => t['status'] == 'available',
      );
      final item = store.menuList().first;
      return store.createOrder(
        type: 'dine_in',
        tableId: table['id'] as int,
        guestCount: 2,
        items: [
          {'menuItemId': item['id'], 'quantity': 2, 'optionIds': []},
        ],
      );
    }

    // โปรโมชันถูกประเมินใหม่ตอน _recalculate() เท่านั้น (ตอนแก้ไขออเดอร์) ไม่ใช่ตอนอ่านเฉย ๆ
    // เหมือนกับฝั่ง backend เทสต์นี้เลยต้อง "แตะ" ออเดอร์เบา ๆ เพื่อบังคับคำนวณใหม่
    Map<String, dynamic> touch(int orderId) =>
        store.applyDiscount(orderId, 'none', 0);

    test(
      'สร้างโปรโมชัน auto (ไม่ใช้โค้ด) แล้ว apply ให้ออเดอร์ที่เข้าเงื่อนไขทันที',
      () {
        final promotion = store.savePromotion({
          'name': 'ลด 10%',
          'type': 'percent',
          'value': 10.0,
          'conditions': const {},
          'isActive': true,
        });

        final order = openOrder();
        final subtotal = (order['subtotal'] as num).toDouble();

        expect(order['promotionId'], promotion['id']);
        expect(order['promotionDiscountAmount'], subtotal * 0.1);
      },
    );

    test('ลบโปรโมชัน auto ที่ยังเข้าเงื่อนไขอยู่ ระบบใส่กลับให้ทันที', () {
      final promotion = store.savePromotion({
        'name': 'ลด 10%',
        'type': 'percent',
        'value': 10.0,
        'conditions': const {},
        'isActive': true,
      });
      final order = openOrder();

      final removed = store.removePromotion(order['id'] as int);
      expect(removed['promotionId'], promotion['id']);
    });

    test('ปิดใช้งานโปรโมชัน auto แล้วออเดอร์ต้องไม่มีโปรโมชันอีกต่อไป', () {
      final promotion = store.savePromotion({
        'name': 'ลด 10%',
        'type': 'percent',
        'value': 10.0,
        'conditions': const {},
        'isActive': true,
      });
      final order = openOrder();

      store.savePromotion({'isActive': false}, id: promotion['id'] as int);
      final result = touch(order['id'] as int);

      expect(result['promotionId'], isNull);
      expect(result['promotionDiscountAmount'], 0.0);
    });

    test('สร้างโปรโมชันแบบใช้โค้ดซ้ำต้องถูกปฏิเสธ', () {
      store.savePromotion({
        'name': 'ลด 20 บาท',
        'type': 'amount',
        'value': 20.0,
        'code': 'save20',
        'conditions': const {},
        'isActive': true,
      });

      expect(
        () => store.savePromotion({
          'name': 'ลด 20 บาท (ซ้ำ)',
          'type': 'amount',
          'value': 20.0,
          'code': 'SAVE20',
          'conditions': const {},
          'isActive': true,
        }),
        throwsException,
      );
    });

    test('กรอกโค้ดที่ไม่มีอยู่จริงถูกปฏิเสธ', () {
      final order = openOrder();
      expect(
        () => store.redeemPromotionCode(order['id'] as int, 'NOTREAL'),
        throwsException,
      );
    });

    test(
      'กรอกโค้ดที่ถูกต้อง apply ทันที และยึดโค้ดไว้แม้ auto ให้ส่วนลดมากกว่า',
      () {
        final auto = store.savePromotion({
          'name': 'ลด 10% ทั้งบิล',
          'type': 'percent',
          'value': 10.0,
          'conditions': const {},
          'isActive': true,
        });
        store.savePromotion({
          'name': 'ลด 20 บาท',
          'type': 'amount',
          'value': 20.0,
          'code': 'save20',
          'conditions': const {},
          'isActive': true,
        });

        final order = openOrder();
        final redeemed = store.redeemPromotionCode(
          order['id'] as int,
          'save20',
        );
        expect(redeemed['promotionCode'], 'SAVE20');
        expect(redeemed['promotionDiscountAmount'], 20.0);

        // auto (10%) ให้ส่วนลดมากกว่า 20 บาทแน่นอนที่ subtotal นี้ แต่ต้องยึดโค้ดที่กรอกไว้เป็นหลัก
        final afterTouch = touch(order['id'] as int);
        expect(afterTouch['promotionId'], redeemed['promotionId']);
        expect(afterTouch['promotionCode'], 'SAVE20');
        expect(auto['code'], isNull);
      },
    );

    test('ลบโปรโมชัน (โค้ด) ออก → กลับไปใช้ auto ที่ยังเข้าเงื่อนไขแทน', () {
      final auto = store.savePromotion({
        'name': 'ลด 10% ทั้งบิล',
        'type': 'percent',
        'value': 10.0,
        'conditions': const {},
        'isActive': true,
      });
      store.savePromotion({
        'name': 'ลด 20 บาท',
        'type': 'amount',
        'value': 20.0,
        'code': 'save20',
        'conditions': const {},
        'isActive': true,
      });
      final order = openOrder();
      store.redeemPromotionCode(order['id'] as int, 'save20');

      final result = store.removePromotion(order['id'] as int);
      expect(result['promotionId'], auto['id']);
      expect(result['promotionCode'], isNull);
    });

    test(
      'eligiblePromotions คืนเฉพาะรายการที่เข้าเงื่อนไขหรือกำลังใช้งานอยู่',
      () {
        final promotion = store.savePromotion({
          'name': 'ลด 10%',
          'type': 'percent',
          'value': 10.0,
          'conditions': const {},
          'isActive': true,
        });
        final order = openOrder();

        final eligible = store.eligiblePromotions(order['id'] as int);
        final entry = eligible.firstWhere(
          (row) => row['promotionId'] == promotion['id'],
        );
        expect(entry['isEligibleNow'], isTrue);
        expect(entry['isCurrentlyApplied'], isTrue);
        expect(entry['requiresCode'], isFalse);
      },
    );

    test(
      'ลบโปรโมชันที่เคยใช้ในออเดอร์แล้วไม่กระทบออเดอร์เก่า (snapshot ไว้แล้ว)',
      () {
        final promotion = store.savePromotion({
          'name': 'ลด 10%',
          'type': 'percent',
          'value': 10.0,
          'conditions': const {},
          'isActive': true,
        });
        final order = openOrder();
        expect(order['promotionId'], promotion['id']);

        store.deletePromotion(promotion['id'] as int);

        final stillThere = store.findOrder(order['id'] as int);
        expect(stillThere['promotionName'], 'ลด 10%');
      },
    );
  });

  group('DemoStore reports — มีข้อมูลจาก seed history ตั้งแต่สร้างขึ้นมา', () {
    test(
      'dashboard และ salesSummary มีข้อมูลให้ดูทันทีไม่ต้องรอสร้างออเดอร์ใหม่',
      () {
        final dashboard = store.dashboard();
        expect(dashboard['today'], isNotNull);
        expect(
          (dashboard['live'] as Map)['totalTables'],
          store.tableList().length,
        );

        final summary = store.salesSummary();
        expect(summary['orderCount'], isA<int>());
      },
    );
  });

  group('DemoStore ingredients — ตัดสต๊อกอัตโนมัติเมื่อขาย (ticket 06)', () {
    test(
      'CRUD พื้นฐาน + isLowStock คำนวณจาก currentStock/lowStockThreshold',
      () {
        final ingredient = store.saveIngredient({
          'name': 'กุ้งทดสอบ',
          'unit': 'กรัม',
          'currentStock': 100.0,
          'lowStockThreshold': 20.0,
        });
        expect(ingredient['isLowStock'], false);

        final updated = store.saveIngredient({
          'name': 'กุ้งทดสอบ (แก้ไข)',
          'unit': 'กรัม',
          'lowStockThreshold': 150.0,
        }, id: ingredient['id'] as int);
        expect(updated['name'], 'กุ้งทดสอบ (แก้ไข)');
        // currentStock (100) <= lowStockThreshold ใหม่ (150) → ใกล้หมด
        expect(updated['isLowStock'], true);
      },
    );

    test('adjustIngredientStock ปรับสต๊อกได้ และปฏิเสธ delta = 0', () {
      final ingredient = store.saveIngredient({
        'name': 'ข้าวทดสอบ',
        'unit': 'กก.',
        'currentStock': 10.0,
        'lowStockThreshold': 2.0,
      });
      final increased = store.adjustIngredientStock(ingredient['id'] as int, 5);
      expect(increased['currentStock'], 15.0);

      final decreased = store.adjustIngredientStock(
        ingredient['id'] as int,
        -20,
      );
      expect(decreased['currentStock'], -5.0);
      expect(decreased['isLowStock'], true);

      expect(
        () => store.adjustIngredientStock(ingredient['id'] as int, 0),
        throwsException,
      );
    });

    test('ลบวัตถุดิบที่ผูกกับเมนูอยู่ไม่ได้ ต้องเลิกผูกก่อน', () {
      final ingredient = store.saveIngredient({
        'name': 'หมูทดสอบ-ลบ',
        'unit': 'กรัม',
        'currentStock': 100.0,
        'lowStockThreshold': 20.0,
      });
      final category = store.categories.first;
      final menuItem = store.saveMenuItem({
        'name': 'เมนูทดสอบ-ผูกวัตถุดิบ',
        'categoryId': category['id'],
        'price': 10.0,
        'ingredients': [
          {'ingredientId': ingredient['id'], 'qtyPerUnit': 10},
        ],
      });

      expect(
        () => store.deleteIngredient(ingredient['id'] as int),
        throwsException,
      );

      store.saveMenuItem({
        'categoryId': category['id'],
        'ingredients': <Map<String, dynamic>>[],
      }, id: menuItem['id'] as int);
      store.deleteIngredient(ingredient['id'] as int);
      expect(
        store.ingredients.any((row) => row['id'] == ingredient['id']),
        false,
      );
    });

    test('เลือกวัตถุดิบซ้ำกันในเมนูเดียวไม่ได้', () {
      final ingredient = store.saveIngredient({
        'name': 'ไข่ทดสอบ',
        'unit': 'ฟอง',
        'currentStock': 50.0,
        'lowStockThreshold': 10.0,
      });
      final category = store.categories.first;

      expect(
        () => store.saveMenuItem({
          'name': 'เมนูทดสอบ-ซ้ำ',
          'categoryId': category['id'],
          'price': 10.0,
          'ingredients': [
            {'ingredientId': ingredient['id'], 'qtyPerUnit': 1},
            {'ingredientId': ingredient['id'], 'qtyPerUnit': 2},
          ],
        }),
        throwsException,
      );
    });

    test('ผูกวัตถุดิบที่ไม่มีอยู่จริงไม่ได้', () {
      final category = store.categories.first;
      expect(
        () => store.saveMenuItem({
          'name': 'เมนูทดสอบ-ไม่มีวัตถุดิบ',
          'categoryId': category['id'],
          'price': 10.0,
          'ingredients': [
            {'ingredientId': 999999, 'qtyPerUnit': 1},
          ],
        }),
        throwsException,
      );
    });

    test(
      'flow: สั่ง → ส่งครัว → ตัดสต๊อก → หมด → ปิดขายอัตโนมัติ → ยกเลิก/ปรับ/ลบ → คืนสต๊อก → เปิดขายกลับ',
      () {
        final ingredient = store.saveIngredient({
          'name': 'วัตถุดิบทดสอบ-flow',
          'unit': 'ชิ้น',
          'currentStock': 3.0,
          'lowStockThreshold': 1.0,
        });
        final ingredientId = ingredient['id'] as int;
        final category = store.categories.first;
        final menuItem = store.saveMenuItem({
          'name': 'เมนูทดสอบ-flow',
          'categoryId': category['id'],
          'price': 50.0,
          'ingredients': [
            {'ingredientId': ingredientId, 'qtyPerUnit': 1},
          ],
        });
        final menuItemId = menuItem['id'] as int;
        final table = store.tableList().firstWhere(
          (t) => t['status'] == 'available',
        );

        // 1) สั่ง 2 ที่ — ยังไม่ตัดสต๊อกจนกว่าจะส่งครัว
        final order = store.createOrder(
          type: 'dine_in',
          tableId: table['id'] as int,
          guestCount: 2,
          items: [
            {'menuItemId': menuItemId, 'quantity': 2, 'optionIds': []},
          ],
        );
        expect(store.ingredient(ingredientId)['currentStock'], 3.0);

        // 2) ส่งครัว → ตัดสต๊อก 2 ชิ้น เหลือ 1 (ยังพอขายได้)
        store.sendToKitchen(order['id'] as int);
        expect(store.ingredient(ingredientId)['currentStock'], 1.0);
        expect(store.menuItem(menuItemId)['isAvailable'], true);

        // 3) ส่งครัวซ้ำไม่ตัดซ้ำ (idempotent)
        store.sendToKitchen(order['id'] as int);
        expect(store.ingredient(ingredientId)['currentStock'], 1.0);

        // 4) เพิ่มรายการเข้าออเดอร์ที่ส่งครัวไปแล้ว → ตัดทันที จนสต๊อกหมด
        store.addItems(order['id'] as int, [
          {'menuItemId': menuItemId, 'quantity': 1, 'optionIds': []},
        ]);
        expect(store.ingredient(ingredientId)['currentStock'], 0.0);
        expect(store.menuItem(menuItemId)['isAvailable'], false);
        expect(store.menuItem(menuItemId)['autoDisabledByStock'], true);

        // 5) สั่งเมนูที่ปิดขายอยู่ในออเดอร์ใหม่ต้องถูกปฏิเสธ
        final table2 = store.tableList().firstWhere(
          (t) => t['status'] == 'available' && t['id'] != table['id'],
        );
        expect(
          () => store.createOrder(
            type: 'dine_in',
            tableId: table2['id'] as int,
            guestCount: 1,
            items: [
              {'menuItemId': menuItemId, 'quantity': 1, 'optionIds': []},
            ],
          ),
          throwsException,
        );

        // 6) ยกเลิกรายการที่เพิ่งเพิ่ม (ยัง pending) → คืนสต๊อก → เปิดขายกลับอัตโนมัติ
        final justAddedItem =
            (store.findOrder(order['id'] as int)['items'] as List)
                .cast<Map<String, dynamic>>()
                .firstWhere((item) => item['quantity'] == 1);
        store.updateItemStatus(
          order['id'] as int,
          justAddedItem['id'] as int,
          'cancelled',
        );
        expect(store.ingredient(ingredientId)['currentStock'], 1.0);
        expect(store.menuItem(menuItemId)['isAvailable'], true);
        expect(store.menuItem(menuItemId)['autoDisabledByStock'], false);

        // 7) ปรับสต๊อกด้วยมือให้เป็น 0 ก็ปิดขายอัตโนมัติเหมือนกัน
        store.adjustIngredientStock(ingredientId, -1);
        expect(store.ingredient(ingredientId)['currentStock'], 0.0);
        expect(store.menuItem(menuItemId)['isAvailable'], false);

        // 8) เติมสต๊อกกลับก็เปิดขายอัตโนมัติ
        store.adjustIngredientStock(ingredientId, 5);
        expect(store.ingredient(ingredientId)['currentStock'], 5.0);
        expect(store.menuItem(menuItemId)['isAvailable'], true);

        // 9) แก้จำนวนรายการที่ตัดสต๊อกไปแล้ว (2 → 4) ต้องปรับตามส่วนต่างเท่านั้น
        final firstItem = (store.findOrder(order['id'] as int)['items'] as List)
            .cast<Map<String, dynamic>>()
            .firstWhere((item) => item['status'] == 'pending');
        store.updateItem(
          order['id'] as int,
          firstItem['id'] as int,
          quantity: 4,
        );
        expect(store.ingredient(ingredientId)['currentStock'], 3.0);

        // 10) ลบรายการที่ตัดสต๊อกไปแล้ว (qty 4) → คืนสต๊อกเต็มจำนวน
        store.removeItem(order['id'] as int, firstItem['id'] as int);
        expect(store.ingredient(ingredientId)['currentStock'], 7.0);

        // 11) เพิ่มรายการใหม่แล้วยกเลิกทั้งบิล → คืนสต๊อกให้ทุกรายการที่ตัดไปแล้ว
        store.addItems(order['id'] as int, [
          {'menuItemId': menuItemId, 'quantity': 2, 'optionIds': []},
        ]);
        expect(store.ingredient(ingredientId)['currentStock'], 5.0);
        store.cancelOrder(order['id'] as int, 'ทดสอบยกเลิกทั้งบิล');
        expect(store.ingredient(ingredientId)['currentStock'], 7.0);
      },
    );
  });

  group('DemoStore tax invoices — ใบกำกับภาษี (ticket 07)', () {
    // จ่ายเงินเต็มจำนวนให้ออเดอร์ใหม่ 1 ใบ (mirror ของ payments group ด้านบน)
    // เพื่อให้ issueTaxInvoice ผ่านเงื่อนไข "จ่ายครบแล้วเท่านั้น"
    Map<String, dynamic> paidOrder() {
      final table = store.tableList().firstWhere(
        (t) => t['status'] == 'available',
      );
      final item = store.menuList().first;
      final order = store.createOrder(
        type: 'dine_in',
        tableId: table['id'] as int,
        guestCount: 2,
        items: [
          {'menuItemId': item['id'], 'quantity': 1, 'optionIds': []},
        ],
      );
      final total = (order['total'] as num).toDouble();
      store.pay(
        orderId: order['id'] as int,
        method: 'cash',
        amount: total,
        received: total,
        cashierId: 6,
      );
      return store.findOrder(order['id'] as int);
    }

    test(
      'ออกใบกำกับภาษีอย่างย่อสำเร็จ — เลขที่รันตรงรูปแบบ INV<ปี พ.ศ. 2 หลัก>-<เลขรัน 6 หลัก>',
      () {
        final order = paidOrder();
        final invoice = store.issueTaxInvoice(order['id'] as int, {
          'invoiceType': TaxInvoiceType.abbreviated,
        });

        final buddhistYear = DateTime.now().year + 543;
        final yy = buddhistYear.toString().substring(
          buddhistYear.toString().length - 2,
        );
        expect(invoice['runningNumber'], matches(RegExp('^INV$yy-\\d{6}\$')));
        expect(invoice['invoiceType'], TaxInvoiceType.abbreviated);
        expect(invoice['isVoid'], false);
      },
    );

    test(
      'มูลค่าสินค้า/บริการคือฐานภาษีรวมค่าบริการ — บวก VAT แล้วเท่ายอดรวมพอดี (ตรงกับ backend)',
      () {
        final order = paidOrder();
        final invoice = store.issueTaxInvoice(order['id'] as int, {
          'invoiceType': TaxInvoiceType.full,
          'customerName': 'บริษัท ทดสอบ จำกัด',
          'customerAddress': 'กรุงเทพมหานคร',
        });

        final total = (order['total'] as num).toDouble();
        final vat = (order['vat'] as num).toDouble();
        final serviceCharge = (order['serviceCharge'] as num).toDouble();
        expect(
          serviceCharge,
          greaterThan(0),
          reason: 'dine-in ต้องมีค่าบริการ',
        );
        final subtotal = (invoice['subtotal'] as num).toDouble();
        expect(subtotal, closeTo(total - vat, 0.005));
        expect(
          subtotal,
          greaterThan((order['subtotal'] as num).toDouble()),
          reason: 'ต้องรวมค่าบริการ ไม่ใช่ค่าอาหารล้วน',
        );
        expect(
          subtotal + (invoice['vat'] as num).toDouble(),
          closeTo((invoice['total'] as num).toDouble(), 0.005),
        );
      },
    );

    test('ใบกำกับภาษีเต็มรูปต้องระบุชื่อและที่อยู่ลูกค้า ไม่งั้นถูกปฏิเสธ', () {
      final order = paidOrder();
      expect(
        () => store.issueTaxInvoice(order['id'] as int, {
          'invoiceType': TaxInvoiceType.full,
        }),
        throwsException,
      );

      final invoice = store.issueTaxInvoice(order['id'] as int, {
        'invoiceType': TaxInvoiceType.full,
        'customerName': 'บริษัท ทดสอบ จำกัด',
        'customerAddress': '123 ถนนทดสอบ',
      });
      expect(invoice['customerName'], 'บริษัท ทดสอบ จำกัด');
      // เลขผู้เสียภาษีลูกค้าไม่บังคับแม้เต็มรูป (ดู docs/tickets/07-tax-invoice.md)
      expect(invoice['customerTaxId'], isNull);
    });

    test('ออกซ้ำให้ออเดอร์เดียวกันไม่ได้ถ้ายังไม่ยกเลิกใบเดิม', () {
      final order = paidOrder();
      store.issueTaxInvoice(order['id'] as int, {
        'invoiceType': TaxInvoiceType.abbreviated,
      });

      expect(
        () => store.issueTaxInvoice(order['id'] as int, {
          'invoiceType': TaxInvoiceType.abbreviated,
        }),
        throwsException,
      );
    });

    test('ออกใบกำกับภาษีให้ออเดอร์ที่ยังไม่จ่ายเงินไม่ได้', () {
      final table = store.tableList().firstWhere(
        (t) => t['status'] == 'available',
      );
      final item = store.menuList().first;
      final order = store.createOrder(
        type: 'dine_in',
        tableId: table['id'] as int,
        guestCount: 1,
        items: [
          {'menuItemId': item['id'], 'quantity': 1, 'optionIds': []},
        ],
      );

      expect(
        () => store.issueTaxInvoice(order['id'] as int, {
          'invoiceType': TaxInvoiceType.abbreviated,
        }),
        throwsException,
      );
    });

    test('เลขที่รันเรียงต่อเนื่องไม่ซ้ำข้ามหลายออเดอร์', () {
      final order1 = paidOrder();
      final order2 = paidOrder();
      final invoice1 = store.issueTaxInvoice(order1['id'] as int, {
        'invoiceType': TaxInvoiceType.abbreviated,
      });
      final invoice2 = store.issueTaxInvoice(order2['id'] as int, {
        'invoiceType': TaxInvoiceType.abbreviated,
      });

      expect(invoice1['runningNumber'], isNot(invoice2['runningNumber']));
      final seq1 = int.parse(
        (invoice1['runningNumber'] as String).split('-').last,
      );
      final seq2 = int.parse(
        (invoice2['runningNumber'] as String).split('-').last,
      );
      expect(seq2, seq1 + 1);
    });

    test('taxInvoiceForOrder โยน 404 ก่อนออก แล้วคืนใบล่าสุดหลังออกสำเร็จ', () {
      final order = paidOrder();
      expect(
        () => store.taxInvoiceForOrder(order['id'] as int),
        throwsA(
          isA<ApiException>().having((e) => e.statusCode, 'statusCode', 404),
        ),
      );

      final issued = store.issueTaxInvoice(order['id'] as int, {
        'invoiceType': TaxInvoiceType.abbreviated,
      });
      expect(store.taxInvoiceForOrder(order['id'] as int)['id'], issued['id']);
    });

    test('ยกเลิกใบแล้วออกใหม่ได้ด้วยเลขที่รันใหม่ ไม่ใช้เลขเดิมซ้ำ', () {
      final order = paidOrder();
      final first = store.issueTaxInvoice(order['id'] as int, {
        'invoiceType': TaxInvoiceType.abbreviated,
      });

      final voided = store.voidTaxInvoice(
        order['id'] as int,
        'ออกผิดประเภท',
        voidedById: 2,
      );
      expect(voided['isVoid'], true);
      expect(voided['voidReason'], 'ออกผิดประเภท');
      expect(voided['voidedByName'], isNotNull);

      final second = store.issueTaxInvoice(order['id'] as int, {
        'invoiceType': TaxInvoiceType.abbreviated,
      });
      expect(second['runningNumber'], isNot(first['runningNumber']));
      expect(store.taxInvoiceForOrder(order['id'] as int)['id'], second['id']);
    });

    test('ยกเลิกใบกำกับภาษีที่ยังไม่เคยออกให้ออเดอร์นี้ไม่ได้ (404)', () {
      final order = paidOrder();
      expect(
        () => store.voidTaxInvoice(order['id'] as int, 'เหตุผลทดสอบ'),
        throwsA(
          isA<ApiException>().having((e) => e.statusCode, 'statusCode', 404),
        ),
      );
    });

    test('ออกใบกำกับภาษีไม่ได้ถ้าร้านยังไม่ตั้งค่าเลขผู้เสียภาษี/ที่อยู่', () {
      final order = paidOrder();
      store.settings['storeTaxId'] = null;

      expect(
        () => store.issueTaxInvoice(order['id'] as int, {
          'invoiceType': TaxInvoiceType.abbreviated,
        }),
        throwsException,
      );
    });
  });

  group('DemoStore audit logs — บันทึกการกระทำที่เสี่ยง (ticket 08)', () {
    Map<String, dynamic> openOrder() {
      final table = store.tableList().firstWhere(
        (t) => t['status'] == 'available',
      );
      final item = store.menuList().first;
      return store.createOrder(
        type: 'dine_in',
        tableId: table['id'] as int,
        guestCount: 1,
        items: [
          {'menuItemId': item['id'], 'quantity': 1, 'optionIds': []},
        ],
      );
    }

    test('cancelOrder log เป็น order.cancel พร้อมเหตุผลและชื่อผู้ทำ', () {
      final order = openOrder();
      store.cancelOrder(order['id'] as int, 'ลูกค้ายกเลิก', actorId: 2);

      final logs = store.auditLogList(action: 'order.cancel').rows;
      expect(logs, isNotEmpty);
      final log = logs.first;
      expect(log['entityType'], 'order');
      expect(log['entityId'], order['id']);
      expect(log['reason'], 'ลูกค้ายกเลิก');
      expect(log['actorName'], 'สมชาย (ผู้จัดการ)');
      expect(log['summary'], contains(order['code']));
    });

    test(
      'void รายการหลังครัวทำแล้ว log เป็น order_item.void แต่ยกเลิกตอน pending ไม่ log',
      () {
        final orderA = openOrder();
        final itemA = (orderA['items'] as List).first as Map<String, dynamic>;
        store.updateItemStatus(
          orderA['id'] as int,
          itemA['id'] as int,
          OrderItemStatus.cancelled,
          actorId: 3,
        );
        expect(
          store
              .auditLogList(
                action: 'order_item.void',
                entityId: itemA['id'] as int,
              )
              .rows,
          isEmpty,
        );

        final orderB = openOrder();
        final itemB = (orderB['items'] as List).first as Map<String, dynamic>;
        store.updateItemStatus(
          orderB['id'] as int,
          itemB['id'] as int,
          OrderItemStatus.cooking,
        );
        store.updateItemStatus(
          orderB['id'] as int,
          itemB['id'] as int,
          OrderItemStatus.cancelled,
          actorId: 2,
        );

        final logs = store
            .auditLogList(
              action: 'order_item.void',
              entityId: itemB['id'] as int,
            )
            .rows;
        expect(logs, hasLength(1));
        expect(logs.first['entityType'], 'order_item');
        expect(logs.first['actorName'], 'สมชาย (ผู้จัดการ)');
      },
    );

    test(
      'applyDiscount log เป็น order.discount ทุกครั้งรวมถึงตอนยกเลิกส่วนลด',
      () {
        final order = openOrder();
        store.applyDiscount(
          order['id'] as int,
          DiscountType.percent,
          10,
          actorId: 6,
        );
        var logs = store
            .auditLogList(
              action: 'order.discount',
              entityId: order['id'] as int,
            )
            .rows;
        expect(logs, hasLength(1));
        expect(logs.first['metadata']['newType'], DiscountType.percent);

        store.applyDiscount(
          order['id'] as int,
          DiscountType.none,
          0,
          actorId: 6,
        );
        logs = store
            .auditLogList(
              action: 'order.discount',
              entityId: order['id'] as int,
            )
            .rows;
        expect(logs, hasLength(2));
      },
    );

    test(
      'updateStaff log แยก role_change/deactivate/password_reset แต่แก้ชื่อเฉยๆ ไม่ log',
      () {
        final created = store.createStaff(
          name: 'พนักงานทดสอบ audit log',
          username: 'audit_log_test_${DateTime.now().microsecondsSinceEpoch}',
          password: 'test1234',
          role: UserRole.waiter,
        );
        final userId = created['id'] as int;

        store.updateStaff(userId, {'role': UserRole.cashier}, actorId: 1);
        final roleLogs = store
            .auditLogList(action: 'user.role_change', entityId: userId)
            .rows;
        expect(roleLogs, hasLength(1));
        expect(roleLogs.first['metadata']['previousRole'], UserRole.waiter);
        expect(roleLogs.first['metadata']['newRole'], UserRole.cashier);

        store.updateStaff(userId, {'isActive': false}, actorId: 1);
        expect(
          store.auditLogList(action: 'user.deactivate', entityId: userId).rows,
          hasLength(1),
        );

        store.updateStaff(userId, {'password': 'newpassword'}, actorId: 1);
        expect(
          store
              .auditLogList(action: 'user.password_reset', entityId: userId)
              .rows,
          hasLength(1),
        );

        final before = store.auditLogList(entityId: userId).rows.length;
        store.updateStaff(userId, {'name': 'ชื่อใหม่เฉยๆ'}, actorId: 1);
        expect(store.auditLogList(entityId: userId).rows, hasLength(before));
      },
    );

    // หน้าจัดการพนักงานภาษาเกาหลีเคยเป็นชื่อไทยทั้งหน้า ทั้งที่ seed มี nameKo อยู่แล้ว (#64)
    test(
      'staff ส่งชื่อตามภาษาที่แสดง และแก้ชื่อเองแล้วได้ชื่อที่พิมพ์ทุกภาษา',
      () {
        addTearDown(() => DemoNames.language = 'th');
        DemoNames.language = 'ko';
        final hasThai = RegExp(r'[\u0E00-\u0E7F]');
        final names = store.staff().map((u) => u['name'] as String).toList();
        expect(
          names.where(hasThai.hasMatch),
          isEmpty,
          reason: names.join(', '),
        );

        final manager = store.staff().firstWhere(
          (u) => u['username'] == 'manager',
        );
        store.updateStaff(manager['id'] as int, {'name': '김매니저'}, actorId: 1);
        DemoNames.language = 'th';
        expect(
          store.staff().firstWhere((u) => u['username'] == 'manager')['name'],
          '김매니저',
          reason: 'ชื่อที่ร้านพิมพ์เองต้องไม่ถูกคำแปลเก่าใน seed ทับ',
        );
      },
    );

    test(
      'updateStaff ห้ามเปลี่ยนบทบาท/ปิดใช้งานบัญชีตัวเอง (mirror backend)',
      () {
        final created = store.createStaff(
          name: 'แอดมินสำรอง',
          username: 'self_guard_${DateTime.now().microsecondsSinceEpoch}',
          password: 'test1234',
          role: UserRole.admin,
        );
        final selfId = created['id'] as int;

        expect(
          () => store.updateStaff(selfId, {
            'role': UserRole.waiter,
          }, actorId: selfId),
          throwsA(
            isA<ApiException>().having((e) => e.statusCode, 'status', 400),
          ),
        );
        expect(
          () => store.updateStaff(selfId, {'isActive': false}, actorId: selfId),
          throwsA(isA<ApiException>()),
        );
        // แก้ชื่อตัวเองได้ และคนอื่นเปลี่ยนบทบาทให้ได้ตามปกติ
        store.updateStaff(selfId, {'name': 'ชื่อใหม่'}, actorId: selfId);
        final changed = store.updateStaff(selfId, {
          'role': UserRole.manager,
        }, actorId: 1);
        expect(changed['role'], UserRole.manager);
      },
    );

    test('deleteStaff log เป็น user.delete แม้บัญชีจะถูกลบไปแล้ว', () {
      final created = store.createStaff(
        name: 'จะถูกลบ',
        username: 'audit_log_del_${DateTime.now().microsecondsSinceEpoch}',
        password: 'test1234',
        role: UserRole.waiter,
      );
      final userId = created['id'] as int;

      store.deleteStaff(userId, actorId: 1);

      final logs = store
          .auditLogList(action: 'user.delete', entityId: userId)
          .rows;
      expect(logs, hasLength(1));
      expect(logs.first['actorUserId'], 1);
      expect(logs.first['actorName'], 'ผู้ดูแลระบบ');
    });

    test(
      'updateSettings log เป็น settings.update เฉพาะตอนแก้ VAT/ค่าบริการ',
      () {
        final previousVat = store.settings['vatRate'] as double;
        store.updateSettings({'vatRate': previousVat + 0.01}, actorId: 1);
        expect(
          store.auditLogList(action: 'settings.update').rows,
          hasLength(1),
        );

        store.updateSettings({'storeName': 'ร้านทดสอบ audit log'}, actorId: 1);
        expect(
          store.auditLogList(action: 'settings.update').rows,
          hasLength(1),
        );
      },
    );

    test('refundPayment log เป็น payment.refund', () {
      final order = openOrder();
      final total = (order['total'] as num).toDouble();
      final payment = store.pay(
        orderId: order['id'] as int,
        method: 'cash',
        amount: total,
        received: total,
        cashierId: 6,
      );
      final paymentId = (payment['payment'] as Map)['id'] as int;

      final refund = store.refundPayment(
        paymentId: paymentId,
        amount: total,
        reason: 'ลูกค้าคืนอาหาร',
        refundedById: 2,
      );

      final logs = store
          .auditLogList(action: 'payment.refund', entityId: refund['id'] as int)
          .rows;
      expect(logs, hasLength(1));
      expect(logs.first['entityType'], 'refund');
      expect(logs.first['reason'], 'ลูกค้าคืนอาหาร');
    });

    test('voidTaxInvoice log เป็น tax_invoice.void', () {
      final table = store.tableList().firstWhere(
        (t) => t['status'] == 'available',
      );
      final item = store.menuList().first;
      final order = store.createOrder(
        type: 'dine_in',
        tableId: table['id'] as int,
        guestCount: 1,
        items: [
          {'menuItemId': item['id'], 'quantity': 1, 'optionIds': []},
        ],
      );
      final total = (order['total'] as num).toDouble();
      store.pay(
        orderId: order['id'] as int,
        method: 'cash',
        amount: total,
        received: total,
        cashierId: 6,
      );
      final invoice = store.issueTaxInvoice(order['id'] as int, {
        'invoiceType': TaxInvoiceType.abbreviated,
      });

      store.voidTaxInvoice(order['id'] as int, 'ออกผิดประเภท', voidedById: 1);

      final logs = store
          .auditLogList(
            action: 'tax_invoice.void',
            entityId: invoice['id'] as int,
          )
          .rows;
      expect(logs, hasLength(1));
      expect(logs.first['reason'], 'ออกผิดประเภท');
    });

    // ดู docs/tickets/14-financial-audit-trail.md — audit ระดับบัญชี/การเงิน
    test('saveMenuItem log เป็น menu.price_change เฉพาะตอนราคาเปลี่ยนจริง', () {
      final category = store.categories.first;
      final menuItem = store.saveMenuItem({
        'name': 'เมนูทดสอบ-audit ราคา',
        'categoryId': category['id'],
        'price': 100.0,
      });
      final itemId = menuItem['id'] as int;

      // แก้แค่ชื่อเฉยๆ ไม่ควร log
      store.saveMenuItem(
        {
          'categoryId': category['id'],
          'name': 'เมนูทดสอบ-audit ราคา (เปลี่ยนชื่อ)',
        },
        id: itemId,
        actorId: 1,
      );
      expect(
        store.auditLogList(action: 'menu.price_change', entityId: itemId).rows,
        isEmpty,
      );

      store.saveMenuItem(
        {'categoryId': category['id'], 'price': 120.0},
        id: itemId,
        actorId: 1,
      );
      final logs = store
          .auditLogList(action: 'menu.price_change', entityId: itemId)
          .rows;
      expect(logs, hasLength(1));
      expect(logs.first['metadata']['previousPrice'], 100.0);
      expect(logs.first['metadata']['newPrice'], 120.0);
      expect(logs.first['actorUserId'], 1);
    });

    test('savePromotion/deletePromotion log ครบทั้งสร้าง/แก้ไข/ลบ', () {
      final promotion = store.savePromotion({
        'name': 'โปรทดสอบ audit',
        'type': 'percent',
        'value': 10,
        'conditions': const {},
      }, actorId: 1);
      final promotionId = promotion['id'] as int;
      expect(
        store
            .auditLogList(action: 'promotion.create', entityId: promotionId)
            .rows,
        hasLength(1),
      );

      store.savePromotion({'value': 15}, id: promotionId, actorId: 1);
      expect(
        store
            .auditLogList(action: 'promotion.update', entityId: promotionId)
            .rows,
        hasLength(1),
      );

      store.deletePromotion(promotionId, actorId: 1);
      final deleteLogs = store
          .auditLogList(action: 'promotion.delete', entityId: promotionId)
          .rows;
      expect(deleteLogs, hasLength(1));
      expect(deleteLogs.first['summary'], contains('โปรทดสอบ audit'));
    });

    test(
      'adjustIngredientStock log เป็น ingredient.stock_adjust พร้อมส่วนต่างสต๊อก',
      () {
        final ingredient = store.saveIngredient({
          'name': 'วัตถุดิบทดสอบ-audit',
          'unit': 'กรัม',
          'currentStock': 100.0,
          'lowStockThreshold': 20.0,
        });
        final ingredientId = ingredient['id'] as int;

        store.adjustIngredientStock(ingredientId, -30, actorId: 1);

        final logs = store
            .auditLogList(
              action: 'ingredient.stock_adjust',
              entityId: ingredientId,
            )
            .rows;
        expect(logs, hasLength(1));
        expect(logs.first['metadata']['delta'], -30.0);
        expect(logs.first['metadata']['previousStock'], 100.0);
        expect(logs.first['metadata']['newStock'], 70.0);
      },
    );

    test('auditLogExportCsv คืน CSV ที่มี header และแถวตรงตาม filter', () {
      final previousVat = store.settings['vatRate'] as double;
      store.updateSettings({'vatRate': previousVat + 0.01}, actorId: 1);

      final csv = store.auditLogExportCsv(action: 'settings.update');

      expect(
        csv,
        contains('วันเวลา,ผู้ทำ,การกระทำ,ประเภท,รหัสอ้างอิง,รายละเอียด,เหตุผล'),
      );
      expect(csv, contains('settings.update'));
      final dataLines = csv
          .split('\r\n')
          .skip(1)
          .where((line) => line.isNotEmpty)
          .toList();
      for (final line in dataLines) {
        expect(line, contains('settings.update'));
      }
    });
  });

  group('DemoStore customers/loyalty — ลูกค้า/แต้มสะสม (ticket 09)', () {
    Map<String, dynamic> openOrder({int? customerId}) {
      final table = store.tableList().firstWhere(
        (t) => t['status'] == 'available',
      );
      final item = store.menuList().first;
      return store.createOrder(
        type: 'dine_in',
        tableId: table['id'] as int,
        customerId: customerId,
        guestCount: 1,
        items: [
          {'menuItemId': item['id'], 'quantity': 2, 'optionIds': []},
        ],
      );
    }

    test('createCustomer สร้างลูกค้าใหม่ pointsBalance เริ่มต้นเป็น 0', () {
      final customer = store.createCustomer(
        name: 'คุณสมหญิง',
        phone: '0812345678',
      );

      expect(customer['pointsBalance'], 0);
      expect(store.customers, contains(customer));
    });

    test('createCustomer ด้วยเบอร์โทรซ้ำต้องถูกปฏิเสธ', () {
      store.createCustomer(name: 'คุณสมหญิง', phone: '0812345678');

      expect(
        () => store.createCustomer(name: 'คุณสมชาย', phone: '0812345678'),
        throwsException,
      );
    });

    test('customerSearch ค้นหาได้ทั้งจากชื่อและเบอร์โทร (partial match)', () {
      store.createCustomer(name: 'สมหญิง ใจดี', phone: '0899999999');
      store.createCustomer(name: 'John Smith', phone: '0888888888');

      expect(store.customerSearch(search: 'สมหญิง'), hasLength(1));
      expect(store.customerSearch(search: '9999'), hasLength(1));
      expect(store.customerSearch(search: 'ไม่มีจริง'), isEmpty);
    });

    test(
      'createOrder ผูก customerId แล้ว order มี customerName/customerPhone',
      () {
        final customer = store.createCustomer(
          name: 'คุณสมหญิง',
          phone: '0812345678',
        );

        final order = openOrder(customerId: customer['id'] as int);

        expect(order['customerId'], customer['id']);
        expect(order['customerName'], customer['name']);
        expect(order['customerPhone'], customer['phone']);
      },
    );

    test('createOrder ด้วย customerId ที่ไม่มีจริงต้องถูกปฏิเสธ', () {
      expect(() => openOrder(customerId: 999999), throwsException);
    });

    test(
      'จ่ายเงินครบเต็มจำนวนของออเดอร์ที่ผูกลูกค้า → ได้แต้มสะสมตามอัตราที่ตั้งค่า',
      () {
        final customer = store.createCustomer(
          name: 'คุณสมหญิง',
          phone: '0812345678',
        );
        final order = openOrder(customerId: customer['id'] as int);
        final total = (order['total'] as num).toDouble();
        final earnRate = (store.settings['pointsEarnRateBaht'] as num)
            .toDouble();
        final expectedPoints = (total / earnRate).floor();

        final result = store.pay(
          orderId: order['id'] as int,
          method: 'cash',
          amount: total,
          received: total,
        );

        expect(result['isFullyPaid'], isTrue);
        expect((result['order'] as Map)['pointsEarned'], expectedPoints);
        expect(
          store.findCustomer(customer['id'] as int)['pointsBalance'],
          expectedPoints,
        );
      },
    );

    test('ออเดอร์ที่ไม่ได้ผูกลูกค้า จ่ายครบแล้วไม่ได้แต้ม', () {
      final order = openOrder();
      final total = (order['total'] as num).toDouble();

      store.pay(
        orderId: order['id'] as int,
        method: 'cash',
        amount: total,
        received: total,
      );

      expect(store.findOrder(order['id'] as int)['pointsEarned'], 0);
    });

    test('แยกจ่ายหลายรอบ ลูกค้าได้แต้มแค่ครั้งเดียวตอนจ่ายครบ', () {
      final customer = store.createCustomer(
        name: 'คุณสมหญิง',
        phone: '0812345678',
      );
      final order = openOrder(customerId: customer['id'] as int);
      final total = (order['total'] as num).toDouble();
      final half = total / 2;

      final firstResult = store.pay(
        orderId: order['id'] as int,
        method: 'cash',
        amount: half,
        received: half,
      );
      expect(firstResult['isFullyPaid'], isFalse);
      expect(store.findCustomer(customer['id'] as int)['pointsBalance'], 0);

      final remaining = total - half;
      final secondResult = store.pay(
        orderId: order['id'] as int,
        method: 'cash',
        amount: remaining,
        received: remaining,
      );
      expect(secondResult['isFullyPaid'], isTrue);

      final earnRate = (store.settings['pointsEarnRateBaht'] as num).toDouble();
      final expectedPoints = (total / earnRate).floor();
      expect(
        store.findCustomer(customer['id'] as int)['pointsBalance'],
        expectedPoints,
      );
    });

    test(
      'ใช้แต้มสะสมแลกส่วนลด → ลดยอดที่ต้องเก็บจริง แต่ไม่กระทบยอดที่นับเข้าออเดอร์',
      () {
        final customer = store.createCustomer(
          name: 'คุณสมหญิง',
          phone: '0812345678',
        );
        store.adjustCustomerPoints(customer['id'] as int, 50);
        final order = openOrder(customerId: customer['id'] as int);
        final total = (order['total'] as num).toDouble();
        final redeemRate = (store.settings['pointsRedeemValueBaht'] as num)
            .toDouble();
        const pointsToRedeem = 10;
        final redeemedValue = pointsToRedeem * redeemRate;

        final result = store.pay(
          orderId: order['id'] as int,
          method: 'cash',
          amount: total,
          received: total - redeemedValue,
          pointsToRedeem: pointsToRedeem,
        );

        final payment = result['payment'] as Map<String, dynamic>;
        // ยอดที่นับเข้าบัญชีจ่ายของออเดอร์ (amount) ต้องไม่ลดลงจากการใช้แต้ม —
        // ลดแค่ยอดที่เก็บเงินจริง (received) เท่านั้น (ดู docs/DECISIONS.md)
        expect(payment['amount'], total);
        expect(payment['pointsRedeemed'], pointsToRedeem);
        expect(payment['pointsRedeemedValue'], redeemedValue);
        expect(payment['received'], total - redeemedValue);
        expect(result['isFullyPaid'], isTrue);

        final earnRate = (store.settings['pointsEarnRateBaht'] as num)
            .toDouble();
        final earnedThisOrder = (total / earnRate).floor();
        expect(
          store.findCustomer(customer['id'] as int)['pointsBalance'],
          50 - pointsToRedeem + earnedThisOrder,
        );
      },
    );

    test('ใช้แต้มเกินยอดคงเหลือของลูกค้าต้องถูกปฏิเสธ', () {
      final customer = store.createCustomer(
        name: 'คุณสมหญิง',
        phone: '0812345678',
      );
      final order = openOrder(customerId: customer['id'] as int);
      final total = (order['total'] as num).toDouble();

      expect(
        () => store.pay(
          orderId: order['id'] as int,
          method: 'cash',
          amount: total,
          pointsToRedeem: 1,
        ),
        throwsException,
      );
    });

    test('ใช้แต้มโดยออเดอร์ไม่ได้ผูกลูกค้าต้องถูกปฏิเสธ', () {
      final order = openOrder();
      final total = (order['total'] as num).toDouble();

      expect(
        () => store.pay(
          orderId: order['id'] as int,
          method: 'cash',
          amount: total,
          pointsToRedeem: 1,
        ),
        throwsException,
      );
    });

    test('ใช้แต้มที่มีมูลค่าเกินยอดที่ต้องชำระรอบนี้ต้องถูกปฏิเสธ', () {
      final customer = store.createCustomer(
        name: 'คุณสมหญิง',
        phone: '0812345678',
      );
      store.adjustCustomerPoints(customer['id'] as int, 1000);
      final order = openOrder(customerId: customer['id'] as int);
      final total = (order['total'] as num).toDouble();
      final redeemRate = (store.settings['pointsRedeemValueBaht'] as num)
          .toDouble();
      // แต้มพอ (1000) แต่มูลค่าเกินยอดที่จ่ายจริงรอบนี้ (จ่ายแค่บางส่วน)
      final partialAmount = total / 4;
      final tooManyPoints = (partialAmount / redeemRate).ceil() + 10;

      expect(
        () => store.pay(
          orderId: order['id'] as int,
          method: 'cash',
          amount: partialAmount,
          pointsToRedeem: tooManyPoints,
        ),
        throwsException,
      );
    });
  });

  group('DemoStore takeaway/delivery — เลขคิวรับอาหาร (ticket 10)', () {
    Map<String, dynamic> openOrder({required String type, int? tableId}) {
      final item = store.menuList().first;
      return store.createOrder(
        type: type,
        tableId: tableId,
        guestCount: 1,
        items: [
          {'menuItemId': item['id'], 'quantity': 1, 'optionIds': []},
        ],
      );
    }

    test('ออเดอร์ทานที่ร้านไม่มีเลขคิว', () {
      final table = store.tableList().firstWhere(
        (t) => t['status'] == 'available',
      );
      final order = openOrder(
        type: OrderType.dineIn,
        tableId: table['id'] as int,
      );

      expect(order['queueNumber'], isNull);
    });

    test('ออเดอร์เดลิเวอรีไม่มีเลขคิว (ไรเดอร์อ้างอิงจาก code แทน)', () {
      final order = openOrder(type: OrderType.delivery);

      expect(order['tableId'], isNull);
      expect(order['queueNumber'], isNull);
    });

    test('ออเดอร์กลับบ้านหลายใบติดกัน ได้เลขคิวรันต่อเนื่องเริ่มที่ 1', () {
      final first = openOrder(type: OrderType.takeaway);
      final second = openOrder(type: OrderType.takeaway);
      final third = openOrder(type: OrderType.takeaway);

      expect(first['queueNumber'], 1);
      expect(second['queueNumber'], 2);
      expect(third['queueNumber'], 3);
    });

    test('เลขคิวนับแยกจากออเดอร์ dine_in/delivery ที่แทรกอยู่ระหว่างกัน', () {
      final table = store.tableList().firstWhere(
        (t) => t['status'] == 'available',
      );
      final firstTakeaway = openOrder(type: OrderType.takeaway);
      openOrder(type: OrderType.dineIn, tableId: table['id'] as int);
      openOrder(type: OrderType.delivery);
      final secondTakeaway = openOrder(type: OrderType.takeaway);

      expect(firstTakeaway['queueNumber'], 1);
      expect(secondTakeaway['queueNumber'], 2);
    });
  });

  group('DemoStore self-order — สั่งอาหารเองผ่าน QR (ticket 17)', () {
    test('โต๊ะทุกตัวมี qrToken ไม่ซ้ำกันตั้งแต่ seed มา', () {
      final tokens = store.tableList().map((t) => t['qrToken']).toList();
      expect(tokens, everyElement(isNotNull));
      expect(tokens.toSet().length, tokens.length);
    });

    test(
      'ลูกค้ากด "ส่งเข้าครัว" แล้วครัวเห็นทันที ไม่ค้างเป็นร่าง (mirror ของ backend — DECISIONS #46)',
      () async {
        final table = store.tableList().firstWhere(
          (t) => t['status'] == 'available',
        );
        final item = store.menuList().first;
        final order = await DemoSelfOrderDataSource(store).addItems(
          table['qrToken'] as String,
          [OrderItemPayload(menuItemId: item['id'] as int, quantity: 1)],
        );

        expect(order.status, OrderStatus.inKitchen);
        final queue = store.kitchenQueue(['pending', 'cooking', 'ready']);
        expect(queue.where((row) => row['orderId'] == order.id), hasLength(1));
      },
    );

    test('resolveTableByQrToken หาโต๊ะถูกตัวจาก token ที่ seed มา', () {
      final table = store.tableList().first;
      final resolved = store.resolveTableByQrToken(table['qrToken'] as String);
      expect(resolved['id'], table['id']);
    });

    test('resolveTableByQrToken token ไม่มีจริง → ApiException 404', () {
      expect(
        () => store.resolveTableByQrToken('ไม่มีจริง'),
        throwsA(
          isA<ApiException>().having((e) => e.statusCode, 'statusCode', 404),
        ),
      );
    });

    test('resolveTableByQrToken โต๊ะถูกปิดใช้งานแล้ว → ApiException 404', () {
      final table = store.tableList().first;
      store.saveTable({'isActive': false}, id: table['id'] as int);

      expect(
        () => store.resolveTableByQrToken(table['qrToken'] as String),
        throwsA(isA<ApiException>()),
      );
    });

    test('regenerateQrToken ออก token ใหม่ ปิด token เก่าทันที', () {
      final table = store.tableList().first;
      final oldToken = table['qrToken'] as String;

      final updated = store.regenerateQrToken(table['id'] as int);
      final newToken = updated['qrToken'] as String;

      expect(newToken, isNot(oldToken));
      expect(
        () => store.resolveTableByQrToken(oldToken),
        throwsA(isA<ApiException>()),
      );
      expect(store.resolveTableByQrToken(newToken)['id'], table['id']);
    });
  });

  group(
    'DemoStore shift + refund — เงินสดที่คืนลูกค้าหักจากลิ้นชักของกะที่คืน (DECISIONS #44)',
    () {
      // mirror ของเทสต์ชุดเดียวกันใน backend/tests/shift.test.js — โหมดสาธิตต้องได้ตัวเลขเดียวกันทุกกรณี
      Map<String, dynamic> openFreshShift(double openingCash) {
        final current = store.currentShift();
        if (current != null) {
          store.closeShift(
            current['id'] as int,
            countedCash: (current['openingCash'] as num).toDouble(),
            closedById: 2,
          );
        }
        return store.openShift(openingCash: openingCash, openedById: 6);
      }

      ({double total, int paymentId}) paidOrder(String method) {
        final table = store.tableList().firstWhere(
          (t) => t['status'] == 'available',
        );
        final item = store.menuList().first;
        final order = store.createOrder(
          type: 'dine_in',
          tableId: table['id'] as int,
          guestCount: 1,
          items: [
            {'menuItemId': item['id'], 'quantity': 1, 'optionIds': []},
          ],
        );
        final total = (order['total'] as num).toDouble();
        final isCash = method == PaymentMethod.cash;
        final result = store.pay(
          orderId: order['id'] as int,
          method: method,
          amount: total,
          received: isCash ? total : null,
          reference: isCash ? null : 'T-1',
          cashierId: 6,
        );
        return (
          total: total,
          paymentId: (result['payment'] as Map)['id'] as int,
        );
      }

      test('คืนเงินสดระหว่างกะ ถูกหักจากยอดที่คาดไว้ — นับตรงต้องไม่ขาด', () {
        final shift = openFreshShift(500);
        final paid = paidOrder(PaymentMethod.cash);
        store.refundPayment(
          paymentId: paid.paymentId,
          amount: 20,
          reason: 'ทดสอบ',
          refundedById: 2,
        );

        final inDrawer = 500 + paid.total - 20;
        final closed = store.closeShift(
          shift['id'] as int,
          countedCash: inDrawer,
          closedById: 6,
        );
        expect(closed['expectedCash'], closeTo(inDrawer, 0.005));
        expect(closed['variance'], closeTo(0, 0.005));
      });

      test(
        'คืนเงินสดของบิลจากกะก่อน หักจากลิ้นชักกะที่คืน ไม่ใช่กะที่รับเงินมา',
        () {
          final morning = openFreshShift(1000);
          final paid = paidOrder(PaymentMethod.cash);
          final closedMorning = store.closeShift(
            morning['id'] as int,
            countedCash: 1000 + paid.total,
            closedById: 6,
          );
          expect(closedMorning['variance'], closeTo(0, 0.005));

          final afternoon = openFreshShift(300);
          store.refundPayment(
            paymentId: paid.paymentId,
            amount: 10,
            reason: 'ลูกค้ากลับมาขอคืนตอนบ่าย',
            refundedById: 2,
          );
          final closedAfternoon = store.closeShift(
            afternoon['id'] as int,
            countedCash: 290,
            closedById: 6,
          );
          expect(closedAfternoon['expectedCash'], closeTo(290, 0.005));
          expect(closedAfternoon['variance'], closeTo(0, 0.005));
          expect(closedMorning['variance'], closeTo(0, 0.005));
        },
      );

      test('ไม่มีกะเปิดอยู่ คืนเงินสดไม่ได้ (409) เหมือนรับเงินสดไม่ได้', () {
        openFreshShift(0);
        final paid = paidOrder(PaymentMethod.cash);
        final current = store.currentShift()!;
        store.closeShift(
          current['id'] as int,
          countedCash: paid.total,
          closedById: 6,
        );

        expect(
          () => store.refundPayment(
            paymentId: paid.paymentId,
            amount: 5,
            reason: 'ทดสอบ',
            refundedById: 2,
          ),
          throwsA(
            isA<ApiException>().having((e) => e.statusCode, 'status', 409),
          ),
        );
      });

      test('คืนเงินที่จ่ายผ่าน QR ได้แม้ไม่มีกะเปิด เพราะไม่แตะลิ้นชัก', () {
        openFreshShift(0);
        final paid = paidOrder(PaymentMethod.qr);
        final current = store.currentShift()!;
        store.closeShift(current['id'] as int, countedCash: 0, closedById: 6);

        final refund = store.refundPayment(
          paymentId: paid.paymentId,
          amount: 5,
          reason: 'ทดสอบ',
          refundedById: 2,
        );
        expect(refund['amount'], 5);
      });
    },
  );

  // เคาน์เตอร์เนื้อสดของร้านที่ขายส่งด้วย — ขายตามน้ำหนัก, สแกนบาร์โค้ด, ขายเชื่อ/วางบิล
  // (ดู docs/tickets/18-sell-by-weight.md, 19-barcode-scale.md, 20-b2b-credit.md)
  group('DemoStore ขายตามน้ำหนัก / บาร์โค้ด (tickets 18–19)', () {
    const porkBelly =
        25; // 280 บาท/กก. ตัดสต๊อกวัตถุดิบ 7 (หมูสามชั้น) 1 กก./กก.
    const kimchi = 29; // ขายเป็นชิ้น มีบาร์โค้ด

    Map<String, dynamic> takeaway(List<Map<String, dynamic>> items) =>
        store.createOrder(type: 'takeaway', guestCount: 1, items: items);

    double stockOf(int ingredientId) =>
        (store.ingredients.firstWhere(
                  (row) => row['id'] == ingredientId,
                )['currentStock']
                as num)
            .toDouble();

    test('ชั่ง 485 กรัม → ราคาบรรทัด = 280 × 0.485 และจำนวนเป็น 1 เสมอ', () {
      final order = takeaway([
        {'menuItemId': porkBelly, 'quantity': 1, 'weightGrams': 485},
      ]);

      final item = (order['items'] as List).single as Map;
      expect(item['weightGrams'], 485);
      expect(item['quantity'], 1);
      expect(order['subtotal'], 135.8);
    });

    test(
      'สินค้าชั่งน้ำหนักต้องมีน้ำหนัก / สินค้าชิ้นห้ามมีน้ำหนัก / บรรทัดละ 1 ถุง',
      () {
        expect(
          () => takeaway([
            {'menuItemId': porkBelly, 'quantity': 1},
          ]),
          throwsA(isA<ApiException>()),
        );
        expect(
          () => takeaway([
            {'menuItemId': kimchi, 'quantity': 1, 'weightGrams': 500},
          ]),
          throwsA(isA<ApiException>()),
        );
        expect(
          () => takeaway([
            {'menuItemId': porkBelly, 'quantity': 2, 'weightGrams': 500},
          ]),
          throwsA(isA<ApiException>()),
        );
      },
    );

    test('แก้จำนวนของบรรทัดชั่งน้ำหนักไม่ได้ ต้องลบแล้วชั่งใหม่', () {
      final order = takeaway([
        {'menuItemId': porkBelly, 'quantity': 1, 'weightGrams': 485},
      ]);
      final itemId = ((order['items'] as List).single as Map)['id'] as int;

      expect(
        () => store.updateItem(order['id'] as int, itemId, quantity: 2),
        throwsA(isA<ApiException>()),
      );
    });

    test('จ่ายครบแล้วตัดสต๊อกเป็นกิโลกรัมตามน้ำหนักจริง ครั้งเดียว', () {
      final before = stockOf(7);
      final order = takeaway([
        {'menuItemId': porkBelly, 'quantity': 1, 'weightGrams': 485},
        {'menuItemId': porkBelly, 'quantity': 1, 'weightGrams': 1250},
      ]);
      final total = (order['total'] as num).toDouble();

      store.pay(
        orderId: order['id'] as int,
        method: 'cash',
        amount: total,
        received: total,
      );

      expect(stockOf(7), closeTo(before - 1.735, 1e-9));
    });

    test(
      'บาร์โค้ด/PLU ซ้ำกับเมนูอื่นไม่ได้ และ PLU ใช้ได้เฉพาะเมนูขายตามน้ำหนัก',
      () {
        final base = {
          'categoryId': 8,
          'name': 'ของใหม่',
          'price': 99.0,
          'isAvailable': true,
        };

        expect(
          () => store.saveMenuItem({...base, 'barcode': '8850999320021'}),
          throwsA(isA<ApiException>()),
        );
        expect(
          () => store.saveMenuItem({
            ...base,
            'soldByWeight': true,
            'scalePlu': '00101',
          }),
          throwsA(isA<ApiException>()),
          reason: 'PLU 00101 = 101 ของหมูสามชั้น',
        );
        expect(
          () => store.saveMenuItem({...base, 'scalePlu': '555'}),
          throwsA(isA<ApiException>()),
        );

        final saved = store.saveMenuItem({
          ...base,
          'soldByWeight': true,
          'scalePlu': '00555',
        });
        expect(saved['scalePlu'], '555', reason: 'เก็บ PLU แบบตัดเลข 0 นำหน้า');
      },
    );

    test(
      'QR สั่งเองไม่เห็นและสั่งสินค้าชั่งน้ำหนักไม่ได้ (ต้องให้พนักงานชั่ง)',
      () async {
        final token = store.tableList().first['qrToken'] as String;
        final source = DemoSelfOrderDataSource(store);

        final menu = await source.getMenu(token);
        expect(menu.items.map((item) => item.id), isNot(contains(porkBelly)));
        expect(menu.items.map((item) => item.id), contains(kimchi));
        await expectLater(
          source.addItems(token, [
            const OrderItemPayload(menuItemId: porkBelly, quantity: 1),
          ]),
          throwsA(isA<ApiException>()),
        );
      },
    );
  });

  group('DemoStore ขายเชื่อ / ใบวางบิล / รับชำระหนี้ (ticket 20)', () {
    const b2b = 900; // บริษัท โซลบาร์บีคิว วงเงิน 50,000 เครดิต 30 วัน
    const cashier = 6;
    const waiter = 3;

    // เดโม seed บิลขายเชื่อที่เลยกำหนดไว้ให้ลองคิดดอกเบี้ย (ticket 21) — กลุ่มนี้ทดสอบกฎของ ticket 20
    // จากบัญชีที่ยังไม่มีหนี้ จึงเอาบิลนั้นออกก่อน (กลุ่ม ticket 21 ด้านล่างใช้บิลนั้นจริง)
    setUp(
      () => store.payments.removeWhere(
        (payment) => payment['method'] == PaymentMethod.credit,
      ),
    );
    tearDown(AppClock.unfreeze);

    Map<String, dynamic> creditSale(double kg, {int? customerId = b2b}) {
      final order = store.createOrder(
        type: 'takeaway',
        guestCount: 1,
        customerId: customerId,
        items: [
          {
            'menuItemId': 26, // ริบอาย 1,200 บาท/กก.
            'quantity': 1,
            'weightGrams': (kg * 1000).round(),
          },
        ],
      );
      store.pay(
        orderId: order['id'] as int,
        method: 'credit',
        amount: (order['total'] as num).toDouble(),
        cashierId: cashier,
      );
      return store.findOrder(order['id'] as int);
    }

    double outstanding() =>
        (store.receivableStatement(b2b)['outstanding'] as num).toDouble();

    test(
      'ขายเชื่อปิดบิลได้โดยไม่มีเงินเข้า ยอดไปค้างในบัญชีลูกค้า ครบกำหนด +30 วัน',
      () {
        AppClock.freeze(DateTime(2026, 9, 1, 12));

        final order = creditSale(2);

        expect(order['status'], OrderStatus.paid);
        final statement = store.receivableStatement(b2b);
        expect(statement['outstanding'], order['total']);
        final invoice = (statement['invoices'] as List).single as Map;
        expect(invoice['dueDate'], '2026-10-01');
      },
    );

    test('ขายเชื่อเกินวงเงินถูกปฏิเสธ พร้อมบอกยอดที่ใช้ได้', () {
      store.updateCustomerCredit(b2b, {
        'creditLimit': 1000.0,
        'creditTermDays': 30,
      });

      expect(
        () => creditSale(2),
        throwsA(
          isA<ApiException>().having((e) => e.statusCode, 'statusCode', 409),
        ),
      );
    });

    test('ต้องผูกลูกค้า / พนักงานเสิร์ฟทำไม่ได้ / ใช้แต้มร่วมไม่ได้', () {
      expect(
        () => creditSale(1, customerId: null),
        throwsA(isA<ApiException>()),
      );

      final order = store.createOrder(
        type: 'takeaway',
        guestCount: 1,
        customerId: b2b,
        items: [
          {'menuItemId': 29, 'quantity': 1},
        ],
      );
      final total = (order['total'] as num).toDouble();
      expect(
        () => store.pay(
          orderId: order['id'] as int,
          method: 'credit',
          amount: total,
          cashierId: waiter,
        ),
        throwsA(
          isA<ApiException>().having((e) => e.statusCode, 'statusCode', 403),
        ),
      );
      store.adjustCustomerPoints(b2b, 50);
      expect(
        () => store.pay(
          orderId: order['id'] as int,
          method: 'credit',
          amount: total,
          cashierId: cashier,
          pointsToRedeem: 10,
        ),
        throwsA(isA<ApiException>()),
      );
    });

    test('รับชำระหนี้ตัดบิลเก่าสุดก่อน (FIFO) และรับเกินยอดค้างไม่ได้', () {
      final first = creditSale(1);
      final second = creditSale(0.5);
      final firstTotal = (first['total'] as num).toDouble();

      final receipt = store.createArReceipt({
        'customerId': b2b,
        'amount': firstTotal + 100,
        'method': 'transfer',
      }, actorId: cashier);

      final allocations = (receipt['allocations'] as List).cast<Map>();
      expect(allocations.map((line) => line['orderCode']), [
        first['code'],
        second['code'],
      ]);
      expect(allocations.first['amount'], firstTotal);
      expect(allocations.last['amount'], 100);
      expect(receipt['receiptNo'], startsWith('RC'));

      expect(
        () => store.createArReceipt({
          'customerId': b2b,
          'amount': outstanding() + 1,
          'method': 'transfer',
        }),
        throwsA(isA<ApiException>()),
      );
    });

    test(
      'รับชำระเงินสดเข้าลิ้นชักกะ — ปิดกะแล้วยอดคาดหวังรวมหนี้ที่เก็บได้',
      () {
        creditSale(1);
        final shift = store.currentShift()!;
        final opening = (shift['openingCash'] as num).toDouble();

        store.createArReceipt({
          'customerId': b2b,
          'amount': 500.0,
          'method': 'cash',
        }, actorId: cashier);

        final closed = store.closeShift(
          shift['id'] as int,
          countedCash: opening + 500,
          closedById: cashier,
        );
        expect(closed['variance'], 0);
      },
    );

    test(
      'ยกเลิกใบเสร็จเงินสดหลังปิดกะไม่ได้ ส่วนโอนยกเลิกได้และหนี้กลับมาค้าง',
      () {
        creditSale(1);
        final before = outstanding();
        final cash = store.createArReceipt({
          'customerId': b2b,
          'amount': 300.0,
          'method': 'cash',
        }, actorId: cashier);
        final transfer = store.createArReceipt({
          'customerId': b2b,
          'amount': 200.0,
          'method': 'transfer',
        }, actorId: cashier);
        final shift = store.currentShift()!;
        store.closeShift(
          shift['id'] as int,
          countedCash: 0,
          closedById: cashier,
        );

        expect(
          () => store.voidArReceipt(cash['id'] as int, 'กรอกผิด', actorId: 2),
          throwsA(isA<ApiException>()),
        );
        store.voidArReceipt(transfer['id'] as int, 'เช็คเด้ง', actorId: 2);
        expect(outstanding(), before - 300);
      },
    );

    test(
      'ใบวางบิลรวบบิลที่ยังไม่วาง — ออกซ้ำไม่ได้, รับตามใบจนครบแล้วสถานะ paid',
      () {
        creditSale(1);
        creditSale(0.5);
        final total = outstanding();

        final note = store.createBillingNote({'customerId': b2b}, actorId: 2);
        expect(note['noteNo'], startsWith('BN'));
        expect(note['total'], total);
        expect((note['items'] as List), hasLength(2));
        expect(
          () => store.createBillingNote({'customerId': b2b}),
          throwsA(isA<ApiException>()),
          reason: 'บิลทุกใบอยู่ในใบวางบิลแล้ว',
        );

        store.createArReceipt({
          'customerId': b2b,
          'amount': total,
          'method': 'transfer',
          'billingNoteId': note['id'],
        }, actorId: cashier);

        final after = store.billingNoteDocument(note['id'] as int);
        expect(after['status'], 'paid');
        expect(after['remaining'], 0);
        expect(after['total'], total, reason: 'ยอดบนใบวางบิลคงเดิมเสมอ');
      },
    );

    test('ยกเลิกใบวางบิลแล้ววางบิลใหม่ได้', () {
      creditSale(1);
      final note = store.createBillingNote({'customerId': b2b}, actorId: 2);

      store.voidBillingNote(note['id'] as int, 'ที่อยู่ผิด', actorId: 2);

      final again = store.createBillingNote({'customerId': b2b}, actorId: 2);
      expect(again['noteNo'], isNot(note['noteNo']));
    });

    test('คืนเงินบิลขายเชื่อ (ลดหนี้) ได้ไม่เกินยอดที่ยังค้าง', () {
      final order = creditSale(1);
      final payment = store.payments.lastWhere(
        (row) => row['orderId'] == order['id'],
      );
      store.createArReceipt({
        'customerId': b2b,
        'amount': 1000.0,
        'method': 'transfer',
      }, actorId: cashier);
      final owed = outstanding();

      expect(
        () => store.refundPayment(
          paymentId: payment['id'] as int,
          amount: owed + 1,
          reason: 'ของเสีย',
          refundedById: 2,
        ),
        throwsA(isA<ApiException>()),
      );
      store.refundPayment(
        paymentId: payment['id'] as int,
        amount: owed,
        reason: 'ของเสีย',
        refundedById: 2,
      );
      expect(outstanding(), 0);
    });

    test(
      'อายุหนี้: เลยกำหนด 10 วัน → ช่อง 1–30 วัน และขึ้นเป็นยอดเกินกำหนด',
      () {
        AppClock.freeze(DateTime(2026, 9, 1, 12));
        creditSale(1);

        AppClock.freeze(DateTime(2026, 10, 11, 12));
        final summary = store.receivableCustomers().firstWhere(
          (row) => (row['customer'] as Map)['id'] == b2b,
        );

        expect(summary['overdue'], summary['outstanding']);
        expect((summary['aging'] as Map)['days1to30'], summary['outstanding']);
      },
    );
  });

  group('DemoStore ดอกเบี้ยผิดนัด / ใบลดหนี้ / อีเมลเอกสาร (tickets 21, 23)', () {
    const b2b = 900;
    const manager = 2;
    const cashier = 6;

    tearDown(AppClock.unfreeze);

    Map<String, dynamic> seededInvoice() =>
        ((store.receivableStatement(b2b)['invoices'] as List).single as Map)
            .cast<String, dynamic>();

    double outstanding() =>
        (store.receivableStatement(b2b)['outstanding'] as num).toDouble();

    test(
      'บิลที่ seed ไว้เลยกำหนด 15 วัน ผ่อนผัน 7 วัน → คิด 8 วันที่ 12% ต่อปี '
      'บวกเข้ายอดค้าง และกดซ้ำวันเดิมไม่ได้ดอกเบี้ยซ้ำ',
      () {
        AppClock.freeze(DateTime(2026, 9, 23, 12));
        store.reset();
        final invoice = seededInvoice();
        expect(invoice['dueDate'], '2026-09-08');
        final principal = (invoice['amount'] as num).toDouble();

        final preview = store.lateFeePreview(b2b);
        final line = (preview['items'] as List).single as Map;
        expect(line['periodFrom'], '2026-09-16');
        expect(line['periodTo'], '2026-09-23');
        expect(line['days'], 8);
        final expected = ((principal * 100) * 12 * 8 / 36500).round() / 100;
        expect(line['amount'], expected);

        final charge = store.createLateFee({
          'customerId': b2b,
        }, actorId: manager);
        expect(charge['chargeNo'], startsWith('LF69-'));
        expect(outstanding(), closeTo(principal + expected, 0.001));
        expect(seededInvoice()['interest'], expected);
        expect(
          () => store.createLateFee({'customerId': b2b}, actorId: manager),
          throwsA(
            isA<ApiException>().having((e) => e.statusCode, 'statusCode', 409),
          ),
        );

        // รอบถัดไปนับต่อจากวันที่คิดไปแล้ว
        AppClock.freeze(DateTime(2026, 10, 3, 12));
        final next = (store.lateFeePreview(b2b)['items'] as List).single as Map;
        expect(next['periodFrom'], '2026-09-24');
        expect(next['days'], 10);
      },
    );

    test('ยกเลิกใบแจ้งดอกเบี้ยที่ถูกชำระแล้วไม่ได้ จนกว่าจะยกเลิกใบเสร็จ', () {
      AppClock.freeze(DateTime(2026, 9, 23, 12));
      store.reset();
      final principal = (seededInvoice()['amount'] as num).toDouble();
      final charge = store.createLateFee({'customerId': b2b}, actorId: manager);
      final receipt = store.createArReceipt({
        'customerId': b2b,
        'amount': outstanding(),
        'method': 'transfer',
      }, actorId: cashier);
      expect(outstanding(), 0);

      expect(
        () =>
            store.voidLateFee(charge['id'] as int, 'ยกเว้น', actorId: manager),
        throwsA(isA<ApiException>()),
      );
      store.voidArReceipt(receipt['id'] as int, 'โอนผิด', actorId: manager);
      final voided = store.voidLateFee(
        charge['id'] as int,
        'ยกเว้นให้ลูกค้าประจำ',
        actorId: manager,
      );
      expect(voided['isVoided'], isTrue);
      expect(outstanding(), closeTo(principal, 0.001));
    });

    test('ยังไม่ตั้งอัตรา = คิดไม่ได้ และตั้งเกิน 15% ไม่ได้', () {
      store.updateSettings({'lateFeeAnnualRatePercent': 0.0});
      expect((store.lateFeePreview(b2b)['items'] as List), isEmpty);
      expect(
        () => store.createLateFee({'customerId': b2b}, actorId: manager),
        throwsA(isA<ApiException>()),
      );
      expect(
        () => store.updateSettings({'lateFeeAnnualRatePercent': 16.0}),
        throwsA(isA<ApiException>()),
      );
    });

    test(
      'ลดหนี้บิลขายเชื่อได้ใบลดหนี้ทุกครั้ง: มูลค่าเดิม มูลค่าที่ถูกต้อง VAT ของผลต่าง',
      () {
        final paymentId = seededInvoice()['paymentId'] as int;
        final original = (seededInvoice()['amount'] as num).toDouble();
        final note = store.createCreditNote({
          'paymentId': paymentId,
          'amount': 100.0,
          'reason': 'เนื้อชำรุด',
        }, actorId: manager);
        expect(note['noteNo'], startsWith('CN'));
        expect(note['originalAmount'], original);
        expect(note['correctAmount'], closeTo(original - 100, 0.001));
        expect(note['vatAmount'], greaterThan(0));
        expect(outstanding(), closeTo(original - 100, 0.001));

        // คืนเงินผ่านทางเดิม (หน้ารายละเอียดบิล) ก็ได้ใบลดหนี้เหมือนกัน
        final refund = store.refundPayment(
          paymentId: paymentId,
          amount: 50,
          reason: 'ส่งขาด',
          refundedById: manager,
        );
        expect(refund['creditNoteNo'], startsWith('CN'));
        final second = store.creditNoteDocument(refund['creditNoteId'] as int);
        expect(second['previousCredited'], 100.0);
        expect(
          (store.receivableStatement(b2b)['creditNotes'] as List),
          hasLength(2),
        );

        // บิลเงินสดออกใบลดหนี้ไม่ได้
        final cash = store.payments.firstWhere(
          (row) => row['method'] == PaymentMethod.cash,
        );
        expect(
          () => store.createCreditNote({
            'paymentId': cash['id'],
            'amount': 1.0,
            'reason': 'x',
          }, actorId: manager),
          throwsA(isA<ApiException>()),
        );
      },
    );

    test(
      'ส่งอีเมล (จำลอง): ใช้อีเมลลูกค้าเป็นค่าเริ่มต้น บันทึกประวัติ + audit '
      'เอกสารที่ยกเลิกส่งไม่ได้',
      () {
        final note = store.createBillingNote({
          'customerId': b2b,
        }, actorId: cashier);
        final sent = store.emailDocument(
          'billing_note',
          note['id'] as int,
          actorId: cashier,
        );
        final emails = sent['emails'] as List;
        expect((emails.single as Map)['to'], 'ap@soulbbq.example');
        expect(
          store.auditLogs.any(
            (log) => log['action'] == 'receivable.document_email',
          ),
          isTrue,
        );

        store.voidBillingNote(note['id'] as int, 'ออกผิด', actorId: manager);
        expect(
          () => store.emailDocument('billing_note', note['id'] as int),
          throwsA(
            isA<ApiException>().having((e) => e.statusCode, 'statusCode', 409),
          ),
        );

        store.updateCustomerCredit(b2b, {
          'creditLimit': 50000.0,
          'creditTermDays': 30,
          'email': '',
        });
        final other = store.createBillingNote({
          'customerId': b2b,
        }, actorId: cashier);
        expect(
          () => store.emailDocument('billing_note', other['id'] as int),
          throwsA(
            isA<ApiException>().having((e) => e.statusCode, 'statusCode', 400),
          ),
        );
      },
    );
  });

  group('DemoStore แต้มสะสมของบิลขายเชื่อ — ได้ตอนรับชำระครบ (DECISIONS #59)', () {
    const b2b = 900;
    const manager = 2;
    const cashier = 6;

    tearDown(AppClock.unfreeze);

    int balance() => (store.findCustomer(b2b)['pointsBalance'] as num).toInt();
    int pointsFor(double baht) =>
        (baht * 100).round() ~/ 2500; // seed: 25 บาทต่อ 1 แต้ม
    double r2(double baht) => (baht * 100).round() / 100;
    Map<String, dynamic> lastAudit(String action) =>
        store.auditLogs.lastWhere((row) => row['action'] == action);

    Map<String, dynamic> creditSale() {
      final order = store.createOrder(
        type: 'takeaway',
        guestCount: 1,
        customerId: b2b,
        items: [
          {'menuItemId': 26, 'quantity': 1, 'weightGrams': 1500},
        ],
      );
      store.pay(
        orderId: order['id'] as int,
        method: 'credit',
        amount: (order['total'] as num).toDouble(),
        cashierId: cashier,
      );
      return store.findOrder(order['id'] as int);
    }

    Map<String, dynamic> collect(double amount) => store.createArReceipt({
      'customerId': b2b,
      'amount': amount,
      'method': 'transfer',
    }, actorId: cashier);

    setUp(
      () => store.payments.removeWhere(
        (payment) => payment['method'] == PaymentMethod.credit,
      ),
    );

    test(
      'ลงบัญชี/จ่ายบางส่วนยังไม่ได้แต้ม — ชำระครบแล้วได้ ตรงกับสูตรเดียวกับบิลเงินสด',
      () {
        final order = creditSale();
        final total = (order['total'] as num).toDouble();
        expect(order['pointsEarned'], 0);
        expect(balance(), 0);

        collect(100);
        expect(balance(), 0);

        collect(r2(total - 100));
        expect(balance(), pointsFor(total));
        expect(
          store.findOrder(order['id'] as int)['pointsEarned'],
          pointsFor(total),
        );
        expect(
          (lastAudit('receivable.receipt')['metadata'] as Map)['pointsEarned'],
          pointsFor(total),
        );
      },
    );

    test(
      'ยกเลิกใบเสร็จ = ดึงแต้มคืนเท่าที่มี ไม่ติดลบ รับชำระใหม่ไม่ได้แต้มซ้ำ',
      () {
        final order = creditSale();
        final total = (order['total'] as num).toDouble();
        final earned = pointsFor(total);
        final receipt = collect(total);
        expect(balance(), earned);

        // ลูกค้าใช้แต้มไปเกือบหมดก่อนใบเสร็จถูกยกเลิก
        store.adjustCustomerPoints(b2b, -(earned - 3));
        store.voidArReceipt(receipt['id'] as int, 'เช็คเด้ง', actorId: manager);
        final audit = lastAudit('receivable.receipt_void')['metadata'] as Map;
        expect(audit['pointsRevoked'], 3);
        expect(audit['pointsNotRecovered'], earned - 3);
        expect(balance(), 0);

        collect(total);
        expect(balance(), 3, reason: 'ได้คืนเฉพาะส่วนที่ดึงกลับไป');
        expect(store.findOrder(order['id'] as int)['pointsEarned'], earned);
      },
    );

    test(
      'บิลที่ seed ไว้: จ่ายเท่ายอดบิลแต่ดอกเบี้ยยังค้าง = ยังไม่ครบ ยกเว้นดอกเบี้ยแล้วได้แต้ม',
      () {
        AppClock.freeze(DateTime(2026, 9, 23, 12));
        store.reset();
        final invoice =
            ((store.receivableStatement(b2b)['invoices'] as List).single as Map)
                .cast<String, dynamic>();
        final order = store.findOrder(invoice['orderId'] as int);
        final total = (order['total'] as num).toDouble();
        final charge = store.createLateFee({
          'customerId': b2b,
        }, actorId: manager);

        collect((invoice['amount'] as num).toDouble());
        expect(balance(), 0, reason: 'ดอกเบี้ยยังค้าง');
        store.voidLateFee(charge['id'] as int, 'ยกเว้นให้', actorId: manager);
        expect(
          balance(),
          pointsFor(total),
          reason: 'ดอกเบี้ยไม่นับเป็นยอดซื้อ',
        );
      },
    );

    test(
      'ลดหนี้แล้วจ่ายที่เหลือ: แต้มจากยอดสุทธิ — ลดหนี้ทั้งบิลไม่ได้แต้ม',
      () {
        final order = creditSale();
        final total = (order['total'] as num).toDouble();
        final paymentId =
            store.payments.lastWhere(
                  (row) => row['orderId'] == order['id'],
                )['id']
                as int;
        store.createCreditNote({
          'paymentId': paymentId,
          'amount': 200.0,
          'reason': 'ของชำรุด',
        }, actorId: manager);
        expect(balance(), 0);
        collect(r2(total - 200));
        expect(balance(), pointsFor(total - 200));

        final other = creditSale();
        final otherPayment =
            store.payments.lastWhere(
                  (row) => row['orderId'] == other['id'],
                )['id']
                as int;
        final before = balance();
        store.createCreditNote({
          'paymentId': otherPayment,
          'amount': (other['total'] as num).toDouble(),
          'reason': 'คืนของทั้งบิล',
        }, actorId: manager);
        expect(balance(), before);
      },
    );
  });
}
