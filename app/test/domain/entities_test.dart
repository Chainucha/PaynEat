// Copyright 2026 Suruch Chakrapeesirisuk
// SPDX-License-Identifier: Apache-2.0

import 'package:flutter_test/flutter_test.dart';
import 'package:payneat_pos/core/constants/app_constants.dart';
import 'package:payneat_pos/features/auth/domain/entities/user.dart';
import 'package:payneat_pos/features/menu/data/models/menu_item_model.dart';
import 'package:payneat_pos/features/order/domain/entities/order.dart';
import 'package:payneat_pos/features/order/domain/entities/order_item.dart';
import 'package:payneat_pos/features/order/data/models/order_model.dart';
import 'package:payneat_pos/features/payment/data/models/payment_model.dart';
import 'package:payneat_pos/features/table/domain/entities/dining_table.dart';

void main() {
  group('User (สิทธิ์ตามบทบาท)', () {
    User userWith(String role) => User(
      id: 1,
      name: 'ทดสอบ',
      username: 'test',
      role: role,
      isActive: true,
    );

    test('แอดมินและผู้จัดการมีสิทธิ์ระดับบริหาร', () {
      expect(userWith(UserRole.admin).isManagement, isTrue);
      expect(userWith(UserRole.manager).isManagement, isTrue);
      expect(userWith(UserRole.waiter).isManagement, isFalse);
    });

    test('ครัวไม่มีสิทธิ์รับออเดอร์หรือเก็บเงิน', () {
      final kitchen = userWith(UserRole.kitchen);

      expect(kitchen.isKitchen, isTrue);
      expect(kitchen.canTakeOrder, isFalse);
      expect(kitchen.canCollectPayment, isFalse);
      expect(kitchen.canSeeReports, isFalse);
    });

    test('ตัวย่อใน avatar มาจากอักษรตัวแรกของชื่อ', () {
      expect(userWith(UserRole.waiter).initials, 'ท');
    });
  });

  group('OrderItem (การเดินสถานะ)', () {
    OrderItem itemWith(String status) => OrderItem(
      id: 1,
      orderId: 1,
      name: 'ผัดกะเพรา',
      unitPrice: 75,
      quantity: 1,
      lineTotal: 75,
      status: status,
    );

    test('สถานะเดินตามลำดับ รอทำ → กำลังทำ → พร้อมเสิร์ฟ → เสิร์ฟแล้ว', () {
      expect(
        itemWith(OrderItemStatus.pending).nextStatus,
        OrderItemStatus.cooking,
      );
      expect(
        itemWith(OrderItemStatus.cooking).nextStatus,
        OrderItemStatus.ready,
      );
      expect(
        itemWith(OrderItemStatus.ready).nextStatus,
        OrderItemStatus.served,
      );
      expect(itemWith(OrderItemStatus.served).nextStatus, isNull);
    });

    test('แก้ไขได้เฉพาะรายการที่ครัวยังไม่เริ่มทำ', () {
      expect(itemWith(OrderItemStatus.pending).isEditable, isTrue);
      expect(itemWith(OrderItemStatus.cooking).isEditable, isFalse);
    });

    test(
      'ครัวเคยทำแล้วถูกเลิกทำกลับไปรอทำ ยังนับว่าเริ่มทำแล้ว แก้/ลบไม่ได้ (T05 #104)',
      () {
        final undone = OrderItemModel.fromJson({
          'id': 1,
          'name': 'ผัดกะเพรา',
          'status': OrderItemStatus.pending,
          'kitchenReached': OrderItemStatus.ready,
        });
        expect(undone.kitchenReached, OrderItemStatus.ready);
        expect(undone.kitchenStarted, isTrue);
        expect(undone.isEditable, isFalse);

        final untouched = OrderItemModel.fromJson({
          'id': 2,
          'name': 'ผัดกะเพรา',
          'status': OrderItemStatus.pending,
          'kitchenReached': null,
        });
        expect(untouched.kitchenStarted, isFalse);
        expect(untouched.isEditable, isTrue);
      },
    );
  });

  group('Order', () {
    Order orderWith({
      required String status,
      List<OrderItem> items = const [],
    }) => Order(
      id: 1,
      code: 'ORD-20260101-0001',
      type: OrderType.dineIn,
      status: status,
      subtotal: 100,
      total: 117.7,
      tableName: 'A1',
      items: items,
    );

    final activeItem = OrderItem(
      id: 1,
      orderId: 1,
      name: 'ผัดกะเพรา',
      unitPrice: 75,
      quantity: 2,
      lineTotal: 150,
      status: OrderItemStatus.pending,
    );
    final cancelledItem = OrderItem(
      id: 2,
      orderId: 1,
      name: 'ต้มยำ',
      unitPrice: 220,
      quantity: 1,
      lineTotal: 220,
      status: OrderItemStatus.cancelled,
    );

    test('ไม่นับรายการที่ยกเลิกเป็นจำนวนรายการในบิล', () {
      final order = orderWith(
        status: OrderStatus.open,
        items: [activeItem, cancelledItem],
      );

      expect(order.activeItems.length, 1);
      expect(order.totalQuantity, 2);
    });

    test('ส่งครัวได้เฉพาะออเดอร์ที่ยังไม่ส่งและมีรายการอาหาร', () {
      expect(
        orderWith(
          status: OrderStatus.open,
          items: [activeItem],
        ).canSendToKitchen,
        isTrue,
      );
      expect(orderWith(status: OrderStatus.open).canSendToKitchen, isFalse);
      expect(
        orderWith(
          status: OrderStatus.inKitchen,
          items: [activeItem],
        ).canSendToKitchen,
        isFalse,
      );
    });
  });

  group('DiningTable', () {
    test('โต๊ะที่มีออเดอร์เปิดอยู่ต้องรายงานว่ามีบิลค้าง', () {
      const table = DiningTable(
        id: 1,
        name: 'A1',
        zone: 'โซนในร้าน',
        seats: 4,
        status: TableStatus.occupied,
        currentOrder: TableOrderSummary(
          id: 9,
          code: 'ORD-1',
          status: OrderStatus.inKitchen,
          total: 500,
        ),
      );

      expect(table.hasOpenOrder, isTrue);
      expect(table.isAvailable, isFalse);
      expect(table.statusLabel, 'มีลูกค้า');
    });
  });

  group('PaymentSummary (T06 #82)', () {
    test('อ่านยอดคืนเงินจาก backend และรวมยอดที่คืนแล้วแยกตาม payment', () {
      final summary = PaymentSummaryModel.fromJson({
        'orderId': 1,
        'total': 100.05,
        'paid': 30,
        'refunded': 70,
        'remaining': 70.05,
        'payments': [
          {'id': 1, 'orderId': 1, 'method': 'cash', 'amount': 50},
          {'id': 2, 'orderId': 1, 'method': 'qr', 'amount': 50},
        ],
        'refunds': [
          {'id': 9, 'paymentId': 1, 'orderId': 1, 'amount': 50, 'reason': 'a'},
          {'id': 10, 'paymentId': 2, 'orderId': 1, 'amount': 20, 'reason': 'b'},
        ],
      });
      expect(summary.paid, 30);
      expect(summary.refunded, 70);
      expect(summary.remaining, 70.05);
      expect(summary.refundedFor(1), 50);
      expect(summary.refundedFor(2), 20);
      expect(summary.refundedFor(3), 0);
      expect(summary.isPartiallyPaid, isTrue);
    });

    test('backend รุ่นเก่าที่ยังไม่ส่งยอดคืนเงิน → ถือว่าไม่มีการคืน', () {
      final summary = PaymentSummaryModel.fromJson({
        'orderId': 1,
        'total': 100,
        'paid': 0,
        'remaining': 100,
      });
      expect(summary.refunded, 0);
      expect(summary.refunds, isEmpty);
    });
  });

  group('SplitPreview (T10 #83)', () {
    test(
      'อ่านโหมด VAT รวมในราคาและส่วนปรับจาก backend ตัวเลขรวมได้ยอดที่เก็บ',
      () {
        final preview = SplitPreviewModel.fromJson({
          'orderId': 1,
          'itemIds': [1, 2],
          'subtotal': 480,
          'discountAmount': 240,
          'serviceCharge': 24,
          'vat': 18.48,
          'vatIncluded': false,
          'adjustment': -100,
          'total': 182.48,
          'remaining': 182.48,
          'isLastBatch': true,
        });
        expect(preview.vatIncluded, isFalse);
        expect(preview.adjustment, -100);
        expect(
          preview.subtotal -
              preview.discountAmount +
              preview.serviceCharge +
              preview.vat +
              preview.adjustment,
          closeTo(preview.total, 0.001),
        );
      },
    );

    test('backend รุ่นเก่าที่ยังไม่ส่งสองค่านี้ → VAT แยก ไม่มีส่วนปรับ', () {
      final preview = SplitPreviewModel.fromJson({'orderId': 1, 'total': 10});
      expect(preview.vatIncluded, isFalse);
      expect(preview.adjustment, 0);
    });
  });

  group('MenuItemModel (เมนูฝั่งลูกค้า QR)', () {
    test(
      'อ่านเมนูที่มีแค่ฟิลด์ของหน้า QR ได้ครบ ฟิลด์ฝั่งพนักงานที่ไม่ได้ส่งมาใช้ค่าเริ่มต้น',
      () {
        // ชุดคีย์เดียวกับ public-order.service.js#toPublicMenuItem
        final item = MenuItemModel.fromJson({
          'id': 7,
          'categoryId': 2,
          'name': 'ผัดกะเพราหมูสับ',
          'nameEn': 'Basil Pork',
          'description': null,
          'price': 75,
          'imageUrl': null,
          'isAvailable': true,
          'isRecommended': true,
          'optionGroups': [
            {
              'id': 3,
              'name': 'เพิ่มท็อปปิ้ง',
              'minSelect': 1,
              'maxSelect': 1,
              'isRequired': true,
              'options': [
                {
                  'id': 10,
                  'name': 'ไม่เพิ่ม',
                  'priceDelta': 0,
                  'isDefault': true,
                },
                {
                  'id': 11,
                  'name': 'ไข่ดาว',
                  'priceDelta': 15,
                  'isDefault': false,
                },
              ],
            },
          ],
        });

        expect(item.displayName, isNotEmpty);
        expect(item.price, 75);
        expect(item.isRecommended, isTrue);
        expect(item.requiresSelection, isTrue);
        expect(item.optionGroups.single.options.last.priceDelta, 15);
        expect(item.optionGroups.single.defaults.single.id, 10);
        expect(item.ingredients, isEmpty);
        expect(item.soldByWeight, isFalse);
        expect(item.barcode, isNull);
        expect(item.scalePlu, isNull);
      },
    );
  });
}
